
param service_name string
param aca_env_name string
param files_storage_account_name string = ''

resource aca_env 'Microsoft.App/managedEnvironments@2024-03-01' existing = {
  name: aca_env_name
}

resource storage_account 'Microsoft.Storage/storageAccounts@2021-04-01' existing = {
  name: files_storage_account_name
}

resource storage_account_files 'Microsoft.Storage/storageAccounts/fileServices@2021-04-01' existing = {
  parent: storage_account
  name: 'default'
}

// File Share
resource file_share 'Microsoft.Storage/storageAccounts/fileServices/shares@2021-04-01' = {
  parent: storage_account_files
  name: '${service_name}-files-share'
  properties: {
    accessTier: 'Hot'
  }
}

// File Share on Container App Environment
resource file_share_aca 'Microsoft.App/managedEnvironments/storages@2024-03-01' = {
  name: '${service_name}-files-env'
  parent: aca_env
  properties: {
    azureFile: {
      accessMode: 'ReadWrite'
      accountKey: storage_account.listKeys().keys[0].value
      accountName: files_storage_account_name
      shareName: '${service_name}-files-share'
    }
  }
}
