# VSIX Module for AppVeyor by Mads Kristensen

function Vsix-Build {

    [CmdletBinding()]
    param (
        [Parameter(Position=0, Mandatory=0)]
        [string]$file = "*.sln",

        [Parameter(Position=1, Mandatory=0)]
        [string]$configuration = "Release",

        
        [switch]$updateBuildVersion,
        [switch]$pushArtifacts
    ) 

    $buildFile = Get-ChildItem $file
    $env:CONFIGURATION = $configuration

    msbuild $buildFile.FullName /p:configuration=$configuration /p:DeployExtension=false /p:ZipPackageCompressionLevel=normal /v:m

    if ($updateBuildVersion){
        Vsix-UpdateBuildVersion
    }

    if ($pushArtifacts){
        Vsix-PushArtifacts
    }
}

function Vsix-PushArtifacts {

    [CmdletBinding()]
    param (
        [Parameter(Position=0, Mandatory=0)]
        [string]$path = "./**/bin/$configuration/*.vsix"
    ) 

    Get-ChildItem $path | % { Push-AppveyorArtifact $_.FullName -FileName $_.Name }
}

function Vsix-UpdateBuildVersion {
     Write-Host "Updating AppVeyor build..." -ForegroundColor Cyan -NoNewline
     Update-AppveyorBuild -Version $env:APPVEYOR_BUILD_VERSION
     Write-Host "OK" `n -ForegroundColor Green
}

function Vsix-IncrementVersion {

    [CmdletBinding()]
    param (
        [Parameter(Position=0, Mandatory=0)]
        [string]$manifestFilePath = "**\source.extension.vsixmanifest",

        [Parameter(Position=1, Mandatory=0)]
        [int]$buildNumber = $env:APPVEYOR_BUILD_NUMBER,

        [ValidateSet("build","revision")]
        [Parameter(Position=2, Mandatory=0)]
        [string]$versionType = "build",

        [switch]$updateBuildVersion
    )

    Write-Host "`nIncrementing VSIX version..."  -ForegroundColor Cyan -NoNewline

    $vsixManifest = Get-ChildItem $manifestFilePath
    [xml]$vsixXml = Get-Content $vsixManifest

    $ns = New-Object System.Xml.XmlNamespaceManager $vsixXml.NameTable
    $ns.AddNamespace("ns", $vsixXml.DocumentElement.NamespaceURI)

    $attrVersion = $vsixXml.SelectSingleNode("//ns:Identity", $ns).Attributes["Version"]

    [Version]$version = $attrVersion.Value;

    if ($versionType -eq "build"){
        $version = New-Object Version ([int]$version.Major),([int]$version.Minor),$buildNumber
    }
    elseif ($versionType -eq "revision"){
        $version = New-Object Version ([int]$version.Major),([int]$version.Minor),([System.Math]::Max([int]$version.Build, 0)),$buildNumber
    }
        
    [Version]$newVersion = $Version
    $attrVersion.Value = $newVersion

    $vsixXml.Save($vsixManifest)

    $env:APPVEYOR_BUILD_VERSION = $newVersion.ToString()

    Write-Host $newVersion.ToString() -ForegroundColor Green

    if ($updateBuildVersion){
        Vsix-UpdateBuildVersion
    }
}