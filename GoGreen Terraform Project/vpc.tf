resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "${local.name_prefix}-vpc" }
}

resource "aws_internet_gateway" "igw" { vpc_id = aws_vpc.main.id }

resource "aws_subnet" "public" {
  for_each = {
    a = { cidr = "10.0.0.0/24",  az = local.azs[0] }
    b = { cidr = "10.0.1.0/24",  az = local.azs[1] }
  }
  vpc_id = aws_vpc.main.id
  cidr_block = each.value.cidr
  availability_zone = each.value.az
  map_public_ip_on_launch = true
  tags = { Name = "${local.name_prefix}-public-${each.key}" }
}

resource "aws_subnet" "private_app" {
  for_each = {
    a = { cidr = "10.0.10.0/24", az = local.azs[0] }
    b = { cidr = "10.0.11.0/24", az = local.azs[1] }
  }
  vpc_id = aws_vpc.main.id
  cidr_block = each.value.cidr
  availability_zone = each.value.az
  tags = { Name = "${local.name_prefix}-private-app-${each.key}" }
}

resource "aws_subnet" "private_db" {
  for_each = {
    a = { cidr = "10.0.20.0/24", az = local.azs[0] }
    b = { cidr = "10.0.21.0/24", az = local.azs[1] }
  }
  vpc_id = aws_vpc.main.id
  cidr_block = each.value.cidr
  availability_zone = each.value.az
  tags = { Name = "${local.name_prefix}-private-db-${each.key}" }
}

resource "aws_eip" "nat" { domain = "vpc" }
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public["a"].id
  depends_on    = [aws_internet_gateway.igw]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "${local.name_prefix}-rt-public" }
}
resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public
  subnet_id = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private_app" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = { Name = "${local.name_prefix}-rt-private-app" }
}
resource "aws_route_table_association" "private_app" {
  for_each = aws_subnet.private_app
  subnet_id = each.value.id
  route_table_id = aws_route_table.private_app.id
}

resource "aws_route_table" "private_db" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "${local.name_prefix}-rt-private-db" }
}
resource "aws_route_table_association" "private_db" {
  for_each = aws_subnet.private_db
  subnet_id = each.value.id
  route_table_id = aws_route_table.private_db.id
}
