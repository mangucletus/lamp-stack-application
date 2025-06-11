#!/bin/bash

/**
 * Manual Deployment Script for Simple Blog Application
 * 
 * This script provides a manual deployment option as an alternative to the
 * automated CI/CD pipeline. It performs the same deployment steps that
 * GitHub Actions would execute.
 * 
 * Usage: ./scripts/deploy.sh [environment]
 * Example: ./scripts/deploy.sh production
 */

# Enable strict error handling
set -euo pipefail

# Configuration variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"
SRC_DIR="$PROJECT_ROOT/src"

# Color codes for output formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if required tools are installed
    local missing_tools=()
    
    if ! command -v terraform &> /dev/null; then
        missing_tools+=("terraform")
    fi
    
    if ! command -v aws &> /dev/null; then
        missing_tools+=("aws-cli")
    fi
    
    if ! command -v ssh &> /dev/null; then
        missing_tools+=("ssh")
    fi
    
    if ! command -v scp &> /dev/null; then
        missing_tools+=("scp")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        echo "Please install the missing tools and try again."
        exit 1
    fi
    
    # Check if AWS credentials are configured
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured or invalid"
        echo "Please run 'aws configure' to set up your credentials."
        exit 1
    fi
    
    # Check if we're in the correct directory
    if [ ! -f "$TERRAFORM_DIR/main.tf" ]; then
        print_error "Terraform configuration not found. Are you in the project root?"
        exit 1
    fi
    
    print_success "All prerequisites satisfied"
}

# Function to validate Terraform configuration
validate_terraform() {
    print_status "Validating Terraform configuration..."
    
    cd "$TERRAFORM_DIR"
    
    # Initialize Terraform if needed
    if [ ! -d ".terraform" ]; then
        print_status "Initializing Terraform..."
        terraform init
    fi
    
    # Validate configuration
    if terraform validate; then
        print_success "Terraform configuration is valid"
    else
        print_error "Terraform configuration validation failed"
        exit 1
    fi
    
    # Format check
    if terraform fmt -check; then
        print_success "Terraform configuration is properly formatted"
    else
        print_warning "Terraform configuration needs formatting (run: terraform fmt)"
    fi
}

# Function to plan Terraform deployment
plan_terraform() {
    print_status "Creating Terraform execution plan..."
    
    cd "$TERRAFORM_DIR"
    
    # Create plan
    if terraform plan -out=deployment.tfplan; then
        print_success "Terraform plan created successfully"
        return 0
    else
        print_error "Terraform planning failed"
        return 1
    fi
}

# Function to apply Terraform configuration
apply_terraform() {
    print_status "Applying Terraform configuration..."
    
    cd "$TERRAFORM_DIR"
    
    # Apply the plan
    if terraform apply deployment.tfplan; then
        print_success "Infrastructure deployed successfully"
        
        # Clean up plan file
        rm -f deployment.tfplan
        
        return 0
    else
        print_error "Terraform apply failed"
        return 1
    fi
}

# Function to get infrastructure outputs
get_terraform_outputs() {
    print_status "Retrieving infrastructure information..."
    
    cd "$TERRAFORM_DIR"
    
    # Get outputs and store in variables
    INSTANCE_IP=$(terraform output -raw instance_public_ip 2>/dev/null || echo "")
    INSTANCE_ID=$(terraform output -raw instance_id 2>/dev/null || echo "")
    SSH_KEY_NAME=$(terraform output -raw ssh_key_name 2>/dev/null || echo "")
    
    if [ -z "$INSTANCE_IP" ]; then
        print_error "Could not retrieve instance IP address"
        return 1
    fi
    
    print_success "Instance IP: $INSTANCE_IP"
    print_success "Instance ID: $INSTANCE_ID"
    
    # Check if SSH key file exists
    SSH_KEY_FILE="$TERRAFORM_DIR/${SSH_KEY_NAME}.pem"
    if [ ! -f "$SSH_KEY_FILE" ]; then
        print_error "SSH key file not found: $SSH_KEY_FILE"
        return 1
    fi
    
    return 0
}

# Function to wait for instance to be ready
wait_for_instance() {
    print_status "Waiting for instance to be ready..."
    
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        print_status "Attempt $attempt/$max_attempts: Checking instance readiness..."
        
        # Try to connect and check if userdata script completed
        if ssh -i "$SSH_KEY_FILE" -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
           ubuntu@"$INSTANCE_IP" "test -f /var/log/userdata-complete" 2>/dev/null; then
            print_success "Instance is ready for deployment!"
            return 0
        fi
        
        print_status "Instance not ready yet, waiting 30 seconds..."
        sleep 30
        ((attempt++))
    done
    
    print_warning "Instance readiness check timed out, proceeding anyway..."
    return 0
}

# Function to create deployment package
create_deployment_package() {
    print_status "Creating deployment package..."
    
    cd "$PROJECT_ROOT"
    
    # Create temporary deployment package
    local temp_dir=$(mktemp -d)
    local package_file="$temp_dir/blog-deployment.tar.gz"
    
    # Copy source files
    tar -czf "$package_file" -C "$PROJECT_ROOT" src/
    
    echo "$package_file"
}

# Function to deploy application code
deploy_application() {
    print_status "Deploying application code to server..."
    
    # Create deployment package
    local package_file=$(create_deployment_package)
    
    # Copy package to server
    print_status "Uploading application files..."
    if scp -i "$SSH_KEY_FILE" -o StrictHostKeyChecking=no "$package_file" ubuntu@"$INSTANCE_IP":/tmp/blog-deployment.tar.gz; then
        print_success "Files uploaded successfully"
    else
        print_error "Failed to upload files to server"
        rm -f "$package_file"
        return 1
    fi
    
    # Execute deployment commands on server
    print_status "Installing application on server..."
    ssh -i "$SSH_KEY_FILE" -o StrictHostKeyChecking=no ubuntu@"$INSTANCE_IP" << 'EOF'
        set -e
        
        echo "📦 Extracting application files..."
        cd /tmp
        tar -xzf blog-deployment.tar.gz
        
        echo "📁 Installing files to web directory..."
        sudo cp -r src/* /var/www/html/blog/
        sudo chown -R www-data:www-data /var/www/html/blog
        sudo chmod -R 755 /var/www/html/blog
        
        echo "🗄️ Setting up database..."
        mysql -u root -p${MYSQL_ROOT_PASSWORD:-"RootSecurePassword123!"} < /var/www/html/blog/database.sql
        
        echo "🔄 Reloading Apache..."
        sudo systemctl reload apache2
        
        echo "🧹 Cleaning up temporary files..."
        rm -f /tmp/blog-deployment.tar.gz
        rm -rf /tmp/src
        
        echo "✅ Application deployment completed!"
EOF
    
    # Clean up local package
    rm -f "$package_file"
    
    if [ $? -eq 0 ]; then
        print_success "Application deployed successfully"
        return 0
    else
        print_error "Application deployment failed"
        return 1
    fi
}

# Function to verify deployment
verify_deployment() {
    print_status "Verifying deployment..."
    
    # Wait for services to stabilize
    sleep 10
    
    # Test website accessibility
    print_status "Testing website accessibility..."
    if curl -f -s "http://$INSTANCE_IP/blog" > /dev/null; then
        print_success "✅ Blog website is accessible at http://$INSTANCE_IP/blog"
    else
        print_warning "❌ Blog website test failed - but this might be temporary"
    fi
    
    # Check server status
    print_status "Checking server services..."
    ssh -i "$SSH_KEY_FILE" -o StrictHostKeyChecking=no ubuntu@"$INSTANCE_IP" << 'EOF'
        echo "=== Service Status Check ==="
        echo "Apache2: $(systemctl is-active apache2)"
        echo "MySQL: $(systemctl is-active mysql)"
        echo "UFW Firewall: $(systemctl is-active ufw)"
        
        echo "=== Database Connection Test ==="
        if mysql -u blog_user -p${MYSQL_BLOG_PASSWORD:-"SecurePassword123!"} -e "SELECT COUNT(*) as total_posts FROM blog_db.posts;" 2>/dev/null; then
            echo "✅ Database connection successful"
        else
            echo "❌ Database connection failed"
        fi
        
        echo "=== Disk Usage ==="
        df -h / | grep -v Filesystem
        
        echo "=== Recent Apache Logs ==="
        sudo tail -3 /var/log/apache2/blog_error.log 2>/dev/null || echo "No recent Apache errors"
EOF
}

# Function to display deployment summary
show_deployment_summary() {
    print_success "🎉 Deployment Summary"
    echo "========================="
    echo "🌐 Blog URL: http://$INSTANCE_IP/blog"
    echo "🖥️  SSH Access: ssh -i $SSH_KEY_FILE ubuntu@$INSTANCE_IP"
    echo "📊 Instance ID: $INSTANCE_ID"
    echo "🔑 SSH Key: $SSH_KEY_FILE"
    echo "========================="
    echo ""
    echo "🚀 Your blog is now live! Visit the URL above to see your application."
    echo "💡 To make changes, edit files in the 'src/' directory and run this script again."
}

# Function to handle cleanup on script exit
cleanup() {
    if [ -n "${TERRAFORM_DIR:-}" ] && [ -f "$TERRAFORM_DIR/deployment.tfplan" ]; then
        rm -f "$TERRAFORM_DIR/deployment.tfplan"
    fi
}

# Function to show usage information
show_usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -p, --plan     Only run Terraform plan (don't apply)"
    echo "  -s, --skip-tf  Skip Terraform and only deploy application code"
    echo "  -v, --verify   Only run deployment verification"
    echo ""
    echo "Examples:"
    echo "  $0                 # Full deployment"
    echo "  $0 --plan          # Only plan infrastructure changes"
    echo "  $0 --skip-tf       # Only deploy application code"
    echo "  $0 --verify        # Only verify existing deployment"
}

# Main deployment function
main() {
    local plan_only=false
    local skip_terraform=false
    local verify_only=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -p|--plan)
                plan_only=true
                shift
                ;;
            -s|--skip-tf)
                skip_terraform=true
                shift
                ;;
            -v|--verify)
                verify_only=true
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Set up cleanup trap
    trap cleanup EXIT
    
    print_success "🚀 Starting Blog Application Deployment"
    echo "========================================"
    
    # Check prerequisites
    check_prerequisites
    
    if [ "$verify_only" = true ]; then
        # Only run verification
        get_terraform_outputs
        verify_deployment
        show_deployment_summary
        exit 0
    fi
    
    if [ "$skip_terraform" = false ]; then
        # Run Terraform workflow
        validate_terraform
        plan_terraform
        
        if [ "$plan_only" = true ]; then
            print_success "Terraform plan completed. Review the plan above."
            exit 0
        fi
        
        apply_terraform
        get_terraform_outputs
        wait_for_instance
    else
        # Skip Terraform, just get existing outputs
        get_terraform_outputs
    fi
    
    # Deploy application
    deploy_application
    verify_deployment
    show_deployment_summary
    
    print_success "🎉 Deployment completed successfully!"
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi