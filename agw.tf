resource "azurerm_public_ip" "appgw" {
  name                = "webgoat-appgw"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_application_gateway" "this" {
  name                = "webgoat"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  sku {
    name     = var.appgw_sku
    tier     = var.appgw_sku
    capacity = 1
  }

  gateway_ip_configuration {
    name      = "appGatewayIpConfig"
    subnet_id = azurerm_subnet.appgw.id
  }

  frontend_port {
    name = "port80"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "publicFrontend"
    public_ip_address_id = azurerm_public_ip.appgw.id
  }

  # Minimal placeholder objects to satisfy initial creation; AGIC will manage real listeners/rules/pools.
  backend_address_pool {
    name = "placeholder-backend"
  }

  backend_http_settings {
    name                  = "placeholder-settings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 30
  }

  http_listener {
    name                           = "placeholder-listener"
    frontend_ip_configuration_name = "publicFrontend"
    frontend_port_name             = "port80"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "placeholder-rule"
    rule_type                  = "Basic"
    http_listener_name         = "placeholder-listener"
    backend_address_pool_name  = "placeholder-backend"
    backend_http_settings_name = "placeholder-settings"
    priority                   = 100
  }

  waf_configuration {
    enabled          = true
    firewall_mode    = "Prevention"
    rule_set_type    = "OWASP"
    rule_set_version = "3.2"
  }

  lifecycle {
    ignore_changes = [
      backend_address_pool,
      backend_http_settings,
      http_listener,
      request_routing_rule,
      probe,
      ssl_certificate,
      rewrite_rule_set,
      url_path_map,
      tags
    ]
  }

  depends_on = [ azurerm_subnet_network_security_group_association.appgw ]
}
