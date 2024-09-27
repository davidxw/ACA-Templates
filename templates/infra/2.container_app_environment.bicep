var location = resourceGroup().location

@description('Name of an existing virtual network')
param vnet_name string

@description('The resource group of the virtual network - optional if the VNet is in the same resource group')
param vnet_resource_group string = ''

@description('Name of the core subnet')
param core_subnet_name string 

@description('Name of the container app environment')
param aca_env_name string

@description('Is the ACA environment internal')
param aca_is_internal bool = false

@description('Name of the log analytics workspace to use for app logs')
param laws_name string

@description('Custom domain name suffix for internal ACA environment - optional. Leave empty if not needed')
param custom_domain_name string = ''
@secure()
param custom_domain_certificate_password string = ''
param custom_domain_cert_as_base64 string = ''

// Virtual network
resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  name: vnet_name
  scope: resourceGroup((empty(vnet_resource_group)) ? resourceGroup().name : vnet_resource_group)
}

// Subnet for external ACA environment
resource core_subnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' existing = {
  name: core_subnet_name
  parent: vnet
}

// Log Analytics workspace
resource laws 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: laws_name
}
// ACA environment
resource aca_env 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: aca_env_name
  location: location
  properties: {
    vnetConfiguration: {
      internal: aca_is_internal
      infrastructureSubnetId: core_subnet.id
    }
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: laws.properties.customerId
        sharedKey: laws.listKeys().primarySharedKey
      }
    }
    //change to key vault configuration
    customDomainConfiguration: (!empty(custom_domain_name)) ? {
      certificatePassword: custom_domain_certificate_password
      certificateValue: custom_domain_cert_as_base64
      dnsSuffix: custom_domain_name
    }:{}
    workloadProfiles: [
      {
        workloadProfileType: 'Consumption'
        name: 'Consumption'
      }
    ]
  }
}

// create dns entry for default domain - only required for internal ACA environment
module private_dns_defult '2b.private_dns.bicep' = if (aca_is_internal) {
  name: 'private_dns_default'
  params: {
    vnet_name: vnet.name
    vnet_resource_group: vnet_resource_group
    domain_name: aca_env.properties.defaultDomain
    static_ip: aca_env.properties.staticIp
  }
}

//create dns entry for custom domain
module private_dns_custom '2b.private_dns.bicep' = if(!empty(custom_domain_name)) {
  name: 'private_dns_custom'
  params: {
    vnet_name: vnet.name
    domain_name: custom_domain_name
    static_ip: aca_env.properties.staticIp
  }
}
