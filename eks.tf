# ================= Cluster IAM role =================
# The EKS control plane assumes this role to manage AWS resources (ENIs, LBs, etc.)
resource "aws_iam_role" "cluster" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# ================= EKS cluster =================
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  version  = var.kubernetes_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    # Control plane ENIs go in all 4 subnets; nodes only in private (see node group)
    subnet_ids              = concat(aws_subnet.private[*].id, aws_subnet.public[*].id)
    endpoint_private_access = true
    endpoint_public_access  = true # so kubectl works from your laptop
  }

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true # whoever runs apply gets cluster-admin
  }

  depends_on = [aws_iam_role_policy_attachment.cluster_policy]

  tags = {
    Name = var.cluster_name
  }
}

# ================= Node IAM role =================
# Worker EC2 instances assume this role
resource "aws_iam_role" "node" {
  name = "${var.cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "node" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",          # join the cluster
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",               # VPC CNI assigns pod IPs
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly", # pull images from ECR
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",       # SSM Session Manager access
  ])

  role       = aws_iam_role.node.name
  policy_arn = each.value
}

# ================= Managed node group =================
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-nodes"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = aws_subnet.private[*].id # workers stay private, egress via NAT

  ami_type       = "AL2023_x86_64_STANDARD"
  capacity_type  = "ON_DEMAND"
  instance_types = var.node_instance_types

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  update_config {
    max_unavailable = 1
  }

  # Let the cluster autoscaler / manual scaling change desired_size without Terraform drift
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }

  depends_on = [
    aws_iam_role_policy_attachment.node,
    aws_route_table_association.private, # nodes need NAT egress to register
  ]
}


resource "aws_eks_addon" "pod_identity" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "eks-pod-identity-agent"
}

resource "aws_eks_pod_identity_association" "example" {
  cluster_name    = aws_eks_cluster.main.name
  namespace       = "default"
  service_account = "my-app"
  role_arn        = aws_iam_role.my_app.arn
}

resource "aws_iam_role" "my_app" {
  name = "${var.cluster_name}-my-app"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "my_app_s3" {
  role       = aws_iam_role.my_app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}