#!/bin/bash

# Destroy and Recreate Infrastructure Script
# This script completely destroys existing resources and recreates everything fresh

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
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_action() { echo -e "${CYAN}[ACTION]${NC} $1"; }
print_destroy() { echo -e "${MAGENTA}[DESTROY]${NC} $1"; }

# Function to confirm destruction
confirm_destruction() {
    echo ""
    print_warning "⚠️  WARNING: DESTRUCTIVE OPERATION ⚠️"
    echo "======================================"
    echo "This script will:"
    echo "  🗑️  DESTROY all existing blog infrastructure"
    echo "  💥 TERMINATE all EC2 instances"
    echo "  🔥 DELETE VPCs, subnets, security groups"
    echo "  🗝️  REMOVE SSH key pairs"
    echo "  🆕 CREATE everything fresh from scratch"
    echo "  📦 INSTALL all dependencies"
    echo "  🚀 DEPLOY the application"
    echo ""
    print_warning "This action cannot be undone!"
    echo ""
    
    if [ "${FORCE_DESTROY:-}" = "true" ]; then
        print_action "Force mode enabled, proceeding with destruction..."
        return 0
    fi
    
    read -p "Type 'DESTROY' to confirm you want to proceed: " confirmation
    
    if [ "$confirmation" != "DESTROY" ]; then
        print_error "Operation cancelled"
        exit 1
    fi
    
    print_action "Destruction confirmed. Proceeding..."
}

# Function to backup current state (optional)
backup_current_state() {
    print_status "📋 Creating backup of current infrastructure state..."
    
    local backup_dir="$PROJECT_ROOT/backups/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Backup Terraform state
    if [ -f "$TERRAFORM_DIR/terraform.tfstate" ]; then
        cp "$TERRAFORM_DIR/terraform.tfstate" "$backup_dir/"
        print_success "Terraform state backed up"
    fi
    
    # List current resources
    echo "=== Current EC2 Instances ===" > "$backup_dir/current_resources.txt"
    aws ec2 describe-instances \
        --filters "Name=tag:Project,Values=simple-blog" \
        --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PublicIpAddress,Tags[?Key==`Name`].Value|[0]]' \
        --output table >> "$backup_dir/current_resources.txt" 2>/dev/null || echo "No instances found" >> "$backup_dir/current_resources.txt"
    
    echo "" >> "$backup_dir/current_resources.txt"
    echo "=== Current VPCs ===" >> "$backup_dir/current_resources.txt"
    aws ec2 describe-vpcs \
        --filters "Name=tag:Project,Values=simple-blog" \
        --query 'Vpcs[*].[VpcId,State,CidrBlock,Tags[?Key==`Name`].Value|[0]]' \
        --output table >> "$backup_dir/current_resources.txt" 2>/dev/null || echo "No VPCs found" >> "$backup_dir/current_resources.txt"
    
    print_success "Current state backed up to: $backup_dir"
}

# Function to manually destroy resources (failsafe)
manual_resource_cleanup() {
    print_destroy "🧹 Performing manual resource cleanup..."
    
    # Terminate all blog project instances
    print_action "Terminating EC2 instances..."
    local instances=$(aws ec2 describe-instances \
        --filters "Name=tag:Project,Values=simple-blog" "Name=instance-state-name,Values=running,stopped,pending" \
        --query 'Reservations[*].Instances[*].InstanceId' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$instances" ]; then
        echo "Found instances: $instances"
        for instance in $instances; do
            print_destroy "Terminating instance: $instance"
            aws ec2 terminate-instances --instance-ids "$instance" >/dev/null 2>&1 || true
        done
        
        print_action "Waiting for instances to terminate..."
        for instance in $instances; do
            aws ec2 wait instance-terminated --instance-ids "$instance" 2>/dev/null || true
        done
        print_success "All instances terminated"
    else
        print_status "No instances to terminate"
    fi
    
    # Release Elastic IPs
    print_action "Releasing Elastic IPs..."
    local eips=$(aws ec2 describe-addresses \
        --filters "Name=tag:Project,Values=simple-blog" \
        --query 'Addresses[*].AllocationId' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$eips" ]; then
        for eip in $eips; do
            print_destroy "Releasing EIP: $eip"
            aws ec2 release-address --allocation-id "$eip" >/dev/null 2>&1 || true
        done
        print_success "Elastic IPs released"
    fi
    
    # Delete Security Groups
    print_action "Deleting security groups..."
    local sgs=$(aws ec2 describe-security-groups \
        --filters "Name=tag:Project,Values=simple-blog" \
        --query 'SecurityGroups[*].GroupId' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$sgs" ]; then
        for sg in $sgs; do
            print_destroy "Deleting security group: $sg"
            aws ec2 delete-security-group --group-id "$sg" >/dev/null 2>&1 || true
        done
        print_success "Security groups deleted"
    fi
    
    # Delete Subnets
    print_action "Deleting subnets..."
    local subnets=$(aws ec2 describe-subnets \
        --filters "Name=tag:Project,Values=simple-blog" \
        --query 'Subnets[*].SubnetId' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$subnets" ]; then
        for subnet in $subnets; do
            print_destroy "Deleting subnet: $subnet"
            aws ec2 delete-subnet --subnet-id "$subnet" >/dev/null 2>&1 || true
        done
        print_success "Subnets deleted"
    fi
    
    # Delete Internet Gateways
    print_action "Deleting internet gateways..."
    local igws=$(aws ec2 describe-internet-gateways \
        --filters "Name=tag:Project,Values=simple-blog" \
        --query 'InternetGateways[*].InternetGatewayId' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$igws" ]; then
        for igw in $igws; do
            # Detach from VPCs first
            local vpcs=$(aws ec2 describe-internet-gateways \
                --internet-gateway-ids "$igw" \
                --query 'InternetGateways[0].Attachments[*].VpcId' \
                --output text 2>/dev/null || echo "")
            
            for vpc in $vpcs; do
                print_destroy "Detaching IGW $igw from VPC $vpc"
                aws ec2 detach-internet-gateway --internet-gateway-id "$igw" --vpc-id "$vpc" >/dev/null 2>&1 || true
            done
            
            print_destroy "Deleting internet gateway: $igw"
            aws ec2 delete-internet-gateway --internet-gateway-id "$igw" >/dev/null 2>&1 || true
        done
        print_success "Internet gateways deleted"
    fi
    
    # Delete VPCs
    print_action "Deleting VPCs..."
    local vpcs=$(aws ec2 describe-vpcs \
        --filters "Name=tag:Project,Values=simple-blog" \
        --query 'Vpcs[*].VpcId' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$vpcs" ]; then
        for vpc in $vpcs; do
            print_destroy "Deleting VPC: $vpc"
            aws ec2 delete-vpc --vpc-id "$vpc" >/dev/null 2>&1 || true
        done
        print_success "VPCs deleted"
    fi
    
    # Delete Key Pairs
    print_action "Deleting key pairs..."
    local keys=$(aws ec2 describe-key-pairs \
        --filters "Name=tag:Project,Values=simple-blog" \
        --query 'KeyPairs[*].KeyName' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$keys" ]; then
        for key in $keys; do
            print_destroy "Deleting key pair: $key"
            aws ec2 delete-key-pair --key-name "$key" >/dev/null 2>&1 || true
            # Remove local key file
            rm -f "$TERRAFORM_DIR/${key}.pem" 2>/dev/null || true
        done
        print_success "Key pairs deleted"
    fi
    
    print_success "Manual cleanup completed"
}

# Function to destroy via Terraform
terraform_destroy() {
    print_destroy "🔥 Destroying infrastructure via Terraform..."
    
    cd "$TERRAFORM_DIR"
    
    # Remove any existing tfvars that might force existing resources
    rm -f terraform.tfvars
    
    # Create clean tfvars for destruction
    cat > terraform.tfvars << EOF
# Clean configuration for fresh deployment
use_existing_resources = false

# Project configuration
aws_region = "eu-west-1"
environment = "production"
project_name = "simple-blog"
terraform_state_bucket = "cletusmangu-lampstack-app-terraform-state-2025"

# Instance configuration
instance_type = "t3.micro"
instance_name = "simple-blog-server"

# Database passwords
mysql_root_password = "RootSecurePassword123!"
mysql_blog_password = "SecurePassword123!"

# Network configuration
vpc_cidr = "10.0.0.0/16"
public_subnet_cidr = "10.0.1.0/24"
availability_zone = "eu-west-1a"

# Security configuration
allowed_ssh_cidrs = ["0.0.0.0/0"]
allowed_http_cidrs = ["0.0.0.0/0"]
EOF
    
    # Initialize Terraform
    print_action "Initializing Terraform..."
    terraform init -reconfigure
    
    # Destroy everything
    print_destroy "Destroying all Terraform-managed resources..."
    if terraform destroy -auto-approve; then
        print_success "Terraform destroy completed"
    else
        print_warning "Terraform destroy had issues, proceeding with manual cleanup"
    fi
    
    # Clean up Terraform files
    rm -f terraform.tfstate*
    rm -f tfplan
    rm -f .terraform.lock.hcl
    rm -rf .terraform/
    
    cd "$PROJECT_ROOT"
}

# Function to create fresh infrastructure
create_fresh_infrastructure() {
    print_success "🆕 Creating fresh infrastructure..."
    
    cd "$TERRAFORM_DIR"
    
    # Initialize Terraform
    print_action "Initializing Terraform..."
    terraform init
    
    # Plan the deployment
    print_action "Planning fresh deployment..."
    terraform plan -out=tfplan
    
    # Apply the plan
    print_action "Creating fresh infrastructure..."
    terraform apply -auto-approve tfplan
    
    # Get outputs
    print_status "Retrieving infrastructure information..."
    local instance_ip=$(terraform output -raw instance_public_ip 2>/dev/null || echo "")
    local instance_id=$(terraform output -raw instance_id 2>/dev/null || echo "")
    local ssh_key_name=$(terraform output -raw ssh_key_name 2>/dev/null || echo "")
    
    if [ -n "$instance_ip" ] && [ -n "$instance_id" ]; then
        print_success "Fresh infrastructure created successfully!"
        echo "  Instance ID: $instance_id"
        echo "  Public IP: $instance_ip"
        echo "  SSH Key: $ssh_key_name"
        
        # Export for use in deployment
        export FRESH_INSTANCE_IP="$instance_ip"
        export FRESH_INSTANCE_ID="$instance_id"
        export FRESH_SSH_KEY="$ssh_key_name"
    else
        print_error "Failed to retrieve infrastructure information"
        return 1
    fi
    
    rm -f tfplan
    cd "$PROJECT_ROOT"
}

# Function to wait for fresh instance to be ready
wait_for_fresh_instance() {
    local instance_ip="$1"
    local ssh_key="$2"
    
    print_status "⏳ Waiting for fresh instance to be completely ready..."
    
    local ssh_key_file="$TERRAFORM_DIR/${ssh_key}.pem"
    if [ ! -f "$ssh_key_file" ]; then
        print_error "SSH key file not found: $ssh_key_file"
        return 1
    fi
    
    chmod 600 "$ssh_key_file"
    
    # Wait for SSH connectivity
    print_action "Testing SSH connectivity..."
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        echo "Attempt $attempt/$max_attempts: Testing SSH to $instance_ip..."
        
        if timeout 10 ssh -i "$ssh_key_file" -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@"$instance_ip" "echo 'SSH ready'" 2>/dev/null; then
            print_success "✅ SSH connection established!"
            break
        fi
        
        if [ $attempt -eq $max_attempts ]; then
            print_error "SSH connection failed after $max_attempts attempts"
            return 1
        fi
        
        sleep 20
        ((attempt++))
    done
    
    # Wait for userdata to complete
    print_action "Waiting for system initialization to complete..."
    max_attempts=40
    attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        echo "Attempt $attempt/$max_attempts: Checking system readiness..."
        
        if ssh -i "$ssh_key_file" -o StrictHostKeyChecking=no ubuntu@"$instance_ip" "test -f /var/log/userdata-complete" 2>/dev/null; then
            print_success "✅ System initialization completed!"
            break
        fi
        
        if [ $attempt -eq $max_attempts ]; then
            print_warning "System initialization check timed out, proceeding anyway..."
            break
        fi
        
        # Show progress
        if [ $((attempt % 5)) -eq 0 ]; then
            ssh -i "$ssh_key_file" -o StrictHostKeyChecking=no ubuntu@"$instance_ip" "tail -3 /var/log/userdata-setup.log 2>/dev/null || echo 'Initialization in progress...'" || true
        fi
        
        sleep 30
        ((attempt++))
    done
    
    # Verify services
    print_action "Verifying installed services..."
    ssh -i "$ssh_key_file" -o StrictHostKeyChecking=no ubuntu@"$instance_ip" "
        echo '=== Service Status ==='
        systemctl is-active apache2 && echo '✅ Apache: ACTIVE' || echo '❌ Apache: INACTIVE'
        systemctl is-active mysql && echo '✅ MySQL: ACTIVE' || echo '❌ MySQL: INACTIVE'
        echo ''
        echo '=== Installation Verification ==='
        php --version | head -1 && echo '✅ PHP: INSTALLED' || echo '❌ PHP: MISSING'
        mysql --version | head -1 && echo '✅ MySQL Client: INSTALLED' || echo '❌ MySQL Client: MISSING'
        apache2 -v | head -1 && echo '✅ Apache: INSTALLED' || echo '❌ Apache: MISSING'
    " || true
    
    print_success "Fresh instance is ready for deployment!"
}

# Function to deploy application to fresh instance
deploy_to_fresh_instance() {
    local instance_ip="$1"
    local ssh_key="$2"
    
    print_success "🚀 Deploying application to fresh instance..."
    
    local ssh_key_file="$TERRAFORM_DIR/${ssh_key}.pem"
    
    # Create deployment package
    print_action "Creating deployment package..."
    cd "$PROJECT_ROOT"
    tar -czf "/tmp/fresh-blog-deployment.tar.gz" src/
    
    # Upload deployment package
    print_action "Uploading application files..."
    scp -i "$ssh_key_file" -o StrictHostKeyChecking=no "/tmp/fresh-blog-deployment.tar.gz" ubuntu@"$instance_ip":/tmp/
    
    # Deploy application
    print_action "Deploying fresh application..."
    ssh -i "$ssh_key_file" -o StrictHostKeyChecking=no ubuntu@"$instance_ip" << 'EOF'
set -e

echo "=== Fresh Application Deployment ==="

# Extract deployment package
cd /tmp
tar -xzf fresh-blog-deployment.tar.gz
echo "✅ Deployment package extracted"

# Deploy application files
BLOG_DIR="/var/www/html/blog"
sudo mkdir -p "$BLOG_DIR"

echo "📁 Deploying fresh application files..."
sudo cp -r src/* "$BLOG_DIR/"
sudo chown -R www-data:www-data "$BLOG_DIR"
sudo chmod -R 755 "$BLOG_DIR"
echo "✅ Fresh application files deployed"

# Setup database
if [ -f "$BLOG_DIR/database.sql" ]; then
    echo "🗄️ Setting up fresh database..."
    
    # Use the configured MySQL password
    if mysql -u root -p"${MYSQL_ROOT_PASSWORD:-RootSecurePassword123!}" < "$BLOG_DIR/database.sql" 2>/dev/null; then
        echo "✅ Fresh database setup completed"
    else
        echo "⚠️ Database setup had issues, trying alternative method..."
        # Try without password (fresh install might not have password set yet)
        mysql -u root < "$BLOG_DIR/database.sql" 2>/dev/null || echo "Database setup attempted"
    fi
fi

# Reload services
echo "🔄 Reloading services..."
sudo systemctl reload apache2
sudo systemctl restart mysql

# Final verification
echo "=== Fresh Deployment Verification ==="
systemctl is-active apache2 && echo "✅ Apache: RUNNING" || echo "❌ Apache: FAILED"
systemctl is-active mysql && echo "✅ MySQL: RUNNING" || echo "❌ MySQL: FAILED"

if [ -f "$BLOG_DIR/index.php" ]; then
    echo "✅ Blog files: DEPLOYED"
else
    echo "❌ Blog files: MISSING"
fi

# Test database connection
if mysql -u blog_user -p"${MYSQL_BLOG_PASSWORD:-SecurePassword123!}" -e "SELECT COUNT(*) FROM blog_db.posts;" 2>/dev/null; then
    echo "✅ Database connection: WORKING"
else
    echo "❌ Database connection: FAILED"
fi

# Cleanup
rm -f /tmp/fresh-blog-deployment.tar.gz
rm -rf /tmp/src

echo "✅ Fresh application deployment completed!"
EOF

    # Clean up local files
    rm -f "/tmp/fresh-blog-deployment.tar.gz"
    
    print_success "Fresh application deployment completed!"
}

# Function to verify fresh deployment
verify_fresh_deployment() {
    local instance_ip="$1"
    
    print_status "🔍 Verifying fresh deployment..."
    
    # Wait for services to stabilize
    sleep 15
    
    # Test blog accessibility
    local max_attempts=8
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        echo "🌐 Attempt $attempt/$max_attempts: Testing fresh blog at http://$instance_ip/blog"
        
        if curl -f -s --max-time 15 "http://$instance_ip/blog" >/dev/null 2>&1; then
            print_success "✅ Fresh blog is accessible!"
            
            # Get content preview
            echo "📄 Blog content preview:"
            curl -s "http://$instance_ip/blog" | grep -E "(title|<h1|Blog|Welcome)" | head -3 || echo "Fresh content loaded"
            break
        else
            echo "❌ Fresh blog not accessible yet (attempt $attempt/$max_attempts)"
            
            if [ $attempt -eq $max_attempts ]; then
                print_error "Fresh blog accessibility verification failed"
                return 1
            fi
            
            sleep 20
        fi
        ((attempt++))
    done
    
    print_success "Fresh deployment verification completed!"
}

# Main function
main() {
    echo ""
    print_success "🔥 DESTROY AND RECREATE INFRASTRUCTURE SCRIPT"
    echo "=============================================="
    print_status "This script will completely rebuild your blog infrastructure"
    echo ""
    
    # Check prerequisites
    print_status "Checking prerequisites..."
    for cmd in aws terraform ssh scp curl; do
        if ! command -v $cmd &> /dev/null; then
            print_error "Required command not found: $cmd"
            exit 1
        fi
    done
    
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured"
        exit 1
    fi
    
    print_success "All prerequisites satisfied"
    
    # Confirm destruction
    confirm_destruction
    
    # Backup current state
    backup_current_state
    
    # Destroy existing infrastructure
    print_destroy "🔥 PHASE 1: DESTROYING EXISTING INFRASTRUCTURE"
    echo "=============================================="
    terraform_destroy
    sleep 5
    manual_resource_cleanup
    
    print_success "🗑️ All existing resources have been destroyed"
    echo ""
    
    # Create fresh infrastructure
    print_success "🆕 PHASE 2: CREATING FRESH INFRASTRUCTURE"
    echo "=========================================="
    create_fresh_infrastructure
    
    # Wait for fresh instance
    print_status "⏳ PHASE 3: WAITING FOR FRESH INSTANCE"
    echo "======================================"
    wait_for_fresh_instance "$FRESH_INSTANCE_IP" "$FRESH_SSH_KEY"
    
    # Deploy to fresh instance
    print_success "🚀 PHASE 4: DEPLOYING TO FRESH INSTANCE"
    echo "======================================="
    deploy_to_fresh_instance "$FRESH_INSTANCE_IP" "$FRESH_SSH_KEY"
    
    # Verify fresh deployment
    print_status "🔍 PHASE 5: VERIFYING FRESH DEPLOYMENT"
    echo "======================================"
    verify_fresh_deployment "$FRESH_INSTANCE_IP"
    
    # Success summary
    echo ""
    print_success "🎉 FRESH INFRASTRUCTURE DEPLOYMENT COMPLETED!"
    echo "=============================================="
    echo "🆕 Everything has been recreated from scratch"
    echo "📦 All dependencies freshly installed"
    echo "🌐 Blog URL: http://$FRESH_INSTANCE_IP/blog"
    echo "🏠 Server: http://$FRESH_INSTANCE_IP"
    echo "🖥️ SSH: ssh -i $FRESH_SSH_KEY.pem ubuntu@$FRESH_INSTANCE_IP"
    echo "📊 Instance: $FRESH_INSTANCE_ID"
    echo "=============================================="
    echo ""
    print_success "Your blog is now running on completely fresh infrastructure!"
}

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        echo "Destroy and Recreate Infrastructure Script"
        echo ""
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --force        Skip confirmation prompt"
        echo ""
        echo "This script will:"
        echo "  1. Completely destroy all existing blog infrastructure"
        echo "  2. Create everything fresh from scratch"
        echo "  3. Install all dependencies"
        echo "  4. Deploy the application"
        echo ""
        echo "⚠️  WARNING: This is a destructive operation!"
        exit 0
        ;;
    --force)
        export FORCE_DESTROY="true"
        main
        ;;
    "")
        main
        ;;
    *)
        print_error "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac