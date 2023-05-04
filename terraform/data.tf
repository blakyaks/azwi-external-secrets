data "azurerm_resource_group" "this" {
  name = var.aks_resource_group_name
}

data "azurerm_kubernetes_cluster" "this" {
  name                = var.aks_cluster_name
  resource_group_name = data.azurerm_resource_group.this.name
}

data "azurerm_client_config" "this" {}
