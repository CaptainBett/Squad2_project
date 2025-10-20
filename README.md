# 🚀 Squad2 Infrastructure as Code

Welcome to the infrastructure backbone of Squad2's project! This repository contains our Infrastructure as Code (IaC) implementation using Terraform, designed with modularity, security, and scalability in mind.

## 🏗️ Architecture Overview

```
infra/
├── 📁 modules/                # Reusable infrastructure components
│   ├── 🔐 iam/               # Identity and Access Management configurations
│   └── 🌐 vpc/               # Virtual Private Cloud network setup
├── 📁 envs/                  # Environment-specific configurations
│   └── staging.tfvars        # Staging environment variables
└── 📄 Core Terraform files   # Root module configuration
```

## 🧩 Core Modules

### VPC Module
- Network isolation and security
- Configurable subnets and routing
- Scalable architecture design

### IAM Module
- Principle of least privilege
- Role-based access control
- Security-first approach

## 🛠️ Getting Started

1. **Prerequisites**
   - Terraform >= 1.0.0
   - AWS CLI configured
   - Proper AWS credentials with required permissions

2. **Initialize Terraform**
   ```bash
   terraform init
   ```

3. **Plan Your Changes**
   ```bash
   terraform plan -var-file=envs/staging.tfvars -out=tfplan
   ```

4. **Apply Infrastructure**
   ```bash
   terraform apply tfplan
   ```

## 🔒 Security Best Practices

- State file is stored remotely in S3 with encryption
- State locking implemented via DynamoDB
- IAM policies follow least privilege principle
- Network security groups tightly controlled

## 🌱 Environment Management

The infrastructure supports multiple environments through variable files:
- `envs/staging.tfvars` - Staging environment configuration
- Production and other environments can be added following the same pattern

## 📚 Documentation

Each module includes:
- `main.tf` - Core resource definitions
- `variables.tf` - Input variables
- `outputs.tf` - Output values

## 🤝 Contributing

1. Branch naming convention: `feature/description` or `fix/description`
2. Submit PRs with clear descriptions
3. Ensure `terraform fmt` and `terraform validate` pass
4. Include relevant tests and documentation

## 🔄 State Management

- Remote state stored in S3
- State locking via DynamoDB
- Backup and versioning enabled

---

💡 **Pro Tip:** Always run `terraform plan` before applying changes to understand the impact of your modifications.

📝 **Note:** Make sure to review the `.gitignore` file to ensure no sensitive information is committed.

For questions or support, reach out to the infrastructure team.

Happy Infrastructure as Code! 🎉