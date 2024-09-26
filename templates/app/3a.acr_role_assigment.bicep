param container_registry_name string
param service_name string
param principalId string

var role_definition_id_acr_pull = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '7f951dda-4ed3-4680-a7ca-43fe172d538d'
)

resource container_registry 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' existing = {
  name: container_registry_name
}

resource service_acr_ra 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, container_registry_name, 'acr_pull_${service_name}')
  scope: container_registry
  properties: {
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: role_definition_id_acr_pull
  }
}
