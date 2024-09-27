@description('Name of the container app environment')
param aca_env_name string

@description('Name of the Azure container registry. Only required if container images are in an Azure Container Registry')
param container_registry_name string = ''

@description('Name of a the key vault. Only required if secret environment variables are specificed in service_params')
param key_vault_name string = ''

@description('Name of the storage account that will host Azure Files share. Only required if volume mounts are specified in service_params')
param files_storage_account_name string = ''

param service_params array
// [
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
// ]

module services '1.service.bicep' = [for service in service_params: {
    name: service.name
    params: {
      aca_env_name: aca_env_name
      container_registry_name: container_registry_name
      key_vault_name: key_vault_name
      files_storage_account_name: files_storage_account_name
      service_params: service
    }
  }
]
