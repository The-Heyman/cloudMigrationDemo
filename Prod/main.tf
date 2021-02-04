provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

module "non-prod-env" {
  source = "../modules/non-prod-env"
  subscription_id       = var.subscription_id
  environment_prefix    = var.environment_prefix
  rg_location              = var.rg_location
  cosmosdb_account_name = var.cosmosdb_account_name
  mongoDB_name          = var.mongoDB_name
  mongoDB_collection    = var.mongoDB_collection
  app_service_plan_name = var.app_service_plan_name
  app_service_name      = var.app_service_name
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