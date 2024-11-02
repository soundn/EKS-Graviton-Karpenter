locals {
  irsa_name = "karpenter-irsa"
}

resource "aws_iam_instance_profile" "karpenter" {
  name = "KarpenterNodeInstanceProfile-${var.cluster_name}"
  role = aws_iam_role.karpenter_node.name
}

# IAM role for Karpenter nodes
resource "aws_iam_role" "karpenter_node" {
  name = "karpenter-node-role-${var.cluster_name}"

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

# Karpenter Controller Policy
resource "aws_iam_policy" "karpenter_controller" {
  name = "karpenter-policy-${var.cluster_name}"

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
    - key: karpenter.sh/capacity-type
      operator: In
      values: ["spot", "on-demand"]
    - key: kubernetes.io/arch
      operator: In
      values: ["amd64", "arm64"]  # Enable both x86 and ARM architectures
    - key: kubernetes.io/os
      operator: In
      values: ["linux"]
  limits:
    resources:
      cpu: "100"
      memory: 400Gi
  provider:
    subnetSelector:
      karpenter.sh/discovery: ${var.cluster_name}
    securityGroupSelector:
      karpenter.sh/discovery: ${var.cluster_name}
    instanceProfile: ${aws_iam_instance_profile.karpenter.name}
    tags:
      karpenter.sh/discovery: ${var.cluster_name}
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
    karpenter.sh/discovery: ${var.cluster_name}
  securityGroupSelector:
    karpenter.sh/discovery: ${var.cluster_name}
  instanceProfile: ${aws_iam_instance_profile.karpenter.name}
  tags:
    karpenter.sh/discovery: ${var.cluster_name}
  blockDeviceMappings:
    - deviceName: /dev/xvda
      ebs:
        volumeSize: 50Gi
        volumeType: gp3
        deleteOnTermination: true
YAML
}