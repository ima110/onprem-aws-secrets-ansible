#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SESSION_DIR="/tmp/aws-secrets"

usage() {
    cat << EOF
Usage: $0 [OPTIONS] SERVER_NAME [COMMAND]

Authenticate to on-prem servers using temporary credentials from AWS Secrets Manager

OPTIONS:
    -u, --user USERNAME        Specific username to use
    -t, --token-file FILE      Use specific token file
    --ssh                      Use SSH for connection
    --web                      Use for web authentication
    -h, --help                 Show this help message

EXAMPLES:
    $0 web-server-01
    $0 --ssh db-server-01
    $0 --user admin app-server-01 "ls -la"
EOF
}

authenticate_ssh() {
    local server="$1"
    local username="$2"
    local token_file="$3"
    
    if [ ! -f "$token_file" ]; then
        echo "Error: Token file not found: $token_file"
        exit 1
    fi
    
    local host=$(grep -oP '(?<=ansible_host=)[^ ]+' "$SCRIPT_DIR/../inventory/hosts.ini" | grep "$server" | head -1)
    local password=$(jq -r '.password' "$token_file")
    
    if [ -z "$host" ]; then
        echo "Error: Could not find host for server: $server"
        exit 1
    fi
    
    echo "Connecting to $server ($host) as $username..."
    
    # Using sshpass for password authentication (consider using SSH keys in production)
    sshpass -p "$password" ssh "${username}@${host}" \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null
}

check_token_expiry() {
    local token_file="$1"
    local expiry=$(jq -r '.token_expiry' "$token_file")
    local current_time=$(date +%s)
    
    if [ "$current_time" -ge "$expiry" ]; then
        echo "Error: Session token has expired"
        return 1
    fi
    
    local time_left=$((expiry - current_time))
    echo "Session valid for: $((time_left / 60)) minutes"
    return 0
}

main() {
    local server=""
    local username=""
    local token_file=""
    local connection_type="ssh"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -u|--user)
                username="$2"
                shift 2
                ;;
            -t|--token-file)
                token_file="$2"
                shift 2
                ;;
            --ssh)
                connection_type="ssh"
                shift
                ;;
            --web)
                connection_type="web"
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                if [ -z "$server" ]; then
                    server="$1"
                else
                    break
                fi
                shift
                ;;
        esac
    done
    
    if [ -z "$server" ]; then
        echo "Error: Server name is required" >&2
        usage
        exit 1
    fi
    
    # Find latest token file if not specified
    if [ -z "$token_file" ]; then
        token_file=$(ls -t "$SESSION_DIR/session-$server-"*.json 2>/dev/null | head -1)
    fi
    
    if [ -z "$token_file" ] || [ ! -f "$token_file" ]; then
        echo "Error: No valid session token found for $server"
        echo "Run: ./scripts/credential-retriever.sh --server $server"
        exit 1
    fi
    
    # Check token expiry
    if ! check_token_expiry "$token_file"; then
        exit 1
    fi
    
    # Set username from token if not provided
    if [ -z "$username" ]; then
        username=$(jq -r '.username' "$token_file")
    fi
    
    # Perform authentication based on type
    case "$connection_type" in
        "ssh")
            authenticate_ssh "$server" "$username" "$token_file"
            ;;
        "web")
            echo "Web authentication for $server as $username"
            # Add web authentication logic here
            ;;
        *)
            echo "Error: Unknown connection type: $connection_type"
            exit 1
            ;;
    esac
}

main "$@"
