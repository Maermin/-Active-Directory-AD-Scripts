# import ad modul
Import-Module ActiveDirectory

# Parameter
$DaysInactive = 30
$RecycleBinOU = "OU=Recycling Bin,DC=example,DC=com"
$DeletionDateAttr = "extensionAttribute1" # ungenutztes Attribut -> Speicherung Löschdatum

# verschieben in Recycling Bin OU
function Move-ToRecycleBin {
    param (
        [string]$UserDN
    )
    
    Move-ADObject -Identity $UserDN -TargetPath $RecycleBinOU
    Write-Host "Benutzer $UserDN wurde in die Recycling Bin OU verschoben."
}

# setzt Löschdatum
function Set-DeletionDate {
    param (
        [string]$UserDN,
        [datetime]$DeletionDate
    )
    
    Set-ADUser -Identity $UserDN -Add @{$DeletionDateAttr = $DeletionDate.ToString("yyyy-MM-dd")}
    Write-Host "Löschdatum für Benutzer $UserDN auf $DeletionDate gesetzt."
}

# löscht Benutzer
function Delete-ExpiredUsers {
    $UsersToDelete = Get-ADUser -Filter * -SearchBase $RecycleBinOU -Properties $DeletionDateAttr |
                     Where-Object { 
                         $_.$DeletionDateAttr -and 
                         [datetime]::ParseExact($_.$DeletionDateAttr, "yyyy-MM-dd", $null) -lt (Get-Date)
                     }

    foreach ($user in $UsersToDelete) {
        Remove-ADUser -Identity $user.DistinguishedName -Confirm:$false
        Write-Host "Benutzer $($user.DistinguishedName) wurde gelöscht."
    }
}

# 1. Verschieben in Recycling Bin OU
$InactiveUsers = Get-ADUser -Filter * -Properties LastLogonDate |
                 Where-Object { $_.LastLogonDate -lt (Get-Date).AddDays(-$DaysInactive) -and $_.Enabled -eq $true }

foreach ($user in $InactiveUsers) {
    Move-ToRecycleBin -UserDN $user.DistinguishedName
    Set-DeletionDate -UserDN $user.DistinguishedName -DeletionDate (Get-Date).AddDays($DaysInactive)
}

# 2. Löscht abgelaufene Benutzer
Delete-ExpiredUsers
