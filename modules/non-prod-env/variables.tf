
  variable "subscription_id" {
  type        = string
  description = "Azure Subscription ID"
  }

  variable "environment_prefix" {
  type        = string
  description = "Environment short name"
  }

variable "rg_location" {

  type        = string
  description = "Resource Group location in Azure"
}

variable "app_service_plan_name" {
  type        = string
  description = "App Service Plan name in Azure"
}

variable "app_service_name" {
  type        = string
  description = "App Service name in Azure"
}

variable "cosmosdb_account_name" {
  default = "sentia-cosmosdb-account"
  type        = string
  description = "CosmosDB Account name in Azure"
}

variable "mongoDB_name" {
  type        = string
  description = "MongoDB name in Azure"
}

variable "mongoDB_collection" {
  type        = string
  description = "MongoDB Collection name in Azure"
}