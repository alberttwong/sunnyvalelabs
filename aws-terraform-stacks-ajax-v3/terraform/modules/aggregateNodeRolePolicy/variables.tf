
variable "requestId" {
  description = "The request ID of the cluster"
  type        = string
}

variable "featureFlags" {
  description = "The feature flags for different configs"
  type        = map(bool)
}
