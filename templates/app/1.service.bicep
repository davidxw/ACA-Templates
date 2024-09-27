var location = resourceGroup().location

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
//     is_ingress_external: true
//     target_port: 80
//     workload_profile: 'Consumption
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

var service_name = service_params.name

// Pull in existing resources
resource aca_env 'Microsoft.App/managedEnvironments@2024-03-01' existing = {
  name: aca_env_name
}

////
//// Create envrionment variable array - will be a combination clear variables and secret references
////


// clear envs
var clear_envs = [
  // if envs is not defined, loop through an empty object
  for env in items(service_params.?envs ?? {}) : {
    name: env.key
    value: env.value
  }
] 

// secret envs
var secret_envs = [
  for secret in items(service_params.?envs_secret ?? {}) : {
    name: secret.key
    secretRef: safe_secret_name(secret.key)
  }
]


// ACA secrets - referenced by secret envs
var aca_secrets = [
  for (secret, i) in items(service_params.?envs_secret ?? {}) : {
    name: safe_secret_name(secret.key)
    keyVaultUrl: 'https://${key_vault_name}.vault.azure.net/secrets/${service_name}-${safe_secret_name(secret.key)}' 
    identity: service_identity.id
  }
]

var all_envs = union(clear_envs, secret_envs)

////
//// Create an identity for the container app
////

resource service_identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${service_name}-identity'
  location: location
}


////
//// Volume Mounts - only created if volume mounts are specified
////

var volume_name = '${service_params.name}-files-vol'
//var volume_name = 'filesvol'

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

var volumes = empty(files_storage_account_name) ? [] : [
  {
    name: volume_name
    storageName: '${service_name}-files-env'
    storageType: 'AzureFile'
  }
]

module file_share '2c.file_share.bicep' = if (!empty(files_storage_account_name)) {
  name: '${service_name}_file_share'
  params: {
    service_name: service_name
    aca_env_name: aca_env_name
    files_storage_account_name: files_storage_account_name
  }
}

////
//// ACA Service
////

resource service 'Microsoft.App/containerApps@2024-03-01' = {
  name: service_name
  location: location
  dependsOn: [
    file_share
    service_acr_ra
    service_kv_ra
  ]
  properties: {
    environmentId: aca_env.id
    workloadProfileName: service_params.workload_profile ?? 'Consumption'
    configuration: {
      ingress: {
        external: service_params.is_ingress_external ?? false
        targetPort: service_params.target_port ?? '80'
      }
      registries: empty(container_registry_name) ? [] : [
        {
          server: '${toLower(container_registry_name)}.azurecr.io'
          identity: service_identity.id
        }
      ]
      secrets: aca_secrets
    }
    template: {
      volumes: volumes
      containers: [
        {
          name: service_params.container_name ?? service_name
          image: service_params.container_image
          volumeMounts: volume_mounts
          env: all_envs
        }
      ]
    }
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${service_identity.id}' : {}
    }
  }
}

////
//// Role Assignments for container registry
////

module service_acr_ra '2a.acr_role_assigment.bicep' = if (!empty(container_registry_name)) {
  name: '${service_name}_acr_role_assignment'
  params: {
    container_registry_name: container_registry_name
    service_name: service_name
    principalId: service_identity.properties.principalId
  }
}

////
//// Role Assignments for key vault, and key vauult secrets for secret envs
////

module service_kv_ra '2b.kv_role_assigment_and_secrets.bicep' = if (!empty(key_vault_name)) {
  name: '${service_name}_kv_role_assignment'
  params: {
    key_vault_name: key_vault_name
    service_name: service_name
    principalId: service_identity.properties.principalId
    secrets: service_params.?envs_secret ?? {}
  }
}
