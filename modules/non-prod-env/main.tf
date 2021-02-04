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
  count               = 3
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  app_service_plan_id = azurerm_app_service_plan.app_plan.id

  site_config {
    linux_fx_version = "NODE|14"
    scm_type         = "LocalGit"
  }

  app_settings = {
      "SOME_KEY" = "some-value"
  }

  connection_string {
    name  = "MONGODB_URI"
    type  = "DocDb"
    value = "mongodb://${azurerm_cosmosdb_account.cosmosdb.name}:${azurerm_cosmosdb_account.cosmosdb.primary_key}@${azurerm_cosmosdb_account.cosmosdb.name}.mongo.cosmos.azure.com:10250/${var.mongoDB_name}?ssl=true&sslverifycertificate=false"
  }
}