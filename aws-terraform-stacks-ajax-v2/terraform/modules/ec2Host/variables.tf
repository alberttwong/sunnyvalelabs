variable "requestId" {
  description = "The request ID"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID in which cluster is created"
  type        = string
}

variable "private_subnet_id" {
  description = "The ID of the private subnet"
  type        = string
}

variable "instances" {
  description = "Map containing configurations for bastion and diagnose hosts"
  type = map(object({
    enabled      = bool
    instanceType = string
  }))
}
