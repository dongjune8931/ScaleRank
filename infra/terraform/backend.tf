terraform {
  backend "s3" {
    bucket         = "scalerank-terraform-state"
    key            = "terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "scalerank-terraform-lock"
    encrypt        = true
  }
}
