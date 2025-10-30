provider "aws" {
  region = "ap-northeast-1"
  default_tags {
    tags = {
      Owner       = "mamezou"
      Environment = "mz-dev-site"
      SystemName  = "Mamezou Developer Site Example System"
    }
  }
}
