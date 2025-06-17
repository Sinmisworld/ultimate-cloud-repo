############################################################
# 1) DB Subnet Group using private subnets
############################################################

resource "aws_db_subnet_group" "ult_rds_subnet_group" {
  name = "ult-rds-subnet-group"
  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id,
  ]

  tags = {
    Name = "ult-rds-subnet-group"
  }
}

############################################################
# 2) Two RDS Instances (one per AZ)
############################################################

#
# RDS-A: in AZ matching private_a (assumes private_a is in us-east-1a)
#
resource "aws_db_instance" "ult_rds_a" {
  identifier             = "ult-rds-a"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_name                = "ultdba" # initial database name
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.ult_rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db.id]
  availability_zone      = var.public_azs[0] # AZ of ult-private-a
  publicly_accessible    = false
  skip_final_snapshot    = true
  multi_az               = false

  tags = {
    Name = "ult-rds-a"
  }
}

#
# RDS-B: in AZ matching private_b (assumes private_b is in us-east-1b)
#
resource "aws_db_instance" "ult_rds_b" {
  identifier             = "ult-rds-b"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_name                = "ultdbb" # initial database name
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.ult_rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db.id]
  availability_zone      = var.public_azs[1] # AZ of ult-private-b
  publicly_accessible    = false
  skip_final_snapshot    = true
  multi_az               = false

  tags = {
    Name = "ult-rds-b"
  }
}

