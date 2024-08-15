#!/bin/bash

# Function to determine the OS type
get_os_type() {
    if [ "$(uname)" == "Darwin" ]; then
        echo "macOS"
    elif [ "$(uname -s | cut -c 1-10)" == "MINGW32_NT" ] || [ "$(uname -s | cut -c 1-10)" == "MINGW64_NT" ]; then
        echo "Windows"
    elif [ "$(uname)" == "Linux" ]; then
        echo "Linux"
    else
        echo "Unsupported"
    fi
}

# Function to check if file exists
check_file_exists() {
    local file_path="$1"
    if [ ! -f "$file_path" ]; then
        echo "File $file_path does not exist."
        exit 1
    fi
}

# Function to compute SHA checksum based on OS
compute_sha_checksum() {
    local file_path="$1"
    local checksum

    check_file_exists "$file_path"
    if [ $? -ne 0 ]; then
        return 1
    fi

    case $(get_os_type) in
        "macOS"| "Linux")
            checksum=$(shasum -a 256 "$file_path" | awk '{print $1}')
            echo "$checksum"
            ;;
        "Windows")
            checksum=$(sha256sum "$file_path" | awk '{print $1}')
            echo "$checksum"
            ;;
        *)
            echo "Unsupported OS."
            return 1
            ;;
    esac
    return 0
}

# Function to get the S3 bucket name using requestId

verify_checksum() {
    local requestId="$1"
    shift
    local file_checksum_map=""

    # Iterate over remaining arguments to create file_checksum_map
    while [ "$#" -gt 1 ]; do
        local file_path="$1"
        local file_checksum="$2"
        file_checksum_map="$file_checksum_map\"$file_path\":\"$file_checksum\","
        shift 2
    done

    # Remove trailing comma and construct full json body
    file_checksum_map="${file_checksum_map%,}"
    local json_body="{
        \"requestId\": \"$requestId\",
        \"cloudProvider\": \"AWS\",
        \"onboarding_stack_checksum\": {
            \"file_checksum_map\": {
                $file_checksum_map
            }
        }
    }"
    echo $file_checksum_map
    echo "$json_body"

   local fixed_url="https://api.onehouse.ai/v1/validate-onboarding-stack"
   response_body=$(curl -s -X POST "$fixed_url" \
         -H "Content-Type: application/json" \
         -d "$json_body")

   echo "Response from API:"
   echo "$response_body"

   # Check for "failureResponse" key in the response using jq
   if echo "$response_body" | jq -e 'has("failureResponse")' &>/dev/null; then
       failure_reason=$(echo "$response_body" | jq -r '.failureResponse.reason')
       echo "Validation Error: One or more script files have been modified locally. Please undo these changes or update the new checksum in product-config and try again"
       echo "Reason: $failure_reason"
       exit 1
   fi
}

# Main function
main() {
    local main_file_path="./terraform/main.tf"
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

    request_id=1234

    # verify file checksum
    verify_checksum "$request_id" "$main_file_path" "$main_file_checksum" "$s3_core_role_policy_file_path" "$s3_core_role_policy_file_checksum" "$s3_data_load_policy_file_path" "$s3_data_load_policy_file_checksum" "$s3_node_role_policy_file_path"  "$s3_node_role_policy_file_checksum" "$database_data_load_policy_file_path" "$database_data_load_policy_file_checksum" "$aggregate_node_role_policy_file_path" "$aggregate_node_role_policy_file_checksum"

}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi