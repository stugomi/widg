<#
.SYNOPSIS
    Generate-TestMsi creates Windows Installer MSI databases for testing purposes.

.DESCRIPTION
    Use this script to generate test Windows Installer MSI databases. This allows test environments to be staged with real working MSI's
    without the pain of having to hunt for N vesions of the same software.
    These can be used to test evaluation and applicability pre/post installation.

.PARAMETER Manufacturers
    The number of fictional company names to generate MSI's for.

.PARAMETER Packages
    The number of packages/applications to create per Manufacturer.

.PARAMETER Versions
    The number of versions of each package to create.

.PARAMETER Architecture
    The target system architecture. Possible values; all, x86, x64. Selecting all will produce an x86 and x64 package.

.PARAMETER StagingRoot
    Optional. Default: c:\widgstaging.

    The root folder for output files. Should be a local path.

.EXAMPLE
    Generate-TestMsi -Manufactuer 3 -Packages 2 -Versions 2

    This will create a total of 12 MSIs; 2 versions of each package, 2 packages per Manufacturer, 3 Manufacturers

.EXAMPLE
    Generate-TestMsi -Manufactuer 3 -Packages 2 -Versions 2 -Architecture all

    This will create a total of 24 MISs; 2 MSIs (x86 & x64) per version, 2 versions of each package , 2 packages per Manufacturer, 3 Manufacturers

.NOTES
    Initial scirpt version
    Requires PowerShell v5 due to using a Class
    Requires the WIX Toolset installed with its ".\bin\" directory available in the PATH environment variable
    ToDo:
        option to wipe source dirs post msi creation (or default) as we probably don't care about keeping them
        number of manufacturers and perhaps application names could better as external files to script
        Do we really need an architecture switch? Lets just make x86 & x64 packages everytime.
        Add pre-req checks for WIX exe's available from PATH
#>

#Requires -Version 5

Param
(
    # Number of Manufacturers
    [Parameter(Mandatory=$true,
                ValueFromPipelineByPropertyName=$true,
                Position=0)]
    [int]$Manufacturers,

    # Number of packages versions to create per manufacturer
    [Parameter(Mandatory=$true,
                ValueFromPipelineByPropertyName=$true,
                Position=1)]
    [int]$Packages,

    # Number of packages versions to create per manufacturer
    [Parameter(Mandatory=$true,
                ValueFromPipelineByPropertyName=$true,
                Position=2)]
    [int]$Versions,

    # Package architecture, default all
    [Parameter(Mandatory=$false,
                ValueFromPipelineByPropertyName=$true,
                Position=3)]
    [ValidateSet("all","x86","x64")]
    [string]$Architecture="all",

    # Staging directory root folder, default c:\staging
    [Parameter(Mandatory=$false,
                ValueFromPipelineByPropertyName=$true,
                Position=4)]
    [string]$StagingRoot="c:\widgstaging"
)

function GenerateGuid()
{
    $guid = [System.Guid]::NewGuid().ToString().ToUpper()
    return $guid
}

# Get a random manufacturer from a list
function GetRandomManufacturer([int]$randomCount)
{
    $manufacturerList = 'Jupiter Mining Corporation,MomCorp,Pinehurst Company,Soylent Corporation,'
    $manufacturerList += 'Nucleic Exchange Research and Development,Multi-National United,'
    $manufacturerList += 'Buy N Large,Dante Laboratories,PharmaKom Industries,OsCorp,Hanso Foundation,'
    $manufacturerList += 'Blue Sun Corporation,LuthorCorp,Weyland-Yutani Corporation,Omni Consumer Products,'
    $manufacturerList += 'Umbrella Corporation,Zorg Industries,BiffCo Enterprises,Tyrell Corporation,E Corp'

    $manufacturers = $manufacturerList.Split(',')

    return ($manufacturers | Get-Random -Count $randomCount)
}

# Generates a random capitalised product name between 5 and 10 characters long
function GenerateRandomProductName()
{
    $randomCaptial = (65..90) | Get-Random -Count 1 | ForEach-Object {[char]$_}
    $randomLetters = -join ((97..122) | Get-Random -Count (Get-Random -Minimum 4 -Maximum 10) | ForEach-Object {[char]$_})

    return ($randomCaptial + $randomLetters)
}

function GenerateVersion([int]$buildVersion)
{
    # base version string start at 1.0.0
    $baseVersion = '1.0.'

    return $baseVersion + $buildVersion.ToString()
}

function SplitPlaceholderValue([string]$placeholderValue)
{
    return $placeholderValue.Split('-')[1]
}

function ExecuteProcess($commandPath, $commandArguments)
{
    $processStartInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processStartInfo.FileName = $commandPath
    $processStartInfo.RedirectStandardError = $true
    $processStartInfo.RedirectStandardOutput = $true
    $processStartInfo.UseShellExecute = $false
    $processStartInfo.Arguments = $commandArguments
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $processStartInfo
    $process.Start() | Out-Null
    $process.WaitForExit()

    return [pscustomobject]@{
        StdOut = $process.StandardOutput.ReadToEnd()
        StdErr = $process.StandardError.ReadToEnd()
        ExitCode = $process.ExitCode  
    }
}

function UpdateProgress($id, $activity, $percentComplete, $currentOperation, $status)
{
    Write-Progress -Id $id -Activity $activity -PercentComplete $percentComplete -CurrentOperation $currentOperation -Status $status
}

class MsiInfo 
{
    [string]$ProductName
    [string]$ProductManufacturer
    [string]$ProductCode
    [string]$UpgradeCode
    [string]$ProductVersion
    [string]$PackageDescription
    [string]$PackageManufacturer
    [string]$PackageComments
    [string]$ProductVersionExe
    [string]$MainExeFileName
    [string]$MainExeFileSource
    [string]$AppDirName
    [string]$ProductExe
    [string]$ProductSpaceVersion
    [string]$StartMenuProductVersion
    [string]$DesktopProductVersion
    [string]$ProgFileProductManufacturer
    [string]$PackageArchitecture
    [string]$ProgramFilesFolder
    [string]$OutputFilePrefix

    MsiInfo([string]$productManufacturer, [string]$productName, [string]$productCode, [string]$upgradeCode, [string]$productVersion, [string]$packageArchitecture)
    {
        $this.ProductManufacturer = $productManufacturer
        $this.ProductName = $productName + " ($packageArchitecture)"
        $this.ProductCode = $productCode
        $this.UpgradeCode = $upgradeCode
        $this.ProductVersion = $productVersion
        $this.PackageDescription = "{0} {1} {2} installer" -f $productManufacturer, $productName, $productVersion
        $this.PackageManufacturer = $this.ProductManufacturer
        $this.PackageComments = "$productName is a registered trademark of $productManufacturer"
        $this.ProductVersionExe = "$productName$productVersion.exe"
        $this.MainExeFileName = "$productName`Appl$productVersion.exe"
        $this.MainExeFileSource = "$productName`Appl$productVersion.exe"
        $this.AppDirName = "$productName $productVersion"
        $this.ProductExe = "$productName.exe"
        $this.ProductSpaceVersion = "$productName $productVersion"
        $this.StartMenuProductVersion = "startmenu$productName$productVersion"
        $this.DesktopProductVersion = "desktop$productName$productVersion"
        $this.ProgFileProductManufacturer = $this.ProductManufacturer -replace " |-", "_"
        $this.PackageArchitecture = $packageArchitecture
        $this.ProgramFilesFolder = switch ($this.PackageArchitecture) 
        {
            "x86" { "ProgramFilesFolder" }
            "x64" { "ProgramFiles64Folder" }
        }
        $this.OutputFilePrefix = $productName + "-" + $packageArchitecture + "-" + $productVersion
    }

}

function CreateDummyContent($productManufacturer, $baseProductName, $productVersion)
{
    UpdateProgress 1 "Generating MSI's" $($msisProcessed / $totalMsis * 100) "Processing $productManufacturer $baseProductName $productVersion" "Generating output folder and dummy payload"

    # Create folders for dummy content files and msi output
    $dataPath = "$StagingRoot\$productManufacturer\$baseProductName\$productVersion"

    if (!(Test-Path -Path "$dataPath\source"))
    {
        New-Item -Path "$dataPath\source" -ItemType Directory -Force | Out-Null
    }
    if (!(Test-Path -Path "$dataPath\msi"))
    {
        New-Item -Path "$dataPath\msi" -ItemType Directory -Force | Out-Null
    }

    # create some non 0-byte dummy content "$productName`Appl$productVersion.exe"
    Set-Content -Path "$dataPath\source\$baseProductName`Appl$productVersion.exe" -Value "$productName $productVersion"
    Set-Content -Path "$dataPath\source\helper.dll" -Value "$productName $productVersion"
    Set-Content -Path "$dataPath\source\manual.pdf" -Value "$productName $productVersion)"

    return $dataPath
}

function CreateOutputMsi($msiInfo, $workingDir, $baseProductName)
{    
    # load in template wix xml
    try 
    {
        [xml]$wksTemplate = Get-Content -Path ".\template.wks" -ErrorAction Stop
    }
    catch 
    {
        Write-Host "Failed to locate WIX template file .\template.wks"
        exit
    }

    # xml namespace manager
    $nsmgr = New-Object System.Xml.XmlNamespaceManager($wksTemplate.NameTable)
    $nsmgr.AddNamespace("ab", $wksTemplate.DocumentElement.NamespaceURI)

    # use xpath to find nodes with 1 or more attributes that need updated
    # the template xml has place holder attribute values prefixed with 'replace-'
    $nodesToUpdate = $wksTemplate.SelectNodes("//attribute::*[contains(., 'replace-')]/..", $nsmgr)

    UpdateProgress 1 "Generating MSI's" $($msisProcessed / $totalMsis * 100) "Processing $($msiInfo.ProductManufacturer) $($msiInfo.ProductName) $($msiInfo.ProductVersion)" "Transforming WIX template"

    # so there was probably a much better way of doing this. 
    # i could have included the template xml as a here string and just used $variablename to complete
    # but i didnt go down that rabbit hole...i went down a different one...a long one...
    # the point of the below was to be able to dynamically update an attribute based on its placeholder value in the template
    # it also seems there might be a way to transform the template.xml natively with wix
    foreach ($node in $nodesToUpdate)
    {
        # determine node type which infers attribute names which we need to know in order to update
        # for most node types, the 2nd arg for SetAttribute is inferred by assuming .$variablename maps to a class property
        switch ($node.LocalName) 
        {
            Product 
            {
                $node.SetAttribute("Name", $msiInfo.ProductName)
                $node.SetAttribute("Manufacturer", $msiInfo.ProductManufacturer)
                $node.SetAttribute("Version", $msiInfo.ProductVersion)
                $node.SetAttribute("Id", $msiInfo.ProductCode)
                $node.SetAttribute("UpgradeCode", $msiInfo.UpgradeCode)
            }
            Package
            {
                $descriptionValue = SplitPlaceholderValue($node.Description)
                $commentsValue = SplitPlaceholderValue($node.Comments)
                $manufacturerValue = SplitPlaceholderValue($node.Manufacturer)

                $node.SetAttribute("Description", $msiInfo.$descriptionValue)
                $node.SetAttribute("Comments", $msiInfo.$commentsValue)
                $node.SetAttribute("Manufacturer", $msiInfo.$manufacturerValue)
            }
            Directory 
            {
                $idValue = SplitPlaceholderValue($node.Id)
                $nameValue = SplitPlaceholderValue($node.Name)

                if ($node.Id.Contains('replace'))
                {
                    $node.SetAttribute("Id", $msiInfo.$idValue)
                }

                if ($node.Name.Contains('replace'))
                {
                    $node.SetAttribute("Name", $msiInfo.$nameValue)
                }
            }
            File 
            {
                $idValue = SplitPlaceholderValue($node.Id)
                $nameValue = SplitPlaceholderValue($node.Name)
                $sourceValue = SplitPlaceholderValue($node.Source)

                $node.SetAttribute("Id", $msiInfo.$idValue)
                $node.SetAttribute("Name", $msiInfo.$nameValue)
                $node.SetAttribute("Source", $msiInfo.$sourceValue)

            }
            Shortcut 
            {
                $idValue = SplitPlaceholderValue($node.Id)
                $nameValue = SplitPlaceholderValue($node.Name)
                $iconValue = SplitPlaceholderValue($node.Icon)

                $node.SetAttribute("Id", $msiInfo.$idValue)
                $node.SetAttribute("Name", $msiInfo.$nameValue)
                $node.SetAttribute("Icon", $msiInfo.$iconValue)
            }
            Icon 
            {
                $idValue = SplitPlaceholderValue($node.Id)
                $sourceFile = SplitPlaceholderValue($node.SourceFile)

                $node.SetAttribute("Id", $msiInfo.$idValue)
                $node.SetAttribute("SourceFile", $msiInfo.$sourceFile)
            }
            Component
            {
                $guidValue = SplitPlaceholderValue($node.Guid)
                if ($guidValue -eq 'NewGuid')
                {
                    $node.SetAttribute("Guid", $(GenerateGuid))
                }
            }
            Property
            {
                # if > 1 property nodes are added to the template this will need to change
                $node.SetAttribute("Value", "$($msiInfo.ProductManufacturer) $($msiInfo.ProductName) $($msiInfo.ProductVersion) Installation [1]")
            }
        }
    }

    # save xml to relevant source directory for use with candle.exe & light.exe
    $wksTemplate.Save("$workingDir\source\$($msiInfo.OutputFilePrefix).wks")

    UpdateProgress 1 "Generating MSI's" $($msisProcessed / $totalMsis * 100) "Processing $($msiInfo.ProductManufacturer) $($msiInfo.ProductName) $($msiInfo.ProductVersion)" "Calling WIX toolkit Candle.exe"

    # call candle.exe
    # ToDo: try catch
    $result = ExecuteProcess "candle.exe" "-arch $($msiInfo.PackageArchitecture) -out ""$workingDir\source\$($msiInfo.OutputFilePrefix).wixobj"" ""$workingDir\source\$($msiInfo.OutputFilePrefix).wks"""
    if ($result.ExitCode -ne 0)
    {
        Write-Host "Error encountered running Candle.exe"
        Write-Host "Exit code: $($result.ExitCode)"
        Write-Host "Command output: $($result.StdOut)"
        break
    }
    $result = $null

    UpdateProgress 1 "Generating MSI's" $($msisProcessed / $totalMsis * 100) "Processing $($msiInfo.ProductManufacturer) $($msiInfo.ProductName) $($msiInfo.ProductVersion)" "Calling WIX toolkit Light.exe"

    # call light.exe
    # ToDo: try catch
    $result = ExecuteProcess "light.exe" "-spdb -out ""$workingDir\msi\$($msiInfo.OutputFilePrefix).msi"" ""$workingDir\source\$($msiInfo.OutputFilePrefix).wixobj"""
    if ($result.ExitCode -ne 0)
    {
        Write-Host "Error encountered running Light.exe"
        Write-Host "Exit code: $($result.ExitCode)"
        Write-Host "Command output: $($result.StdOut)"
        break
    }
}

# Main

# how may MSIs are we making
$totalMsis = ($Manufacturers * ($Packages * $Versions))

if ($Architecture -eq "all")
{
    $totalMsis = $totalMsis * 2
}

$msisProcessed = 0

# Get list of tandom manufacturers
$manufacturerList = GetRandomManufacturer $Manufacturers

for ($i = 0; $i -lt $Manufacturers; $i++) 
{
    # Grab a manufacturer to process
    $tempManufacturer = $manufacturerList[$i]

    for ($j = 0; $j -lt $Packages; $j++)
    {
        # generate random product name
        $tempProductName = GenerateRandomProductName

        # generate x86 and x64 package upgrade codes
        $x86UpgradeCode = GenerateGuid
        $x64UpgradeCode = GenerateGuid

        # generate version and create output dir, msi's
        for ($k = 0; $k -lt $Versions; $k++)
        {
            # generate product code and version starting at 1.0.0
            $tempVersion = GenerateVersion $k

            # create dummy content and get data path
            $dataPath = CreateDummyContent $tempManufacturer $tempProductName $tempVersion

            # x86 package
            if (($Architecture -eq 'x86') -or ($Architecture -eq 'all'))
            {
                # generate package and upgrade code
                $tempProductCode = GenerateGuid
                #$tempUpgradeCode = GenerateGuid

                UpdateProgress 1 "Generating MSI's" $($msisProcessed / $totalMsis * 100) "Processing $tempManufacturer $tempProductName $tempVersion" "Generating MSI details"

                # create an MsiInfo instance to hold required values
                $msiInfo = [MsiInfo]::New($tempManufacturer
                , $tempProductName
                , $tempProductCode
                , $x86UpgradeCode
                , $tempVersion
                , "x86")

                # call CreateOutputMsi to create MSI
                CreateOutputMsi $msiInfo $dataPath

                $msisProcessed++
            }
            
            # x64 package
            if (($Architecture -eq 'x64') -or ($Architecture -eq 'all'))
            {     
                # generate package and upgrade code
                $tempProductCode = GenerateGuid
                #$tempUpgradeCode = GenerateGuid

                UpdateProgress 1 "Generating MSI's" $($msisProcessed / $totalMsis * 100) "Processing $tempManufacturer $tempProductName x64 $tempVersion" "Generating MSI details"

                # create an MsiInfo instance to hold required values
                $msiInfo = [MsiInfo]::New($tempManufacturer
                , $tempProductName
                , $tempProductCode
                , $x64UpgradeCode
                , $tempVersion
                , "x64")

                # call CreateOutputMsi to create MSI
                CreateOutputMsi $msiInfo $dataPath

                $msisProcessed++
            }
        }
    }
}

Write-Host "Generate-TestMsi completed $msisProcessed packages."