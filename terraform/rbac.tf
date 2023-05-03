resource "azurerm_user_assigned_identity" "external_secrets" {
  resource_group_name = data.azurerm_resource_group.this.name
  location            = data.azurerm_resource_group.this.location
  name                = format("umi-external-secrets-%s", random_string.deployment_id.result)
  tags                = local.tags
}

resource "azurerm_federated_identity_credential" "external_secrets" {
  name                = format("fed-external-secrets-%s", random_string.deployment_id.result)
  resource_group_name = data.azurerm_resource_group.this.name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = data.azurerm_kubernetes_cluster.this.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.external_secrets.id
  subject             = "system:serviceaccount:external-secrets:workload-identity-sa"
}

resource "azurerm_role_assignment" "external_secrets_keyvault_admin" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = azurerm_user_assigned_identity.external_secrets.principal_id
}


