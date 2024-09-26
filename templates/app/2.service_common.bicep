// Create resources common for every service:
// - User assigned identity
// - Azure Files share and the corresponding ACA volume
// - Key Vault role assignment
// - Azure Container Registry role assignment
// - Key Vault secrets
// - Outputs an array combining clear text environment variables and secret backed environment variables

var location = resourceGroup().location

@description('Name of the service')
param service_name string

@description('Target ACA environment name for all services')
param aca_env_name string

@description('Name of the Azure container registry. Only required if container images are in an Azure Container Registry')
param container_registry_name string = ''

@description('Name of a the key vault. Only required if secret environment variables are specificed in service_params')
param key_vault_name string = ''

@description('Name of the storage account that will host Azure Files share. Only required if volume mounts are specified in service_params')
param files_storage_account_name string = ''

@description('Parameters for the service')
param service_params object
//   {
//     name: 'service-name'
//     container_name: 'container-name'
//     container_image: 'path/image:tag'
//     envs: {
//       SQL_SERVER: 'sql_server'
//       SQL_DATABASE: 'sql_database'
//       SQL_USER: 'sql_user'
//     }
//     envs_secret: {
//       SQL_PASSWORD: 'secret string'
//     }
//     volume_mounts: [
//     {
//        mountPath: '/app/logs'
//        subPath: 'logs'
//      }
//   }

func safe_secret_name(secret_name string) string => replace(toLower(secret_name), '_', '-')

var clear_envs = [
  // if envs is not defined, loop through an empty object
  for env in items(service_params.?envs ?? {}) : {
    name: env.key
    value: env.value
  }
] 

var secret_envs = [
  for secret in items(service_params.?envs_secret ?? {}) : {
    name: secret.key
    secretRef: safe_secret_name(secret.key)
  }
]

var volume_name = '${service_params.name}-files-vol'

var volume_mounts = [
  for volume_mount in service_params.?volume_mounts ?? []: (contains(volume_mount, 'subPath'))
    ? {
        volumeName: volume_name
        mountPath: volume_mount.mountPath
        subPath: volume_mount.subPath
      }
    : {
        volumeName: volume_name
        mountPath: volume_mount.mountPath
      }
]

var volumes = empty(container_registry_name) ? [] : [
  {
    name: volume_name
    storageName: '${service_name}-files-env'
    storageType: 'AzureFile'
  }
]

var all_envs = union(clear_envs, secret_envs)

var aca_secrets = [
  for (secret, i) in items(service_params.?envs_secret ?? {}) : {
    name: safe_secret_name(secret.key)
    keyVaultUrl: 'https://${key_vault_name}.vault.azure.net/secrets/${service_params.name}-${safe_secret_name(secret.key)}' 
    identity: service_identity.id
  }
]

// Identity
resource service_identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${service_name}-identity'
  location: location
}



// Role assignments - only create if required

module service_acr_ra '3a.acr_role_assigment.bicep' = if (!empty(container_registry_name)) {
  name: '${service_name}_acr_role_assignment'
  params: {
    container_registry_name: container_registry_name
    service_name: service_name
    principalId: service_identity.properties.principalId
  }
}

module service_kv_ra '3b.kv_role_assigment_and_secrets.bicep' = if (!empty(key_vault_name)) {
  name: '${service_name}_kv_role_assignment'
  params: {
    key_vault_name: key_vault_name
    service_name: service_name
    principalId: service_identity.properties.principalId
    secrets: service_params.?envs_secret ?? {}
  }
}

module file_share '3c.file_share.bicep' = if (!empty(files_storage_account_name)) {
  name: '${service_name}_file_share'
  params: {
    service_name: service_name
    aca_env_name: aca_env_name
    files_storage_account_name: files_storage_account_name
    
  }
}

output identity_id string = service_identity.id
output envs array = all_envs
output volume_mounts array = volume_mounts
output aca_volumes array = volumes
output aca_secrets array = aca_secrets
