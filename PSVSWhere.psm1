param()

function Import-Env
{
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        [string] $BatFile,

        [ValidateSet("x86", "amd64", "arm", "arm64")]
        [string] $Architecture,

        [ValidateSet("x86", "amd64")]
        [string] $HostArchitecture
    )

    if ($Script:Environment)
    {
        ForEach ($key in $Script:Environment.Keys)
        {
            Set-Item -Path env:$key -Value $Script:Environment[$key]
        }
    }

    $Script:Environment = @{};

    if ($PSCmdlet.ShouldProcess($BatFile, 'Import Visual Studio environment'))
    {
        $cmd = "`"$BatFile`" -arch=$Architecture -host_arch=$HostArchitecture > nul & set"
        cmd /c $cmd | ForEach-Object {
            $p, $v = $_.split('=')
            $orig = $null
            $orig = Get-Content Env:$p -ErrorAction SilentlyContinue
            $Script:Environment[$p] = $orig
            Set-Item -Path env:$p -Value $v
        }
    }
}

function Set-VSEnv
{
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        [string] $vsvars32FullPath,

        [ValidateSet("x86", "amd64", "arm", "arm64")]
        [string] $Architecture,

        [ValidateSet("x86", "amd64")]
        [string] $HostArchitecture
    )

    if (-not (Test-Path $vsvars32FullPath))
    {
        Write-Warning "Could not find file '$vsvars32FullPath'";
        return;
    }

    Write-Verbose "Importing Visual Studio environment variables from '$vsvars32FullPath'";

    Import-Env $vsvars32FullPath -Architecture $Architecture -HostArchitecture $HostArchitecture
}

function Invoke-VSWhere
{
    [CmdletBinding()]
    [OutputType([PSObject[]])]
    param
    (
        # Finds all instances regardless if they are complete.
        [switch] $All,

        # One or more products to find.
        # Defaults to Community, Professional, and Enterprise.
        # Specify `*` by itself to search all product instances installed.
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Alias('Products')]
        [ValidateSet('Community', 'Professional', 'Enterprise', '*')]
        [string[]] $Product,

        # One or more workloads or components required when finding instances.
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Alias('Requires')]
        [string[]] $Require,

        # A version range for instances to find. Example: [15.0,16.0) will find versions 15.*.
        [string] $Version,

        # Return only the newest version and last installed.
        [switch] $Latest
    )

    $VSWhereArgs = @()
    if ($All) { $VSWhereArgs += '-all' }
    if ($Product) { $VSWhereArgs += '-products', ($Product -join ',') }
    if ($Require) { $VSWhereArgs += '-requires', ($Require -join ',') }
    if ($Version) { $VSWhereArgs += '-version', $Version }
    if ($Latest) { $VSWhereArgs += '-latest' }

    & "${PSScriptRoot}\vswhere.exe" -format json $VSWhereArgs | ConvertFrom-Json
}

function Get-VisualStudioInstance
{
    [CmdletBinding()]
    [OutputType([PSObject[]])]
    param
    (
        # The version by which to limit.
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $Version,

        # Allow prerelease versions.
        [Parameter()]
        [switch] $AllowPrerelease
    )

    $v = Invoke-VSWhere -Version:$Version
    if (!$AllowPrerelease)
    {
        $v = $v | Where-Object channelId -notlike '*.Preview'
    }

    $v | Add-Member -MemberType AliasProperty -Name 'PSPath' -Value 'installationPath'
    return $v
}

function Set-VSEnvComnTools
{
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        [string] $envVar,
        [string] $BatFile
    )

    if (-not (Test-Path Env:$envVar))
    {
        Write-Warning "Environment variable $envVar is undefined"
        return;
    }

    $vsvars32FullPath = Join-Path (Get-Item Env:$envVar).Value $BatFile

    Set-VSEnv $vsvars32FullPath
}

function Set-VSEnvVSWhere
{
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        [string] $Version,

        [string] $BatFile,

        [ValidateSet("x86", "amd64", "arm", "arm64")]
        [string] $Architecture,

        [ValidateSet("x86", "amd64")]
        [string] $HostArchitecture
    )

    $vsPath = Invoke-VSWhere -Version $Version

    if (!$vsPath)
    {
        Write-Warning "Could not find Visual Studio installation path for version '$version'"
        return;
    }

    $vsvars32FullPath = Join-Path $vsPath $BatFile

    Set-VSEnv $vsvars32FullPath -Architecture $Architecture -HostArchitecture $HostArchitecture
}

function Set-WAIK
{
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $pesetenvFullPath = "C:\Program Files\Windows AIK\Tools\PETools\pesetenv.cmd"

    if (-not (Test-Path $pesetenvFullPath))
    {
        Write-Warning "Could not find pesetenv.cmd"
        return;
    }

    Write-Verbose "Importing Windows AIK environment";

    Import-Env $pesetenvFullPath
}

function Set-VS2010
{
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Set-VSEnvComnTools 'VS100COMNTOOLS' 'vsvars32.bat'
}

function Set-VS2012
{
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Set-VSEnvComnTools 'VS110COMNTOOLS' 'vsvars32.bat'
}

function Set-VS2013
{
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Set-VSEnvComnTools 'VS120COMNTOOLS' 'vsvars32.bat'
}

function Set-VS2015
{
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Set-VSEnvComnTools 'VS140COMNTOOLS' 'VsDevCmd.bat'
}

function Set-VS2017
{
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        [ValidateSet("x86", "amd64", "arm", "arm64")]
        [string] $Architecture = "x86",

        [ValidateSet("x86", "amd64")]
        [string] $HostArchitecture = "x86"
    )
    Set-VSEnvVSWhere -Version '[15.0,16.0)' -batFile 'Common7\Tools\VsDevCmd.bat' -Architecture $Architecture -HostArchitecture $HostArchitecture
}

function Set-VS2019
{
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        [ValidateSet("x86", "amd64", "arm", "arm64")]
        [string] $Architecture = "x86",

        [ValidateSet("x86", "amd64")]
        [string] $HostArchitecture = "x86"
    )

    Get-VisualStudioInstance -Version 16 | Set-VisualStudioInstance -Architecture $Architecture -HostArchitecture $HostArchitecture
}

function Set-VS2022
{
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        [ValidateSet("x86", "amd64", "arm", "arm64")]
        [string] $Architecture = "x86",

        [ValidateSet("x86", "amd64")]
        [string] $HostArchitecture = "x86"
    )

    Get-VisualStudioInstance -Version 17 | Set-VisualStudioInstance -Architecture $Architecture -HostArchitecture $HostArchitecture
}

function Set-VisualStudioInstance
{
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        [Parameter(Position = 0, Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [PSObject] $Instance
    )

    process
    {
        $vsvars32 = $Instance | Get-ChildItem -Include 'Common7\Tools\VsDevCmd.bat'
        if (!$vsvars32)
        {
            # Fallback to crawling
            $vsvars32 = $Instance | Get-ChildItem -Depth 3 -Include 'VsDevCmd.bat', 'vsvars32.bat' | Select-Object -First 1
        }

        if ($vsvars32)
        {
            Set-VSEnv $vsvars32.FullName -Architecture $Architecture -HostArchitecture $HostArchitecture
        }
        else
        {
            Write-Error "Cannot find vsdevcmd.bat or vsvars32.bat for $Instance"
        }
    }
}

Set-Alias vs2010 Set-VS2010
Set-Alias vs2012 Set-VS2012
Set-Alias vs2013 Set-VS2013
Set-Alias vs2015 Set-VS2015
Set-Alias vs2017 Set-VS2017
Set-Alias vs2019 Set-VS2019
Set-Alias vs2022 Set-VS2022
Set-Alias waik Set-WAIK

