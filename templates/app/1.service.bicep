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

var backend_service_name = service_params.name

var identity_id = '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${backend_service_name}-identity'

// Pull in existing resources
resource aca_env 'Microsoft.App/managedEnvironments@2024-03-01' existing = {
  name: aca_env_name
}

// Common resources
module service_common './2.service_common.bicep' = {
  name: '${backend_service_name}_commnon'
  params: {
    service_name: backend_service_name
    aca_env_name: aca_env_name
    container_registry_name: container_registry_name
    key_vault_name: key_vault_name
    files_storage_account_name: files_storage_account_name
    service_params: service_params
  }
}

// Service
resource backend_service 'Microsoft.App/containerApps@2024-03-01' = {
  name: backend_service_name
  location: location
  properties: {
    environmentId: aca_env.id
    workloadProfileName: service_params.workload_profile
    configuration: {
      ingress: {
        external: service_params.is_ingress_external
        targetPort: service_params.target_port
      }
      registries: empty(container_registry_name) ? [] : [
        {
          server: '${toLower(container_registry_name)}.azurecr.io'
          identity: service_common.outputs.identity_id
        }
      ]
      secrets: service_common.outputs.aca_secrets
    }
    template: {
      volumes: service_common.outputs.aca_volumes
      containers: [
        {
          name: service_params.container_name
          image: service_params.container_image
          volumeMounts: service_common.outputs.volume_mounts
          env: service_common.outputs.envs
        }
      ]
    }
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      // this is a bit of a hack. This property must be known at compile time, but because the identity is created in the common services module it isn't. 
      // We can generate the id string but we rely on the name of the identity being that same as the name used by the module ("{service_name}-identity")
      '${identity_id}' : {}
    }
  }
}
