terraform {
  backend "s3" {
    bucket = "123terrabucket123"
    key    = "terraform.tfstate"
    region = "eu-central-1"
  }
}