<#
This script writes the AD distinguishedNames to matching username in CAMS database.
This is necessary as this is how CAMS authenticates users using LDAP.
#>

Import-Module -Name "ActiveDirectory" -ErrorAction Stop

$sqlConnection = new-object System.Data.SqlClient.SqlConnection
#I should see if the crentials of the below link can be put into an encrypted JSON file.
$sqlConnection.ConnectionString = "Persist Security Info=False;User ID=;Password=;Initial Catalog=CAMS_Enterprise_Test;Server=SVR-DB01.cleary.edu"
$sqlConnection.Open()
$sqlCommand = New-Object System.Data.SqlClient.SqlCommand
$sqlcommand.Connection = $sqlConnection
$sqlDataAdapter = New-Object System.Data.SqlClient.SqlDataAdapter $sqlCommand

[String[]]$tables='[CAMS_Enterprise_Test].[dbo].[CAMSUser]',
        '[CAMS_Enterprise_Test].[dbo].[FacultyPortal]',
        '[CAMS_Enterprise_Test].[dbo].[StudentPortal_2]' #Marc says this particular table should not be used, what username do students specify?

$data = New-Object System.Data.DataSet
$queryAllUsers = "SELECT * FROM [CAMS_Enterprise_Test].[dbo].[CAMSUser]"
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
        $Error[0] <#Considering that these are inconsistancies between the system, this should be logged and a ticket should be made.#>
        continue
    }
}

$xmlString = [System.IO.StringReader]::new($xmlData.NewDataSet.OuterXml)
$xmlReader = [System.Xml.XmlReader]::Create($xmlString)

$newData = New-Object System.Data.Dataset
$newData.ReadXml($xmlReader)

$sqlCommand = New-Object System.Data.SqlClient.SqlCommand
$insertCommand = "INSERT INTO [CAMS_Enterprise_Test].[dbo].[CAMSUser] (camsuser, ActiveDirectoryIdentifier) "+"VALUES (@camsuser, @ActiveDirectoryIdentifier)" #Ideally, use an UPDATE rather than an INSERT.
$sqlParameter = New-Object System.Data.SqlClient.SqlParameter

$sqlParameter.Value = "zpayne"
$sqlCommand.Parameters.Add("camsuser", $sqlParameter.Value)

$sqlParameter.Value = "testCN"
$sqlCommand.Parameters.Add("ActiveDirectoryIdentifier", $sqlParameter.Value)

$sqlCommand.CommandText = $insertCommand
$sqlDataAdapter.InsertCommand = $sqlCommand
$sqlCommand.Connection = $sqlConnection

$sqlDataAdapter.Update($newData) #Once all updates are made, accept changes.

$sqlConnection.Close() #Outside of nested foreach.

#Close all necessary objects to free memory.