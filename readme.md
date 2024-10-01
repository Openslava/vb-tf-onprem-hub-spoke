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

**vnet topology**
- spoke1        - 10.1.0.0/16
    - mgmt(10.1.0.64/27), dmz (10.1.0.32/27), workload (10.1.1.0/24), AzureFirewallSubnet (10.1.2.0/26), apim (10.1.3.0/26)
- spoke2    - 10.2.0.0/16
- hub       - 10.0.0.0/16
    - GatewaySubnet (10.0.255.224/27), mgmt, dmz, AzureFirewallSubnet (10.0.1.0/26), AzureBastionSubnet (10.0.2.0/24), apim
- on-prem   - 192.168.0.0/16 (optional deployment)

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


    # deploy - network and apim only
    ./deploy.ps1 -prefix vb07 -apim

    # get password for VMs
    terraform output password
```

## destroy all created resources 
```powershell
    # delete all resources persisted in state file on local machine
    terraform destroy
```

## run command on VM's

Via azure portal on respective VM run is possible ro run shell command. or via SSH on Jumpbox thta have public IP e.g. in hub.

here is list of some of hte usefull commands 

```bash
    # update ubuntu
    sudo apt-get update

    # upgrade
    sudo apt-get upgrade -y

    # install web server
    sudo apt install apache2 -y
    sudo ufw allow 'Apache Full'

    # install net tools to be able to execute ifconfig
    sudo apt install net-tools

    # nework scan tool
    sudo apt install nmap -y
```







