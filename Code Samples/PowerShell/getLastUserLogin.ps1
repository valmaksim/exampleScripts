<#
    This script reports users who have not logged in within a specified amount of time.
#>

$domain = (Get-WmiObject -Class win32_ComputerSystem).domain
$csvName = $domain + "LastUserLogin.csv"
$users = Get-ADUser -Filter {Enabled -ne $false} -Properties displayName,samAccountName,lastLogonDate

$resultsTable = @() #Creating a table to store our results in.

foreach ($user in $users) {
    if ($user.lastLogonDate -lt (Get-Date).AddDays(-30)) {
        #This will change depending on how alerting needs to be configured.
        $userResult = New-Object -TypeName psobject
        $userResult | Add-Member -MemberType NoteProperty -Name "displayName" -Value $user.DisplayName
        $userResult | Add-Member -MemberType NoteProperty -Name "samAccountName" -Value $user.SamAccountName
        $userResult | Add-Member -MemberType NoteProperty -Name "lastLogonDate" -Value $user.LastLogonDate
        $resultsTable += $userResult #This is adding the next row of information to our next table.
    }
}

try
{
    $originalCSV = Import-Csv -Path "$env:windir\LTSvc\scripts\$csvName"
    $compareResults = Compare-Object -ReferenceObject $originalCSV -DifferenceObject $resultsTable #We are needing to make sure we are not logging previously logged results
}
catch
{
    #This is here because I could not seem to supress errors
}

if ($compareResults -ne $null -or $originalCSV -eq $null)
{
    $resultsTable | Export-Csv -Path "$env:windir\LTSvc\scripts\$csvName" -NoTypeInformation -Force
    Write-Output $resultsTable
}