@description('The Azure region into which the resources should be deployed.')
param location string

var onpremVnetName = 'vnet-onpremises'
var onpremVnetAddress = '192.168.0.0/16'
var onpremSubnet1Name = 'GatewaySubnet'
var onpremSubnet1Address = '192.168.1.0/27'
var onpremSubnet2Name = 'snet-onpremises-worker'
var onpremSubnet2Address = '192.168.0.0/24'
var azureHubVnetName = 'vnet-azure-hub'
var azureHubVnetAddress = '10.0.0.0/16'
var azureHubSubnet1Name = 'GatewaySubnet'
var azureHubSubnet1Address = '10.0.1.0/27'
var azureSpokeVnetName = 'vnet-azure-spoke'
var azureSpokeVnetAddress = '10.1.0.0/16'
var azureSpokeSubnet1Name = 'snet-azure-worker'
var azureSpokeSubnet1Address = '10.1.0.0/28'
var onpremVNGName = 'vng-onpremises'
var azureVNGName = 'vng-azure-hub'
var onpremLNGName = 'lng-onpremises'
var azureLNGName = 'lng-azure'
var onpremConnectionName = 'conn-to-azure'
var azureConnectionName = 'conn-to-onpremises'
var onpremVNGPip = 'pip-vng-onpremises'
var azureVNGPip = 'pip-vng-azure-hub'
var routeTableName = 'rt-gateway-routes'
var onpremVMName = 'vm-onpremises'
var azureVMName = 'vm-azure'
var windowsUsername = 'AzureUser'
var windowsPassword = 'SL-cr3_hUgt5iEZ'
var vmSize = 'Standard_D2s_v3'
var vmImage = {
  publisher: 'MicrosoftWindowsServer'
  offer: 'WindowsServer'
  sku: '2019-Datacenter'
  version: 'latest'
}
var vmOsDisk = {
  createOption: 'FromImage'
  managedDisk: {
    storageAccountType: 'StandardSSD_LRS'
  }
}
var onpremVMOsProfile = {
  computerName: onpremVMName
  adminUsername: windowsUsername
  adminPassword: windowsPassword
}

var azureVMOsProfile = {
  computerName: azureVMName
  adminUsername: windowsUsername
  adminPassword: windowsPassword
}

resource onPremVnet 'Microsoft.Network/virtualNetworks@2022-05-01' = {
  name: onpremVnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        onpremVnetAddress
      ]
    }
  }
  resource onPremSubnet1 'subnets' = {
    name: onpremSubnet1Name
    properties: {
      addressPrefix: onpremSubnet1Address
    }
  }
  resource onPremSubnet2 'subnets' = {
    name: onpremSubnet2Name
    properties: {
      addressPrefix: onpremSubnet2Address
    }
    dependsOn: [
      onPremSubnet1
    ]
  }
}

resource azureHubVnet 'Microsoft.Network/virtualNetworks@2022-05-01' = {
  name: azureHubVnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        azureHubVnetAddress
      ]
    }
  }
  resource azureHubSubnet1 'subnets' = {
    name: azureHubSubnet1Name
    properties: {
      addressPrefix: azureHubSubnet1Address
      routeTable: {
        id: routeTable.id
      }
    }
  }
}

resource azureSpokeVnet 'Microsoft.Network/virtualNetworks@2022-05-01' = {
  name: azureSpokeVnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        azureSpokeVnetAddress
      ]
    }
  }
  resource azureSpokeSubnet1 'subnets' = {
    name: azureSpokeSubnet1Name
    properties: {
      addressPrefix: azureSpokeSubnet1Address
    }
  }
}

resource peering1 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2022-07-01' = {
  name: 'hubToSpoke'
  parent: azureHubVnet
  properties: {
    allowForwardedTraffic: true
    allowGatewayTransit: true
    allowVirtualNetworkAccess: true
    remoteVirtualNetwork: {
      id: azureSpokeVnet.id
    }
    remoteVirtualNetworkAddressSpace: {
      addressPrefixes: [
        azureSpokeVnetAddress
      ]
    }
    useRemoteGateways: false
  }
  dependsOn: [
    azureVPN
  ]
}

resource peering2 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2022-07-01' = {
  name: 'spokeToHub'
  parent: azureSpokeVnet
  properties: {
    allowForwardedTraffic: true
    allowGatewayTransit: false
    allowVirtualNetworkAccess: true
    remoteVirtualNetwork: {
      id: azureHubVnet.id
    }
    remoteVirtualNetworkAddressSpace: {
      addressPrefixes: [
        azureHubVnetAddress
      ]
    }
    useRemoteGateways: true
  }
  dependsOn: [
    azureVPN
  ]
}

resource routeTable 'Microsoft.Network/routeTables@2022-07-01' = {
  name: routeTableName
  location: location
  properties: {
    disableBgpRoutePropagation: false
  }
}

resource routeTableRoute1 'Microsoft.Network/routeTables/routes@2022-07-01' = {
  name: 'route1'
  parent: routeTable
  properties: {
    nextHopType: 'VirtualAppliance'
    nextHopIpAddress: '10.0.0.6'
    addressPrefix: '0.0.0.0/1'
  }
  dependsOn: [
    azureConnection
  ]
}

resource routeTableRoute2 'Microsoft.Network/routeTables/routes@2022-07-01' = {
  name: 'route2'
  parent: routeTable
  properties: {
    nextHopType: 'VirtualAppliance'
    nextHopIpAddress: '10.0.0.6'
    addressPrefix: '128.0.0.0/1'
  }
  dependsOn: [
    azureConnection
  ]
}

resource onPremVNGPip 'Microsoft.Network/publicIPAddresses@2022-05-01' = {
  name: onpremVNGPip
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
  }
}

resource azureVNGPIP 'Microsoft.Network/publicIPAddresses@2022-05-01' = {
  name: azureVNGPip
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
  }
}

resource onpremVPN 'Microsoft.Network/virtualNetworkGateways@2022-07-01' = {
  name: onpremVNGName
  location: location
  properties: {
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    vpnGatewayGeneration: 'Generation1'
    sku: {
      name: 'VpnGw1'
      tier: 'VpnGw1'
    }
    ipConfigurations: [
      {
        name: 'gatewayconfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: onPremVnet::onPremSubnet1.id
          }
          publicIPAddress: {
            id: onPremVNGPip.id
          }
        }
      }
    ]
  }
}

resource azureVPN 'Microsoft.Network/virtualNetworkGateways@2022-07-01' = {
  name: azureVNGName
  location: location
  properties: {
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    vpnGatewayGeneration: 'Generation1'
    sku: {
      name: 'VpnGw1'
      tier: 'VpnGw1'
    }
    ipConfigurations: [
      {
        name: 'gatewayconfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: azureHubVnet::azureHubSubnet1.id
          }
          publicIPAddress: {
            id: azureVNGPIP.id
          }
        }
      }
    ]
  }
}

resource onPremLNG 'Microsoft.Network/localNetworkGateways@2022-07-01' = {
  name: onpremLNGName
  location: location
  properties: {
    localNetworkAddressSpace: {
      addressPrefixes: [
        onpremVnetAddress
      ]
    }
    gatewayIpAddress: onPremVNGPip.properties.ipAddress
  }
}

resource azureLNG 'Microsoft.Network/localNetworkGateways@2022-07-01' = {
  name: azureLNGName
  location: location
  properties: {
    localNetworkAddressSpace: {
      addressPrefixes: [
        azureHubVnetAddress
      ]
    }
    gatewayIpAddress: azureVNGPIP.properties.ipAddress
  }
}

resource onPremConnection 'Microsoft.Network/connections@2022-07-01' = {
  name: onpremConnectionName
  location: location
  properties: {
    sharedKey: 'azure123456'
    connectionType: 'IPsec'
    connectionMode: 'ResponderOnly'
    ipsecPolicies: [
      {
        dhGroup: 'DHGroup1'
        ikeEncryption: 'AES128'
        ikeIntegrity: 'SHA1'
        ipsecEncryption: 'AES128'
        ipsecIntegrity: 'SHA1'
        pfsGroup: 'None'
        saDataSizeKilobytes: 102400000
        saLifeTimeSeconds: 27000
      }
    ]
    virtualNetworkGateway1: {
      id: onpremVPN.id
      properties: {
      }
    }
    localNetworkGateway2: {
      id: azureLNG.id
      properties: {
      }
    }
  }
}

resource azureConnection 'Microsoft.Network/connections@2022-07-01' = {
  name: azureConnectionName
  location: location
  properties: {
    sharedKey: '654321eruza'
    connectionType: 'IPsec'
    connectionMode: 'Default'
    ipsecPolicies: [
      {
        dhGroup: 'DHGroup2'
        ikeEncryption: 'GCMAES256'
        ikeIntegrity: 'GCMAES256'
        ipsecEncryption: 'GCMAES256'
        ipsecIntegrity: 'GCMAES256'
        pfsGroup: 'None'
        saDataSizeKilobytes: 102400000
        saLifeTimeSeconds: 27000
      }
    ]
    virtualNetworkGateway1: {
      id: azureVPN.id
      properties: {
      }
    }
    localNetworkGateway2: {
      id: onPremLNG.id
      properties: {
      }
    }
  }
}

resource onpremNic 'Microsoft.Network/networkInterfaces@2022-05-01' = {
  name: '${onpremVMName}-NIC'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: '${onpremVMName}NicConfig1'
        properties: {
          subnet: {
            id: onPremVnet::onPremSubnet2.id
          }
        }
      }
    ]
  }
}

resource onpremVm 'Microsoft.Compute/virtualMachines@2022-08-01' = {
  name: onpremVMName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: onpremVMOsProfile
    storageProfile: {
      imageReference: vmImage
      osDisk: vmOsDisk
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: onpremNic.id
        }
      ]
    }
  }
}

resource azureNic 'Microsoft.Network/networkInterfaces@2022-05-01' = {
  name: '${azureVMName}-NIC'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: '${azureVMName}NicConfig1'
        properties: {
          subnet: {
            id: azureSpokeVnet::azureSpokeSubnet1.id
          }
        }
      }
    ]
  }
}

resource azureVm 'Microsoft.Compute/virtualMachines@2022-08-01' = {
  name: azureVMName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: azureVMOsProfile
    storageProfile: {
      imageReference: vmImage
      osDisk: vmOsDisk
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: azureNic.id
        }
      ]
    }
  }
}
