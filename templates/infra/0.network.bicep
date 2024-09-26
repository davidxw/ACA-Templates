var location = resourceGroup().location

param vnet_name string
param core_subnet_name string 

param vnet_cidr string = '10.1.0.0/16'
param core_subnet_cidr string = '10.1.1.0/24'

// Virtual network
resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: vnet_name
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnet_cidr
      ]
    }
  }
}

// Subnet for external ACA environment
resource wxacatestprofilesvnet_subnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' = {
  name: core_subnet_name
  parent: vnet
  properties: {
    addressPrefix: core_subnet_cidr
    delegations: [
      {
        name: '0'
        properties: {
          serviceName: 'Microsoft.App/environments'
        }
      }
    ]
  }
}
