@description('Location for all resources')
param location string = resourceGroup().location

@description('Address prefix for VNet 1')
param vnet1Prefix string = '10.0.0.0/16'
@description('Address prefix for VNet 2')
param vnet2Prefix string = '10.1.0.0/16'

@description('Admin username for the demo VMs')
param adminUsername string = 'azureuser'
@secure()
@description('Admin password for the demo VMs')
param adminPassword string

@description('Size of the demo VMs')
param vmSize string = 'Standard_B1s'

// VNet 1
resource vnet1 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: 'vnet1-demo'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [vnet1Prefix]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: '10.0.0.0/24'
        }
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: '10.0.255.0/27'
        }
      }
    ]
  }
}

// VNet 2
resource vnet2 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: 'vnet2-demo'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [vnet2Prefix]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: '10.1.0.0/24'
        }
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: '10.1.255.0/27'
        }
      }
    ]
  }
}

// Public IPs for Gateways
resource pip1 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: 'vnet1-gw-pip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

resource pip2 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: 'vnet2-gw-pip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

// Virtual Network Gateways
resource vnetGateway1 'Microsoft.Network/virtualNetworkGateways@2021-08-01' = {
  name: 'vnet1-gateway'
  location: location
  sku: {
    name: 'VpnGw1'
    tier: 'VpnGw1'
  }
  properties: {
    ipConfigurations: [
      {
        name: 'vnetGatewayConfig'
        properties: {
          publicIPAddress: {
            id: pip1.id
          }
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnet1.name, 'GatewaySubnet')
          }
        }
      }
    ]
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    enableBgp: false
  }
}

resource vnetGateway2 'Microsoft.Network/virtualNetworkGateways@2021-08-01' = {
  name: 'vnet2-gateway'
  location: location
  sku: {
    name: 'VpnGw1'
    tier: 'VpnGw1'
  }
  properties: {
    ipConfigurations: [
      {
        name: 'vnetGatewayConfig'
        properties: {
          publicIPAddress: {
            id: pip2.id
          }
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnet2.name, 'GatewaySubnet')
          }
        }
      }
    ]
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    enableBgp: false
  }
}

// Intentional "on-prem" local network gateway with WRONG address prefix
// This simulates an incorrect traffic selector / address space mismatch for troubleshooting
resource localOnpremWrong 'Microsoft.Network/localNetworkGateways@2021-05-01' = {
  name: 'onprem-wrong'
  location: location
  properties: {
    // Public IP is a placeholder to represent the remote gateway
    gatewayIpAddress: '203.0.113.10'
    localNetworkAddressSpace: {
      // Intentionally wrong prefix (does NOT match vnet2)
      addressPrefixes: [
        '10.200.0.0/16'
      ]
    }
  }
}

// Connections
// 1) VNet-to-VNet connection (correct)
resource connVnet 'Microsoft.Network/connections@2021-08-01' = {
  name: 'vnet1-to-vnet2-connection'
  location: location
  properties: {
    connectionType: 'Vnet2Vnet'
    virtualNetworkGateway1: {
      id: vnetGateway1.id
    }
    virtualNetworkGateway2: {
      id: vnetGateway2.id
    }
    sharedKey: 'P@ssw0rd12345!'
    ipsecPolicies: [
      {
        saLifeTimeSeconds: 3600
        saDataSizeKilobytes: 102400000
        ipsecEncryption: 'AES256'
        ipsecIntegrity: 'SHA256'
        ikeEncryption: 'AES256'
        ikeIntegrity: 'SHA256'
        dhGroup: 'DHGroup14'
        pfsGroup: 'PFS2'
      }
    ]
  }
  dependsOn: [
    vnetGateway1
    vnetGateway2
  ]
}

// 2) Site-to-Site connection to the intentionally misconfigured local gateway (simulates bad traffic selectors)
resource connSiteWrong 'Microsoft.Network/connections@2021-08-01' = {
  name: 'vnet1-to-onprem-wrong-connection'
  location: location
  properties: {
    connectionType: 'IPsec'
    virtualNetworkGateway1: {
      id: vnetGateway1.id
    }
    localNetworkGateway2: {
      id: localOnpremWrong.id
    }
    sharedKey: 'BadSharedKey!'
    ipsecPolicies: [
      {
        saLifeTimeSeconds: 28800
        saDataSizeKilobytes: 102400000
        ipsecEncryption: 'AES128'
        ipsecIntegrity: 'SHA1'
        ikeEncryption: 'AES128'
        ikeIntegrity: 'SHA1'
        dhGroup: 'DHGroup1'
        pfsGroup: 'PFS1'
      }
    ]
  }
  dependsOn: [
    vnetGateway1
    localOnpremWrong
  ]
}

// Demo VMs (basic) in each VNet default subnet
resource pipVm1 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: 'vm1-pip'
  location: location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

resource nic1 'Microsoft.Network/networkInterfaces@2021-05-01' = {
  name: 'vm1-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnet1.name, 'default')
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: pipVm1.id
          }
        }
      }
    ]
  }
}

resource vm1 'Microsoft.Compute/virtualMachines@2021-07-01' = {
  name: 'vm1-demo'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: 'vm1'
      adminUsername: adminUsername
      adminPassword: adminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'UbuntuServer'
        sku: '18.04-LTS'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic1.id
        }
      ]
    }
  }
  dependsOn: [
    nic1
  ]
}

// VM2
resource pipVm2 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: 'vm2-pip'
  location: location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

resource nic2 'Microsoft.Network/networkInterfaces@2021-05-01' = {
  name: 'vm2-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnet2.name, 'default')
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: pipVm2.id
          }
        }
      }
    ]
  }
}

resource vm2 'Microsoft.Compute/virtualMachines@2021-07-01' = {
  name: 'vm2-demo'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: 'vm2'
      adminUsername: adminUsername
      adminPassword: adminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'UbuntuServer'
        sku: '18.04-LTS'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic2.id
        }
      ]
    }
  }
  dependsOn: [
    nic2
  ]
}

// Outputs
output vnet1Id string = vnet1.id
output vnet2Id string = vnet2.id
output vnetGateway1Id string = vnetGateway1.id
output vnetGateway2Id string = vnetGateway2.id
output connectionVnetId string = connVnet.id
output connectionSiteWrongId string = connSiteWrong.id
