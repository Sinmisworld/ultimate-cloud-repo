output "vpc_id" {
  value = aws_vpc.ult.id
}

output "subnet_ids" {
  value = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id,
    aws_subnet.private_a.id,
    aws_subnet.private_b.id,
  ]
}

output "rds_a_endpoint" {
  value = aws_db_instance.ult_rds_a.address
}

output "rds_b_endpoint" {
  value = aws_db_instance.ult_rds_b.address
}