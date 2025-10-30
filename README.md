# On-Prem Server Credential Management with AWS Secrets Manager

## 📘 Project Overview

An **Ansible** and **Bash-based** automation solution for securely managing on-premises server credentials using **AWS Secrets Manager** and temporary session tokens.
This project enables secure credential rotation, retrieval, and authentication for on-prem servers through seamless AWS integration.

---

## ✨ Features

* 🔐 **Automated AWS Secrets Manager setup**
* 🔑 **Secure credential storage and retrieval**
* ⏱️ **Temporary session token generation**
* 🖥️ **On-prem server authentication via SSH**
* 🔄 **Credential rotation automation**
* 📊 **Session management and cleanup**
* 🛡️ **Security best practices implementation**

---

## 🧩 Prerequisites

* AWS CLI configured with proper IAM permissions
* **Ansible 2.9+**
* **Bash 4.0+**
* Access to on-prem servers
* `jq` for JSON processing
* `sshpass` for SSH authentication (or SSH keys)

---

## 📁 Project Structure

```
onprem-aws-secrets-ansible/
├── scripts/          # Bash scripts for credential management
├── playbooks/        # Ansible playbooks for automation
├── roles/            # Ansible roles for reusable components
├── inventory/        # Server inventory files
├── config/           # Configuration files
└── templates/        # Template files
```

---

## 🚀 Quick Start

### 1️⃣ Initial Setup

```bash
# Clone the project
git clone <repository-url>
cd onprem-aws-secrets-ansible

# Make scripts executable
chmod +x scripts/*.sh

# Install dependencies
pip install -r requirements.txt

# Configure your inventory
cp inventory/hosts.ini.example inventory/hosts.ini
# Edit inventory/hosts.ini with your server details
```

---

### 2️⃣ AWS Secrets Manager Setup

```bash
# Option 1: Using Bash script
./scripts/aws-secret-setup.sh

# Option 2: Using Ansible playbook
ansible-playbook playbooks/setup-aws-secrets.yml

# Verify setup
aws secretsmanager list-secrets --query 'SecretList[?Name.contains(@, `onprem-server/`)]'
```

---

### 3️⃣ Basic Usage Examples

#### Retrieve Credentials for a Single Server

```bash
./scripts/credential-retriever.sh --server web-server-01
```

Example output:

```
USERNAME=admin
PASSWORD=securepassword123
SERVER_TYPE=linux
SESSION_TOKEN=temp-session-123
TOKEN_EXPIRY=1698765432
```

#### Authenticate to On-Prem Servers

```bash
./scripts/onprem-auth.sh --ssh web-server-01
./scripts/onprem-auth.sh --user admin --ssh db-server-01
```

#### Run Commands on Multiple Servers

```bash
for server in web-server-01 db-server-01 app-server-01; do
    echo "=== $server ==="
    ./scripts/onprem-auth.sh $server "df -h"
done
```

---

### 4️⃣ Advanced Usage

#### Bulk Operations with Ansible

```bash
ansible-playbook playbooks/retrieve-credentials.yml -e "target_server=all"
ansible-playbook playbooks/auth-onprem-servers.yml -e "auth_type=ssh"
```

#### Credential Rotation

```bash
ansible-playbook playbooks/rotate-credentials.yml
./scripts/credential-rotator.sh --server db-server-01 --force
```

#### Schedule Automatic Rotation (Cron)

```bash
echo "0 2 * * 1 /path/to/scripts/credential-rotator.sh --all" | crontab -
```

---

## 🔁 Integration Examples

### CI/CD Pipelines (GitLab)

```yaml
deploy_to_onprem:
  stage: deploy
  before_script:
    - apt-get update && apt-get install -y jq sshpass
    - pip install ansible boto3
  script:
    - ./scripts/credential-retriever.sh --server production-app-01 --output shell > creds.env
    - source creds.env
    - ansible-playbook playbooks/deploy.yml -e "target_server=production-app-01"
```

### Docker Integration

```dockerfile
FROM ubuntu:20.04
RUN apt-get update && apt-get install -y python3 python3-pip jq sshpass awscli
COPY . /app
WORKDIR /app
CMD ["./scripts/onprem-auth.sh", "container-server", "python3", "app.py"]
```

### Environment Variables

```bash
source <(./scripts/credential-retriever.sh --server web-server-01 --output shell)
export $(./scripts/credential-retriever.sh --server db-server-01 | xargs)
```

---

## 🔒 Security Best Practices

* Use **IAM roles** instead of access keys
* Regularly **rotate credentials** (every 90 days recommended)
* Limit **token lifetime**
* Use **secure temporary directories** for storing tokens
* Monitor sessions and enable auditing/logging

---

## 🧠 Monitoring and Logging

```bash
# Monitor active sessions
watch -n 30 './scripts/session-manager.sh list'

# Log session activities
./scripts/onprem-auth.sh web-server-01 "app_command" | tee -a /var/log/onprem-access.log

# Generate session report
./scripts/session-manager.sh report --format html > session-report.html
```

Integrations:

* **Nagios**: Credential expiry checks
* **Prometheus**: Export metrics
* **CloudWatch**: Push metrics for monitoring

---

## 🧰 Troubleshooting

```bash
# Enable debug mode
export DEBUG=true
./scripts/credential-retriever.sh --server web-server-01

# Check AWS permissions
aws secretsmanager describe-secret --secret-id onprem-server/web-server-01

# Configure AWS credentials if missing
aws configure
```

Common issues:

* SSH connection errors → Check `inventory/hosts.ini`
* Token expiry → Adjust duration using `--duration` flag

---

## 🧱 Best Practices Summary

**Security:**

* Rotate credentials
* Enforce IAM role usage
* Use encrypted storage

**Operations:**

* Enable logging and monitoring
* Automate cleanup of expired sessions

**Maintenance:**

* Keep dependencies updated
* Review IAM policies regularly

---

## 🤝 Contributing

Contributions are welcome!
Please review the **contributing guidelines** and **code of conduct** before submitting PRs or issues.

---

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

