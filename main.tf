################################################### Providers #########################################################
# Declare version version pre-reqs

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.1.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "3.1.0"
    }

    local = {
      source  = "hashicorp/local"
      version = "2.1.0"
    }

    null = {
      source  = "hashicorp/null"
      version = "3.1.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.8.0"
    }
  }

  required_version = ">= 0.14"
}


#################################################### VPC ##############################################
# Setup Networking

variable "region" {
  default     = "us-east-2"
  description = "AWS region"
}

provider "aws" {
  region = var.region
}

data "aws_availability_zones" "available" {}

locals {
  cluster_name = "company-eks-${random_string.suffix.result}"
}

resource "random_string" "suffix" {
  length  = 8
  special = false
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.12.0"

  name                 = "company-eks-vpc"
  cidr                 = "10.0.0.0/16"
  azs                  = data.aws_availability_zones.available.names
  private_subnets      = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets       = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }
}

############################################ Security Groups ####################################
# Create Security Groups for accessing the VPC

resource "aws_security_group" "worker_group_mgmt_one" {
  name_prefix = "worker_group_mgmt_one"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    cidr_blocks = [
      "10.0.0.0/8",
    ]
  }
}


resource "aws_security_group" "all_worker_mgmt" {
  name_prefix = "all_worker_management"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    cidr_blocks = [
      "10.0.0.0/8",
      "172.16.0.0/12",
      "192.168.0.0/16",
    ]
  }
}


#################################################### EKS CLUSTER ########################################################
# Build EKS cluster

module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "18.7.1"
  cluster_name    = "company-eks-cluster"
  cluster_version = "1.21"
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets


  # EKS Managed Node Group(s)
  eks_managed_node_group_defaults = {
    ami_type               = "AL2_x86_64"
    disk_size              = 50
    instance_types         = ["t2.small"]
    vpc_security_group_ids = [aws_security_group.worker_group_mgmt_one.id]

  }

  eks_managed_node_groups = {
    worker-group-1 = {
      min_size     = 3
      max_size     = 3
      desired_size = 3
      instance_types = ["t2.small"]
    }
  }
}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

################################ DEPLOY APPS on K8s ############################################# 
# Normally this portion should be split out for future terraform deployments and decoupled from underlying cluster.
# included here for simplicity.

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  token                  = data.aws_eks_cluster_auth.cluster.token
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
}

resource "kubernetes_deployment" "deploy_search-api" {
  metadata {
    name = "search-api"
    labels = {
      test = "search-api"
    }
  }

  spec {
    replicas = 3

    selector {
      match_labels = {
        test = "search-api"
      }
    }

    template {
      metadata {
        labels = {
          test = "search-api"
        }
      }

      spec {
        container {
          image = "nginx:1.20.2"
          name  = "search-api"
          }
        }
      }
    }

}

resource "kubernetes_service" "service_search-api" {
  metadata {
    name = "search-api"
  }
  spec {
    selector = {
      test = "search-api"
    }
    port {
      port        = 8080
      target_port = 80
    }

    type = "LoadBalancer"
  }
}

resource "kubernetes_deployment" "deploy_graph-api" {
  metadata {
    name = "graph-api"
    labels = {
      test = "graph-api"
    }
  }

  spec {
    replicas = 3

    selector {
      match_labels = {
        test = "graph-api"
      }
    }

    template {
      metadata {
        labels = {
          test = "graph-api"
        }
      }

      spec {
        container {
          image = "nginx:1.20.2"
          name  = "graph-api"
          }
        }
      }
    }
}

resource "kubernetes_service" "service_graph-api" {
  metadata {
    name = "graph-api"
  }
  spec {
    selector = {
      test = "graph-api"
    }
    port {
      port        = 8081
      target_port = 80
    }

    type = "LoadBalancer"
  }
}


#################################################### ALB LoadBal ########################################################
# Build ALB and point to K8s services
# RAN OUT OF TIME
# Research Notes:
# - Need helm? combo of helm + alb?
# Research Examples:
# https://github.com/DNXLabs/terraform-aws-eks-lb-controller
# https://github.com/GSA/terraform-kubernetes-aws-load-balancer-controller

