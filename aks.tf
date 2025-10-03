resource "azurerm_user_assigned_identity" "aks" {
  name                = "aks"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
}

resource "azurerm_role_assignment" "aks_can_join_aksapiserver_subnet" {
  scope                = azurerm_subnet.aks_api_server.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
}

resource "azurerm_role_assignment" "aks_can_join_akscluster_subnet" {
  scope                = azurerm_subnet.aks_cluster.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
}

resource "azurerm_kubernetes_cluster" "this" {
  name                                = "webgoat"
  location                            = azurerm_resource_group.this.location
  resource_group_name                 = azurerm_resource_group.this.name
  dns_prefix                          = "webgoat-dns"
  role_based_access_control_enabled   = true
  private_cluster_public_fqdn_enabled = false
  private_dns_zone_id                 = "System"

  api_server_access_profile {
    virtual_network_integration_enabled = true
    subnet_id                           = azurerm_subnet.aks_api_server.id
  }

  default_node_pool {
    name           = "nodepool1"
    vm_size        = "Standard_DS2_v2"
    node_count     = 2
    vnet_subnet_id = azurerm_subnet.aks_cluster.id
    upgrade_settings {
      drain_timeout_in_minutes      = 0
      max_surge                     = "10%"
      node_soak_duration_in_minutes = 0
    }
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks.id]
  }

  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
    outbound_type  = "loadBalancer"
  }

  private_cluster_enabled = true

  ingress_application_gateway {
    gateway_id = azurerm_application_gateway.this.id
  }

  #   provisioner "local-exec" {
  #     command     = <<EOT
  # cat <<EOF > /tmp/kubeconfig
  # ${self.kube_config_raw}
  # EOF
  # kubectl apply -f webgoat-app.yaml --kubeconfig /tmp/kubeconfig
  # EOT
  #     interpreter = ["bash", "-c"]
  #   }

  depends_on = [
    azurerm_role_assignment.aks_can_join_aksapiserver_subnet,
    azurerm_role_assignment.aks_can_join_akscluster_subnet
  ]
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
# resource "terraform_data" "restart_agic" {
#   input = {
#     kubeconfig = azurerm_kubernetes_cluster.this.kube_config_raw
#   }

#   provisioner "local-exec" {
#     command     = <<EOT
# cat <<EOF > /tmp/kubeconfig
# ${self.input.kubeconfig}
# EOF
# kubectl delete pod -n kube-system -l app=ingress-appgw --kubeconfig /tmp/kubeconfig
# EOT
#     interpreter = ["bash", "-c"]
#   }
#   depends_on = [
#     azurerm_role_assignment.agicaddon_can_modify_appgw,
#     azurerm_role_assignment.agicaddon_can_read_appgw_rg,
#     azurerm_role_assignment.agicaddon_can_modify_appgw_subnet,
#   ]
# }
