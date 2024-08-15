terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      version = "4.34.0"
    }
  }
  backend "s3" {
    bucket = "onehouse-customer-bucket-4d350f4e"
    key    = "onboarding/terraform/preboarding/onehouse.tfstate"
    region = "us-west-2"
  }
}

provider "aws" {
  region = "us-west-2"
}