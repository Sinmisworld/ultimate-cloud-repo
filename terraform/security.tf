#
# ult-web-sg: allow HTTP/HTTPS from anywhere; SSH from YOUR_IP only.
#
resource "aws_security_group" "web" {
  name        = "ult-web-sg"
  description = "Allow HTTP/HTTPS from 0.0.0.0/0; SSH from my IP"
  vpc_id      = aws_vpc.ult.id

  # Ingress rules
  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # ← replace with your actual IP, e.g. "203.0.113.45/32"
  }

  # Egress: default to all traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ult-web-sg"
  }
}

#
# ult-db-sg: allow MySQL (3306) only from ult-web-sg.
#
resource "aws_security_group" "db" {
  name        = "ult-db-sg"
  description = "Allow MySQL from ult-web-sg only"
  vpc_id      = aws_vpc.ult.id

  # Ingress rule from ult-web-sg
  ingress {
    description     = "MySQL from web servers"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  # Egress: default to all traffic (so DB can reach out if needed)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ult-db-sg"
  }
}

#
# Security Group for the ALB: allow HTTP (80) from anywhere
#
resource "aws_security_group" "alb_sg" {
  name        = "ult-alb-sg"
  description = "Allow HTTP from 0.0.0.0/0"
  vpc_id      = aws_vpc.ult.id

  ingress {
    from_port   = 80
    to_port     = 80
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
    Name = "ult-alb-sg"
  }
}