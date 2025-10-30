#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/../config"
LOG_FILE="/var/log/aws-secrets-setup.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[WARN] $1${NC}" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" | tee -a "$LOG_FILE"
    exit 1
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        error "AWS CLI is not installed. Please install it first."
    fi
    
    # Check jq
    if ! command -v jq &> /dev/null; then
        error "jq is not installed. Please install it first."
    fi
    
    # Check AWS configuration
    if ! aws sts get-caller-identity &> /dev/null; then
        error "AWS CLI is not configured properly. Run 'aws configure' first."
    fi
    
    log "All prerequisites satisfied"
}

create_iam_policy() {
    local policy_name="$1"
    local policy_file="$CONFIG_DIR/iam-policy.json"
    
    log "Creating IAM policy: $policy_name"
    
    if [ ! -f "$policy_file" ]; then
        cat > "$policy_file" << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "secretsmanager:CreateSecret",
                "secretsmanager:GetSecretValue",
                "secretsmanager:PutSecretValue",
                "secretsmanager:UpdateSecret",
                "secretsmanager:RotateSecret",
                "secretsmanager:DescribeSecret"
            ],
            "Resource": "arn:aws:secretsmanager:*:*:secret:onprem-server/*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "secretsmanager:ListSecrets"
            ],
            "Resource": "*"
        }
    ]
}
EOF
    fi
    
    aws iam create-policy \
        --policy-name "$policy_name" \
        --policy-document "file://$policy_file" \
        --description "Policy for managing on-prem server credentials" || warn "Policy may already exist"
}

create_secret_for_server() {
    local server_name="$1"
    local username="$2"
    local password="$3"
    local server_type="${4:-linux}"
    
    log "Creating secret for server: $server_name"
    
    local secret_name="onprem-server/$server_name"
    local secret_string=$(jq -n \
        --arg username "$username" \
        --arg password "$password" \
        --arg server_type "$server_type" \
        '{
            username: $username,
            password: $password,
            server_type: $server_type,
            created: now | todate,
            rotation_required: true
        }')
    
    if aws secretsmanager describe-secret --secret-id "$secret_name" &> /dev/null; then
        warn "Secret $secret_name already exists. Updating..."
        aws secretsmanager put-secret-value \
            --secret-id "$secret_name" \
            --secret-string "$secret_string"
    else
        aws secretsmanager create-secret \
            --name "$secret_name" \
            --secret-string "$secret_string" \
            --description "Credentials for on-prem server $server_name"
    fi
}

setup_initial_secrets() {
    log "Setting up initial secrets..."
    
    # Example servers - in production, this would come from inventory
    create_secret_for_server "web-server-01" "admin" "securepassword123" "linux"
    create_secret_for_server "db-server-01" "dbadmin" "dbpassword456" "linux"
    create_secret_for_server "app-server-01" "appuser" "apppass789" "linux"
}

main() {
    log "Starting AWS Secrets Manager setup..."
    
    check_prerequisites
    create_iam_policy "OnPremSecretsManager"
    setup_initial_secrets
    
    log "Setup completed successfully!"
}

main "$@"
