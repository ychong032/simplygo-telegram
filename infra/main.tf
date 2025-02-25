terraform {
  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "~> 5.87.0"
    }
    archive = {
      source = "hashicorp/archive"
      version = "~> 2.7.0"
    }
  }

  required_version = ">= 1.10"
}

provider "aws" {
  region = "ap-southeast-1"
}