# LAMP Stack To-Do Application on AWS

A simple To-Do list application built with the LAMP stack (Linux, Apache, MySQL, PHP) and deployed on AWS EC2 using Terraform and GitHub Actions.

## 🏗️ Architecture

- **Frontend**: HTML + CSS
- **Backend**: PHP
- **Database**: MySQL
- **Infrastructure**: AWS EC2 (Ubuntu 22.04)
- **Provisioning**: Terraform
- **Deployment**: GitHub Actions
- **Region**: eu-west-1

## 🚀 Features

- ✅ Add new tasks
- ❌ Delete existing tasks
- 📱 Responsive design
- 🔒 Secure infrastructure following AWS Well-Architected Framework
- 🚀 Automated deployment with GitHub Actions

## 📋 Prerequisites

1. AWS Account with appropriate permissions
2. Terraform installed locally
3. GitHub repository with secrets configured
4. SSH key pair for EC2 access

## 🔧 Required GitHub Secrets

Set up the following secrets in your GitHub repository:

- `AWS_ACCESS_KEY_ID`: Your AWS access key
- `AWS_SECRET_ACCESS_KEY`: Your AWS secret access key
- `EC2_PUBLIC_KEY`: Your EC2 public key content
- `EC2_PRIVATE_KEY`: Your EC2 private key content

## 🏁 Quick Start

1. **Clone the repository**
```bash
git clone <your-repo-url>
cd lamp-stack-application