$ConnectionServer = "connectionserver.mydomain.com"
$DesktopPool = "Desktop-Pool"
$vCenter_Url = "vcenter.mydomain.com"

$List = Import-CSV -Path .\VMsToAdd.csv -Delimiter ";"

foreach($Object in $List){

    $VmToAdd = $Object.VM
    $UserToAssaign = $Object.User

    <#
        Get API Token
    #>

    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Content-Type", "application/json")
    $headers.Add("Cookie", "JSESSIONID=9D2D203F27F39BF2BC1F3468693E4F7E")

    $body = "{`n	`"username`": `"USERNAME`",`n    `"password`": `"PASSWORT`",`n    `"domain`": `"DOMAIN`"`n}"

    $token = Invoke-RestMethod "$ConnectionServer/rest/login" -Method 'POST' -Headers $headers -Body $body
    $token | ConvertTo-Json
    $token = $token.access_token

    <#
        Get vCenter ID
    #>

    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", "Bearer $token")
    $headers.Add("Cookie", "JSESSIONID=C59AE49A26C5285968E993182A975FED")

    $vCenter_ID = Invoke-RestMethod "$ConnectionServer/rest/config/v1/virtual-centers" -Method 'GET' -Headers $headers
    $vCenter_ID | ConvertTo-Json
    $vCenter_ID = ($vCenter_ID | Where-Object {$_.server_name -like $vCenter_Url}).id

    <#
        Get vCenter ID for VM
    #>

    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", "Bearer $token")
    $headers.Add("Cookie", "JSESSIONID=8A32C180137C4A9904D6A861B5C140FC")

    $VM_ID = Invoke-RestMethod "$ConnectionServer/rest/external/v1/virtual-machines?vcenter_id=$($vcenter_id)" -Method 'GET' -Headers $headers
    $VM_ID | ConvertTo-Json
    $VM_ID = $VM_ID | where-object {$_.name -eq $VmToAdd}.id

    <#
        Get Pool ID 
    #>

    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", "Bearer $token")
    $headers.Add("Cookie", "JSESSIONID=9D2D203F27F39BF2BC1F3468693E4F7E")

    $Pool_ID = Invoke-RestMethod "$ConnectionServer/rest/inventory/v1/desktop-pools" -Method 'GET' -Headers $headers
    $Pool_ID | ConvertTo-Json
    $Pool_ID = ($Pool_ID | Where-Object {$_.name -like $DesktopPool}).id

    <#
        Register VM on Connection Server by vCenter ID and get unique Horizon ID
    #>

    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Content-Type", "application/json")
    $headers.Add("Authorization", "Bearer $token")
    $headers.Add("Cookie", "JSESSIONID=59FF17A95378EAF53B05761B6D51F803")

    $body = "[`n    `"$VM_ID`"`n]"

    $VM_Horizon_ID = Invoke-RestMethod "$ConnectionServer/rest/inventory/v1/desktop-pools/$Pool_ID/action/add-machines" -Method 'POST' -Headers $headers -Body $body
    $VM_Horizon_ID | ConvertTo-Json  
    $VM_Horizon_ID = $VM_Horizon_ID.id

    <#
        Get User SID from Active Directory
    #>

    $User_ID = (Get-ADUser $UserToAssaign).sid
    $User_ID = $User_ID.Value

    Start-Sleep -Seconds 5 

    <#
        Assaign User to VM
    #>

    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Content-Type", "application/json")
    $headers.Add("Authorization", "Bearer $token")
    $headers.Add("Cookie", "JSESSIONID=9D2D203F27F39BF2BC1F3468693E4F7E")

    $body = "[`n    `"$User_ID`"`n]"

    $response = Invoke-RestMethod "$ConnectionServer/rest/inventory/v1/machines/$VM_Horizon_ID/action/assign-users" -Method 'POST' -Headers $headers -Body $body
    $response | ConvertTo-Json

}




