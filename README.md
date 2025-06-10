# lamp-stack-application

## Simple LAMP Stack Blog

A beginner-friendly LAMP stack blog application deployed on AWS Lightsail with automated CI/CD pipeline using Terraform and GitHub Actions.

## 🚀 Features

- **Simple Blog Application**: Create and view blog posts
- **Complete LAMP Stack**: Linux (Ubuntu), Apache, MySQL, PHP
- **Infrastructure as Code**: Terraform for AWS Lightsail
- **Automated CI/CD**: GitHub Actions for deployment
- **Responsive Design**: Mobile-friendly interface
- **Health Monitoring**: Built-in health check endpoint

## 🏗️ Architecture

```
GitHub Repository → GitHub Actions → AWS Lightsail Instance
                                          ↓
                            LAMP Stack (Apache + MySQL + PHP)
```

## 📋 Prerequisites

- AWS Account with billing enabled
- GitHub Account
- Local machine with:
  - Terraform installed
  - AWS CLI installed and configured
  - Git installed

## 🛠️ Setup Instructions

### Step 1: Clone and Setup Repository
```bash
git clone <your-repo-url>
cd simple-lamp-blog
```

### Step 2: Configure AWS CLI
```bash
aws configure
# Enter your AWS Access Key ID, Secret Key, Region, and Output format
```

### Step 3: Deploy Infrastructure
```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### Step 4: Configure GitHub Secrets
Add these secrets to your GitHub repository:
- `AWS_ACCESS_KEY_ID`: From Terraform output
- `AWS_SECRET_ACCESS_KEY`: From Terraform output  
- `SSH_PRIVATE_KEY`: Content of `blog-server-key.pem`
- `DB_PASSWORD`: Your database password

### Step 5: Push Code and Deploy
```bash
git add .
git commit -m "Initial deployment"
git push origin main
```

## 🔧 Configuration

### Database Configuration
- **Database**: blog_db
- **User**: blog_user
- **Password**: Set in terraform/variables.tf

### Server Configuration
- **Instance Type**: AWS Lightsail micro_2_0
- **OS**: Ubuntu 20.04
- **Web Server**: Apache2
- **Database**: MySQL 8.0
- **PHP Version**: 7.4+

## 📊 Monitoring

### Health Check
Visit `http://your-ip/health.php` to check:
- Server status
- PHP version
- Database connectivity

### Logs
```bash
# SSH into server
ssh -i blog-server-key.pem ubuntu@<your-ip>

# Check Apache logs
sudo tail -f /var/log/apache2/access.log
sudo tail -f /var/log/apache2/error.log
```

## 🔄 CI/CD Pipeline

The GitHub Actions workflow automatically:
1. Triggers on push to main branch
2. Connects to AWS Lightsail
3. Deploys code to web server
4. Runs health checks
5. Reports deployment status

## 📁 Project Structure

```
simple-lamp-blog/
├── src/index.php           # Main application
├── terraform/              # Infrastructure code
├── .github/workflows/      # CI/CD pipeline
├── database/setup.sql      # Database setup
└── README.md              # This file
```

## 🛡️ Security

- Database credentials stored securely
- Input sanitization with htmlspecialchars()
- SSH key-based server access
- IAM user with minimal permissions

## 💰 Cost Estimation

- AWS Lightsail micro_2_0: ~$3.50/month
- Static IP: Free with instance
- Data transfer: 1TB included

## 🔧 Customization

### Adding New Features
1. Modify `src/index.php`
2. Update database schema if needed
3. Push changes to trigger deployment

### Scaling Up
1. Change `bundle_id` in `terraform/main.tf`
2. Run `terraform apply`

## 🐛 Troubleshooting

### Common Issues

**Deployment Failed**
- Check GitHub Actions logs
- Verify AWS credentials
- Ensure SSH key is correct

**Website Not Loading**
- Check security group rules
- Verify Apache is running: `sudo systemctl status apache2`
- Check Apache error logs

**Database Connection Error**
- Verify MySQL is running: `sudo systemctl status mysql`
- Check database credentials
- Test connection: `mysql -u blog_user -p blog_db`

## 📝 License

This project is open source and available under the MIT License.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes
4. Submit a pull request

## 📞 Support

If you encounter issues:
1. Check the troubleshooting section
2. Review GitHub Actions logs
3. Check AWS Lightsail console
4. Open an issue in this repository