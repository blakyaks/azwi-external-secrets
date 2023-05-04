output "vault_name" {
  description = "The Key Vault created by the demo code base."
  value       = azurerm_key_vault.this.name
}
