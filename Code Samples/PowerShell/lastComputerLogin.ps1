<#
    This script will report which comptuers are possibly inactive and present it in a table.
#>

$domain = (Get-WmiObject -Class win32_ComputerSystem).domain
$csvName = $domain + "LastComputerLogin.csv"
$computers = Get-ADComputer -Filter * -Properties DistinguishedName,LastLogon,OperatingSystem #Grab all AD computers from everywhere.
$resultsTable = @() #Creating a table to store our results in.

foreach ($computer in $computers) 
{
    $lastLoginDate = [Datetime]::FromFileTime($computer.lastLogon)

    if (($lastLoginDate -lt (Get-Date).AddDays(-90)) -and ($computer.OperatingSystem -notmatch "Server")) #Server are excluded because they do not power off and on, causing a login to register
    {
        #This will change depending on how alerting needs to be configured.
        $computerResult = New-Object -TypeName psobject
        $computerResult | Add-Member -MemberType NoteProperty -Name "distinguishedName" -Value $computer.DistinguishedName
        $computerResult | Add-Member -MemberType NoteProperty -Name "lastLoginDate" -Value $lastLoginDate
        $resultsTable += $computerResult #This is adding the next row of information to our next table.
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