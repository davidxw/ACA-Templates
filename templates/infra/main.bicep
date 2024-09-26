// Core networking - if vnet_name is not provided, a vnet and subnet will be created

@description('Name of an existing virtual network')
param vnet_name string = ''

@description('The resource group of the virtual network - optional if the VNet is in the same resource group')
param vnet_resource_group string = ''

@description('Name of the core subnet')
param core_subnet_name string = ''

// End core networking

@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param name string

@description('Container registry SKU')
@allowed([
  'Basic'
  'Classic'
  'Premium'
  'Standard'
])
param container_registry_sku string = 'Basic'

@description('Key vault SKU')
@allowed([
  'standard'
  'premium'
])
param key_vault_sku string = 'standard'

@description('Custom domain name suffix for internal ACA environment - optional. Leave empty if not needed')
param custom_domain_name string = ''

@secure()
param custom_domain_certificate_password string = ''

param custom_domain_cert_as_base64 string = ''

var resourceToken = toLower(uniqueString(subscription().id, name, resourceGroup().location))

var aca_env_name = toLower('${name}-acae-${resourceToken}')
var laws_name = toLower('${name}-laws-${resourceToken}')
var container_registry_name = safe_name('${name}acr${resourceToken}')
var key_vault_name = toLower('${name}-kv-${resourceToken}')
var files_storage_account_name = safe_name('${take(name, 8)}sa${resourceToken}')

var create_network_resources = vnet_name == ''

var vnet_name_resolved = create_network_resources ? toLower('${name}-vnet-${resourceToken}') : vnet_name
var vnet_resource_group_resolved = create_network_resources ? resourceGroup().name : vnet_resource_group
var core_subnet_name_resolved = create_network_resources ? 'aca-infra' : core_subnet_name

func safe_name(name string) string => replace(replace(toLower(name), '_', ''), '-', '')

/// Core networking - only created if no network details were provided
module network '0.network.bicep' = if (create_network_resources) {
  name: 'network'
  params: {
    vnet_name: vnet_name_resolved
    core_subnet_name: core_subnet_name_resolved
  }
}

//// Supporting Services
module supporting_services '1.supporting_services.bicep' = {
  name: 'supporting_services'
  dependsOn: [
    network
  ]
  params: {
    laws_name: laws_name
    key_vault_name: key_vault_name
    key_vault_sku: key_vault_sku
    container_registry_name: container_registry_name
    container_registry_sku: container_registry_sku
    files_storage_account_name: files_storage_account_name
  }
}

//// Container App Environment
module container_app_environment '2.container_app_environment.bicep' = {
  name: 'container_app_environment'
  dependsOn: [
    supporting_services
  ]
  params: {
    vnet_name: vnet_name_resolved
    vnet_resource_group : vnet_resource_group_resolved
    core_subnet_name: core_subnet_name_resolved
    aca_env_name: aca_env_name
    laws_name: laws_name
    custom_domain_name: custom_domain_name
    custom_domain_certificate_password: custom_domain_certificate_password
    custom_domain_cert_as_base64: custom_domain_cert_as_base64
  }
}
