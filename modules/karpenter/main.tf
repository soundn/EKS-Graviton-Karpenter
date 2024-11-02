resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

locals {
  name_suffix = random_string.suffix.result
}

resource "aws_iam_role" "karpenter_node" {
  name = "karpenter-node-role-${var.cluster_name}-${local.name_suffix}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_instance_profile" "karpenter" {
  name = "KarpenterNodeInstanceProfile-${var.cluster_name}-${local.name_suffix}"
  role = aws_iam_role.karpenter_node.name
}

resource "aws_iam_policy" "karpenter_controller" {
  name = "karpenter-policy-${var.cluster_name}-${local.name_suffix}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateLaunchTemplate",
          "ec2:CreateFleet",
          "ec2:RunInstances",
          "ec2:CreateTags",
          "iam:PassRole",
          "ec2:TerminateInstances",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeInstances",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeAvailabilityZones",
          "ssm:GetParameter"
        ]
        Resource = ["*"]
      }
    ]
  })
}

# Karpenter Provisioner
resource "kubectl_manifest" "karpenter_provisioner" {
  yaml_body = <<-YAML
apiVersion: karpenter.sh/v1alpha5
kind: Provisioner
metadata:
  name: default
spec:
  requirements:
    - key: "node.kubernetes.io/instance-type"
      operator: In
      values: ["t4g.small", "t4g.medium", "c6g.large", "m6g.large"]  # Graviton instance types
    - key: "kubernetes.io/arch"
      operator: In
      values: ["arm64"]  # Graviton architecture
    - key: "karpenter.sh/capacity-type"
      operator: In
      values: ["spot", "on-demand"]
  limits:
    resources:
      cpu: "100"
      memory: "100Gi"
  providerRef:
    name: default
  ttlSecondsAfterEmpty: 30
YAML
}

# Karpenter Node Template
resource "kubectl_manifest" "karpenter_node_template" {
  yaml_body = <<-YAML
apiVersion: karpenter.k8s.aws/v1alpha1
kind: AWSNodeTemplate
metadata:
  name: default
spec:
  subnetSelector:
    karpenter.sh/discovery: "${var.cluster_name}"
  securityGroupSelector:
    karpenter.sh/discovery: "${var.cluster_name}"
  instanceProfile: ${aws_iam_instance_profile.karpenter.name}
  tags:
    karpenter.sh/discovery: "${var.cluster_name}"
  blockDeviceMappings:
    - deviceName: /dev/xvda
      ebs:
        volumeSize: 100Gi
        volumeType: gp3
        deleteOnTermination: true
  userData: |
    MIME-Version: 1.0
    Content-Type: multipart/mixed; boundary="BOUNDARY"

    --BOUNDARY
    Content-Type: text/x-shellscript; charset="us-ascii"

    #!/bin/bash
    /etc/eks/bootstrap.sh ${var.cluster_name} \
      --container-runtime containerd \
      --kubelet-extra-args '--max-pods=110'

    --BOUNDARY--
YAML
}

# Attach required policies to karpenter node role
resource "aws_iam_role_policy_attachment" "karpenter_ssm_policy" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "karpenter_eks_worker_policy" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "karpenter_eks_cni_policy" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "karpenter_ecr_policy" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Tag subnets for Karpenter auto-discovery
resource "aws_ec2_tag" "subnet_tags" {
  count       = length(var.subnet_ids)
  resource_id = var.subnet_ids[count.index]
  key         = "karpenter.sh/discovery"
  value       = var.cluster_name
}

# Tag security groups for Karpenter auto-discovery
resource "aws_ec2_tag" "security_group_tags" {
  resource_id = var.vpc_id
  key         = "karpenter.sh/discovery"
  value       = var.cluster_name
}