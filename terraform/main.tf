provider "aws" {
  region = "eu-central-1"
  version = "~> 5.9"
}

resource "aws_vpc" "huso_vpc" {
  cidr_block = "12.0.0.0/16"

  tags = {
    Name        = "${var.resource_name} VPC"
    Environment = "Production"
    Project     = "Project-${var.resource_name}"
  }
}

resource "aws_subnet" "public_subnet" {
  count                   = length(data.aws_availability_zones.available.names)
  vpc_id                  = aws_vpc.huso_vpc.id
  cidr_block              = "12.0.${count.index}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.resource_name}-public-subnet-${count.index}"
    Environment = "Production-${count.index}"
    Project     = "Project-${var.resource_name}-${count.index}"

    "kubernetes.io/role/elb" = "1"
    "kubernetes.io/cluster/${var.resource_name}" = "owned"
  }
}

resource "aws_subnet" "private_subnet" {
  count             = length(data.aws_availability_zones.available.names)
  vpc_id            = aws_vpc.huso_vpc.id
  cidr_block        = "12.0.${length(data.aws_availability_zones.available.names) + count.index}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name        = "${var.resource_name}-private-subnet-${count.index}"
    Environment = "Production-${count.index}"
    Project     = "Project-${var.resource_name}-${count.index}"

    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/${var.resource_name}" = "owned"
  }
}

resource "aws_eip" "eip" {
  domain = "vpc"
  tags = {
    Name        = "EIP for NAT Gateway ${var.resource_name}"
    Environment = "Production"
    Project     = "Project-${var.resource_name}"
  }
}

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.public_subnet[0].id

  tags = {
    Name        = "NAT Gateway ${var.resource_name}"
    Environment = "Production"
    Project     = "Project-${var.resource_name}"
  }
}

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.huso_vpc.id

  tags = {
    Name        = "Internet Gateway ${var.resource_name}"
    Environment = "Production"
    Project     = "Project-${var.resource_name}"
  }
}

resource "aws_route_table" "public_route_table_internet_gateway" {
  vpc_id = aws_vpc.huso_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }

  tags = {
    Name        = "Public Route Table Internet Gateway ${var.resource_name}"
    Environment = "Production"
    Project     = "Project-${var.resource_name}"
  }
}

resource "aws_route_table" "private_route_table_nat_gateway" {
  vpc_id = aws_vpc.huso_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }

  tags = {
    Name        = "Private Route Table Nat Gateway ${var.resource_name}"
    Environment = "Production"
    Project     = "Project-${var.resource_name}"
  }
}

// Associations
resource "aws_route_table_association" "public_subnet_route_table_association" {
 subnet_id      = aws_subnet.public_subnet[0].id
 route_table_id = aws_route_table.public_route_table_internet_gateway.id
}

resource "aws_route_table_association" "private_subnet_route_table_association" {
 subnet_id      = aws_subnet.private_subnet[0].id
 route_table_id = aws_route_table.private_route_table_nat_gateway.id
}

resource "aws_db_instance" "postgresql_instance" {
    allocated_storage = var.db["allocated_storage"]
  engine            = var.db["engine"]
  engine_version    = var.db["engine_version"]
  instance_class    = var.db["instance_class"]
  identifier        = lower("${var.resource_name}postgresqlinstance")
  username          = var.db["username"]
  password          = var.db["password"]

  tags = {
    Name        = "Postgresql Instance ${var.resource_name}"
    Environment = "Production"
    Project     = "Project-${var.resource_name}"
  }
}

// ------------------ROLES------------------

resource "aws_iam_role" "eks_access_role" {
  name = "${var.resource_name}_eks_access_role"

  assume_role_policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "eks.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        },
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": [
                    "arn:aws:iam::426102426245:root",
                    "arn:aws:iam::164400546917:root"
                ]
            },
            "Action": "sts:AssumeRole"
        }
    ]
  }
  POLICY

  tags = {
    Name        = "EKS Cluster IAM Role ${var.resource_name}"
    Environment = "Production"
    Project     = "Project-${var.resource_name}"
  }
}

resource "aws_iam_policy" "cluster_autoscaling" {
  name = "${var.resource_name}_autoscaling_role"

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "autoscaling:DescribeAutoScalingGroups",
                "autoscaling:DescribeAutoScalingInstances",
                "autoscaling:DescribeLaunchConfigurations",
                "autoscaling:DescribeScalingActivities",
                "autoscaling:DescribeTags",
                "ec2:DescribeInstanceTypes",
                "ec2:DescribeLaunchTemplateVersions"
            ],
            "Resource": [
                "*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "autoscaling:SetDesiredCapacity",
                "autoscaling:TerminateInstanceInAutoScalingGroup",
                "ec2:DescribeImages",
                "ec2:GetInstanceTypesFromInstanceRequirements",
                "eks:DescribeNodegroup"
            ],
            "Resource": [
                "*"
            ]
        }
    ]
  }
  POLICY

  tags = {
    Name        = "Auto Scaling IAM Role ${var.resource_name}"
    Environment = "Production"
    Project     = "Project-${var.resource_name}"
  }
}

// -----------EKS cluster access role attachment-----------
/*//-----TESTING-----
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_access_role.name
}


resource "aws_iam_role_policy_attachment" "autoscaling_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AutoScalingFullAccess"
  role       = aws_iam_role.eks_autoscaling_role.name
}
*/


//------------------EKS------------------
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = "${var.resource_name}-cluster-new-1"
  cluster_version = "1.24"

  cluster_endpoint_public_access  = true

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  vpc_id                   = aws_vpc.huso_vpc.id
  subnet_ids               = aws_subnet.public_subnet[*].id
  control_plane_subnet_ids = aws_subnet.private_subnet[*].id

  // EKS Managed Node Group(s)
  eks_managed_node_group_defaults = {
    instance_types = ["t2.medium"]
  }

  eks_managed_node_groups = {
    green = {
      min_size     = 1
      max_size     = 3
      desired_size = 1

      instance_types = ["t2.medium"]
      capacity_type  = "ON_DEMAND"

      iam_role_additional_policies = {
        additional = aws_iam_policy.cluster_autoscaling.arn
      }
      //aws_iam_role.eks_access_role.name
      
    }
  }

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}
