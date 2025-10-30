#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMP_DIR="/tmp/aws-secrets"
CONFIG_FILE="$SCRIPT_DIR/../config/servers.conf"

# Default values
SERVER_NAME=""
DURATION=3600
OUTPUT_FORMAT="env"

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Retrieve credentials from AWS Secrets Manager for on-prem servers

OPTIONS:
    -s, --server SERVER_NAME    Specific server to retrieve credentials for
    -d, --duration SECONDS      Token duration in seconds (default: 3600)
    -o, --output FORMAT         Output format: env, json, shell (default: env)
    -h, --help                  Show this help message

EXAMPLES:
    $0 -s web-server-01
    $0 --server db-server-01 --duration 7200 --output json
EOF
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--server)
                SERVER_NAME="$2"
                shift 2
                ;;
            -d|--duration)
                DURATION="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

validate_environment() {
    if ! command -v aws &> /dev/null; then
        echo "Error: AWS CLI is not installed or not in PATH"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        echo "Error: jq is not installed"
        exit 1
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        echo "Error: AWS credentials not configured"
        exit 1
    fi
}

retrieve_credentials() {
    local server="$1"
    local secret_name="onprem-server/$server"
    
    echo "Retrieving credentials for: $server" >&2
    
    local secret_value=$(aws secretsmanager get-secret-value \
        --secret-id "$secret_name" \
        --query 'SecretString' \
        --output text 2>/dev/null || echo "{}")
    
    if [ "$secret_value" == "{}" ]; then
        echo "Error: Could not retrieve credentials for $server" >&2
        return 1
    fi
    
    echo "$secret_value"
}

generate_session_token() {
    local credentials="$1"
    local duration="$2"
    local username=$(echo "$credentials" | jq -r '.username')
    
    # Generate a temporary session token
    local token_data=$(echo "$credentials" | jq \
        --arg expiry "$(date -d "+$duration seconds" +%s)" \
        --arg token_id "$(uuidgen || echo "temp-$(date +%s)")" \
        '. + {
            session_token: $token_id,
            token_expiry: $expiry|tonumber,
            generated_at: now|todate
        }')
    
    echo "$token_data"
}

format_output() {
    local data="$1"
    local format="$2"
    
    case "$format" in
        "env")
            echo "$data" | jq -r 'to_entries | map("\(.key|ascii_upcase)=\(.value|tostring)") | .[]'
            ;;
        "json")
            echo "$data" | jq '.'
            ;;
        "shell")
            echo "$data" | jq -r 'to_entries | map("export \(.key|ascii_upcase)=\(.value|tostring|@sh)") | .[]'
            ;;
        *)
            echo "Unknown format: $format" >&2
            return 1
            ;;
    esac
}

main() {
    parse_arguments "$@"
    validate_environment
    
    if [ -z "$SERVER_NAME" ]; then
        echo "Error: Server name is required" >&2
        usage
        exit 1
    fi
    
    # Create temp directory
    mkdir -p "$TEMP_DIR"
    
    # Retrieve and process credentials
    local credentials=$(retrieve_credentials "$SERVER_NAME")
    local session_data=$(generate_session_token "$credentials" "$DURATION")
    
    # Save session data
    local session_file="$TEMP_DIR/session-$SERVER_NAME-$(date +%s).json"
    echo "$session_data" > "$session_file"
    
    # Output in requested format
    format_output "$session_data" "$OUTPUT_FORMAT"
    
    echo "Session data saved to: $session_file" >&2
}

main "$@"
