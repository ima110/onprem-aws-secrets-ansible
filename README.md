# On-Prem Server Credential Management with AWS Secrets Manager

Ansible and Bash based solution for securely managing on-prem server credentials using AWS Secrets Manager with temporary session tokens.

## Features
- Automated AWS Secrets Manager setup
- Secure credential storage and retrieval
- Temporary session token generation
- On-prem server authentication
- Credential rotation automation
- Session management and cleanup

## Prerequisites
- AWS CLI configured with appropriate permissions
- Ansible 2.9+
- Bash 4.0+
- Access to on-prem servers

## Quick Start
```bash
# Setup AWS Secrets Manager
ansible-playbook playbooks/setup-aws-secrets.yml

# Retrieve and use credentials
./scripts/credential-retriever.sh --server web-server-01
