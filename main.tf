terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.90.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
  backend "azurerm" {
    key = "terraform-payment.tfstate"
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

data "azurerm_resource_group" "main_group" {
  name = "fiap-tech-challenge-main-group"
}

module "azure" {
  source                           = "./azure"
  location                         = var.location
  environment                      = var.environment
  main_resource_group              = data.azurerm_resource_group.main_group.name
  main_resource_group_location     = data.azurerm_resource_group.main_group.location
  mercadopago_authentication_token = var.mercadopago_authentication_token
  mercadopago_user_id              = var.mercadopago_user_id
  mercadopago_cashier_id           = var.mercadopago_cashier_id
}

module "github" {
  source              = "./github"
  depends_on          = [module.azure]
  sanduba_payment_url = module.azure.sanduba_payment_url
  environment         = data.azurerm_resource_group.main_group.tags["environment"]
}