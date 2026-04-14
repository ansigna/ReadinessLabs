@description('Location for all resources')
param location string = resourceGroup().location

@description('Name prefix for all resources')
param namePrefix string = 'vpnlab'

@description('Virtual Network 1 address space (must not overlap with VNet2)')
param vnet1Prefix string = '10.10.0.0/16'
@description('VM subnet prefix for VNet1')
param vnet1VmSubnet string = '10.10.1.0/24'
@description('Gateway subnet prefix for VNet1')
param vnet1GatewaySubnet string = '10.10.255.0/27'

@description('Virtual Network 2 address space (must not overlap with VNet1)')
param vnet2Prefix string = '10.20.0.0/16'
@description('VM subnet prefix for VNet2')
param vnet2VmSubnet string = '10.20.1.0/24'
@description('Gateway subnet prefix for VNet2')
param vnet2GatewaySubnet string = '10.20.255.0/27'

@description('Windows VM size for VM1')
param vm1Size string = 'Standard_DS1_v2'
@description('Windows SKU/Offer for VM1 image (e.g., 2019-Datacenter)')
param vm1Sku string = '2019-Datacenter'

@description('Windows VM size for VM2')
param vm2Size string = 'Standard_DS1_v2'
@description('Windows SKU/Offer for VM2 image (e.g., 2019-Datacenter)')
param vm2Sku string = '2019-Datacenter'

@description('Admin username for VM1')
param vm1AdminUsername string = 'azureadmin'
@description('Admin password for VM1 (secure string)')
param vm1AdminPassword securestring

@description('Admin username for VM2')
param vm2AdminUsername string = 'azureadmin'
@description('Admin password for VM2 (secure string)')
param vm2AdminPassword securestring

@description('Deploy Bastion?')
param deployBastion bool = false

// Shared key for VPN (lab intention: expose for troubleshooting)
@description('VPN shared key for both connections (lab may use mismatched values to cause failures)')
param vpnSharedKey string = 'LabVpnSharedKey!23'

var vnet1Name = '${namePrefix}-vnet1'
var vnet2Name = '${namePrefix}-vnet2'
var gw1Name = '${namePrefix}-gw1'
var gw2Name = '${namePrefix}-gw2'
var pIpGw1 = '${gw1Name}-pip'
var pIpGw2 = '${gw2Name}-pip'

// --- Virtual Networks ---
resource vnet1 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: vnet1Name
  location: location
  properties: {
    addressSpace: { addressPrefixes: [ vnet1Prefix ] }
    subnets: [
      { name: 'GatewaySubnet'; properties: { addressPrefix: vnet1GatewaySubnet } }
      { name: 'vmSubnet'; properties: { addressPrefix: vnet1VmSubnet } }
    ]
  }
}

resource vnet2 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: vnet2Name
  location: location
  properties: {
    addressSpace: { addressPrefixes: [ vnet2Prefix ] }
    subnets: [
      { name: 'GatewaySubnet'; properties: { addressPrefix: vnet2GatewaySubnet } }
      { name: 'vmSubnet'; properties: { addressPrefix: vnet2VmSubnet } }
    ]
  }
}

// --- Public IPs for Gateways ---
resource publicIpGw1 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: pIpGw1
  location: location
  sku: { name: 'Standard' }
  properties: { publicIPAllocationMethod: 'Static' }
}

resource publicIpGw2 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: pIpGw2
  location: location
  sku: { name: 'Standard' }
  properties: { publicIPAllocationMethod: 'Static' }
}

// --- Virtual Network Gateways ---
resource vnetGateway1 'Microsoft.Network/virtualNetworkGateways@2021-05-01' = {
  name: gw1Name
  location: location
  sku: { name: 'VpnGw1'; tier: 'VpnGw1' }
  properties: {
    enableBgp: false
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    ipConfigurations: [
      {
        name: 'gwIpConfig'
        properties: {
          publicIPAddress: { id: publicIpGw1.id }
          subnet: { id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnet1.name, 'GatewaySubnet') }
        }
      }
    ]
  }
}

resource vnetGateway2 'Microsoft.Network/virtualNetworkGateways@2021-05-01' = {
  name: gw2Name
  location: location
  sku: { name: 'VpnGw1'; tier: 'VpnGw1' }
  properties: {
    enableBgp: false
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    ipConfigurations: [
      {
        name: 'gwIpConfig'
        properties: {
          publicIPAddress: { id: publicIpGw2.id }
          subnet: { id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnet2.name, 'GatewaySubnet') }
        }
      }
    ]
  }
}

// --- Local Network Gateways (point to the peer gateway public IP) ---
// Note: These will reference the peer gateway public IP addresses and set
// address prefixes. For labs we intentionally create one with incorrect prefixes
// to create traffic selector problems.
resource localGw1 'Microsoft.Network/localNetworkGateways@2021-05-01' = {
  name: '${namePrefix}-localgw1'
  location: location
  properties: {
    // reference gateway2 public IP address
    gatewayIpAddress: reference(publicIpGw2.id, '2021-05-01').ipAddress
    localNetworkAddressSpace: { addressPrefixes: [ vnet2Prefix ] }
  }
  dependsOn: [ publicIpGw2 ]
}

resource localGw2 'Microsoft.Network/localNetworkGateways@2021-05-01' = {
  name: '${namePrefix}-localgw2'
  location: location
  properties: {
    gatewayIpAddress: reference(publicIpGw1.id, '2021-05-01').ipAddress
    // Intentionally incorrect address prefixes to create a traffic-selector mismatch
    localNetworkAddressSpace: { addressPrefixes: [ '10.99.0.0/16' ] }
  }
  dependsOn: [ publicIpGw1 ]
}

// --- Connections ---
// Connection 1: uses a specific ipsecPolicy (strong) — engineers can mismatch this
resource connection1 'Microsoft.Network/connections@2021-05-01' = {
  name: '${namePrefix}-conn1'
  location: location
  properties: {
    connectionType: 'IPsec'
    virtualNetworkGateway1: { id: vnetGateway1.id }
    localNetworkGateway2: { id: localGw1.id }
    sharedKey: vpnSharedKey
    ipsecPolicies: [
      {
        saLifeTimeSeconds: 3600
        saDataSizeKilobytes: 102400000
        ipsecEncryption: 'AES256'
        ipsecIntegrity: 'SHA256'
        ikeEncryption: 'AES256'
        ikeIntegrity: 'SHA384'
        dhGroup: 'DHGroup14'
      }
    ]
  }
  dependsOn: [ vnetGateway1, localGw1 ]
}

// Connection 2: intentionally uses a different/weak algorithm to exercise negotiation issues
resource connection2 'Microsoft.Network/connections@2021-05-01' = {
  name: '${namePrefix}-conn2'
  location: location
  properties: {
    connectionType: 'IPsec'
    virtualNetworkGateway1: { id: vnetGateway2.id }
    localNetworkGateway2: { id: localGw2.id }
    sharedKey: 'WrongSharedKey!'
    ipsecPolicies: [
      {
        saLifeTimeSeconds: 7200
        saDataSizeKilobytes: 102400000
        ipsecEncryption: 'DES'
        ipsecIntegrity: 'MD5'
        ikeEncryption: 'DES'
        ikeIntegrity: 'MD5'
        dhGroup: 'DHGroup1'
      }
    ]
  }
  dependsOn: [ vnetGateway2, localGw2 ]
}

// --- Sample VMs in each VNet's VM subnet ---
resource nic1 'Microsoft.Network/networkInterfaces@2021-05-01' = {
  name: '${namePrefix}-vm1-nic'
  location: location
  properties: {
    ipConfigurations: [{ name: 'ipconfig'; properties: { subnet: { id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnet1.name, 'vmSubnet') }; privateIPAllocationMethod: 'Dynamic' } }]
  }
  dependsOn: [ vnet1 ]
}

resource vm1 'Microsoft.Compute/virtualMachines@2021-07-01' = {
  name: '${namePrefix}-vm1'
  location: location
  properties: {
    hardwareProfile: { vmSize: vm1Size }
    osProfile: {
      computerName: '${namePrefix}-vm1'
      adminUsername: vm1AdminUsername
      adminPassword: vm1AdminPassword
      windowsConfiguration: { provisionVMAgent: true }
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: vm1Sku
        version: 'latest'
      }
    }
    networkProfile: { networkInterfaces: [{ id: nic1.id }] }
  }
  dependsOn: [ nic1 ]
}

resource nic2 'Microsoft.Network/networkInterfaces@2021-05-01' = {
  name: '${namePrefix}-vm2-nic'
  location: location
  properties: {
    ipConfigurations: [{ name: 'ipconfig'; properties: { subnet: { id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnet2.name, 'vmSubnet') }; privateIPAllocationMethod: 'Dynamic' } }]
  }
  dependsOn: [ vnet2 ]
}

resource vm2 'Microsoft.Compute/virtualMachines@2021-07-01' = {
  name: '${namePrefix}-vm2'
  location: location
  properties: {
    hardwareProfile: { vmSize: vm2Size }
    osProfile: {
      computerName: '${namePrefix}-vm2'
      adminUsername: vm2AdminUsername
      adminPassword: vm2AdminPassword
      windowsConfiguration: { provisionVMAgent: true }
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: vm2Sku
        version: 'latest'
      }
    }
    networkProfile: { networkInterfaces: [{ id: nic2.id }] }
  }
  dependsOn: [ nic2 ]
}

// --- Optional Bastion ---
resource bastion 'Microsoft.Network/bastionHosts@2021-05-01' = if (deployBastion) {
  name: '${namePrefix}-bastion'
  location: location
  properties: {
    ipConfigurations: [ { name: 'bastionIpConfig'; properties: { subnet: { id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnet1.name, 'AzureBastionSubnet') }; publicIPAddress: { id: publicIpGw1.id } } } ]
  }
  dependsOn: [ vnet1, publicIpGw1 ]
}

output vnet1Id string = vnet1.id
output vnet2Id string = vnet2.id
output gateway1PublicIp string = reference(publicIpGw1.id, '2021-05-01').ipAddress
output gateway2PublicIp string = reference(publicIpGw2.id, '2021-05-01').ipAddress
