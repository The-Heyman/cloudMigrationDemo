provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

# Create Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "${var.environment_prefix}-RG"
  location = var.rg_location

  tags = {
    environment = var.environment_prefix
  }
}

# Generate random number to be appended to the cosmosDB name for uniqueness across azure
resource "random_integer" "ri" {
  min = 10000
  max = 99999
}

# Create cosmosDB with support for MongoDB
resource "azurerm_cosmosdb_account" "cosmosdb" {
  name                = "${var.cosmosdb_account_name}-${random_integer.ri.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  offer_type          = "Standard"
  kind                = "MongoDB"

  enable_free_tier    = true
  consistency_policy {
    consistency_level       = "BoundedStaleness"
    max_interval_in_seconds = 10
    max_staleness_prefix    = 200
  }

  capabilities {
    name = "MongoDBv3.4"
  }

  geo_location {
    location          = azurerm_resource_group.rg.location
    failover_priority = 0
  }
}

# Create MongoDB inside the earlier created CosmosDB
resource "azurerm_cosmosdb_mongo_database" "mongodb" {
  name                = var.mongoDB_name
  resource_group_name = azurerm_resource_group.rg.name
  account_name        = azurerm_cosmosdb_account.cosmosdb.name
  throughput          = 400
}

# Create a MongoDB collection for documents and data storage
resource "azurerm_cosmosdb_mongo_collection" "collection" {
  name                = var.mongoDB_collection
  resource_group_name = azurerm_resource_group.rg.name
  account_name        = azurerm_cosmosdb_account.cosmosdb.name
  database_name       = azurerm_cosmosdb_mongo_database.mongodb.name

  default_ttl_seconds = "777"
  shard_key           = "uniqueKey"
  throughput          = 400
}

# Create Azure app service plan to set up the underlying infrastructure for our web app
resource "azurerm_app_service_plan" "app_plan" {
  name                = var.app_service_plan_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  kind                = "Linux"
  reserved            = true

  sku {
    tier = "Standard"
    size = "S1"
  }
}

# Create Web service to host our app
resource "azurerm_app_service" "webapp" {
  name                = "${var.app_service_name}-${random_integer.ri.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  app_service_plan_id = azurerm_app_service_plan.app_plan.id

  site_config {
    linux_fx_version = "NODE|10.14"
    scm_type         = "LocalGit"
  }

  app_settings = {
      "SOME_KEY" = "some-value"
  }

  connection_string {
    name  = "Database"
    type  = "DocDb"
    value = "Server=tcp:azurerm_cosmosdb_account.cosmosdb.fully_qualified_domain_name Database=azurerm_cosmosdb_mongo_database.mongodb.name;User ID=${var.db_admin_login};Password=${var.db_admin_password};Trusted_Connection=False;Encrypt=True;"
  }
}

# Create Azure front door for load balancing
resource "azurerm_frontdoor" "frontdoor" {
  name                                         = "${var.frontdoor_name}-${random_integer.ri.result}"
  resource_group_name                          = azurerm_resource_group.rg.name
  enforce_backend_pools_certificate_name_check = false

  routing_rule {
    name               = "matchBackendToFrontendRoutingRule"
    accepted_protocols = ["Http", "Https"]
    patterns_to_match  = ["/*"]
    frontend_endpoints = ["primaryFrontendEndpoint"]
    forwarding_configuration {
      forwarding_protocol = "HttpsOnly"
      backend_pool_name   = "sentiaBackend"
    }
  }

  backend_pool_load_balancing {
    name = "loadBalancingSettings1"
  }

  backend_pool_health_probe {
    name = "healthProbeSetting1"
  }

  backend_pool {
    name = "sentiaBackend"
    backend {
      host_header = azurerm_app_service.webapp.default_site_hostname
      address     = azurerm_app_service.webapp.default_site_hostname
      http_port   = 80
      https_port  = 443
    }

    load_balancing_name = "loadBalancingSettings1"
    health_probe_name   = "healthProbeSetting1"
  }

  frontend_endpoint {
    name                              = "primaryFrontendEndpoint"
    host_name                         = "${var.frontdoor_name}-${random_integer.ri.result}.azurefd.net"
  }
}