
terraform {
  required_providers {
    digitalocean = {
      source = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "2.22.0"
    }
    acme = {
      source  = "vancluever/acme"
      version = "~> 2.0"
    }
  }
}
