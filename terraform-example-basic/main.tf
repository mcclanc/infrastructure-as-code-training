# Configure the AWS Provider
provider "aws" {
  region = "us-west-1"
}

# Create an EC2 instance
resource "aws_instance" "example" {
  # AMI ID for Amazon Linux AMI 2018.03.0 (HVM)
  ami           = "ami-03659409b9c7d0c5f"
  instance_type = "t3.micro"

  tags = {
    Name = "example"
  }
}

