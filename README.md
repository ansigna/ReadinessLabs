# Azure VPN Troubleshooting Lab (Bicep)

This repository contains a parameterized Bicep template to deploy a two-VNet VPN troubleshooting lab for networking engineers.

**Files**
- `azurevpnlab.bicep` — main deployment template
- `azurevpnlab.parameters.json` — example parameter values

**Parameters**
- `location`: region to deploy (example: `eastus`)
- `namePrefix`: resource name prefix (example: `vpnlab`)
- `vnet1Prefix`, `vnet1VmSubnet`, `vnet1GatewaySubnet`: VNet1 CIDR and subnet prefixes
- `vnet2Prefix`, `vnet2VmSubnet`, `vnet2GatewaySubnet`: VNet2 CIDR and subnet prefixes (must not overlap with VNet1)
- `vm1Size`, `vm2Size`: VM sizes (example: `Standard_DS1_v2`)
- `vm1Sku`, `vm2Sku`: Windows image SKU (example: `2019-Datacenter`)
- `vm1AdminUsername`, `vm1AdminPassword`, `vm2AdminUsername`, `vm2AdminPassword`: per-VM admin credentials (provide secure values)
- `vpnSharedKey`: shared key used by connection 1 (connection 2 intentionally uses a wrong key in the template)
- `deployBastion`: boolean to enable Azure Bastion deployment

See the template files: [azurevpnlab.bicep](azurevpnlab.bicep) and [azurevpnlab.parameters.json](azurevpnlab.parameters.json)

**Quick deploy (CLI)**
1. Clone and push the repo to `https://github.com/ansigna/ReadinessLabs` (or your fork).
2. Run:

```bash
az login
az account set --subscription "<your-subscription-or-id>"
az deployment group create -g <resource-group-name> --template-file azurevpnlab.bicep --parameters @azurevpnlab.parameters.json
```

**Deploy-to-Azure button**
Place this link in the GitHub README (after pushing `azurevpnlab.bicep` to `ansigna/ReadinessLabs`):

https://portal.azure.com/#create/Microsoft.Template/uri/https://raw.githubusercontent.com/ansigna/ReadinessLabs/main/azurevpnlab.bicep

**Instructor notes / lab guidance**
- Ensure VNet CIDRs do not overlap when creating multiple student instances.
- Intentional failures included for troubleshooting exercises:
  - `connection2` uses a wrong `sharedKey` and weak algorithms to trigger IKE/IPsec negotiation failures.
  - `localGw2` is configured with an incorrect address prefix (`10.99.0.0/16`) to create traffic-selector / SA mismatch scenarios.
  - `ipsecPolicies` differ between connections to exercise algorithm negotiation troubleshooting.
- Suggested student checks: connection diagnostics in the Azure portal, `NetworkWatcher` VPN diagnostic logs, IPsec policy comparison, and verifying traffic selectors and shared keys.

If you want, I can also add a GitHub Actions workflow to validate the Bicep template or an ARM wrapper for the Portal button.
