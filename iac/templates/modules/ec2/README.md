# EC2 Module

This Terraform module creates secure EC2 instances with standardized configurations, IAM roles, and security best practices for the Iceberg Data Lakehouse project.

## Features

- **Secure Instance Creation**: EC2 instances with encrypted root volumes and security hardening
- **IAM Integration**: Automatic IAM role creation with SSM managed instance core policy
- **Security Hardening**: IMDSv2 enforcement, EBS encryption, and monitoring enabled
- **Flexible Configuration**: Custom AMIs, instance types, user data, and additional EBS volumes
- **Network Integration**: VPC placement with configurable security groups

## Architecture

```
┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐
│   EC2 Instance      │    │   IAM Role          │    │   EBS Volumes       │
│                     │    │                     │    │                     │
│ • Encrypted Root    │◄───┤ • SSM Core Policy   │    │ • Encrypted         │
│ • IMDSv2 Required   │    │ • EC2 Assume Role   │    │ • KMS Keys          │
│ • Monitoring        │    │ • Instance Profile  │    │ • Custom Sizes      │
│ • User Data         │    │                     │    │                     │
└─────────────────────┘    └─────────────────────┘    └─────────────────────┘
```

## Usage

### Basic Usage

```hcl
module "application_server" {
  source = "../../../templates/modules/ec2"

  APP           = "${APP_NAME}"
  ENV           = "dev"
  instance_name = "app-server"
  subnet_id     = data.aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.app_sg.id]
}
```

### Advanced Usage with EBS Volumes

```hcl
module "database_server" {
  source = "../../../templates/modules/ec2"

  APP           = "${APP_NAME}"
  ENV           = "prod"
  instance_name = "oracle"
  ami_id        = data.aws_ami.amazon_linux_2.id
  instance_type = "r5.2xlarge"
  subnet_id     = data.aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.db_sg.id]

  ebs_volumes = [
    {
      device_name           = "/dev/sdb"
      volume_type           = "gp3"
      volume_size           = 100
      kms_key_id            = data.aws_kms_key.ebs.arn
      encrypted             = true
      delete_on_termination = true
    }
  ]

  user_data = base64encode(templatefile("scripts/setup.sh", {
    DATABASE_NAME = "oracle"
  }))
}
```

## Inputs

| Name                   | Description                                    | Type           | Default      | Required |
| ---------------------- | ---------------------------------------------- | -------------- | ------------ | :------: |
| APP                    | Application name                               | `string`       | n/a          |   yes    |
| ENV                    | Environment name                               | `string`       | n/a          |   yes    |
| instance_name          | Name for the instance                          | `string`       | n/a          |   yes    |
| subnet_id              | Subnet ID for instance deployment             | `string`       | n/a          |   yes    |
| ami_id                 | AMI ID (uses latest AL2023 if not specified)  | `string`       | `null`       |    no    |
| instance_type          | EC2 instance type                              | `string`       | `"t3.small"` |    no    |
| vpc_security_group_ids | List of security group IDs                     | `list(string)` | `[]`         |    no    |
| public_ip              | Associate public IP address                    | `string`       | `"false"`    |    no    |
| user_data              | User data script for instance initialization   | `string`       | `""`         |    no    |
| key_pair_key_name      | EC2 key pair name for SSH access              | `string`       | `""`         |    no    |
| ebs_volumes            | List of additional EBS volumes to attach      | `list(object)` | `[]`         |    no    |

### EBS Volume Object Structure

```hcl
ebs_volumes = [
  {
    device_name           = string  # Device name (e.g., "/dev/sdb")
    volume_size           = number  # Volume size in GB
    volume_type           = string  # Volume type (gp3, gp2, io1, etc.)
    encrypted             = bool    # Enable encryption
    kms_key_id            = string  # KMS key ARN for encryption
    delete_on_termination = bool    # Delete volume on instance termination
  }
]
```

## Outputs

| Name               | Description                        |
| ------------------ | ---------------------------------- |
| arn                | ARN of the EC2 instance            |
| instance_id        | ID of the EC2 instance             |
| private_ip         | Private IP address                 |
| private_dns        | Private DNS name                   |
| public_ip          | Public IP address (if assigned)    |
| public_dns         | Public DNS name (if assigned)      |
| iam_role_arn       | ARN of the IAM role                |
| iam_role_name      | Name of the IAM role               |
| root_block_device  | Root block device information      |
| ebs_block_devices  | EBS block devices information      |

## Security Features

### Instance Security

- **Encrypted Root Volume**: All root volumes are encrypted by default
- **IMDSv2 Enforcement**: Instance metadata service requires tokens
- **Monitoring Enabled**: CloudWatch detailed monitoring activated
- **EBS Optimization**: Enabled for better storage performance

### IAM Configuration

- **Service Role**: EC2 assume role policy for AWS service integration
- **SSM Access**: AmazonSSMManagedInstanceCore policy for remote management
- **Instance Profile**: Automatic linking of IAM role to EC2 instance

### Network Security

- **VPC Integration**: Deployed in specified subnets with security groups
- **No Public IP**: Default configuration for private subnet deployment
- **Security Group Control**: Configurable inbound/outbound rules

## Implementation Details

### AMI Selection

The module automatically selects the latest Amazon Linux 2023 AMI if no custom AMI is specified:

```hcl
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}
```

### User Data Handling

User data is base64 encoded automatically and supports template rendering:

```hcl
user_data_base64 = base64encode(var.user_data)
user_data_replace_on_change = true
```

### Dynamic EBS Volumes

Additional EBS volumes are created using dynamic blocks:

```hcl
dynamic "ebs_block_device" {
  for_each = var.ebs_volumes
  content {
    device_name           = ebs_block_device.value.device_name
    volume_size           = ebs_block_device.value.volume_size
    volume_type           = ebs_block_device.value.volume_type
    encrypted             = ebs_block_device.value.encrypted
    kms_key_id            = ebs_block_device.value.kms_key_id
    delete_on_termination = ebs_block_device.value.delete_on_termination
  }
}
```

## Common Use Cases

### Database Servers

```hcl
module "oracle_db" {
  source = "../../../templates/modules/ec2"
  
  APP           = "${APP_NAME}"
  ENV           = "prod"
  instance_name = "oracle"
  instance_type = "r5.2xlarge"
  subnet_id     = data.aws_subnet.private.id
  
  ebs_volumes = [{
    device_name           = "/dev/sdb"
    volume_size           = 500
    volume_type           = "gp3"
    encrypted             = true
    kms_key_id            = data.aws_kms_key.ebs.arn
    delete_on_termination = false
  }]
}
```

### Application Servers

```hcl
module "app_server" {
  source = "../../../templates/modules/ec2"
  
  APP           = "${APP_NAME}"
  ENV           = "dev"
  instance_name = "api-server"
  instance_type = "t3.medium"
  subnet_id     = data.aws_subnet.private.id
  
  user_data = base64encode(file("scripts/app-setup.sh"))
}
```

## Dependencies

This module requires:

- **Terraform**: >= 1.0
- **AWS Provider**: >= 5.0
- **Network Infrastructure**: VPC and subnets must exist
- **IAM Permissions**:
  - EC2 instance management
  - IAM role creation
  - EBS volume management
  - KMS key usage (for encryption)

## Related Modules

- `../../foundation/network`: Provides VPC and subnet infrastructure
- `../../foundation/kms-keys`: Provides encryption keys for EBS volumes
- `../secrets-manager`: For secure credential storage
