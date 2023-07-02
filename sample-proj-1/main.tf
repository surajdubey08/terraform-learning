terraform {
    backend "local" {
        path = "./states/terraform.tfstate"
    }
}

provider "aws"{
    region = "us-east-1"
}

variable vpc_cidr_block{}
variable subnet_cidr_block {}
variable avail_zone {}
variable env_prefix {}
variable my_ip {}
variable instance_type {}
# variable public_key_location {}
variable ansible_master_server{}
# variable private_key_location{}
variable ssh_key_private{}

resource "aws_vpc" "myapp-vpc"   {
    cidr_block = var.vpc_cidr_block
    
    enable_dns_hostnames = true

    tags = {
        Name: "${var.env_prefix}-vpc"
    }
}

resource "aws_subnet" "myapp-subnet-1"  {
    vpc_id = aws_vpc.myapp-vpc.id
    cidr_block = var.subnet_cidr_block
    availability_zone = var.avail_zone
    tags = {
        Name: "${var.env_prefix}-subnet-1"
    }
}

resource "aws_route_table" "myapp-route-table"  {
    vpc_id = aws_vpc.myapp-vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.myapp-igw.id
    }
    tags = {
        Name: "${var.env_prefix}-rtb"
    }
}

resource "aws_internet_gateway" "myapp-igw" {
    vpc_id = aws_vpc.myapp-vpc.id
    tags = {
        Name: "${var.env_prefix}-igw"
    }
}

resource "aws_route_table_association" "asso-rtb-subnet"    {
    subnet_id = aws_subnet.myapp-subnet-1.id
    route_table_id = aws_route_table.myapp-route-table.id
}

resource "aws_security_group" "myapp-sg"    {
    name = "myapp-sg"
    vpc_id = aws_vpc.myapp-vpc.id

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = [var.my_ip]
    }

    ingress {
        from_port = 8080
        to_port = 8080
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress  {
        from_port = 0 # any port
        to_port = 0 # any port
        protocol = "-1" # any protocol
        cidr_blocks = ["0.0.0.0/0"]
        prefix_list_ids = []
    }

    tags = {
        Name: "${var.env_prefix}-sg"
    }
}

data "aws_ami" "latest-amazon-linux-image"  {
    most_recent = true
    owners = ["amazon"]
    filter  {
        name = "name"
        values = ["amzn2-ami-hvm-*-x86_64-gp2"]
    }

    filter {
        name = "virtualization-type"
        values = ["hvm"]
    }
}

output "aws_ami"    {
    value = data.aws_ami.latest-amazon-linux-image.id
}

output "ec2_public_ip_dev"    {
    value = aws_instance.myapp-server[*].public_ip
}

output "ec2_public_ip_prod"    {
    value = aws_instance.myapp-server-prod[*].public_ip
}

# resource "aws_key_pair" "ssh-key"   {
#     key_name     = "${var.env_prefix}-server-key"
#     # public_key = "${file(var.public_key_location)}"
#     public_key = file(var.public_key_location)
# }

resource "aws_instance" "myapp-server"  {
    count = 2
    ami = "ami-06b09bfacae1453cb"
    # ami =  data.aws_ami.latest-amazon-linux-image.id
    instance_type = var.instance_type

    subnet_id = aws_subnet.myapp-subnet-1.id
    vpc_security_group_ids = [aws_security_group.myapp-sg.id]
    availability_zone = var.avail_zone

    associate_public_ip_address = true
    
    # key_name = aws_key_pair.ssh-key.key_name
    key_name = "aws-key-pair"

    # user_data = file("entry-script.sh")

    tags = {
        Name: "${var.env_prefix}-server"
    }
}

resource "aws_instance" "myapp-server-prod"  {
    count = 2
    ami = "ami-06b09bfacae1453cb"
    # ami =  data.aws_ami.latest-amazon-linux-image.id
    instance_type = "t2.small"

    subnet_id = aws_subnet.myapp-subnet-1.id
    vpc_security_group_ids = [aws_security_group.myapp-sg.id]
    availability_zone = var.avail_zone

    associate_public_ip_address = true
    
    # key_name = aws_key_pair.ssh-key.key_name
    key_name = "aws-key-pair"

    # user_data = file("entry-script.sh")

    tags = {
        Name: "prod-server"
    }
}

resource "null_resource" "configure_server" {

    # triggers = {
    #     trigger = aws_instance.myapp-server.public_ip
    # }

    depends_on = [
        aws_instance.myapp-server,
        aws_instance.myapp-server-prod,
    ]
    provisioner "remote-exec"   {
        connection  {
            type = "ssh"
            host = var.ansible_master_server
            user = "ubuntu"
            private_key = file("./aws-key-pair.pem")
        }

        inline = [
            "cd /home/ubuntu/ansible",
            "sudo ansible-playbook deploy-docker.yaml"
        ]

    }
}
            # "sudo ansible-playbook --inventory ${aws_instance.myapp-server.public_ip}, --private-key ${var.ssh_key_private} --user ec2-user  deploy-docker.yaml"