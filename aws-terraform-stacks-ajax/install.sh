#!/bin/bash

# Run this script to apply the terraform stack on your AWS account.
# Eg: ./install.sh <aws_profile_name>
source verify-checksum.sh

TERRAFORM_CONFIG_FILE_BASE_PATH="./terraform"
ONBOARDING_STACK_DOWNLOAD_LINK="https://cloud.onehouse.ai/download/terraform-stacks/aws"

# Function to check if a utility tool is installed
check_command_exists() {
    local not_installed_message="$1 is not installed. Please install it and try again."
    case $(get_os_type) in
        "macOS")
            if ! command -v $1 &> /dev/null; then
                echo $not_installed_message
                exit 1
            fi
            ;;
        "Windows")
            if ! where $1 &> /dev/null; then
                echo $not_installed_message
                exit 1
            fi
            ;;
        *)
            echo "Unsupported OS."
            exit 1
            ;;
    esac
}

# Function to get the S3 bucket name using requestId
get_s3_bucket() {
    local request_id="$1"
    local s3_bucket

    # Construct S3 bucket name
    short_id=${request_id:0:8}
    s3_bucket="onehouse-customer-bucket-$short_id"

    echo "$s3_bucket"
}

# Function to parse the config file using yq and extract requestId
parse_request_id() {
    local config_file="$1"
    local request_id

    check_file_exists "$config_file"
    if [ $? -ne 0 ]; then
        return 1
    fi

    is_request_id_in_secrets_manager=$(yq eval '.requestIdSecretManager.enabled' "$config_file")

    if [ "$is_request_id_in_secrets_manager" == true ]; then
        secretArn=$(yq eval '.requestIdSecretManager.secretArn' "$config_file")
        secretValue=$(aws secretsmanager get-secret-value --secret-id $secretArn --query SecretString --output text)
        request_id=$secretValue
    else
        request_id=$(yq eval '.requestId' "$config_file")
    fi

    # Check if requestId was found
    if [ -z "$request_id" ]; then
        echo "requestId not found in the config file."
        exit 1
    fi

    echo "$request_id"
}

initialise_terraform(){
    terraform init -reconfigure
}

# Function to create a Terraform plan
create_terraform_plan() {
    terraform plan -out="$PLAN_FILE.tfplan" | tee "$PLAN_FILE.txt"
    if [ $? -ne 0 ]; then
        echo "Terraform plan failed."
        exit 1
    fi
}

upload_to_s3() {
    local file="$1"
    local s3_path

    if [[ "$file" == *"_plan.txt" ]]; then
        s3_path="s3://$S3_BUCKET/onboarding/terraform/preboarding/backup/plan/$file"
    elif [[ "$file" == *"_output.txt" ]]; then
        s3_path="s3://$S3_BUCKET/onboarding/terraform/preboarding/backup/output/$file"
    elif [[ "$file" == "config.yaml" ]]; then
            s3_path="s3://$S3_BUCKET/onboarding/terraform/preboarding/config.backup.${CURRENT_TIME}.yaml"
    else
        echo "Unknown file type: $file"
        exit 1
    fi

    if [[ -n "$AWS_PROFILE" ]]; then
        aws s3 cp "$file" "$s3_path" --profile "$AWS_PROFILE"
    else
        aws s3 cp "$file" "$s3_path"
    fi
}

# Function to apply the Terraform plan and upload its output to S3
apply_terraform_plan() {
    terraform apply "$PLAN_FILE.tfplan" | tee "$OUTPUT_FILE"
    if [ $? -ne 0 ]; then
        echo "Terraform apply failed."
        exit 1
    fi
    upload_to_s3 "$OUTPUT_FILE"
    upload_to_s3 "config.yaml"
}

# Function to clean up local files
cleanup_local_files() {
    local plan_file="$1"
    local output_file="$2"
    rm -f "$plan_file.txt" "$plan_file.tfplan" "$output_file"
}


# Main function
main() {
    local main_file_path="./terraform/main.tf"
    local config_file_path="./terraform/config.yaml"
    local s3_core_role_policy_file_path="./terraform/modules/s3CoreRolePolicy/main.tf"
    local s3_data_load_policy_file_path="./terraform/modules/s3DataLoadPolicy/main.tf"
    local s3_node_role_policy_file_path="./terraform/modules/s3NodeRolePolicy/main.tf"
    local database_data_load_policy_file_path="./terraform/modules/databaseDataLoadPolicy/main.tf"
    local aggregate_node_role_policy_file_path="./terraform/modules/aggregateNodeRolePolicy/main.tf"
    local main_file_checksum
    local s3_core_role_policy_file_checksum
    local s3_data_load_policy_file_checksum
    local s3_node_role_policy_file_checksum
    local database_data_load_policy_file_checksum
    local aggregate_node_role_policy_file_checksum
    local request_id

    # debug logs to be removed
    echo $(get_os_type)

    check_command_exists "terraform"
    check_command_exists "yq"
    check_command_exists "jq"
    check_command_exists "curl"
    check_command_exists "aws"

    main_file_checksum=$(compute_sha_checksum "$main_file_path")
     if [ $? -ne 0 ]; then exit 1; fi

    s3_core_role_policy_file_checksum=$(compute_sha_checksum "$s3_core_role_policy_file_path")
     if [ $? -ne 0 ]; then exit 1; fi

    s3_data_load_policy_file_checksum=$(compute_sha_checksum "$s3_data_load_policy_file_path")
     if [ $? -ne 0 ]; then exit 1; fi

    s3_node_role_policy_file_checksum=$(compute_sha_checksum "$s3_node_role_policy_file_path")
      if [ $? -ne 0 ]; then exit 1; fi

    database_data_load_policy_file_checksum=$(compute_sha_checksum "$database_data_load_policy_file_path")
      if [ $? -ne 0 ]; then exit 1; fi

    aggregate_node_role_policy_file_checksum=$(compute_sha_checksum "$aggregate_node_role_policy_file_path")
      if [ $? -ne 0 ]; then exit 1; fi

    request_id=$(parse_request_id "$config_file_path")
    echo "request_id: $request_id"

    # verify file checksum
    verify_checksum "$request_id" "$main_file_path" "$main_file_checksum" "$s3_core_role_policy_file_path" "$s3_core_role_policy_file_checksum" "$s3_data_load_policy_file_path" "$s3_data_load_policy_file_checksum" "$s3_node_role_policy_file_path"  "$s3_node_role_policy_file_checksum" "$database_data_load_policy_file_path" "$database_data_load_policy_file_checksum" "$aggregate_node_role_policy_file_path" "$aggregate_node_role_policy_file_checksum"

    # Initialize PLAN_FILE and OUTPUT_FILE
    CURRENT_TIME=$(date +"%Y%m%d_%H%M%S")
    PLAN_FILE="${CURRENT_TIME}_plan"
    OUTPUT_FILE="${CURRENT_TIME}_output.txt"

    S3_BUCKET=$(get_s3_bucket "$request_id")
    AWS_PROFILE="${1:-}"

    echo "Using aws profile: $AWS_PROFILE"
    echo "Saving artefacts to: $S3_BUCKET"

    if [[ -n "$AWS_PROFILE" ]]; then
        export AWS_PROFILE="$AWS_PROFILE"
    fi
    cd $TERRAFORM_CONFIG_FILE_BASE_PATH
    initialise_terraform
    create_terraform_plan
    upload_to_s3 "$PLAN_FILE.txt"

    echo "Do you want to proceed with applying this plan(Y/N)? :"
    read APPLY_PLAN

    lowercase_input=$(echo $APPLY_PLAN | tr '[:upper:]' '[:lower:]')

    if [ "$lowercase_input" == "y" ] || [ "$lowercase_input" == "yes" ]; then
        echo "Proceeding with applying the plan..."
        apply_terraform_plan
    fi

    cleanup_local_files "$PLAN_FILE" "$OUTPUT_FILE"
}

main "$@"
