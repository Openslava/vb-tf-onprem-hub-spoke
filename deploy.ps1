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
    [switch]$onprem   # by default do not deploy on prem and gateways
)

# $env:ARM_SKIP_PROVIDER_REGISTRATION='true'

$env:TF_VAR_prefix = $prefix
$env:TF_VAR_onprem = $onprem

try {


    $tfworkspace = " $(terraform workspace list) "
    if (-not $tfworkspace.Contains(" $prefix " )) {
        terraform workspace new "$prefix"
    } 

    terraform workspace select $prefix
    terraform workspace list
    terraform init
    terraform plan -out "$($prefix).tfplan"
    terraform apply "$($prefix).tfplan"
}
finally {
    Write-Output "finish!"
}