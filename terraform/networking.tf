#
# Internet Gateway
#
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.ult.id

  tags = {
    Name = "ult-igw"
  }
}

#
# Elastic IP for NAT Gateway
#
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "ult-nat-eip"
  }
}

#
# NAT Gateway
#
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id

  tags = {
    Name = "ult-natgw-a"
  }

  depends_on = [aws_internet_gateway.igw]
}

#
# Public Route Table + Route + Associations
#
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.ult.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "ult-public-rt"
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

#
# Private Route Table + Route (to NAT) + Associations
#
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.ult.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "ult-private-rt"
  }

  depends_on = [aws_nat_gateway.nat]
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}
