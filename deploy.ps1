<#
    .SYNOPSIS
        Deploy on-prem-hub-skoke topology with names based on prefix
    .EXAMPLE
        ./deploy.ps1 -prefix vb07
#>
[CmdletBinding()]
param (
    [Parameter()]
    $prefix
)

# $env:ARM_SKIP_PROVIDER_REGISTRATION='true'

$env:TF_VAR_prefix = $prefix

terraform workspace select $prefix
terraform workspace list

terraform init

terraform plan -out main.tfplan

terraform apply main.tfplan