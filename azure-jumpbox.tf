resource "azurerm_public_ip" "jumpbox" {
  name                = "webgoat-jumpbox"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "jumpbox" {
  name                = "webgoat-jumpbox"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.jumpbox.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.jumpbox.id
  }
}

resource "azurerm_linux_virtual_machine" "jumpbox" {
  name                            = "webgoat-jump"
  resource_group_name             = azurerm_resource_group.this.name
  location                        = azurerm_resource_group.this.location
  size                            = "Standard_B2s"
  admin_username                  = "azureuser"
  admin_password                  = "LeP@ssw0rd123!" # TODO: Replace password auth with SSH key
  network_interface_ids           = [azurerm_network_interface.jumpbox.id]
  disable_password_authentication = false

  os_disk {
    name                 = "webgoat-jumpbox-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  # Render cloud-init template with ACR credentials so the VM can build, tag, push and deploy
  custom_data = base64encode(
    templatefile(
      "${path.module}/cloud-init-jumpbox.yaml.tmpl",
      {
        ACR_LOGIN_SERVER = azurerm_container_registry.this.login_server
        ACR_USERNAME     = azurerm_container_registry.this.admin_username
        ACR_PASSWORD     = azurerm_container_registry.this.admin_password
        KUBECONFIG_RAW   = base64encode(azurerm_kubernetes_cluster.this.kube_config_raw)
      }
    )
  )
}
