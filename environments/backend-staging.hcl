bucket         = "your-terraform-state-bucket"
key            = "eks-cluster/staging/terraform.tfstate"
region         = "us-west-2"
dynamodb_table = "terraform-state-locks"
encrypt        = true