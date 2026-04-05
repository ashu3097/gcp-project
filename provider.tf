terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = "kkgcplabs01-036"
  region  = "us-central1"   # use any region available in the lab
}