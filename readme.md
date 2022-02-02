# tf-onprem-hub-spoke

Based on https://docs.microsoft.com/en-us/azure/developer/terraform/hub-spoke-introduction

The purpose of this environmetn is create learning space to simulate on-prem + hub/spoke environemtns with the simple NVA in hub.

some os the user scenarios 
- to learn network conditions in such setup
- to learn and test any new services connected to VNET in Spoke or HUB (e.g. PaaS, private links, private end points)
- others 

## Resources intended t obe created by this templates

- VNET  - on-prem, hub, 2 x spoke
- VM    - vmhub, vbspoke1, vmspoke2, vmonprem
- URD   - from spoke to vmhub

*peering*
- on-prem to hub - peering to simulate VNET gateway 
- spoke to hub 

## quickstart 

```powershell
    # login to azure and set the context to target subscription
    az login  # or: az login --tenant  [tenant id]
    az account set -s [subscription name]
    az account show 

    .\deploy.ps1 -prefix test01
```
