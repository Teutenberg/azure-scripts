<#
 .SYNOPSIS
    Deploys a template to Azure

 .DESCRIPTION
    Deploys an Azure Resource Manager template

 .PARAMETER subscriptionId
    The subscription id where the template will be deployed.

 .PARAMETER templateFilePath
    Path to the template file. Defaults to template.json.

 .PARAMETER parametersFilePath
    Path to the parameters file. Defaults to parameters.json. If file is not found, will prompt for parameter values based on template.

 .PARAMETER resourceGroupName
    The resource group where the template will be deployed. Can be the name of an existing or a new resource group.

 .PARAMETER resourceGroupLocation
    Optional, a resource group location. If specified, will try to create a new resource group in this location. If not specified, assumes resource group is existing.
#>

 $subscriptionId        = "153e948b-1bb2-4ef9-8d7d-a998ca12e7d7";
 $templateUri           = "https://raw.githubusercontent.com/Teutenberg/azure-scripts/master/template/demo-vm-template.json";
 $parametersUri         = "https://raw.githubusercontent.com/Teutenberg/azure-scripts/master/template/demo-vm-parameters.json";
 $resourceGroupName     = "DevAutomationRG";
 $resourceGroupLocation = "Australia Southeast";
 $keyVaultName          = "DevAutomationKV"
 $virtualMachineName    = "demotest"

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

# Sign-in to Azure if not already
cd $PSScriptRoot;
.\connect.ps1;

# select subscription
Write-Host "Selecting subscription '$subscriptionId'";
Select-AzureRmSubscription -SubscriptionID $subscriptionId;

# Register RPs
$resourceProviders = ((Invoke-WebRequest $templateUri).Content | ConvertFrom-Json).resources.ForEach({$_.type.split('/')[0]}) | select -Unique
if($resourceProviders.length) {
    Write-Host "Registering resource providers"
    foreach($resourceProvider in $resourceProviders) {
        RegisterRP($resourceProvider);
    }
}

#Create or check for existing resource group
$resourceGroup = Get-AzureRmResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
if(!$resourceGroup)
{
    Write-Host "Resource group '$resourceGroupName' does not exist. To create a new resource group, please enter a location.";
    if(!$resourceGroupLocation) {
        $resourceGroupLocation = Read-Host "resourceGroupLocation";
    }
    Write-Host "Creating resource group '$resourceGroupName' in location '$resourceGroupLocation'";
    New-AzureRmResourceGroup -Name $resourceGroupName -Location $resourceGroupLocation
}
else{
    Write-Host "Using existing resource group '$resourceGroupName'";
}

# Generate new secret and add to key vault if not exists already
[Reflection.Assembly]::LoadWithPartialName("System.Web")
$secret  = ConvertTo-SecureString -String ([system.web.security.membership]::GeneratePassword(24,4)) -AsPlainText -Force
$secretKeyName = (Split-Path $templateUri -Leaf).Split('.')[0] + '-admin'
Set-AzureKeyVaultSecret -VaultName $keyVaultName -Name $secretKeyName -SecretValue $secret


# Start the deployment
Write-Host "Starting deployment...";
if(Test-Path $parametersUri) {
    New-AzureRmResourceGroupDeployment `
        -ResourceGroupName $resourceGroupName `
        -TemplateUri $templateUri `
        -TemplateParameterUri $parametersUri `
        -adminPassword $secret `
        -verbose;
} else {
    New-AzureRmResourceGroupDeployment `
        -ResourceGroupName $resourceGroupName `
        -TemplateUri $templateUri `
        -adminPassword $secret `
        -verbose;
}

Write-Host "Secret Value is:" (Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name $secretKeyName).SecretValueText
