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

variable "isS3DataLoadEnabled" {
  type        = bool
  description = "Is s3 data load enabled?"
}

variable "isAscpEnabled" {
  type        = bool
  description = "Is ASCP enabled?"
}
