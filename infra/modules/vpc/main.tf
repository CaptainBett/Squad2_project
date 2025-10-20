data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "${var.project_prefix}-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags = { Name = "${var.project_prefix}-igw" }
}

# Public subnets (count)
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  tags = { Name = "${var.project_prefix}-public-${count.index + 1}" }
}

# Private subnets (count)
resource "aws_subnet" "private" {
  count                   = length(var.private_subnet_cidrs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.private_subnet_cidrs[count.index]
  map_public_ip_on_launch = false
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  tags = { Name = "${var.project_prefix}-private-${count.index + 1}" }
}

# Public route table + route to IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "${var.project_prefix}-public-rt" }
}

resource "aws_route_table_association" "public_assocs" {
  count = length(aws_subnet.public)
  subnet_id = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Elastic IP for NAT (single NAT GW)
resource "aws_eip" "nat" {
  domain = "vpc"
  tags = {
    Name = "${var.project_prefix}-nat-eip"
  }
}

# NAT Gateway in the first public subnet
resource "aws_nat_gateway" "natgw" {
  allocation_id = aws_eip.nat.allocation_id
  subnet_id     = aws_subnet.public[0].id
  tags = {
    Name = "${var.project_prefix}-natgw"
  }
}


# Private route table -> NAT Gateway
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.natgw.id
  }
  tags = { Name = "${var.project_prefix}-private-rt" }
}

resource "aws_route_table_association" "private_assocs" {
  count = length(aws_subnet.private)
  subnet_id = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
