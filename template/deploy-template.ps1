<#
 .SYNOPSIS
    Deploys a template to Azure

 .DESCRIPTION
    Deploys an Azure Resource Manager template

 .PARAMETER subscriptionId
    The subscription id where the template will be deployed.

 .PARAMETER templateUri
    URL to the template file. 

 .PARAMETER parametersUri
    URL to the parameters file.

 .PARAMETER resourceGroupName
    The resource group where the template will be deployed. Can be the name of an existing or a new resource group.

 .PARAMETER resourceGroupLocation
    Optional, a resource group location. If specified, will try to create a new resource group in this location. If not specified, assumes resource group is existing.
#>

 $subscriptionId        = "153e948b-1bb2-4ef9-8d7d-a998ca12e7d7";
 $templateUri           = "https://raw.githubusercontent.com/Teutenberg/azure-scripts/master/template/vm-win2016-template.json";
 $parametersUri         = "https://raw.githubusercontent.com/Teutenberg/azure-scripts/master/template/demo-vm-parameters.json";
 $resourceGroupName     = "DevAutomationRG";
 $resourceGroupLocation = "Australia Southeast";
 
<#
.SYNOPSIS
    Registers RPs
#>
Function RegisterRP {
    Param(
        [string]$ResourceProviderNamespace
    )

    Write-Host "Registering resource provider '$ResourceProviderNamespace'";
    Register-AzureRmResourceProvider -ProviderNamespace $ResourceProviderNamespace;
}

#******************************************************************************
# Script body
# Execution begins here
#******************************************************************************
$ErrorActionPreference = "Stop"

# Sign-in to Azure if not already. Connect script prevents interactive login if already logged in. 
cd $PSScriptRoot;
.\connect.ps1 -subscriptionId $subscriptionId

# select subscription
Write-Host "Selecting subscription '$subscriptionId'";
Select-AzureRmSubscription -SubscriptionID $subscriptionId;

$parameterData = (Invoke-WebRequest $parametersUri -Headers @{"Cache-Control"="no-cache"} -DisableKeepAlive).Content | ConvertFrom-Json;
$templateData = (Invoke-WebRequest $templateUri -Headers @{"Cache-Control"="no-cache"} -DisableKeepAlive).Content | ConvertFrom-Json;

# Register RPs
$resourceProviders = $templateData.resources.ForEach({$_.type.split('/')[0]}) | select -Unique;
if($resourceProviders.length) {
    Write-Host "Registering resource providers";
    foreach($resourceProvider in $resourceProviders) {
        RegisterRP($resourceProvider);
    }
}

#Create or check for existing resource group
$resourceGroup = Get-AzureRmResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue;
if(!$resourceGroup)
{
    Write-Host "Resource group '$resourceGroupName' does not exist. To create a new resource group, please enter a location.";
    if(!$resourceGroupLocation) {
        $resourceGroupLocation = Read-Host "resourceGroupLocation";
    }
    Write-Host "Creating resource group '$resourceGroupName' in location '$resourceGroupLocation'";
    New-AzureRmResourceGroup -Name $resourceGroupName -Location $resourceGroupLocation;
}
else{
    Write-Host "Using existing resource group '$resourceGroupName'";
}

# Generate new secret and add to key vault if not exists already
[Reflection.Assembly]::LoadWithPartialName("System.Web");

$keyVaultName  = Split-Path $parameterData.parameters.adminPassword.reference.KeyVault.id -Leaf;
$secretKeyName = $parameterData.parameters.adminPassword.reference.secretName;

if ($keyVaultName -and $secretKeyName) {
    $secret = (Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name $secretKeyName).SecretValue;

    if (!$secret) {
        Write-Host 'Adding new secret in KeyVault...';
        $secret = ConvertTo-SecureString -String ([system.web.security.membership]::GeneratePassword(24,4)) -AsPlainText -Force;
        Set-AzureKeyVaultSecret -VaultName $keyVaultName -Name $secretKeyName -SecretValue $secret;
    } else {
        Write-Host 'Using existing secret in KeyVault...';
    }
} else {
    Write-Error 'Parameter adminPassword is missing the key vault reference';
}

# Start the deployment
Write-Host "Starting deployment...";
New-AzureRmResourceGroupDeployment `
    -ResourceGroupName $resourceGroupName `
    -TemplateUri $templateUri `
    -TemplateParameterUri $parametersUri `
    -verbose;

Write-Host "Secret Value is:" (Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name $secretKeyName).SecretValueText;
