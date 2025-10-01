output "WebGoat" {
  value = "http://${azurerm_public_ip.appgw.ip_address}/WebGoat"
}

output "WebWolf" {
  value = "http://${azurerm_public_ip.appgw.ip_address}/WebWolf"
}
