# VPN Practice Lab — Deploy Template

This template provisions two VNets, each with a Virtual Network Gateway and a basic VM, plus two VPN connections:

- `vnet1-to-vnet2-connection`: a correct VNet-to-VNet connection using AES256/SHA256.
- `vnet1-to-onprem-wrong-connection`: a Site-to-Site connection to a deliberately misconfigured "on-prem" local network gateway (incorrect address prefixes / traffic selectors) using AES128/SHA1 — intended for troubleshooting practice.

Files:

- `main.bicep` — the Bicep template that creates the lab.

Quick deploy (Azure CLI):

```bash
# Create a resource group first
az group create -n vpn-practice-rg -l eastus

# Deploy the Bicep template (you will be prompted to enter a secure admin password)
az deployment group create -g vpn-practice-rg --template-file AzureTemplates/vpn-practice/main.bicep
```

Deploy-to-Azure (portal) button

> Note: The portal create button needs a publicly accessible raw URL (raw.githubusercontent.com). Replace `YOUR_USER` and `YOUR_REPO` below with the repo owner/name after you push this folder to GitHub.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https://raw.githubusercontent.com/YOUR_USER/YOUR_REPO/main/AzureTemplates/vpn-practice/azuredeploy.json)

Instructor notes

- The second connection intentionally has a mismatched address prefix configured in the `localNetworkGateways` resource (`10.200.0.0/16`) that does not match `vnet2` (`10.1.0.0/16`). This simulates incorrect traffic selectors so engineers can practice diagnosing the failure.
- The two connections use different IPSec/IKE algorithm sets via `ipsecPolicies` to give engineers practice validating SA parameters.

Next steps

- Push this folder to GitHub and update the Deploy-to-Azure button link with the correct `YOUR_USER`/`YOUR_REPO` values.
- Optionally run `bicep build AzureTemplates/vpn-practice/main.bicep` to produce ARM JSON for portal-based deployments.
