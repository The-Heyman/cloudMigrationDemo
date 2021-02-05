provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

module "web_app_infra" {
  source = "../modules/webappInfra"
  subscription_id       = var.subscription_id
  environment_prefix    = var.environment_prefix
  rg_location           = var.rg_location
  cosmosdb_account_name = var.cosmosdb_account_name
  mongoDB_name          = var.mongoDB_name
  mongoDB_collection    = var.mongoDB_collection
  app_service_plan_name = var.app_service_plan_name
  app_service_name      = var.app_service_name
}

# Create Azure front door for load balancing
resource "azurerm_frontdoor" "frontdoor" {
  name                                         = "${var.frontdoor_name}-${module.web_app_infra.random_integer}"
  resource_group_name                          = module.web_app_infra.resource_group_name
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
      host_header = module.web_app_infra.app_service_endpoint
      address     = module.web_app_infra.app_service_endpoint
      http_port   = 80
      https_port  = 443
    }

    load_balancing_name = "loadBalancingSettings1"
    health_probe_name   = "healthProbeSetting1"
  }

  frontend_endpoint {
    name                              = "primaryFrontendEndpoint"
    host_name                         = "${var.frontdoor_name}-${module.web_app_infra.random_integer}.azurefd.net"
  }
}