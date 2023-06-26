provider "aws" {
    region = "us-east-1"
    # access_key = "AKIA3TSRU5ZF7V2DQEEK"
    # secret_key = "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"
}

variable "cidr_block"    {
    description = "CIDR Blocks for VPC and Subnet"
    type = list(string)
}

variable "env"  {
    description = "Development Environment"
}

resource "aws_vpc" "development-vpc" {
    cidr_block = var.cidr_block[0]
    tags = {
        Name: "development"
        env: var.env
    }
}

resource "aws_subnet" "dev-subnet-1" {
    vpc_id = aws_vpc.development-vpc.id
    # "10.0.10.0/24"
    cidr_block = var.cidr_block[1]
    availability_zone = "us-east-1a"
    tags = {
        Name: "subnet-1-dev"
        env: var.env
    }
}

# data "aws_vpc" "existing_vpc"   {
#     # cidr_block = "172.31.0.0/16"
#     default = true
# }

# resource "aws_subnet" "dev-subnet-2" {
#     vpc_id = data.aws_vpc.existing_vpc.id
#     cidr_block = "172.31.96.0/20"
#     availability_zone = "us-east-1a"
#     tags = {
#         Name: "subnet-default"
#     }
# }

output "dev-vpc-id" {
    value = aws_vpc.development-vpc.id
}

output "dev-subnet-id" {
    value = aws_subnet.dev-subnet-1.id
}