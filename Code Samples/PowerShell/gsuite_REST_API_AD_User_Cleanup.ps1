Param
(
  [Parameter(Mandatory=$True,Position=0)] [string]$domain,
  [Parameter(Mandatory=$false,Position=1)] [Switch]$exportCSV, #This will throw all accounted acted upon into a CSV in the present working dir.
  [string]$authCode
)

<#
    Notice: This script assumes that you are using GADS (Google Active Directory Sync) to sync changes in your directory and for account provisioning. When GADS runs, and as long as you keep the default suspension policy of
    if account is not found in OUs you've chosen to sync, then it will suspend them. You don't have to have GADS to accomplish this, but if you choose not to you will have to authorize write scopes for direvtoryv1 API.
    This requires you to construct additional API calls. I recommend GADS as it is free and secure (also encrypts its tokens).
#>

Import-Module ActiveDirectory -ErrorAction Stop

$content = Get-Date
$content > .\date.txt
<#
    This hash table is constructed from an encryped and permissions protected file from PWD which contains our information.
    This is what we are going to use our one-time use auth code we have retrieved from the web browser.
    The Refresh token this returns is valid for the duration of the project unless permission is explicitly revoked by the admin.
    
    *Also need to be able to send mail in the event access token ever equal $null after a refresh attempt
    I am not sure whether send this mail through gmail or if I should just do it from the server and install smtp?*
#>
$clientInfo = Get-Content .\client_secret_396656978203-ot3r97cpaf7ealk8ptikra8e0p1paj6c.apps.googleusercontent.com.json | 
    ConvertFrom-Json | select -ExpandProperty installed

$tokenParams = @{
	client_id=$clientInfo.client_id;
  	client_secret=$clientInfo.client_secret;
    code=$authCode;
	grant_type='authorization_code';
	redirect_uri=$clientInfo.redirect_uris;
	}

#saves the access token, expiration of the token, and our permenant refresh token to an encrypted and permissions protected JSON file in PWD.
if (($tokenParams.code).length -gt 30) #if parameter "authCode" is not supplied, fails to meet conditional. This is only used for initial auth ONCE only
{
    $authResponse = Invoke-WebRequest -Uri "https://accounts.google.com/o/oauth2/token" -Method POST -Body $tokenParams | ConvertFrom-Json
    [int]$currentTime = (Get-Date -u %s) #I have to cast to INT because the convertto-JSON cmdlet does not support character included in date-time cmdlet output and will break things.
    [int]$tokenExpireTime = ($currentTime + $authResponse.expires_in) #I add the token expiration time plus the current time so we can request a new access token in-timie to make the next call

    $tokenResponse = @{
        access_token=$authResponse.access_token
        expires_in=$tokenExpireTime
        refresh_token=$authResponse.refresh_token
        }

    $tokenResponse | ConvertTo-Json > tokenResponse.json
    #Write-Host "We have grabbed access and refresh tokens with the authCode"
}

#Contructs a hash table from the previously mentioned JSON file
$tokenResponse = @{
    access_token=(get-content .\tokenResponse.json | ConvertFrom-Json).access_token;
    expires_in=(get-content .\tokenResponse.json | ConvertFrom-Json).expires_in;
    refresh_token=(get-content .\tokenResponse.json | ConvertFrom-Json).refresh_token
    }

<#
    Using refresh token to get new access token
    The access token is used to access an api by sending the access_token parm with any request. 
    Access tokens are only valid for about an hour after that you will need to request a new one using your refresh_token
#>

[Int]$currentTime = (Get-Date -u %s)
[Int]$tokenExpireTime = $tokenResponse.expires_in

if (($tokenExpireTime - 600) -lt $currentTime) #Renew tokens 10 minutes prior to expiration.
{
    $refreshTokenParams = @{
	      client_id=$tokenParams.client_id;
  	      client_secret=$tokenParams.client_secret;
          refresh_token=$tokenResponse.refresh_token;
	      grant_type='refresh_token';
	    }

    $refreshedToken = Invoke-WebRequest -Uri "https://accounts.google.com/o/oauth2/token" -Method POST -Body $refreshTokenParams | ConvertFrom-Json
    [int]$currentTime = (Get-Date -u %s)
    [int]$tokenExpireTime = ($currentTime + $refreshedToken.expires_in)

    $tokenResponse = @{
        access_token=$refreshedToken.access_token
        expires_in=$tokenExpireTime
        refresh_token=$refreshTokenParams.refresh_token
        }

    $tokenResponse | ConvertTo-Json > tokenResponse.json
    #Write-Host "We have grabbed a new access token with our existing refresh token"
}

if ($tokenResponse.access_token -eq $null) #If the access token returns as null, this means that the refresh token is invalid. This means the application may have been deleted or unauthorized.
{
    Send-Mailmessage -smtpServer "aspmx.l.google.com" `
    -from "fromEmailAddress" ` #email removed for confidentiality
    -to "toEmailAddress" ` #email removed for confidentiality
    -subject "Access Token for PowerShell Script: restAdminCalls Returned Null" `
    -body "The access token returned as null, this means that the refresh token is invalid. This means the application may have been deleted or unauthorized. Recommend to follow documentation on the LTI Wiki or within the script comments." `
    -bodyasHTML `
    -priority High
}

$staffCount = 0
$studentCount = 0
$facultyCount = 0
$date = Get-Date
$facultyOrgUnit = "orgUnit" #Org unit removed for confidentiality
$studentOrgUnit = "orgUnit" #Org unit removed for confidentiality
$staffOrgUnit = "orgUnit" #Org unit removed for confidentiality
$allAD_Users = Get-ADUser -Filter * -Properties distinguishedName,emailAddress,CN | Select-Object -Property distinguishedName,emailAddress,CN

do
{  
    $oldPage = $nextPage
    $requestParams = @{
        client_id=$tokenParams.client_id;
        client_secret=$tokenParams.client_secret;
        domain=$domain;
        access_token=$tokenResponse.access_token;
        maxResults="100";
        pageToken="$nextPage";
        }

    $callResponse = Invoke-RestMethod -Method Get -Uri "https://www.googleapis.com/admin/directory/v1/users" -Body $requestParams -ErrorAction Stop
    $nextPage = $callResponse.nextPageToken
    $callOutput = ($callResponse).users | Select-Object -Property primaryEmail,lastLoginTime,creationTime,suspended
    sleep 1

    foreach ($account in $callOutput)
    {
        $adUser = $allAD_Users | where -Property emailaddress -Match $account.primaryEmail
        [Datetime]$lastLogin = ($account.lastLoginTime).Substring(0,10) #casting to datetime to have access to datetime methods.
        $username = $account.primaryEmail
        [Datetime]$creationTime = ($account.creationTime).Substring(0,10) #casting to datetime to have access to datetime methods.
        $isSuspended = $account.suspended
        $userOrgUnit = $adUser.distinguishedName -replace "(^CN=[A-z0-9 ]+,)(.*$)",'$2' #Exludes CN= so we can validate OU location
        [Datetime]$computerLastLogin = [DateTime]::FromFileTime((Get-ADObject -Identity $adUser.distinguishedName -Properties * -ErrorAction SilentlyContinue).lastlogon)
        $userOriginalDescription = (Get-ADUser -Identity $adUser.distinguishedName -Properties description -ErrorAction SilentlyContinue).description

        #This is excluding utility accounts which never login anyways. This is only applicable on the domain.com domain as this is the only place service accounts are made.
        if ($lastLogin -match "1970" -and $domain -eq "domain") {continue} #domain removed for confidentiality
        
        #Setting conditionals for Staff, then Students and Faculty to be handled in one if statement
        $isStudentOrFacultyExpired = ($lastLogin -lt (Get-Date).AddDays(-1095) -and $creationTime -lt (Get-Date).AddDays(-1095) -and $domain -eq "my.domain.com") #put 1095 because this is 3 years in days # -and $isSuspended -ne $true
        $isStaffExpired = ((($lastLogin -lt (Get-Date).AddDays(-30) -or ($computerLastLogin -lt (Get-Date).AddDays(-30) -and
            $computerLastLogin -ne "Sunday, December 31, 1600 7:00:00 PM")) -and 
            $creationTime -lt (Get-Date).AddDays(-30) -and $domain -eq "domain.com"))
        #Staff must use an -or statement for checking whether they have logged into their machines.

        #Setting conditionals to return true if cetains names are passed in for cleanly reusing in other area of this script.
        $isStudentUsername = ($username -match "[0-9]+") #This will be grabbing student by the number in their name. Only students have numbers in their name.
        $isFacultyUsername = ($username -match "[a-z]+@domain.com") #This will grab faculty only if the email is alphabetical with NO numbers AND contains my.domain.com
        $isStaffUserName = ($username -match "[a-z]+@domain.com") #Checking to see if this is a staff account
        $isFacultyOrStudentOU = ($userOrgUnit -match $studentOrgUnit -or $userOrgUnit -match $facultyOrgUnit)
        $isStaffOU = ($userOrgUnit -match $staffOrgUnit)

        if (($isStudentOrFacultyExpired -or $isStaffExpired) -and ($isFacultyOrStudentOU -or $isStaffOU))
        {
            if ($isStudentUsername)
            {
                #Expired Faculty are sent to (orgUnit)
                $username = $username -replace "([a-z+])(\d+)(.*)",'$1$2' #strips away the @my.domain.com
                $adUsername = Get-ADUser $username
                Set-ADUser -Identity $adUsername.ObjectGUID -Description "$userOriginalDescription + lastLogin:$lastLogin movedOn:$date"
                Move-ADObject -Identity $adUsername.ObjectGUID -TargetPath "02ac9fd2-2e0e-4524-adeb-7679b7d59345"
                Disable-ADAccount -Identity $adUsername.ObjectGUID
            }
            elseif ($isFacultyUsername)
            {
                #Expired Faculty are sent to (orgUnit)
                $username = $username -replace "([a-z]+)(.*)",'$1' #strips away the @my.domain.com
                $adUsername = Get-ADUser $username
                Set-ADUser -Identity $adUsername.ObjectGUID -Description "$userOriginalDescription + lastLogin:$lastLogin movedOn:$date"
                Move-ADObject -Identity $adUsername.ObjectGUID -TargetPath "1f84ecbc-a33e-4434-9b13-243cfbabf794"
                Disable-ADAccount -Identity $adUsername.ObjectGUID
                #$facultyCount++
                #Write-Host "Faculty expired: $username $lastLogin $creationTime"
            }
            elseif ($isStudentUsername)
            {
                #Expired Staff are sent to (orgUnit)
                $username = $username -replace "([a-z]+)(.*)",'$1' #strips away the @domain.com
                $adUsername = Get-ADUser $username
                Set-ADUser -Identity $adUsername.ObjectGUID -Description "$userOriginalDescription" + "lastLogin:$lastLogin movedOn:$date"
                Move-ADObject -Identity $adUsername.ObjectGUID -TargetPath "1f84ecbc-a33e-4434-9b13-243cfbabf794"
                Disable-ADAccount -Identity $adUsername.ObjectGUID
                #$facultyCount++
                #Write-Host "Staff expired: $username $lastLogin $creationTime"
            }
            else {continue} #Since if none of the conditions

            if ($exportCSV.IsPresent -eq $true) #this will export CSVs to todays date with faculty or staff pre-pended to the name.
            {
                $reportOutput = @{
                    username=$username;
                    lastLogin=$lastLogin;
                    creationDate=$creationTime
                    disabledDate=$date
                    }
                $userInfo = $reportOutput | ConvertTo-Json | ConvertFrom-Json #I convert to and from JSON just to quickly put it in a format a CSV is compatible with.

                if ($isStudentUsername) {$userInfo | Export-Csv -Path .\logs\((get-date -u %m%d%y) + "studentExpiration.csv") -Append}
                if ($isFacultyUsername) {$userInfo | Export-Csv -Path .\logs\((get-date -u %m%d%y) + "facultyExpiration.csv") -Append}
                if ($isStaffUserName) {$userInfo | Export-Csv -Path .\logs\((get-date -u %m%d%y) + "staffExpiration.csv") -Append}
            }
        }
        else{continue}
    }
} while ($nextPage -ne $null) #if there are no more pages, the nextPageToken will be null.
