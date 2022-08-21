# Created a vpc with subnets
resource "aws_vpc" "tf-vpc" {
  cidr_block = "10.0.0.0/24"
  enable_dns_hostnames =  true   
  tags = {
  Name = "tf-vpc"
  }
}
# 1st subnet for tf-vpc VPC
resource "aws_subnet" "first-subnet" {
  vpc_id = aws_vpc.tf-vpc.id
  cidr_block = "10.0.0.0/25"
  availability_zone = "us-east-1a"
    tags = {
    Name = "first-subnet"
  }
}
# 2nd subnet for tf-vpc VPC
resource "aws_subnet" "second-subnet" {   
  vpc_id = aws_vpc.tf-vpc.id
  cidr_block = "10.0.0.128/25"
  availability_zone = "us-east-1a"

  tags = {
    Name ="second-subnet"
  }
}
# Created an IGW for public internet connectivity. If any ipv6 addresses were created I would also use an egress-only gateway, but that is not the case.
resource "aws_internet_gateway" "tf-igw" {
  vpc_id = aws_vpc.tf-vpc.id
  
  tags = {
    Name ="tf-IGW"
  }
}
# !!!!!!!!!!!!!Attached the IGW to the VPC. I kept getting errors since it already attaches to the VPC. Commenting this out but leaving it to show error!!!!!!!!!!!!!!!!!!!!!!!
#resource "aws_internet_gateway_attachment" "tf-gw-attach" {
#  internet_gateway_id = aws_internet_gateway.tf-igw.id
#  vpc_id = aws_vpc.tf-vpc.id
#}

# Route tables for the subnets
resource "aws_route_table" "first-rt" {
  vpc_id = aws_vpc.tf-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.tf-igw.id
  }

  tags = {
    Name = "first-subnet-rt"
  }
}

resource "aws_route_table" "second-rt" {
  vpc_id = aws_vpc.tf-vpc.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.tf-igw.id
  }

  tags = {
    Name = "second-subnet-rt"
  }
}
# Associating the route table to the subnets
resource "aws_route_table_association" "first-rt-associaton" {
  route_table_id = aws_route_table.first-rt.id
  subnet_id = aws_subnet.first-subnet.id

}

resource "aws_route_table_association" "second-rt-association" {
  route_table_id = aws_route_table.second-rt.id
  subnet_id = aws_subnet.second-subnet.id
}
#SG for SSH capabilities
resource "aws_security_group" "tf-sg" {
  name = "tf-sg"
  vpc_id = aws_vpc.tf-vpc.id

  ingress {
    description = "allow SSH"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "allow http"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  ingress {
    description = "allow https"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "allow ping"
    from_port = -1
    to_port = -1
    protocol = "icmp"
    cidr_blocks = ["10.0.0.0/24"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}
# Created 2 network interfaces for each ec2
resource "aws_network_interface" "prod-server-interface" {
  subnet_id = aws_subnet.first-subnet.id
  security_groups = [aws_security_group.tf-sg.id]
  

  tags = {
    Name = "Prod server network interface"
  }
}
resource "aws_network_interface" "prod-server-interface_2" {
  subnet_id = aws_subnet.second-subnet.id
  security_groups = [aws_security_group.tf-sg.id]

  tags = {
    Name = "Prod server network interface number 2"
  }
}
# Create 2 elastic IP addresses and associated them with the instances created. It will associate once the EC2 instance above is created.
resource "aws_eip" "tf-eip" {
  instance = aws_instance.prod-server.id
  network_interface = aws_network_interface.prod-server-interface.id
  vpc = true
  depends_on =  [aws_internet_gateway.tf-igw]
   
}
resource "aws_eip" "tf-eip_2" {
  instance = aws_instance.prod-server_2.id
  network_interface = aws_network_interface.prod-server-interface_2.id
  vpc = true
  depends_on =  [aws_internet_gateway.tf-igw]
}
# Created a standard EC2 Instance. This is a non portable version with a static AMI ID. Device index 0 means it is the first network interface card (nic) on the instance.
resource "aws_instance" "prod-server" {
  ami = "ami-090fa75af13c156b4"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"

  network_interface {
    network_interface_id = aws_network_interface.prod-server-interface.id
    device_index = 0
  }
  

  user_data = <<-EOF
          #!/bin/bash
          yum update -y 
          yum install -y httpd
          systemctl enable http
          systemctl start httpd
          echo "<h1>Hello there! You are currently using $(hostname -f). I hope this template can help!</h1>" > /var/www/html/index.html
          
          EOF

  tags = {
    Name = "Prod-server"
  }
}
resource "aws_instance" "prod-server_2" {
  ami = "ami-090fa75af13c156b4"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  
  network_interface {
    network_interface_id = aws_network_interface.prod-server-interface_2.id
    device_index = 0
  }
  

  user_data = <<-EOF
          #!/bin/bash
          yum update -y 
          yum install -y httpd
          systemctl enable http
          systemctl start httpd
          echo "<h1>Hello there! You are currently using $(hostname -f). I hope this template can help!</h1>" > /var/www/html/index.html
          
          EOF

  tags = {
    Name = "Prod-server_2"
  }
}
