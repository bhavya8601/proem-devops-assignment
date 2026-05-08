variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource names and tags"
  type        = string
  default     = "devops-app"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "app_port" {
  description = "Application port exposed by the server"
  type        = number
  default     = 5000
}

variable "allowed_cidrs" {
  description = "CIDR ranges allowed to access the application port"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}