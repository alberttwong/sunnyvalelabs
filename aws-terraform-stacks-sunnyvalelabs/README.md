# Create onehouse stack using terraform on AWS
To onboard to Onehouse, customers running on AWS need to create a set of IAM roles.
These terraform scripts help you do that.

## Prerequisites

1. A new s3 bucket e.g. `onehouse-customer-bucket-<REQUEST_ID_PREFIX>` in the same project to store terraform state and other configurations.
2. An AWS account with necessary permissions to run terraform scripts with role/policy creation.

## How to run?

1. Change to terraform directory
```
cd terraform
```

2. Modify the `backend.tf` file to update the backend s3 `bucket` name with <RequestIdPrefix> and <Region> where terraform state will be stored
```
terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      version = "4.34.0"
    }
  }
  backend "s3" {
    bucket = "onehouse-customer-bucket-<RequestIdPrefix>"
    key    = "terraform/preboarding"
    region = "<Region>"
  }
}

provider "aws" {
  region = "<Region>"
}

```
3. Configure `config.yaml` with provided information - 

e.g.
```
requestId: ffffffff-ffff-ffff-ffff-ffffffffffff
environment: production
s3_bucket_arns:
  - arn:aws:s3:::acme-data-lake
```


4. Then, using role/user account on AWS with necessary permissions,

There are two ways to run terraform scripts -

   1. Export the AWS Credentials and then run terraform -
      1. Export the AWS credentials to be used by terraform
      ```
       export AWS_ACCESS_KEY_ID=<AWS_ACCESS_KEY_ID>
       export AWS_SECRET_ACCESS_KEY=<AWS_SECRET_ACCESS_KEY>
       export AWS_SESSION_TOKEN=<AWS_SESSION_TOKEN>
      ``` 
       2. Run terraform - 
       ```
      cd ../
      ./install.sh
      ```
   2. Create the AWS profile and pass it to the script -
       1. Create the AWS profile in `~/.aws/credentials`
       ```
       Eg: 
       [profile_name]
            aws_access_key_id=<AWS_ACCESS_KEY_ID>
            aws_secret_access_key=<AWS_SECRET_ACCESS_KEY>
            aws_session_token=<AWS_SESSION_TOKEN>
       ```
       2. Run terraform - 
       ```
       cd ../
       ./install.sh <profile_name>
       ```

> **Note:**
If you are using user account's security credentials with appropriate permissions, you can just use AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY.

5. If the terraform run is successful, the output will show value - `core_role_arn` that you need to input in Onehouse's UI wizard
