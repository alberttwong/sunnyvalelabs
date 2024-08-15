variable "requestId" {
  description = "The request ID"
  type        = string
}

variable "ec2_instance_type" {
  description = "The type of EC2 instance to use for the bastion host"
  type        = string
  default     = "m5.large"
}

variable "vpc_id" {
  description = "VPC ID in which cluster will be created"
  type        = string
}

variable "private_subnet_id" {
  description = "The ID of the private subnet"
  type        = string
}
