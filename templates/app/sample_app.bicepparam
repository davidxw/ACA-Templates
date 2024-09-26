using 'main.bicep'

param aca_env_name = 'acaEnv'
param container_registry_name = 'containerRegistry'
param key_vault_name = 'keyVault'
param files_storage_account_name = 'filesStorageAccount'

param service_params = [
  {
    name: 'aca-service'
    ingress_external: true
    target_port: 80
    container_name: 'webtest'
    container_image: 'davidxw/webtest:latest'
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
  },  {
    name: 'aca-service-2'
    container_name: 'webtest'
    container_image: 'davidxw/webtest:latest'
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
  }
]


