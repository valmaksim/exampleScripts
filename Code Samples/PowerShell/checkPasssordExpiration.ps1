<#
    This script will report which accounts are showing up with a non-expiring password and
    present it in a table. Results will be checked against a CSV on last run. If results
    differ, they will be noted on an update CSV and output will be given for processing by LabTech.
    The checking of previous output is to reduce creation of tickets with idential information.
#>

$ErrorActionPreference = SilentlyContinue

$domain = (Get-WmiObject -Class win32_ComputerSystem).domain
$csvName = $domain + "PasswordExpiryTrue.csv"
$users = Get-ADUser -Filter {Enabled -ne $false} -Properties displayName,samAccountName,passwordNeverExpires
$resultsTable = @() #Creating a table to store our results in.

foreach ($user in $users) 
{
    if ($user.passwordNeverExpires -eq $true) 
    {
        $userResult = New-Object -TypeName psobject
        $userResult | Add-Member -MemberType NoteProperty -Name "displayName" -Value $user.DisplayName
        $userResult | Add-Member -MemberType NoteProperty -Name "samAccountName" -Value $user.SamAccountName
        $userResult | Add-Member -MemberType NoteProperty -Name "passwordNeverExpires" -Value $user.PasswordNeverExpires
        $resultsTable += $userResult #This is adding the next row of information to our table.
    }
}

try
{
    $originalCSV = Import-Csv -Path "$env:windir\LTSvc\scripts\$csvName"
    $compareResults = Compare-Object -ReferenceObject $originalCSV -DifferenceObject $resultsTable #We are needing to make sure we are not logging previously logged results
}

catch
{
    #This is here since it seems I am not able to suppress all errors.
}

if ($compareResults -ne $null -or $originalCSV -eq $null) #If no changes, or if no CSV because on first run, then run below
{
    $resultsTable | Export-Csv -Path "$env:windir\LTSvc\scripts\$csvName" -NoTypeInformation -Force
    Write-Output $resultsTable
}