<#
    .SYNOPSIS
        Deploy on-prem-hub-skoke topology with names based on prefix
    .EXAMPLE
        ./deploy.ps1 -prefix vb07
#>
[CmdletBinding()]
param (
    [Parameter()]
    $prefix,
    [switch]$onprem,  # by default do not deploy on prem and gateways
    [switch]$destroy, # used to destroy the created resources
    [switch]$apim,    # deploy apim
    [switch]$vms      # deploy VMs  
)

# $env:ARM_SKIP_PROVIDER_REGISTRATION='true'

$env:TF_VAR_prefix = $prefix
$env:TF_VAR_onprem = $onprem
$env:TF_VAR_apim   = $apim
$env:TF_VAR_vms   = $vms

$accountjson = "$(az account show --output json)"
$account = convertfrom-json -inputObject $x
$env:ARM_SUBSCRIPTION_ID = $account.id
Write-output $account
try {


    $tfworkspace = " $(terraform workspace list) "
    if (-not $tfworkspace.Contains(" $prefix " )) {
        terraform workspace new "$prefix"
    } 

    terraform workspace select $prefix
    terraform workspace list
    terraform init
    
    if($destroy) {
        terraform destroy
    } else {
        terraform plan -out "$($prefix).tfplan"
        terraform apply "$($prefix).tfplan"
    }
}
finally {
    Write-Output "finish!"
}