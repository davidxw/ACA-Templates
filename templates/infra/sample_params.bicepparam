using 'main.bicep'

param name = 'aca-1'

param aca_is_internal = false

// Existing network services - if these are not provided, the template will create them in the same resource group
// param vnet_name = 'vnet'
// param vnet_resource_group = 'vnetResourceGroup'
// param core_subnet_name = 'coreSubnet'

// Optional if using a custom domain name
// param custom_domain_name = ''
// param custom_domain_cert_as_base64 = loadFileAsBase64('acatest.internal.com.pfx')
// param custom_domain_cert_as_base64 = ''

