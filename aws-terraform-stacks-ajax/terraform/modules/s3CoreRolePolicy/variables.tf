variable "productFlow" {
  type        = string
  description = "Selected product flow by customer"
}

variable "requestId" {
  type        = string
  description = "The requestId of the onehouse customer account"
}

variable "s3BucketArns" {
  type        = list(any)
  description = "List of s3 bucket arns you want onehouse to access"
  default     = []
}