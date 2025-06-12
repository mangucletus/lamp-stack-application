#!/bin/bash

# Smart Resource Manager - Reuse existing AWS resources, start stopped instances
# This script intelligently manages existing AWS infrastructure without recreating

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
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_action() { echo -e "${CYAN}[ACTION]${NC} $1"; }

# Global variables for discovered resources
declare -g INSTANCE_ID=""
declare -g INSTANCE_STATE=""
declare -g INSTANCE_IP=""
declare -g VPC_ID=""
declare -g SUBNET_ID=""
declare -g SECURITY_GROUP_ID=""
declare -g KEY_NAME=""
declare -g USE_EXISTING=false

# Function to discover existing blog infrastructure
discover_existing_infrastructure() {
    print_status "🔍 Discovering existing blog infrastructure..."
    
    # Look for instances with our project tag
    local instances_data=$(aws ec2 describe-instances \
        --filters "Name=tag:Project,Values=simple-blog" \
        --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PublicIpAddress,PrivateIpAddress,VpcId,SubnetId,SecurityGroups[0].GroupId,KeyName,Tags[?Key==`Name`].Value|[0]]' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$instances_data" ]; then
        print_success "Found existing blog infrastructure!"
        echo ""
        echo "Existing Instances:"
        echo "-------------------"
        
        local instance_count=0
        local selected_instance=""
        
        while IFS=$'\t' read -r inst_id state pub_ip priv_ip vpc subnet sg key name; do
            if [ -n "$inst_id" ]; then
                ((instance_count++))
                echo "[$instance_count] Instance: $inst_id ($name)"
                echo "    State: $state"
                echo "    Public IP: ${pub_ip:-"None"}"
                echo "    Private IP: $priv_ip"
                echo "    VPC: $vpc"
                echo "    Subnet: $subnet"
                echo "    Security Group: $sg"
                echo "    Key Pair: ${key:-"None"}"
                echo ""
                
                # Prefer running instances, then stopped instances
                if [ "$state" = "running" ] && [ -z "$selected_instance" ]; then
                    selected_instance="$inst_id|$state|$pub_ip|$priv_ip|$vpc|$subnet|$sg|$key|$name"
                elif [ "$state" = "stopped" ] && [ -z "$selected_instance" ]; then
                    selected_instance="$inst_id|$state|$pub_ip|$priv_ip|$vpc|$subnet|$sg|$key|$name"
                fi
            fi
        done <<< "$instances_data"
        
        if [ -n "$selected_instance" ]; then
            IFS='|' read -r INSTANCE_ID INSTANCE_STATE INSTANCE_IP priv_ip VPC_ID SUBNET_ID SECURITY_GROUP_ID KEY_NAME inst_name <<< "$selected_instance"
            
            print_success "Selected instance: $INSTANCE_ID ($inst_name) - State: $INSTANCE_STATE"
            USE_EXISTING=true
            
            return 0
        fi
    fi
    
    print_warning "No existing blog instances found"
    USE_EXISTING=false
    return 1
}

# Function to start stopped EC2 instance
start_stopped_instance() {
    local instance_id="$1"
    
    print_action "🚀 Starting stopped instance: $instance_id"
    
    # Start the instance
    aws ec2 start-instances --instance-ids "$instance_id" >/dev/null
    
    print_status "Waiting for instance to start..."
    
    # Wait for instance to be running
    local max_attempts=20
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        local state=$(aws ec2 describe-instances \
            --instance-ids "$instance_id" \
            --query 'Reservations[0].Instances[0].State.Name' \
            --output text)
        
        echo "Attempt $attempt/$max_attempts: Instance state is '$state'"
        
        if [ "$state" = "running" ]; then
            print_success "✅ Instance is now running!"
            
            # Get the new public IP
            INSTANCE_IP=$(aws ec2 describe-instances \
                --instance-ids "$instance_id" \
                --query 'Reservations[0].Instances[0].PublicIpAddress' \
                --output text)
            
            if [ "$INSTANCE_IP" = "None" ] || [ -z "$INSTANCE_IP" ]; then
                print_warning "Instance has no public IP, checking for Elastic IP..."
                # Check if there's an associated Elastic IP
                local eip=$(aws ec2 describe-addresses \
                    --filters "Name=instance-id,Values=$instance_id" \
                    --query 'Addresses[0].PublicIp' \
                    --output text 2>/dev/null || echo "None")
                
                if [ "$eip" != "None" ] && [ -n "$eip" ]; then
                    INSTANCE_IP="$eip"
                    print_success "Found associated Elastic IP: $INSTANCE_IP"
                else
                    print_warning "No public IP available. Instance may be in private subnet."
                    INSTANCE_IP=""
                fi
            else
                print_success "Instance public IP: $INSTANCE_IP"
            fi
            
            INSTANCE_STATE="running"
            return 0
        fi
        
        sleep 15
        ((attempt++))
    done
    
    print_error "Timeout waiting for instance to start"
    return 1
}

# Function to ensure instance is running
ensure_instance_running() {
    if [ -z "$INSTANCE_ID" ]; then
        print_error "No instance ID available"
        return 1
    fi
    
    print_status "🔄 Ensuring instance $INSTANCE_ID is running..."
    
    case "$INSTANCE_STATE" in
        "running")
            print_success "Instance is already running"
            if [ -z "$INSTANCE_IP" ] || [ "$INSTANCE_IP" = "None" ]; then
                # Get current IP
                INSTANCE_IP=$(aws ec2 describe-instances \
                    --instance-ids "$INSTANCE_ID" \
                    --query 'Reservations[0].Instances[0].PublicIpAddress' \
                    --output text)
                print_status "Current public IP: ${INSTANCE_IP:-"None"}"
            fi
            ;;
        "stopped")
            start_stopped_instance "$INSTANCE_ID"
            ;;
        "stopping")
            print_action "Instance is stopping, waiting for it to stop completely..."
            aws ec2 wait instance-stopped --instance-ids "$INSTANCE_ID"
            start_stopped_instance "$INSTANCE_ID"
            ;;
        "pending"|"rebooting")
            print_action "Instance is $INSTANCE_STATE, waiting for it to be running..."
            aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"
            INSTANCE_STATE="running"
            print_success "Instance is now running"
            ;;
        *)
            print_error "Instance is in unsupported state: $INSTANCE_STATE"
            return 1
            ;;
    esac
    
    return 0
}

# Function to discover other existing resources
discover_existing_network_resources() {
    if [ -z "$VPC_ID" ] || [ -z "$SUBNET_ID" ] || [ -z "$SECURITY_GROUP_ID" ]; then
        print_status "🔍 Discovering additional network resources..."
        
        # If we have an instance, get its network details
        if [ -n "$INSTANCE_ID" ]; then
            local instance_details=$(aws ec2 describe-instances \
                --instance-ids "$INSTANCE_ID" \
                --query 'Reservations[0].Instances[0].[VpcId,SubnetId,SecurityGroups[0].GroupId,KeyName]' \
                --output text)
            
            read -r VPC_ID SUBNET_ID SECURITY_GROUP_ID KEY_NAME <<< "$instance_details"
            print_success "Retrieved network details from existing instance"
        fi
    fi
    
    print_status "Network configuration:"
    echo "  VPC ID: ${VPC_ID:-"Not found"}"
    echo "  Subnet ID: ${SUBNET_ID:-"Not found"}"
    echo "  Security Group ID: ${SECURITY_GROUP_ID:-"Not found"}"
    echo "  Key Pair: ${KEY_NAME:-"Not found"}"
}

# Function to create terraform.tfvars for existing resources
create_terraform_config() {
    print_status "📝 Creating Terraform configuration for existing resources..."
    
    local tfvars_file="$TERRAFORM_DIR/terraform.tfvars"
    
    cat > "$tfvars_file" << EOF
# Auto-generated terraform.tfvars for existing resources
# Generated on: $(date)
# Instance State: $INSTANCE_STATE -> running

# Use existing resources configuration
use_existing_resources = true

# Existing resource IDs
existing_instance_id = "$INSTANCE_ID"
existing_vpc_id = "$VPC_ID"
existing_subnet_id = "$SUBNET_ID"
existing_security_group_id = "$SECURITY_GROUP_ID"
existing_key_pair_name = "$KEY_NAME"

# Project configuration
aws_region = "eu-west-1"
environment = "production" 
project_name = "simple-blog"
terraform_state_bucket = "cletusmangu-lampstack-app-terraform-state-2025"

# Database passwords (using defaults, override in secrets)
mysql_root_password = "RootSecurePassword123!"
mysql_blog_password = "SecurePassword123!"

# Network configuration (for reference)
vpc_cidr = "10.0.0.0/16"
public_subnet_cidr = "10.0.1.0/24"
availability_zone = "eu-west-1a"

# Security configuration  
allowed_ssh_cidrs = ["0.0.0.0/0"]
allowed_http_cidrs = ["0.0.0.0/0"]
EOF

    print_success "Terraform configuration created: $tfvars_file"
}

# Function to run Terraform with existing resources
run_terraform_with_existing() {
    print_status "🏗️ Running Terraform with existing resources..."
    
    cd "$TERRAFORM_DIR"
    
    # Initialize Terraform
    print_action "Initializing Terraform..."
    terraform init -reconfigure
    
    # Import existing resources if needed (this prevents conflicts)
    print_action "Checking Terraform state..."
    
    # Plan with existing resources
    print_action "Creating Terraform plan..."
    if terraform plan -out=tfplan; then
        print_success "Terraform plan created successfully"
    else
        print_error "Terraform planning failed"
        return 1
    fi
    
    # Apply the plan
    print_action "Applying Terraform configuration..."
    if terraform apply -auto-approve tfplan; then
        print_success "Terraform applied successfully"
    else
        print_error "Terraform apply failed"
        return 1
    fi
    
    # Get outputs
    print_status "Getting Terraform outputs..."
    local tf_instance_ip=$(terraform output -raw instance_public_ip 2>/dev/null || echo "")
    local tf_instance_id=$(terraform output -raw instance_id 2>/dev/null || echo "")
    
    if [ -n "$tf_instance_ip" ]; then
        INSTANCE_IP="$tf_instance_ip"
        print_success "Terraform outputs retrieved successfully"
    fi
    
    rm -f tfplan
    return 0
}

# Function to wait for SSH connectivity
wait_for_ssh() {
    local instance_ip="$1"
    local ssh_key="$2"
    
    if [ -z "$instance_ip" ]; then
        print_error "No instance IP provided for SSH check"
        return 1
    fi
    
    print_status "🔌 Waiting for SSH connectivity to $instance_ip..."
    
    local max_attempts=15
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        echo "Attempt $attempt/$max_attempts: Testing SSH connection..."
        
        if timeout 10 ssh -i "$ssh_key" -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@"$instance_ip" "echo 'SSH connection successful'" 2>/dev/null; then
            print_success "✅ SSH connection established!"
            return 0
        fi
        
        sleep 10
        ((attempt++))
    done
    
    print_error "SSH connection failed after $max_attempts attempts"
    return 1
}

# Function to deploy application to existing instance
deploy_to_existing_instance() {
    local instance_ip="$1"
    local key_name="$2"
    
    print_status "🚀 Deploying application to existing instance..."
    
    # Find SSH key file
    local ssh_key_file=""
    for key_file in "$TERRAFORM_DIR/${key_name}.pem" "$HOME/.ssh/${key_name}.pem" "$HOME/.ssh/${key_name}" "${key_name}.pem"; do
        if [ -f "$key_file" ]; then
            ssh_key_file="$key_file"
            chmod 600 "$ssh_key_file"
            break
        fi
    done
    
    if [ -z "$ssh_key_file" ]; then
        print_error "SSH key file not found for key: $key_name"
        print_status "Please ensure SSH key is available or configure GitHub secrets"
        return 1
    fi
    
    print_success "Using SSH key: $ssh_key_file"
    
    # Wait for SSH
    if ! wait_for_ssh "$instance_ip" "$ssh_key_file"; then
        return 1
    fi
    
    # Create deployment package
    print_action "Creating deployment package..."
    cd "$PROJECT_ROOT"
    tar -czf "/tmp/blog-deployment.tar.gz" src/
    
    # Upload deployment package
    print_action "Uploading application files..."
    if ! scp -i "$ssh_key_file" -o StrictHostKeyChecking=no "/tmp/blog-deployment.tar.gz" ubuntu@"$instance_ip":/tmp/; then
        print_error "Failed to upload deployment package"
        return 1
    fi
    
    # Deploy application with smart service management
    print_action "Deploying application with smart service management..."
    ssh -i "$ssh_key_file" -o StrictHostKeyChecking=no ubuntu@"$instance_ip" << 'EOF'
set -e

echo "=== Smart Application Deployment ==="

# Extract application files
cd /tmp
if [ -f "blog-deployment.tar.gz" ]; then
    tar -xzf blog-deployment.tar.gz
    echo "✅ Deployment package extracted"
else
    echo "❌ Deployment package not found"
    exit 1
fi

# Ensure web directory exists
BLOG_DIR="/var/www/html/blog"
sudo mkdir -p "$BLOG_DIR"

# Deploy application files
if [ -d "src" ]; then
    echo "📁 Deploying files to $BLOG_DIR..."
    sudo cp -r src/* "$BLOG_DIR/"
    sudo chown -R www-data:www-data "$BLOG_DIR"
    sudo chmod -R 755 "$BLOG_DIR"
    echo "✅ Application files deployed"
else
    echo "❌ Source directory not found"
    exit 1
fi

# Smart service management
echo "=== Smart Service Management ==="

# Check if Apache is installed and start if needed
if command -v apache2 >/dev/null 2>&1; then
    if ! systemctl is-active --quiet apache2; then
        echo "🚀 Starting Apache..."
        sudo systemctl start apache2
        sudo systemctl enable apache2
    else
        echo "🔄 Apache running, reloading configuration..."
        sudo systemctl reload apache2
    fi
    echo "✅ Apache: $(systemctl is-active apache2)"
else
    echo "⚠️ Apache not installed on this instance"
fi

# Check if MySQL is installed and start if needed  
if command -v mysql >/dev/null 2>&1; then
    if ! systemctl is-active --quiet mysql; then
        echo "🚀 Starting MySQL..."
        sudo systemctl start mysql
        sudo systemctl enable mysql
    else
        echo "✅ MySQL already running"
    fi
    echo "✅ MySQL: $(systemctl is-active mysql)"
    
    # Smart database setup
    if [ -f "$BLOG_DIR/database.sql" ]; then
        echo "🗄️ Setting up database..."
        # Try multiple authentication methods
        db_setup_success=false
        
        for mysql_cmd in "mysql -u root -p'RootSecurePassword123!'" "mysql -u root -pRootSecurePassword123!" "mysql -u root" "sudo mysql"; do
            if eval "$mysql_cmd -e 'SELECT 1' >/dev/null 2>&1"; then
                echo "✅ Database connection successful with: ${mysql_cmd%% *}"
                eval "$mysql_cmd < $BLOG_DIR/database.sql" 2>/dev/null || echo "Database setup attempted"
                db_setup_success=true
                break
            fi
        done
        
        if [ "$db_setup_success" = false ]; then
            echo "⚠️ Could not connect to database with any method"
        fi
    fi
else
    echo "⚠️ MySQL not installed on this instance"
fi

# Final verification
echo "=== Final Service Status ==="
command -v apache2 >/dev/null && systemctl is-active apache2 && echo "✅ Apache: ACTIVE" || echo "❌ Apache: INACTIVE"
command -v mysql >/dev/null && systemctl is-active mysql && echo "✅ MySQL: ACTIVE" || echo "❌ MySQL: INACTIVE"

# Check if blog files are accessible
if [ -f "$BLOG_DIR/index.php" ]; then
    echo "✅ Blog files: DEPLOYED"
else
    echo "❌ Blog files: MISSING"
fi

# Cleanup
rm -f /tmp/blog-deployment.tar.gz
rm -rf /tmp/src

echo "✅ Smart deployment completed!"
EOF

    # Clean up local deployment package
    rm -f "/tmp/blog-deployment.tar.gz"
    
    print_success "Application deployment completed!"
    return 0
}

# Function to verify deployment
verify_deployment() {
    local instance_ip="$1"
    
    if [ -z "$instance_ip" ]; then
        print_warning "No instance IP available for verification"
        return 1
    fi
    
    print_status "🔍 Verifying deployment..."
    
    # Wait a moment for services to stabilize
    sleep 10
    
    # Test blog accessibility
    local max_attempts=5
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        echo "Attempt $attempt/$max_attempts: Testing blog accessibility..."
        
        if curl -f -s --max-time 10 "http://$instance_ip/blog" >/dev/null 2>&1; then
            print_success "✅ Blog is accessible at: http://$instance_ip/blog"
            return 0
        fi
        
        if [ $attempt -eq $max_attempts ]; then
            print_warning "❌ Blog not accessible via HTTP"
            print_status "This might be normal if:"
            echo "  - Instance is in private subnet"
            echo "  - Security group doesn't allow HTTP"
            echo "  - Services need more time to start"
            return 1
        fi
        
        sleep 15
        ((attempt++))
    done
}

# Main function
main() {
    print_success "🚀 Smart AWS Resource Manager"
    echo "============================================"
    print_status "Intelligently managing existing AWS resources"
    echo ""
    
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
    
    print_success "All prerequisites satisfied"
    echo ""
    
    # Discover existing infrastructure
    if discover_existing_infrastructure; then
        print_status "Using existing infrastructure approach"
        
        # Ensure instance is running
        if ensure_instance_running; then
            
            # Discover network resources
            discover_existing_network_resources
            
            # Create Terraform configuration
            create_terraform_config
            
            # Run Terraform with existing resources
            if run_terraform_with_existing; then
                
                # Deploy application
                if [ -n "$INSTANCE_IP" ] && [ -n "$KEY_NAME" ]; then
                    if deploy_to_existing_instance "$INSTANCE_IP" "$KEY_NAME"; then
                        
                        # Verify deployment
                        verify_deployment "$INSTANCE_IP"
                        
                        # Success summary
                        echo ""
                        print_success "🎉 Smart deployment completed successfully!"
                        echo "============================================"
                        echo "🏗️  Used existing instance: $INSTANCE_ID"
                        echo "🌐 Blog URL: http://$INSTANCE_IP/blog"
                        echo "🏠 Server: http://$INSTANCE_IP"
                        echo "🖥️  SSH: ssh -i ${KEY_NAME}.pem ubuntu@$INSTANCE_IP"
                        echo "============================================"
                    else
                        print_error "Application deployment failed"
                        exit 1
                    fi
                else
                    print_error "Missing instance IP or SSH key information"
                    exit 1
                fi
            else
                print_error "Terraform execution failed"
                exit 1
            fi
        else
            print_error "Failed to ensure instance is running"
            exit 1
        fi
    else
        print_warning "No existing infrastructure found. Run with --create-new to create new resources"
        echo ""
        print_status "To create new infrastructure, please run:"
        echo "  ./deploy.sh --create-new"
        exit 1
    fi
}

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        echo "Smart AWS Resource Manager"
        echo ""
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --create-new   Force creation of new resources"
        echo ""
        echo "This script intelligently manages existing AWS resources:"
        echo "  - Discovers existing blog instances"
        echo "  - Starts stopped instances instead of recreating"
        echo "  - Reuses existing VPC, subnets, security groups"
        echo "  - Deploys application to running instances"
        exit 0
        ;;
    --create-new)
        print_status "Force creation mode - will create new resources"
        USE_EXISTING=false
        # Here you would call the original deployment logic
        print_warning "New resource creation not implemented in this script"
        print_status "Please use the original deployment script for new resources"
        exit 1
        ;;
    "")
        # Default behavior - smart resource management
        main
        ;;
    *)
        print_error "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac