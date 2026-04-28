terraform {
  backend "s3" {
    bucket         = "scalerank-terraform-state-951897726122"
    key            = "scalerank/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "scalerank-terraform-lock"
    encrypt        = true
  }
}
