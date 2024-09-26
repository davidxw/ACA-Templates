param domain_name string
param static_ip string
param vnet_name string

@description('The resource group of the virtual network - optional if the VNet is in the same resource group')
param vnet_resource_group string = ''


resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  name: vnet_name
  scope: resourceGroup((empty(vnet_resource_group)) ? resourceGroup().name : vnet_resource_group)
}

/// DNS for default name

resource private_dns_domain 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: domain_name
  location: 'global'
}

// link private dns to vnet
resource private_dns_domain_vnet_link 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: vnet.name
  location: 'global'
  parent: private_dns_domain
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

// A record for internal container app in private DNS zone
resource a_record_domain 'Microsoft.Network/privateDnsZones/A@2020-06-01' = {
  name: '*'
  parent: private_dns_domain
  properties: {
    ttl: 3600
    aRecords: [
      {
        ipv4Address: static_ip
      }
    ]
  }
}

