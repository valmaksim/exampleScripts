<#
This script writes the AD distinguishedNames to matching username in CAMS database.
This is necessary as this is how CAMS authenticates users using LDAP.
#>

Import-Module -Name "ActiveDirectory" -ErrorAction Stop

$sqlConnection = new-object System.Data.SqlClient.SqlConnection
#After this script is finished, this should read in credentials from an encrypted file.
$sqlConnection.ConnectionString = "Persist Security Info=False;User ID=user;Password=password;Initial Catalog=CAMS_Enterprise_Test;dbServer.domain.com"
$sqlConnection.Open()
$sqlCommand = New-Object System.Data.SqlClient.SqlCommand
$sqlcommand.Connection = $sqlConnection
$sqlDataAdapter = New-Object System.Data.SqlClient.SqlDataAdapter $sqlCommand

[String[]]$tables='[CAMS_Enterprise_Test].[dbo].[CAMSUser]',
        '[CAMS_Enterprise_Test].[dbo].[FacultyPortal]',
        '[CAMS_Enterprise_Test].[dbo].[StudentPortal_2]'

foreach ($table in $tables)
{
    $data = New-Object System.Data.DataSet
    $queryAllUsers = "$table"
    $sqlCommand.CommandText = $queryAllUsers

    $sqlDataAdapter = New-Object System.Data.SqlClient.SqlDataAdapter $sqlCommand
    $data = New-Object System.Data.DataSet
    $sqlDataAdapter.Fill($data)

    [XML]$xmlData = $data.GetXml()

    foreach ($camsUser in $xmlData.NewDataSet.Table)
    {
        try
        {
            $adCN = (Get-ADUser $camsUser.camsuser).distinguishedName
            $camsUser.ActiveDirectoryIdentifier = $adCN
        }
        catch
        {
            $Error[0] <#Considering that these are inconsistancies between the system, this should be logged and a ticket should be made, likely hand entered.#>
            continue
        }

        $xmlString = [System.IO.StringReader]::new($xmlData.NewDataSet.OuterXml)
        $xmlReader = [System.Xml.XmlReader]::Create($xmlString)

        $newData = New-Object System.Data.Dataset
        $newData.ReadXml($xmlReader)

        $sqlCommand = New-Object System.Data.SqlClient.SqlCommand
        $insertCommand = "INSERT INTO $table (camsuser, ActiveDirectoryIdentifier) "+"VALUES (@camsuser, @ActiveDirectoryIdentifier)" #Ideally, use an UPDATE rather than an INSERT.
        $sqlParameter = New-Object System.Data.SqlClient.SqlParameter

        $sqlParameter.Value = "$camsUser"
        $sqlCommand.Parameters.Add("camsuser", $sqlParameter.Value)

        $sqlParameter.Value = "$camsUser.ActiveDirectoryIdentifier"
        $sqlCommand.Parameters.Add("ActiveDirectoryIdentifier", $sqlParameter.Value)

        $sqlCommand.CommandText = $insertCommand
        $sqlDataAdapter.InsertCommand = $sqlCommand

        $xmlString.Dispose()
    }

    $sqlDataAdapter.Update($newData) #Once all updates are made, accept changes.
}

$sqlConnection.Close()