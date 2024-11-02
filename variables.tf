variable "region" {
  default = "eu-north-1"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "subnet_count" {
  default = 2
}

variable "cluster_name" {
  default = "ken-cluster"
}

variable "ssh_key_name" {
  description = "SSH key name for EC2 instances"
}