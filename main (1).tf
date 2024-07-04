provider "aws" {
  region = "eu-central-1"
}

# Check if the instance already exists with the specific tag
data "aws_instance" "existing_instance" {
  filter {
    name   = "tag:Name"
    values = ["my-php-app"]
  }
  filter {
    name   = "instance-state-name"
    values = ["running"]  # Only retrieve running instances
  }
}

# Check if the security group already exists
data "aws_security_group" "existing_security_group" {
  name = "my-security-group"
}

# Define AWS instance resource, create only if it doesn't exist
resource "aws_instance" "my_app" {
  count = length(data.aws_instance.existing_instance.id) == 0 ? 1 : 0  # Create only if no existing instance found

  ami           = "ami-0910ce22fbfa68e1d"
  instance_type = "t2.micro"
  key_name      = "docker-compose3"

  tags = {
    Name = "my-php-app"
  }
}

# Define AWS security group resource, create only if it doesn't exist
resource "aws_security_group" "my_security_group" {
  count = length(data.aws_security_group.existing_security_group.id) == 0 ? 1 : 0  # Create only if no existing security group found

  name        = "my-security-group"
  description = "Security group for my application"
  vpc_id      = "vpc-04347ab37cb8133ff"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "my-php-app"
  }
}

# Output the public IP if instance was created or use existing instance IP
output "public_ip" {
  value = length(aws_instance.my_app) > 0 ? aws_instance.my_app[0].public_ip : length(data.aws_instance.existing_instance.id) > 0 ? data.aws_instance.existing_instance.public_ip : "No instances found"
}