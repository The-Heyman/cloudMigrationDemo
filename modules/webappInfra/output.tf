output "resource_group_name" {
    description = "name of the resource group"
    value = azurerm_resource_group.rg.name
  
}

output "random_integer" {
    description = "A random integer"
    value = random_integer.ri.result
  
}

output "app_service_endpoint" {
    description = "App service endpoint"
    value = azurerm_app_service.webapp.default_site_hostname
  
}