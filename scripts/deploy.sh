#!/bin/bash

# Smart Deployment Script - Handles Existing Resources
# This script detects existing AWS resources and configures Terraform accordingly

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Function to detect existing resources
detect_existing_resources() {
    print_status "🔍 Detecting existing AWS resources..."
    
    # Create terraform.tfvars file
    TFVARS_FILE="$TERRAFORM_DIR/terraform.tfvars"
    
    echo "# Auto-generated terraform.tfvars for existing resources" > "$TFVARS_FILE"
    echo "# Generated on: $(date)" >> "$TFVARS_FILE"
    echo "" >> "$TFVARS_FILE"
    
    # Check for existing EC2 instances
    print_status "Looking for existing blog server instances..."
    EXISTING_INSTANCES=$(aws ec2 describe-instances \
        --filters "Name=tag:Project,Values=simple-blog" "Name=instance-state-name,Values=running,stopped" \
        --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Name`].Value|[0],State.Name,PublicIpAddress,VpcId,SubnetId,SecurityGroups[0].GroupId,KeyName]' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$EXISTING_INSTANCES" ]; then
        # Parse the first matching instance
        read -r INSTANCE_ID INSTANCE_NAME INSTANCE_STATE PUBLIC_IP VPC_ID SUBNET_ID SG_ID KEY_NAME <<< "$EXISTING_INSTANCES"
        
        print_success "Found existing instance: $INSTANCE_ID ($INSTANCE_NAME) - State: $INSTANCE_STATE"
        
        if [ "$INSTANCE_STATE" = "running" ]; then
            echo "use_existing_resources = true" >> "$TFVARS_FILE"
            echo "existing_instance_id = \"$INSTANCE_ID\"" >> "$TFVARS_FILE"
            echo "existing_vpc_id = \"$VPC_ID\"" >> "$TFVARS_FILE"
            echo "existing_subnet_id = \"$SUBNET_ID\"" >> "$TFVARS_FILE"
            echo "existing_security_group_id = \"$SG_ID\"" >> "$TFVARS_FILE"
            
            if [ -n "$KEY_NAME" ] && [ "$KEY_NAME" != "None" ]; then
                echo "existing_key_pair_name = \"$KEY_NAME\"" >> "$TFVARS_FILE"
                print_success "Will use existing key pair: $KEY_NAME"
            fi
            
            print_success "Configuration set to use existing running instance"
            echo ""
            echo "Existing Resources Found:"
            echo "  Instance ID: $INSTANCE_ID"
            echo "  Instance Name: $INSTANCE_NAME"
            echo "  Public IP: ${PUBLIC_IP:-"None"}"
            echo "  VPC ID: $VPC_ID"
            echo "  Subnet ID: $SUBNET_ID"
            echo "  Security Group: $SG_ID"
            echo "  Key Pair: ${KEY_NAME:-"None"}"
            echo ""
            
            return 0
        else
            print_warning "Instance exists but is $INSTANCE_STATE. Will attempt to use it anyway."
            echo "use_existing_resources = true" >> "$TFVARS_FILE"
            echo "existing_instance_id = \"$INSTANCE_ID\"" >> "$TFVARS_FILE"
        fi
    else
        print_status "No existing blog server instances found, will create new resources"
        echo "use_existing_resources = false" >> "$TFVARS_FILE"
    fi
    
    # Add other configuration
    echo "" >> "$TFVARS_FILE"
    echo "# Project Configuration" >> "$TFVARS_FILE"
    echo "aws_region = \"eu-west-1\"" >> "$TFVARS_FILE"
    echo "environment = \"production\"" >> "$TFVARS_FILE"
    echo "project_name = \"simple-blog\"" >> "$TFVARS_FILE"
    
    print_success "Resource detection complete. Configuration saved to terraform.tfvars"
}

# Function to create Terraform backend configuration
setup_terraform_backend() {
    print_status "🔧 Setting up Terraform backend..."
    
    # Check if state bucket exists
    BUCKET_NAME="cletusmangu-lampstack-app-terraform-state-2025"
    if aws s3 ls "s3://$BUCKET_NAME" >/dev/null 2>&1; then
        print_success "Terraform state bucket exists: $BUCKET_NAME"
    else
        print_status "Creating Terraform state bucket: $BUCKET_NAME"
        aws s3 mb "s3://$BUCKET_NAME" --region eu-west-1
        
        # Enable versioning
        aws s3api put-bucket-versioning \
            --bucket "$BUCKET_NAME" \
            --versioning-configuration Status=Enabled
        
        # Enable encryption
        aws s3api put-bucket-encryption \
            --bucket "$BUCKET_NAME" \
            --server-side-encryption-configuration '{
                "Rules": [
                    {
                        "ApplyServerSideEncryptionByDefault": {
                            "SSEAlgorithm": "AES256"
                        }
                    }
                ]
            }'
        
        print_success "State bucket created and configured"
    fi
}

# Function to handle existing instance deployment
deploy_to_existing_instance() {
    local instance_ip="$1"
    local key_name="$2"
    
    print_status "🚀 Deploying to existing instance: $instance_ip"
    
    # Find the SSH key file
    SSH_KEY_FILE=""
    for key_file in "$TERRAFORM_DIR/${key_name}.pem" "$HOME/.ssh/${key_name}.pem" "$HOME/.ssh/${key_name}" "${key_name}.pem"; do
        if [ -f "$key_file" ]; then
            SSH_KEY_FILE="$key_file"
            chmod 600 "$SSH_KEY_FILE"
            break
        fi
    done
    
    if [ -z "$SSH_KEY_FILE" ]; then
        print_error "SSH key file not found for key: $key_name"
        print_status "Looked in:"
        echo "  - $TERRAFORM_DIR/${key_name}.pem"
        echo "  - $HOME/.ssh/${key_name}.pem"
        echo "  - $HOME/.ssh/${key_name}"
        echo "  - ${key_name}.pem"
        print_status "Please ensure the SSH key file is available or set up GitHub secrets for automated deployment"
        return 1
    fi
    
    print_success "Using SSH key: $SSH_KEY_FILE"
    
    # Test SSH connection
    print_status "Testing SSH connection..."
    if ! ssh -i "$SSH_KEY_FILE" -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@"$instance_ip" "echo 'SSH connection successful'" 2>/dev/null; then
        print_error "SSH connection failed. Please check:"
        echo "  - Instance is running and accessible"
        echo "  - SSH key is correct"
        echo "  - Security group allows SSH access"
        echo "  - Instance has a public IP"
        return 1
    fi
    
    print_success "SSH connection successful"
    
    # Create deployment package
    print_status "Creating deployment package..."
    cd "$PROJECT_ROOT"
    tar -czf "/tmp/blog-deployment.tar.gz" src/
    
    # Upload and deploy
    print_status "Uploading application files..."
    scp -i "$SSH_KEY_FILE" -o StrictHostKeyChecking=no "/tmp/blog-deployment.tar.gz" ubuntu@"$instance_ip":/tmp/
    
    print_status "Deploying application..."
    ssh -i "$SSH_KEY_FILE" -o StrictHostKeyChecking=no ubuntu@"$instance_ip" << 'EOF'
set -e

echo "=== Starting Application Deployment ==="

# Extract files
cd /tmp
if [ -f "blog-deployment.tar.gz" ]; then
    tar -xzf blog-deployment.tar.gz
    echo "✅ Extracted deployment package"
else
    echo "❌ Deployment package not found"
    exit 1
fi

# Ensure blog directory exists
BLOG_DIR="/var/www/html/blog"
sudo mkdir -p "$BLOG_DIR"

# Deploy files
if [ -d "src" ]; then
    echo "Deploying files to $BLOG_DIR..."
    sudo cp -r src/* "$BLOG_DIR/"
    sudo chown -R www-data:www-data "$BLOG_DIR"
    sudo chmod -R 755 "$BLOG_DIR"
    echo "✅ Files deployed successfully"
else
    echo "❌ Source directory not found"
    exit 1
fi

# Check if services are running
echo "=== Checking Services ==="
APACHE_STATUS=$(systemctl is-active apache2 2>/dev/null || echo "inactive")
MYSQL_STATUS=$(systemctl is-active mysql 2>/dev/null || echo "inactive")

echo "Apache: $APACHE_STATUS"
echo "MySQL: $MYSQL_STATUS"

# Start services if needed
if [ "$APACHE_STATUS" != "active" ]; then
    echo "Starting Apache..."
    sudo systemctl start apache2
    sudo systemctl enable apache2
fi

if [ "$MYSQL_STATUS" != "active" ]; then
    echo "Starting MySQL..."
    sudo systemctl start mysql
    sudo systemctl enable mysql
fi

# Setup database if needed and SQL file exists
if [ -f "$BLOG_DIR/database.sql" ]; then
    echo "Setting up database..."
    # Try with different password combinations
    for password in "RootSecurePassword123!" "root" ""; do
        if [ -n "$password" ]; then
            mysql_cmd="mysql -u root -p$password"
        else
            mysql_cmd="mysql -u root"
        fi
        
        if $mysql_cmd -e "SELECT 1" >/dev/null 2>&1; then
            echo "Database connection successful with password configuration"
            $mysql_cmd < "$BLOG_DIR/database.sql" 2>/dev/null || echo "Database setup attempted"
            break
        fi
    done
fi

# Reload Apache
sudo systemctl reload apache2 2>/dev/null || sudo systemctl restart apache2

# Clean up
rm -f /tmp/blog-deployment.tar.gz
rm -rf /tmp/src

echo "✅ Deployment completed!"
EOF
    
    # Clean up local files
    rm -f "/tmp/blog-deployment.tar.gz"
    
    # Verify deployment
    print_status "Verifying deployment..."
    sleep 5
    
    if curl -f -s "http://$instance_ip/blog" >/dev/null; then
        print_success "✅ Blog is accessible at: http://$instance_ip/blog"
    else
        print_warning "⚠️ Blog might not be immediately accessible. Checking services..."
        ssh -i "$SSH_KEY_FILE" -o StrictHostKeyChecking=no ubuntu@"$instance_ip" "
            echo 'Service Status:'
            systemctl is-active apache2 && echo 'Apache: ACTIVE' || echo 'Apache: INACTIVE'
            systemctl is-active mysql && echo 'MySQL: ACTIVE' || echo 'MySQL: INACTIVE'
            echo 'Files:'
            ls -la /var/www/html/blog/ | head -5
        "
    fi
    
    print_success "Deployment to existing instance completed!"
    echo ""
    echo "🌐 Blog URL: http://$instance_ip/blog"
    echo "🖥️  SSH Access: ssh -i $SSH_KEY_FILE ubuntu@$instance_ip"
}

# Function to run smart Terraform deployment
smart_terraform_deploy() {
    print_status "🏗️ Running Terraform deployment..."
    
    cd "$TERRAFORM_DIR"
    
    # Initialize Terraform
    terraform init
    
    # Plan
    print_status "Creating Terraform plan..."
    terraform plan -out=tfplan
    
    # Apply
    print_status "Applying Terraform configuration..."
    terraform apply tfplan
    
    # Get outputs
    INSTANCE_IP=$(terraform output -raw instance_public_ip 2>/dev/null || echo "")
    INSTANCE_ID=$(terraform output -raw instance_id 2>/dev/null || echo "")
    KEY_NAME=$(terraform output -raw ssh_key_name 2>/dev/null || echo "")
    
    if [ -n "$INSTANCE_IP" ]; then
        print_success "Infrastructure ready!"
        echo "  Instance ID: $INSTANCE_ID"
        echo "  Public IP: $INSTANCE_IP"
        echo "  SSH Key: $KEY_NAME"
        
        # If using existing instance, deploy immediately
        if grep -q "use_existing_resources = true" terraform.tfvars 2>/dev/null; then
            deploy_to_existing_instance "$INSTANCE_IP" "$KEY_NAME"
        fi
    else
        print_error "Could not retrieve instance information from Terraform outputs"
        return 1
    fi
    
    rm -f tfplan
}

# Main function
main() {
    print_success "🚀 Smart Blog Deployment Script"
    echo "======================================="
    
    # Check prerequisites
    print_status "Checking prerequisites..."
    for cmd in aws terraform ssh scp curl; do
        if ! command -v $cmd &> /dev/null; then
            print_error "Required command not found: $cmd"
            exit 1
        fi
    done
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured"
        exit 1
    fi
    
    print_success "Prerequisites satisfied"
    
    # Setup backend
    setup_terraform_backend
    
    # Detect existing resources
    detect_existing_resources
    
    # Run Terraform deployment
    smart_terraform_deploy
    
    print_success "🎉 Deployment completed successfully!"
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi