terraform {
  required_providers {
    docker = {
      source                = "kreuzwerker/docker"
      version               = "~> 3.0"
      configuration_aliases = [docker]
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}
