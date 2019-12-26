provider "aws" {
    region = "us-east-2"
}

# Create an EC 2 Instance; deploy a server
/*
resource "aws_instance" "example" {
    ami                     = "ami-0c55b159cbfafe1f0"
    instance_type           = "t2.micro"
    # Example of resource attribute reference expression for [aws_security_group.instance.id]
    vpc_security_group_ids  = [aws_security_group.instance.id]

    # Deploy a single web server to the server
    # Example of interpolation expression for ${var.server_port}, reference inside of a literal string
    user_data = <<-EOF
                #!/bin/bash
                echo "Hello, World" > index.html
                nohup busybox httpd -f -p ${var.server_port} &
                EOF

    tags = {
        Name = "terraform-example"
    }
}
*/

# Create a Launch Configuration
# Deploy a server /  EC2 Instance
resource "aws_launch_configuration" "example" {
    image_id         = "ami-0c55b159cbfafe1f0"
    instance_type    = "t2.micro"
    # Example of resource attribute reference expression for [aws_security_group.instance.id]
    #security_groups  = [aws_security_group.instance.id]
    security_groups  = [aws_security_group.alb.id]

    # Deploy a web server to the EC2 Instance
    # Example of interpolation expression for ${var.server_port}, reference inside of a literal string
    user_data = <<-EOF
                #!/bin/bash
                echo "Hello, World" > index.html
                nohup busybox httpd -f -p ${var.server_port} &
                EOF
    /*
    tags = {
        Name = "terraform-lc-example"
    }
    */
}

# Create an Auto Scaling Group; a service that automatically monitors and adjusts compute resources to maintain performance for hosted applications
resource "aws_autoscaling_group" "example" {
    launch_configuration = aws_launch_configuration.example.name
    # Get the subnet IDs out of the aws_subnet_ids data source
    vpc_zone_identifier  = data.aws_subnet_ids.default.ids

    target_group_arns = [aws_lb_target_group.asg.arn]
    health_check_type = "ELB" # default is EC2

    min_size = 2
    max_size = 10

    tag {
      key                 = "Name"
      value               = "terraform-asg-example"
      propagate_at_launch = true
    }
}

/*
# Create a security group for the EC2 Instances
resource "aws_security_group" "instance" {
    name = "terraform-example-instance"

    ingress {
        # Example of variable reference expression for var.server_port
        from_port   = var.server_port
        to_port     = var.server_port
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

}
*/

# Create a Load Balancer
resource "aws_lb" "example" {
    name               = "terraform-asg-example"
    load_balancer_type = "application"
    subnets            = data.aws_subnet_ids.default.ids
    security_groups    = [aws_security_group.alb.id]
}

# Create a Listener for the Load Balancer
resource "aws_lb_listener" "http" {
    load_balancer_arn = aws_lb.example.arn
    port              = var.server_port
    protocol          = "HTTP"

    # By default, return a simple 404 page
    default_action {
        type = "fixed-response"

        fixed_response {
            content_type = "text/plain"
            message_body = "404: page not found"
            status_code  = 404
        }
    }
}

# Create Listener Rules for the Load Balancer
resource "aws_lb_listener_rule" "asg" {
    listener_arn = aws_lb_listener.http.arn
    priority     = 100

    condition {
        field  = "path-pattern"
        values = ["*"]
    }

    action {
        type             = "forward"
        target_group_arn = aws_lb_target_group.asg.arn
    }
}

# Create a Securuty Group for the Load Balancer
resource "aws_security_group" "alb" {
    name = "terraform-example-alb"

    # Allow inbound HTTP requests
    ingress {
        from_port   = var.server_port
        to_port     = var.server_port
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    # Allow all outbound requests
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

# Create a Target Group for the Load Balancer
resource "aws_lb_target_group" "asg" {
    port     = var.server_port
    protocol = "HTTP"
    vpc_id   = data.aws_vpc.default.id
}

variable "server_port" {
    description = "The port the server will use for HTTP requests"
    type        = number
    default     = 8080
}

data "aws_vpc" "default" {
    default = true
}

data "aws_subnet_ids" "default" {
    vpc_id = data.aws_vpc.default.id
}

/*
data "aws_instances" "example" {
    instance_tags = {
        Name = "terraform-asg-example"
    }
}
*/

/*
data "aws_launch_configuration" "example" {
    name = "terraform-20191218205247123100000001"
}
*/

/*
output "public_ips" {
    value       = data.aws_instances.example.public_ips
    description = "The public IP address of the web server"
}
*/

/*
output "launch_configuration_data" {
#    value       = data.aws_launch_configuration.example.associate_public_ip_address
#    value       = [data.aws_launch_configuration.example.name]
    value       = [data.aws_launch_configuration.example.security_groups]
    description = "The launch configuration data"
}
*/

output "alb_dns_name" {
    value       = aws_lb.example.dns_name
    description = "The domain name of the load balancer"
}
