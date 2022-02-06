# tf-onprem-hub-spoke

Based on https://docs.microsoft.com/en-us/azure/developer/terraform/hub-spoke-introduction

The purpose of this environmetn is create learning space to simulate on-prem + hub/spoke environemtns with the simple NVA in hub.

some of the user scenarios

- to learn network conditions in such setup
- to learn and test any new services connected to VNET in Spoke or HUB (e.g. PaaS, private links, private end points)
- others

## Resources intended t obe created by this templates

- VNET - on-prem, hub, 2 x spoke
- VM - vmhub, vbspoke1, vmspoke2, vmonprem
- URD - from spoke to vmhub

_peering_

- spoke to hub
- on-prem to hub - using VPN gateway - ( TBD peering to simulate VNET gateway )

**resource groups**

- onprem    - on-prem resources
- hub       - hub reposurces
- hub-nva   - VNA in hub
- spoke1    - spoke1 resources
- spoke2    - spoke2 resources
- apim      - placefolder for APIM

## quickstart first deployment

```powershell
    # login to azure and set the context to target subscription
    az login  # or: az login --tenant  [tenant id]
    az account set -s [subscription name]
    az account show

    # deploy hub + spoke1 + spoke2 
    .\deploy.ps1 -prefix test01

    # deploy onprem + hub + spoke1 + spoke2 
    .\deploy.ps1 -onprem -prefix test01 

```
