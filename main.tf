provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

module "non-prod-env" {
  source = "./modules/non-prod-env"
  subscription_id       = var.subscription_id
  environment_prefix    = var.environment_prefix
  rg_location              = var.rg_location
  cosmosdb_account_name = var.cosmosdb_account_name
  mongoDB_name          = var.mongoDB_name
  mongoDB_collection    = var.mongoDB_collection
  app_service_plan_name = var.app_service_plan_name
  app_service_name      = var.app_service_name
}