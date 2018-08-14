<#  
    [string] $AzureTenantId = 'guid in string form' 
    [string] $AzureSubscriptionId = 'guid in string form'

    To find your TenantId or SubscriptionId, execute:
    { 
        Connect-AzureRmAccount
        Get-AzureRmContext -ListAvailable
    }
#>
$AzureTenantId       = 'b56548cb-6b02-4b58-a2a8-4e01a8d357ef' 
$AzureSubscriptionId = '153e948b-1bb2-4ef9-8d7d-a998ca12e7d7'


# Import AzureRM module into the PowerShell session
Import-Module AzureRM

# Set default proxy credential so we can connect to Azure through the internet proxy
[System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials

# set context if already logged in
$PSAzureContext = Get-AzureRmContext -ListAvailable | Where {$_.Tenant -ilike $AzureTenantId -and $_.Subscription -ilike $AzureSubscriptionId} | Set-AzureRmContext
# connect if not logged in
if (!$PSAzureContext) {
    # Interactive login into Azure if we haven't already
    Write-Host "Connecting...";
    Connect-AzureRmAccount -TenantId $AzureTenantId -SubscriptionId $AzureSubscriptionId
}
else {
    Write-Host "Already connected...";
}
