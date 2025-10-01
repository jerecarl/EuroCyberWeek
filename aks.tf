resource "azurerm_kubernetes_cluster" "this" {
  name                              = "webgoat"
  location                          = azurerm_resource_group.this.location
  resource_group_name               = azurerm_resource_group.this.name
  dns_prefix                        = "webgoat-dns"
  role_based_access_control_enabled = true

  default_node_pool {
    name           = "nodepool1"
    vm_size        = "Standard_DS2_v2"
    node_count     = 2
    vnet_subnet_id = azurerm_subnet.aks.id
    upgrade_settings {
      drain_timeout_in_minutes      = 0
      max_surge                     = "10%"
      node_soak_duration_in_minutes = 0
    }
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
    outbound_type  = "loadBalancer"
  }

  ingress_application_gateway {
    gateway_id = azurerm_application_gateway.this.id
  }

  provisioner "local-exec" {
    command     = <<EOT
cat <<EOF > /tmp/kubeconfig
${self.kube_config_raw}
EOF
kubectl apply -f webgoat-app.yaml --kubeconfig /tmp/kubeconfig
EOT
    interpreter = ["bash", "-c"]
  }
}

resource "azurerm_role_assignment" "agicaddon_can_modify_appgw" {
  scope                = azurerm_application_gateway.this.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_kubernetes_cluster.this.ingress_application_gateway[0].ingress_application_gateway_identity[0].object_id
  description          = "Grant AKS AGIC Addon identity permission to modify Application Gateway"
}

resource "azurerm_role_assignment" "agicaddon_can_read_appgw_rg" {
  scope                = azurerm_resource_group.this.id
  role_definition_name = "Reader"
  principal_id         = azurerm_kubernetes_cluster.this.ingress_application_gateway[0].ingress_application_gateway_identity[0].object_id
  description          = "Grant AKS AGIC Addon identity permission to read the Application Gateway's RG"
}

resource "azurerm_role_assignment" "agicaddon_can_modify_appgw_subnet" {
  scope                = azurerm_subnet.appgw.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.this.ingress_application_gateway[0].ingress_application_gateway_identity[0].object_id
  description          = "Grant AKS AGIC Addon identity permission to modify the Application Gateway's subnet"
}

# Restart AGIC pods to pick up the new role assignments
resource "terraform_data" "restart_agic" {
  input = {
    kubeconfig = azurerm_kubernetes_cluster.this.kube_config_raw
  }

  provisioner "local-exec" {
    command     = <<EOT
cat <<EOF > /tmp/kubeconfig
${self.input.kubeconfig}
EOF
kubectl delete pod -n kube-system -l app=ingress-appgw --kubeconfig /tmp/kubeconfig
EOT
    interpreter = ["bash", "-c"]
  }
  depends_on = [
    azurerm_role_assignment.agicaddon_can_modify_appgw,
    azurerm_role_assignment.agicaddon_can_read_appgw_rg,
    azurerm_role_assignment.agicaddon_can_modify_appgw_subnet,
  ]
}
