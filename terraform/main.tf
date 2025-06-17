terraform {
  backend "s3" {
    bucket = "sinmisworld-ult-cloud-terraform-state"
    key = "state.tfstate"
    region = "us-east-1"
  }
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = var.region
  profile = var.profile
}

resource "aws_vpc" "ult" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "ult-vpc"
  }
}

# Public Subnet A
resource "aws_subnet" "public_a" {
  vpc_id            = aws_vpc.ult.id
  cidr_block        = var.public_cidrs[0] # first public CIDR
  availability_zone = var.public_azs[0]   # first AZ
  tags = {
    Name = "ult-public-a"
  }
}

# Public Subnet B
resource "aws_subnet" "public_b" {
  vpc_id            = aws_vpc.ult.id
  cidr_block        = var.public_cidrs[1] # second public CIDR
  availability_zone = var.public_azs[1]   # second AZ
  tags = {
    Name = "ult-public-b"
  }
}

# Private Subnet A
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.ult.id
  cidr_block        = var.private_cidrs[0] # first private CIDR
  availability_zone = var.public_azs[0]    # reuse AZ list for HA
  tags = {
    Name = "ult-private-a"
  }
}

# Private Subnet B
resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.ult.id
  cidr_block        = var.private_cidrs[1] # second private CIDR
  availability_zone = var.public_azs[1]
  tags = {
    Name = "ult-private-b"
  }
}
