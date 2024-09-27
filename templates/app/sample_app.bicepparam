using 'main.bicep'

param aca_env_name = 'acaEnv'

// required if container images are in an Azure Container Registry
param container_registry_name = 'containerRegistry'

// required if secret environment variables are specificed in service_params
param key_vault_name = 'keyVault'

// required if volume mounts are specified in service_params
param files_storage_account_name = 'filesStorageAccount'

param service_params = [
  {
    // an example of a service with all possible parameters
    name: 'aca-service-1'
    
    is_ingress_external: true // optional - if not specified, defaults to false
   
    target_port: 80  // optional - if not specified, defaults to 80
    workload_profile: 'Consumption' // optional - if not specified, defaults to 'Consumption'
    container_name: 'webtest' // optional - if not specified, defaults to the service name
    
    // these templates support images in an Azure Container Registry, in which case the container_image should be in the format 'containerRegistry.azurecr.io/path/image:tag'
    // for images in a public registry, the format should be 'path/image:tag'
    container_image: 'containerRegistry.azurecr.io/davidxw/webtest:latest'
    envs: {
      SQL_SERVER: 'sql_server'
      SQL_DATABASE: 'sql_database'
      SQL_USER: 'sql_user'
    }
    envs_secret: {
      SQL_PASSWORD: 'secret string'
    }
    volume_mounts: [
    {
       mountPath: '/app/logs'
       subPath: 'logs'
     }
    ]
  },{
    // an exmaple with the minimum required parameters
    // Assumes ingress is enabled on port 80, and workload profile is Consumption. The container name is the same as the service name. No environment variables or volume mounts
    name: 'aca-service-2'
    container_image: 'davidxw/webtest:latest'
  }
]


