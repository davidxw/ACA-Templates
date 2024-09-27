param key_vault_name string
param service_name string
param principalId string
@secure()
param secrets object

func safe_secret_name(secret_name string) string => replace(toLower(secret_name), '_', '-')

var role_definition_id_kv_secrets_user = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '4633458b-17de-408a-b874-0445c86b69e6'
)

resource key_vault 'Microsoft.KeyVault/vaults@2021-06-01-preview' existing = {
  name: key_vault_name
}

resource service_kv_ra 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, key_vault_name, 'kv_secret_user_${service_name}')
  scope: key_vault
  properties: {
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: role_definition_id_kv_secrets_user
  }
}

resource service_secrets 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = [
  for secret in items(secrets) : {
    parent: key_vault
    name: '${service_name}-${safe_secret_name(secret.key)}'
    properties: {
      contentType: 'text/plain'
      value: secret.value
    }
  }
]
