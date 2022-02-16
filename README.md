# Status
- [X] VPC w/ CIDRs, DNS, GWs, and AZs
- [X] 3 x /24 private subnets
- [X] EKS Cluster w/ 3 workers
- [ ] ALB
- [X] Deployment for search-api
- [X] Deployment for graph-api
- [ ] Detailed Instructions

# altanaexercise

Using Terraform Configuration Language, or one of the Terraform CDK languages, create a workspace for AWS with the following resources:
-	A VPC with a 10.0.0.0/16 CIDR, DNS support, an Internet Gateway, and NAT Gateways for 3 availability zones
-	3 /24 private subnets associated with the above NAT Gateways
-	A single EKS cluster in all subnets, with public endpoint access enabled
-	AWS Load Balancer controller with Public-facing ALB
 
Additionally, we'll want to deploy an application to the EKS Cluster. Using Terraform, Helm, or another templating tool, please write a script that produces Kubernetes manifests to deploy the following:
 
-	A Deployment named search-api running a bare nginx container, a corresponding Service targeted to port 80, and a corresponding Ingress for host search.altana.ai
-	A Deployment named graph-api running a bare nginx container, a corresponding Service targeted to port 80, and a corresponding Ingress for host graph.altana.ai

Your deliverable should be a git repository (zipped and attached) with the following requirements:
 
-	Your Terraform scripts or configs
-	Your Kubernetes scripts or manifests
-	A README describing how to run your scripts, install prerequisites, etc
-	Clean code that's easy to read and reason about. It doesn't need to be performant, but it should be simple and correct.

# PreRequisites
choco install awscli
choco install kubernetes-cli
aws configure



