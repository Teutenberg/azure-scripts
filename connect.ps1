# Import AzureRM module into the PowerShell session
Import-Module AzureRM

# Set default proxy credential so we can connect to Azure through the internet proxy
[System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials

# set context if already logged in
$context = Get-AzureRmContext | Set-AzureRmContext
    
# connect if not logged in
if (!$context) {
    # Interactive login into Azure if we haven't already
    Write-Host "Connecting...";
    Connect-AzureRmAccount
}
else {
    Write-Host "Already connected...";
}
