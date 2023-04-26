# Path

$path =  $PSScriptRoot
$products = Import-Csv -Path "$path\Subscriptions.csv"


function get_token()
{    
    # Application (client) ID, tenant ID and secret
    $clientId = "<YOUR CLIENT ID>"
    $tenantId = "<YOUR TENANT ID>"
    $clientSecret = '<YOUR CLIENT SECRET>'

    
    # Construct URI
    $uri = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
 
    # Construct Body
    $body = @{
        client_id     = $clientId
        scope         = "https://graph.microsoft.com/.default"
        client_secret = $clientSecret
        grant_type    = "client_credentials"
    }
 
    # Get OAuth 2.0 Token
    $tokenRequest = Invoke-WebRequest -Method Post -Uri $uri -ContentType "application/x-www-form-urlencoded" -Body $body -UseBasicParsing
 
    # Access Token
    return ($tokenRequest.Content | ConvertFrom-Json).access_token
}






$tokentime = [system.diagnostics.stopwatch]::StartNew()
$token = get_token
$i = 0
$url = "https://graph.microsoft.com/beta/users?`$select=userPrincipalName,assignedLicenses"
do
{
    if($tokentime.Elapsed.Minutes -gt 40)
    {
        $token = get_token
        $tokentime.Restart()
         
    }
    $users = Invoke-RestMethod -Method GET -Uri $url -Headers @{Authorization = "Bearer $token"}
    $url = $users.'@odata.nextLink'
    #$users.'@odata.deltaLink'
    foreach($user in $users.value)
    {
        if($($user.assignedLicenses))
        {
            $licenses = @()
            foreach($license in $user.assignedLicenses.skuid)
            {
                foreach($product in $products)
                {
                    if($product.LicenseSKUID -eq $license)
                    {
                        $licenses += $product.LicensePartNumber
                    }
                }
            }
            $userobj = New-Object psobject
            $userobj | Add-Member -MemberType NoteProperty UserPrincipalName $user.userPrincipalName
            $userobj | Add-Member -MemberType NoteProperty Licenses $(($licenses|Sort-Object) -join("+"))
            #$userobj| fl
            $userobj | Export-Csv -Path $path\$directory\LicenseDetails.csv -NoTypeInformation -Append
        }
    }

}
until(!$url)

