var location = resourceGroup().location

@description('Name of the log analytics workspace to use for app logs')
param laws_name string

@description('Name of the container registry')
param container_registry_name string

@description('Container registry SKU')
@allowed([
  'Basic'
  'Classic'
  'Premium'
  'Standard'
])
param container_registry_sku string = 'Basic'

@description('Name of the key vault')
param key_vault_name string

@description('Key vault SKU')
@allowed([
  'standard'
  'premium'
])
param key_vault_sku string = 'standard'

@description('Name of the storage account that will host Azure Files share')
param files_storage_account_name string

// Log Analytics workspace

resource laws 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  location: location
  name: laws_name
}

// Container Registry

resource container_registry 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
  name: container_registry_name
  location: location
  sku: {
    name: container_registry_sku
  }
  properties: {
    adminUserEnabled: false
  }
}

// Key Vault

resource key_vault 'Microsoft.KeyVault/vaults@2021-06-01-preview' = {
  name: key_vault_name
  location: location
  properties: {
    sku: {
      family: 'A'
      name: key_vault_sku
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enabledForDeployment: false
    enabledForDiskEncryption: true
    enabledForTemplateDeployment: false
  }
}

// File shares

resource storage_account 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: files_storage_account_name
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    accessTier: 'Hot'
  }
}

resource storage_account_files 'Microsoft.Storage/storageAccounts/fileServices@2023-05-01' = {
  parent: storage_account
  name: 'default'
  properties: {
    shareDeleteRetentionPolicy: {
      allowPermanentDelete: true
    }
  }
}
