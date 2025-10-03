output "WebGoat" {
  value = "http://${azurerm_public_ip.appgw.ip_address}/WebGoat"
}

output "WebWolf" {
  value = "http://${azurerm_public_ip.appgw.ip_address}/WebWolf"
}

output "jumpbox_ssh_command" {
  value = "ssh azureuser@${azurerm_public_ip.jumpbox.ip_address}"
}
