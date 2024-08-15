variable "requestId" {
  type        = string
  description = "The requestId of the onehouse customer account"
}

variable "s3DataSourceBucketArns" {
  type        = list(string)
  description = "List of data source s3 bucket arns"
}
