# Deploy AWS EKS Cluster&#x20;

# (1 Master, 2 Workers) with Custom VPC using Terraform

---

## Goal:

Create a **highly available EKS cluster** with:

- A custom **VPC**
- Two **private subnets** in **different Availability Zones**
- A **public subnet** for NAT Gateway
- **2 worker nodes** using a managed **Node Group**

---

## ✅ Prerequisites

| Tool      | Install Link                                                                    |
| --------- | ------------------------------------------------------------------------------- |
| Terraform | [Download](https://developer.hashicorp.com/terraform/downloads)                 |
| AWS CLI   | [Download](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) |
| kubectl   | [Download](https://kubernetes.io/docs/tasks/tools/)                             |

### 🛠 Configure AWS credentials

```bash
aws configure
```

---

## Project Structure

```
multi-node-eks-cluster/
├── main.tf                  # Terraform provider
├── variables.tf             # Input variables
├── network.tf               # VPC, subnets, route tables, NAT, SG
├── iam.tf                   # IAM roles for EKS & nodes
├── eks-cluster.tf           # Control plane
├── node-group.tf            # Worker nodes
├── outputs.tf               # Helpful commands and cluster info
```

---

## main.tf

```hcl
provider "aws" {
  region = "us-east-1"
}

```

---

## variables.tf

```hcl
variable "cluster_name" {
  default = "my-cluster"
}
```

---

## network.tf

```hcl
resource "aws_vpc" "dev" {
  cidr_block = "10.0.0.0/16"
  tags = { Name = "test-vpc" }
}

resource "aws_subnet" "dev-pub" {
  vpc_id                  = aws_vpc.dev.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  tags = { Name = "public-subnet" }
}

resource "aws_subnet" "dev-pvt-1" {
  vpc_id                  = aws_vpc.dev.id
  cidr_block              = "10.0.4.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false
  tags = { Name = "private-subnet-1" }
}

resource "aws_subnet" "dev-pvt-2" {
  vpc_id                  = aws_vpc.dev.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = false
  tags = { Name = "private-subnet-2" }
}

resource "aws_internet_gateway" "dev" {
  vpc_id = aws_vpc.dev.id
  tags   = { Name = "internet-gateway" }
}

resource "aws_eip" "dev-eip" {
  domain = "vpc"
  tags   = { Name = "nat-eip" }
}

resource "aws_nat_gateway" "dev" {
  subnet_id     = aws_subnet.dev-pub.id
  allocation_id = aws_eip.dev-eip.id
  tags          = { Name = "nat-gateway" }
}

resource "aws_route_table" "dev-pub" {
  vpc_id = aws_vpc.dev.id
  tags   = { Name = "RT-public" }

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dev.id
  }
}

resource "aws_route_table" "dev-pvt" {
  vpc_id = aws_vpc.dev.id
  tags   = { Name = "RT-private" }

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.dev.id
  }
}

resource "aws_route_table_association" "pub" {
  subnet_id      = aws_subnet.dev-pub.id
  route_table_id = aws_route_table.dev-pub.id
}

resource "aws_route_table_association" "pvt-1" {
  subnet_id      = aws_subnet.dev-pvt-1.id
  route_table_id = aws_route_table.dev-pvt.id
}

resource "aws_route_table_association" "pvt-2" {
  subnet_id      = aws_subnet.dev-pvt-2.id
  route_table_id = aws_route_table.dev-pvt.id
}

resource "aws_security_group" "dev-sg" {
  vpc_id = aws_vpc.dev.id
  tags   = { Name = "terra-SG" }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

---

## iam.tf

```hcl
resource "aws_iam_role" "cluster_role" {
  name = "eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role       = aws_iam_role.cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "node_role" {
  name = "eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "worker_node_policy" {
  role       = aws_iam_role.node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "cni_policy" {
  role       = aws_iam_role.node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "registry_policy" {
  role       = aws_iam_role.node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}
```

---

## eks-cluster.tf

```hcl
locals {
  private_subnets = [
    aws_subnet.dev-pvt-1.id,
    aws_subnet.dev-pvt-2.id
  ]
}

resource "aws_eks_cluster" "cluster" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster_role.arn

  vpc_config {
    subnet_ids              = local.private_subnets
    security_group_ids      = [aws_security_group.dev-sg.id]
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  depends_on = [aws_iam_role_policy_attachment.cluster_policy]
}
```

---

## node-group.tf

```hcl
resource "aws_eks_node_group" "node_group" {
  cluster_name    = aws_eks_cluster.cluster.name
  node_group_name = "custom-node-group"
  node_role_arn   = aws_iam_role.node_role.arn
  subnet_ids      = local.private_subnets

  scaling_config {
    desired_size = 2
    max_size     = 2
    min_size     = 1
  }

  instance_types = ["t3.micro"]
}
```

---

## outputs.tf

```hcl
output "cluster_endpoint" {
  value = aws_eks_cluster.cluster.endpoint
}

output "cluster_name" {
  value = aws_eks_cluster.cluster.name
}
```
---

##  Deployment Steps

### 1. Initialize Terraform

```bash
terraform init
```

### 2. Preview the plan

```bash
terraform plan
```

### 3. Apply the configuration

```bash
terraform apply -auto-approve
```

>  This may take 10–15 minutes.

---

### 4. Update kubeconfig

```bash
aws eks --region us-east-1 update-kubeconfig --name my-cluster
```

### 5. Verify the nodes

```bash
kubectl get nodes
```

You should see **2 worker nodes** in `Ready` state.


---



