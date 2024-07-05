provider "aws" {
  region = "eu-central-1"
}

resource "aws_security_group" "my_security_group" {
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

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "my-php-app"
  }
}

resource "aws_launch_configuration" "my_app_lc" {
  name_prefix     = "my-app-lc"
  image_id        = "ami-0910ce22fbfa68e1d"
  instance_type   = "t2.micro"
  key_name        = "docker-compose3"
  associate_public_ip_address = true
  security_groups = [aws_security_group.my_security_group.id]
  user_data = <<-EOF
      #!/bin/bash
      sudo yum install -y git
      git clone https://gitlab.com/3210snoop3210/testtask.git
      sudo yum install -y aws-cli
      aws configure set aws_access_key_id $TF_VAR_AWS_ACCESS_KEY_ID
      aws configure set aws_secret_access_key $TF_VAR_AWS_SECRET_ACCESS_KEY
      # SSH into the instance and perform Docker-related operations
      sudo yum install -y docker \
      && sudo curl -L "https://github.com/docker/compose/releases/download/v2.21.0/docker-compose-linux-x86_64" -o /usr/local/bin/docker-compose \
      && sudo chmod +x /usr/local/bin/docker-compose \
      && sudo systemctl start docker && sudo systemctl enable docker \
      && sudo docker login -u $TF_VAR_DOCKER_USERNAME -p $TF_VAR_DOCKER_PASSWORD \
      && sudo docker-compose  -f /testtask/docker-compose.yml up -d
      EOF

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_subnet" "subnet1" {
  vpc_id            = "vpc-04347ab37cb8133ff"
  cidr_block        = "172.31.48.0/24"
  availability_zone = "eu-central-1a"
  tags = {
    Name = "subnet1"
  }
}

resource "aws_subnet" "subnet2" {
  vpc_id            = "vpc-04347ab37cb8133ff"
  cidr_block        = "172.31.49.0/24"
  availability_zone = "eu-central-1b"
  tags = {
    Name = "subnet2"
  }
}

resource "aws_autoscaling_group" "my_app_asg" {
  launch_configuration     = aws_launch_configuration.my_app_lc.name
  min_size                 = 1
  max_size                 = 2
  desired_capacity         = 1
  health_check_grace_period = 300
  health_check_type        = "EC2"
  vpc_zone_identifier      = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]

  tag {
    key                 = "Name"
    value               = "my-app-instance"
    propagate_at_launch = true
  }
}

resource "aws_lb" "my_app_lb" {
  name               = "my-app-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.my_security_group.id]
  subnets            = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]

  enable_deletion_protection = false

  tags = {
    Name = "my-app-lb"
  }
}

resource "aws_lb_target_group" "my_app_tg" {
  name     = "my-app-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = "vpc-04347ab37cb8133ff"

  health_check {
    interval            = 30
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name = "my-app-tg"
  }
}

resource "aws_lb_listener" "my_app_listener" {
  load_balancer_arn = aws_lb.my_app_lb.arn
  port              = "8080"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.my_app_tg.arn
  }
}

resource "aws_autoscaling_attachment" "asg_attachment" {
  autoscaling_group_name = aws_autoscaling_group.my_app_asg.name
  lb_target_group_arn    = aws_lb_target_group.my_app_tg.arn
}

data "aws_instances" "my_app_instances" {
  filter {
    name   = "tag:Name"
    values = ["my-app-instance"]
  }
}

output "load_balancer_dns_name" {
  value       = aws_lb.my_app_lb.dns_name
  description = "The DNS name of the load balancer."
}

output "instance_ids" {
  value       = data.aws_instances.my_app_instances.ids
  description = "The IDs of the instances."
}

output "public_ips" {
  value       = data.aws_instances.my_app_instances.public_ips
  description = "The public IPs of the instances."
}