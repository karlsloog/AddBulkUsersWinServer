# Change the path below to the location of your CSV file and log file
$csvPath = "C:\Path"
$logPath = "C:\Path"

# Load CSV file
$users = Import-Csv -Path $csvPath

foreach ($user in $users) {
    # Set variables to firstname, lastname, username, group, password, and OU
    $firstName = $user.FirstName
    $lastName = $user.LastName
    $username = $user.Username
    $group = $user.Group
    $passwordPlain = $user.Password

    # The OU path from the CSV is composed of several parts, merge them together
    $ouParts = $user.OU -split ","
    $ou = [string]::Join(",", $ouParts)

    # Check if the user already exists
    $existingUser = Get-ADUser -Filter { SamAccountName -eq $username } -ErrorAction SilentlyContinue

    if ($existingUser) {
        # If the user exists, log this information to a text file
        $logMessage = "$username already exists"
        Add-Content -Path $logPath -Value $logMessage
    } else {
        # Converting a password to a secure string
        $password = ConvertTo-SecureString $passwordPlain -AsPlainText -Force

        # Check if the OU exists
        $ouExists = Get-ADOrganizationalUnit -Filter { DistinguishedName -eq $ou } -ErrorAction SilentlyContinue
        if (-not $ouExists) {
            Write-Host "OU not found: $ou"
            continue
        }

        # Create a user account and set an OU
        New-ADUser -Name "$firstName $lastName" `
                   -GivenName $firstName `
                   -Surname $lastName `
                   -SamAccountName $username `
                   -UserPrincipalName "$username@email.com" `
                   -AccountPassword $password `
                   -Enabled $true `
                   -Path $ou `
                   -displayname "$firstName $lastName" `
                   -ChangePasswordAtLogon $true  # The user must change the password for the first time

        # Check if the group exists
        $groupExists = Get-ADGroup -Filter { Name -eq $group } -ErrorAction SilentlyContinue
        if (-not $groupExists) {
            Write-Host "Group not found: $group"
            continue
        }

        # Add user to group
        Add-ADGroupMember -Identity $group -Members $username
        Add-ADGroupMember -Identity RoamingUsers -Members "$username"
    }
}
