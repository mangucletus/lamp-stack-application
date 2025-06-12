#!/bin/bash

# Instance Manager - Quick script to find, start, and deploy to existing instances
# This script specifically handles your existing instance at 54.78.153.43

set -euo pipefail

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

# Known instance IP
KNOWN_IP="54.78.153.43"

# Function to find instance by IP
find_instance_by_ip() {
    local ip="$1"
    print_status "🔍 Finding instance with IP: $ip"
    
    local instance_data=$(aws ec2 describe-instances \
        --filters "Name=ip-address,Values=$ip" \
        --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PublicIpAddress,VpcId,SubnetId,SecurityGroups[0].GroupId,KeyName,Tags[?Key==`Name`].Value|[0]]' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$instance_data" ]; then
        read -r INSTANCE_ID INSTANCE_STATE PUBLIC_IP VPC_ID SUBNET_ID SG_ID KEY_NAME INSTANCE_NAME <<< "$instance_data"
        
        print_success "Found instance:"
        echo "  Instance ID: $INSTANCE_ID"
        echo "  Name: ${INSTANCE_NAME:-Unknown}"
        echo "  State: $INSTANCE_STATE"
        echo "  Public IP: $PUBLIC_IP"
        echo "  VPC: $VPC_ID"
        echo "  Subnet: $SUBNET_ID"
        echo "  Security Group: $SG_ID"
        echo "  Key Pair: ${KEY_NAME:-None}"
        
        return 0
    else
        print_error "No instance found with IP: $ip"
        return 1
    fi
}

# Function to start instance if stopped
start_instance_if_needed() {
    local instance_id="$1"
    local current_state="$2"
    
    case "$current_state" in
        "running")
            print_success "Instance is already running"
            return 0
            ;;
        "stopped")
            print_status "🚀 Starting stopped instance..."
            aws ec2 start-instances --instance-ids "$instance_id"
            
            print_status "⏳ Waiting for instance to start..."
            local max_wait=300  # 5 minutes
            local elapsed=0
            
            while [ $elapsed -lt $max_wait ]; do
                local state=$(aws ec2 describe-instances \
                    --instance-ids "$instance_id" \
                    --query 'Reservations[0].Instances[0].State.Name' \
                    --output text)
                
                echo "Current state: $state (${elapsed}s elapsed)"
                
                if [ "$state" = "running" ]; then
                    print_success "✅ Instance started successfully!"
                    return 0
                fi
                
                sleep 15
                elapsed=$((elapsed + 15))
            done
            
            print_error "Timeout waiting for instance to start"
            return 1
            ;;
        "stopping")
            print_status "Instance is stopping, waiting for it to stop first..."
            aws ec2 wait instance-stopped --instance-ids "$instance_id"
            start_instance_if_needed "$instance_id" "stopped"
            ;;
        "pending")
            print_status "Instance is already starting, waiting..."
            aws ec2 wait instance-running --instance-ids "$instance_id"
            print_success "✅ Instance is now running!"
            return 0
            ;;
        *)
            print_error "Instance is in unsupported state: $current_state"
            return 1
            ;;
    esac
}

# Function to create terraform config for existing instance
create_terraform_config() {
    local instance_id="$1"
    local vpc_id="$2"
    local subnet_id="$3"
    local sg_id="$4"
    local key_name="$5"
    
    print_status "📝 Creating Terraform configuration for existing resources..."
    
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local terraform_dir="$(dirname "$script_dir")/terraform"
    local tfvars_file="$terraform_dir/terraform.tfvars"
    
    cat > "$tfvars_file" << EOF
# Auto-generated terraform.tfvars for existing instance
# Generated: $(date)
# Instance: $instance_id

# Use existing resources
use_existing_resources = true

# Existing resource IDs
existing_instance_id = "$instance_id"
existing_vpc_id = "$vpc_id"
existing_subnet_id = "$subnet_id"
existing_security_group_id = "$sg_id"
existing_key_pair_name = "$key_name"

# Project configuration
aws_region = "eu-west-1"
environment = "production"
project_name = "simple-blog"
terraform_state_bucket = "cletusmangu-lampstack-app-terraform-state-2025"

# Database passwords (override in GitHub secrets if needed)
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

    print_success "Terraform configuration created: $tfvars_file"
}

# Function to test SSH connectivity
test_ssh_connection() {
    local instance_ip="$1"
    local key_name="$2"
    
    print_status "🔌 Testing SSH connectivity..."
    
    # Find SSH key file
    local ssh_key=""
    for key_file in "${key_name}.pem" "$HOME/.ssh/${key_name}.pem" "$HOME/.ssh/${key_name}"; do
        if [ -f "$key_file" ]; then
            ssh_key="$key_file"
            chmod 600 "$ssh_key"
            break
        fi
    done
    
    if [ -z "$ssh_key" ]; then
        print_warning "SSH key file not found for: $key_name"
        print_status "Please ensure you have the SSH key file available"
        print_status "Expected locations:"
        echo "  - ${key_name}.pem"
        echo "  - $HOME/.ssh/${key_name}.pem"
        echo "  - $HOME/.ssh/${key_name}"
        return 1
    fi
    
    print_status "Using SSH key: $ssh_key"
    
    # Test connection
    local max_attempts=5
    for attempt in $(seq 1 $max_attempts); do
        echo "SSH attempt $attempt/$max_attempts..."
        
        if timeout 10 ssh -i "$ssh_key" -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@"$instance_ip" "echo 'SSH connection successful'" 2>/dev/null; then
            print_success "✅ SSH connection established!"
            return 0
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            sleep 10
        fi
    done
    
    print_error "SSH connection failed"
    print_status "Possible issues:"
    echo "  - Security group doesn't allow SSH on port 22"
    echo "  - Instance might be in a private subnet"
    echo "  - SSH key mismatch"
    echo "  - Instance still starting services"
    return 1
}

# Function to deploy application
deploy_application() {
    local instance_ip="$1"
    local key_name="$2"
    
    print_status "🚀 Deploying application to $instance_ip..."
    
    # Find SSH key
    local ssh_key=""
    for key_file in "${key_name}.pem" "$HOME/.ssh/${key_name}.pem" "$HOME/.ssh/${key_name}"; do
        if [ -f "$key_file" ]; then
            ssh_key="$key_file"
            chmod 600 "$ssh_key"
            break
        fi
    done
    
    if [ -z "$ssh_key" ]; then
        print_error "SSH key file not found"
        return 1
    fi
    
    # Get script directory and project root
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local project_root="$(dirname "$script_dir")"
    
    # Create deployment package
    print_status "📦 Creating deployment package..."
    cd "$project_root"
    tar -czf "/tmp/blog-deployment.tar.gz" src/
    
    # Upload package
    print_status "📤 Uploading application..."
    if ! scp -i "$ssh_key" -o StrictHostKeyChecking=no "/tmp/blog-deployment.tar.gz" ubuntu@"$instance_ip":/tmp/; then
        print_error "Failed to upload deployment package"
        return 1
    fi
    
    # Deploy application
    print_status "🎯 Deploying application..."
    ssh -i "$ssh_key" -o StrictHostKeyChecking=no ubuntu@"$instance_ip" << 'EOF'
set -e

echo "=== Application Deployment Started ==="

# Extract deployment package
cd /tmp
if [ -f "blog-deployment.tar.gz" ]; then
    tar -xzf blog-deployment.tar.gz
    echo "✅ Deployment package extracted"
else
    echo "❌ Deployment package not found"
    exit 1
fi

# Ensure blog directory exists
BLOG_DIR="/var/www/html/blog"
sudo mkdir -p "$BLOG_DIR"

# Deploy files
if [ -d "src" ]; then
    echo "📁 Copying files to $BLOG_DIR..."
    sudo cp -r src/* "$BLOG_DIR/"
    sudo chown -R www-data:www-data "$BLOG_DIR"
    sudo chmod -R 755 "$BLOG_DIR"
    echo "✅ Files deployed successfully"
else
    echo "❌ Source directory not found"
    exit 1
fi

# Check and manage Apache
echo "🌐 Checking Apache service..."
if command -v apache2 >/dev/null 2>&1; then
    if systemctl is-active --quiet apache2; then
        echo "🔄 Apache is running, reloading configuration..."
        sudo systemctl reload apache2
    else
        echo "🚀 Starting Apache..."
        sudo systemctl start apache2
        sudo systemctl enable apache2
    fi
    echo "Apache status: $(systemctl is-active apache2)"
else
    echo "⚠️ Apache not installed"
fi

# Check and manage MySQL
echo "🗄️ Checking MySQL service..."
if command -v mysql >/dev/null 2>&1; then
    if systemctl is-active --quiet mysql; then
        echo "✅ MySQL is running"
    else
        echo "🚀 Starting MySQL..."
        sudo systemctl start mysql
        sudo systemctl enable mysql
    fi
    echo "MySQL status: $(systemctl is-active mysql)"
    
    # Setup database if SQL file exists
    if [ -f "$BLOG_DIR/database.sql" ]; then
        echo "🗄️ Setting up database..."
        
        # Try different authentication methods
        for mysql_auth in \
            "mysql -u root -pRootSecurePassword123!" \
            "mysql -u root" \
            "sudo mysql -u root"; do
            
            echo "Trying database connection..."
            if eval "$mysql_auth -e 'SELECT 1' >/dev/null 2>&1"; then
                echo "✅ Database connection successful"
                eval "$mysql_auth < $BLOG_DIR/database.sql" >/dev/null 2>&1 || echo "Database setup attempted"
                break
            fi
        done
    fi
else
    echo "⚠️ MySQL not installed"
fi

# Final verification
echo "=== Final Status Check ==="
if command -v apache2 >/dev/null; then
    systemctl is-active --quiet apache2 && echo "✅ Apache: RUNNING" || echo "❌ Apache: NOT RUNNING"
fi
if command -v mysql >/dev/null; then
    systemctl is-active --quiet mysql && echo "✅ MySQL: RUNNING" || echo "❌ MySQL: NOT RUNNING"
fi

# Check blog files
if [ -f "$BLOG_DIR/index.php" ]; then
    echo "✅ Blog files: DEPLOYED"
else
    echo "❌ Blog files: NOT FOUND"
fi

# Cleanup
rm -f /tmp/blog-deployment.tar.gz
rm -rf /tmp/src

echo "✅ Application deployment completed!"
EOF

    # Clean up local package
    rm -f "/tmp/blog-deployment.tar.gz"
    
    if [ $? -eq 0 ]; then
        print_success "Application deployed successfully!"
        return 0
    else
        print_error "Application deployment failed"
        return 1
    fi
}

# Function to verify deployment
verify_deployment() {
    local instance_ip="$1"
    
    print_status "🔍 Verifying deployment..."
    
    # Test HTTP accessibility
    sleep 10
    
    for attempt in {1..5}; do
        echo "HTTP test attempt $attempt/5..."
        
        if curl -f -s --max-time 10 "http://$instance_ip/blog" >/dev/null 2>&1; then
            print_success "✅ Blog is accessible at: http://$instance_ip/blog"
            return 0
        fi
        
        if [ $attempt -lt 5 ]; then
            sleep 15
        fi
    done
    
    print_warning "❌ HTTP verification failed"
    print_status "The blog might still be working - possible reasons:"
    echo "  - Security group blocks HTTP traffic"
    echo "  - Apache needs more time to start"
    echo "  - Configuration issues"
    return 1
}

# Main function
main() {
    print_success "🔧 Instance Manager - Quick Deploy to Existing Infrastructure"
    echo "=============================================================="
    
    # Check AWS CLI
    if ! command -v aws >/dev/null 2>&1; then
        print_error "AWS CLI not found"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        print_error "AWS credentials not configured"
        exit 1
    fi
    
    print_success "✅ Prerequisites satisfied"
    echo ""
    
    # Find the instance
    if find_instance_by_ip "$KNOWN_IP"; then
        echo ""
        
        # Start instance if needed
        if start_instance_if_needed "$INSTANCE_ID" "$INSTANCE_STATE"; then
            echo ""
            
            # Create Terraform config
            create_terraform_config "$INSTANCE_ID" "$VPC_ID" "$SUBNET_ID" "$SG_ID" "$KEY_NAME"
            echo ""
            
            # Get current IP (might have changed after start)
            CURRENT_IP=$(aws ec2 describe-instances \
                --instance-ids "$INSTANCE_ID" \
                --query 'Reservations[0].Instances[0].PublicIpAddress' \
                --output text)
            
            if [ "$CURRENT_IP" = "None" ]; then
                print_warning "Instance has no public IP"
                CURRENT_IP=""
            fi
            
            # Test SSH and deploy if possible
            if [ -n "$CURRENT_IP" ] && [ -n "$KEY_NAME" ]; then
                if test_ssh_connection "$CURRENT_IP" "$KEY_NAME"; then
                    echo ""
                    
                    if deploy_application "$CURRENT_IP" "$KEY_NAME"; then
                        echo ""
                        verify_deployment "$CURRENT_IP"
                        
                        echo ""
                        print_success "🎉 Instance management completed!"
                        echo "=================================="
                        echo "🌐 Blog URL: http://$CURRENT_IP/blog"
                        echo "🏠 Server: http://$CURRENT_IP"
                        echo "🖥️ SSH: ssh -i ${KEY_NAME}.pem ubuntu@$CURRENT_IP"
                        echo "📊 Instance: $INSTANCE_ID"
                        echo "=================================="
                    fi
                fi
            else
                print_warning "Cannot deploy - missing IP or SSH key information"
                echo "Instance IP: ${CURRENT_IP:-None}"
                echo "SSH Key: ${KEY_NAME:-None}"
            fi
        fi
    else
        print_error "Could not find instance with IP: $KNOWN_IP"
        echo ""
        print_status "Searching for any blog-related instances..."
        
        # Search for any instances with blog-related tags
        aws ec2 describe-instances \
            --filters "Name=tag:Project,Values=simple-blog" \
            --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PublicIpAddress,Tags[?Key==`Name`].Value|[0]]' \
            --output table || echo "No instances found with Project=simple-blog tag"
    fi
}

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        echo "Instance Manager - Quick Deploy Tool"
        echo ""
        echo "This script:"
        echo "  1. Finds your existing instance (IP: $KNOWN_IP)"
        echo "  2. Starts it if stopped"
        echo "  3. Creates Terraform config for existing resources"
        echo "  4. Tests SSH connectivity"
        echo "  5. Deploys your application"
        echo "  6. Verifies the deployment"
        echo ""
        echo "Usage: $0 [--help]"
        exit 0
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