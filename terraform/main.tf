locals {

  tags = {
    deployment_id = random_string.deployment_id.result
    environment   = "BlakYaks Blog Content"
  }

  chart_settings = {
    installCRDs = true
  }

}

resource "random_string" "deployment_id" {
  length  = 5
  special = false
  lower   = true
  upper   = false
}

resource "azurerm_key_vault" "this" {
  name                      = format("kv-blakyaks-demo-%s", random_string.deployment_id.result)
  resource_group_name       = data.azurerm_resource_group.this.name
  location                  = data.azurerm_resource_group.this.location
  tenant_id                 = data.azurerm_client_config.this.tenant_id
  sku_name                  = "standard"
  enable_rbac_authorization = true
  tags                      = local.tags
}

resource "azurerm_key_vault_secret" "this" {
  name         = "external-keyvault-secret"
  value        = "T0pS3cr3t:)"
  key_vault_id = azurerm_key_vault.this.id
  depends_on   = [azurerm_role_assignment.self_keyvault_admin]
}

resource "helm_release" "external_secrets_operator" {
  name             = "external-secrets"
  namespace        = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = "0.8.1"
  timeout          = 600
  lint             = true
  create_namespace = true
  wait             = true

  dynamic "set" {
    for_each = local.chart_settings
    content {
      name  = set.key
      value = set.value
      type  = "auto"
    }
  }

}

# Service Account to be used with ClusterSecretStore resource
resource "kubernetes_service_account_v1" "workload_identity" {
  metadata {
    name      = "workload-identity-sa"
    namespace = "external-secrets"
    annotations = {
      "azure.workload.identity/client-id" = azurerm_user_assigned_identity.external_secrets.client_id
      "azure.workload.identity/tenant-id" = data.azurerm_client_config.this.tenant_id
    }
  }
  depends_on = [helm_release.external_secrets_operator]
}

resource "kubectl_manifest" "cluster_secret_store" {
  yaml_body = templatefile("./templates/external-secrets.css.yaml.tftpl", {
    keyvault_url = azurerm_key_vault.this.vault_uri
  })
  force_new = true
  depends_on = [
    kubernetes_service_account_v1.workload_identity,
    helm_release.external_secrets_operator,
    azurerm_role_assignment.external_secrets_keyvault_admin
  ]
}

resource "kubectl_manifest" "external_secret" {
  yaml_body = file("./templates/external-secret.yaml.tftpl")
  force_new = true
  depends_on = [
    kubectl_manifest.cluster_secret_store,
    azurerm_key_vault_secret.this
  ]
}