param()

Set-StrictMode -Version Latest

function Use-VSEnv
{
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        [Parameter(Position = 0, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-Path -LiteralPath:$_ })]
        [string] $LiteralPath,

        # The architecture for compiled binaries/libraries
        [Parameter(Mandatory)]
        [ValidateSet("x86", "amd64", "arm", "arm64")]
        [string] $Architecture,

        # The architecture of compiler binaries
        [Parameter(Mandatory)]
        [ValidateSet("x86", "amd64")]
        [string] $HostArchitecture
    )

    Write-Verbose "Importing Visual Studio environment variables from '${LiteralPath}', Architecture=${Architecture}, HostArchitecture=${HostArchitecture}";

    Restore-Env -ErrorAction Ignore

    $Script:Environment = @{};

    if ($PSCmdlet.ShouldProcess($LiteralPath, 'Import Visual Studio environment'))
    {
        $cmd = "`"$LiteralPath`" -arch=$Architecture -host_arch=$HostArchitecture > nul & set"
        cmd /c $cmd | ForEach-Object {
            $p, $v = $_.split('=')
            $orig = $null
            $orig = Get-Content Env:$p -ErrorAction SilentlyContinue
            $Script:Environment[$p] = $orig
            Set-Item -Path env:$p -Value $v
        }
    }
}

function Restore-Env
{
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if (!$Script:Environment)
    {
        Write-Error "No environment to restore."
        return
    }

    if ($VerbosePreference)
    {
        Write-Verbose "Restoring original environment: $($Script:Environment | Out-String)"
    }

    foreach ($key in $Script:Environment.Keys)
    {
        Set-Item -Path env:$key -Value $Script:Environment[$key]
    }
}

<#
.SYNOPSIS
Wrapper for `vswhere.exe`

.SCOPE Private
#>
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
        [Parameter()]
        [string] $Version
    )

    $VSWhereArgs = @()
    if ($All) { $VSWhereArgs += '-all' }
    if ($Product) { $VSWhereArgs += '-products', ($Product -join ',') }
    if ($Require) { $VSWhereArgs += '-requires', ($Require -join ',') }
    switch ($Version)
    {
        '' {}
        # Special cases
        'latest' { $VSWhereArgs += '-latest' }
        # Everything else
        default { $VSWhereArgs += '-version', $Version }
    }

    Write-Debug "Running vswhere -format json ${VSWhereArgs}"
    & "${PSScriptRoot}\vswhere.exe" -format json $VSWhereArgs | ConvertFrom-Json
}

filter Resolve-NumericVersion
{
    # vswhere will treat an integer as VERSION >= integer.
    # We just want major version.
    [ref] $ref = $null
    if ([int]::TryParse($_, $ref))
    {
        return '[{0}, {1})' -f $ref.Value, ($ref.Value + 1)
    }

    return $_
}

filter Resolve-YearToVersion
{
    # Map years to version numbers.
    switch ($_)
    {
        2022 { 17 }
        2019 { 16 }
        2017 { 15 }
        2015 { 14 }
        2013 { 12 }
        2012 { 11 }
        2010 { 10 }
        default { $_ }
    }
}

<#
.SYNOPSIS
Gets the given Visual Studio instance matching the specified parameters.

.EXAMPLE
Get Visual Studio 2022 (17.0).

PS> Get-VisualStudioInstance -Version 17

installationName    : VisualStudio/17.2.6+32630.192
installationPath    : C:\Program Files\Microsoft Visual Studio\2022\Enterprise
installationVersion : 17.2.32630.192
displayName         : Visual Studio Enterprise 2022
...

.EXAMPLE

Same as previous example but by year.

PS> Get-VisualStudioInstance -Version 2022

installationName    : VisualStudio/17.2.6+32630.192
installationPath    : C:\Program Files\Microsoft Visual Studio\2022\Enterprise
installationVersion : 17.2.32630.192
displayName         : Visual Studio Enterprise 2022
...

#>
function Get-VisualStudioInstance
{
    [CmdletBinding()]
    [OutputType([PSObject[]])]
    param
    (
        # The version range by which to limit, if any.
        # Default returns all non-prerelease versions.
        [Parameter(Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string] $Version,

        # Allow prerelease versions.
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [switch] $AllowPrerelease
    )

    process
    {
        $ResolvedVersion = $Version | Resolve-YearToVersion | Resolve-NumericVersion
        Write-Verbose "Getting Visual Studio version '${Version}' (as '${ResolvedVersion}')"

        $v = Invoke-VSWhere -Version:$ResolvedVersion
        if (!$AllowPrerelease)
        {
            $v = $v | Where-Object channelId -notlike '*.Preview'
        }

        if (!$v -and $Version)
        {
            # They didn't request "all", they requested a specific value.
            Write-Error "Cannot find Visual Studio version '${Version}' because it is not installed."
            return
        }

        Add-Member -PassThru -InputObject $v -MemberType AliasProperty -Name 'PSPath' -Value 'installationPath'
    }
}

<#
Resolve the

.SCOPE Private
#>
function Use-VSEnvComnToolsVariable
{
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        [Parameter(Position = 0, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $envVar,


        [Parameter(Position = 1, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $BatFile,

        # The architecture for compiled binaries/libraries
        [Parameter()]
        [ValidateSet("x86", "amd64", "arm", "arm64")]
        [string] $Architecture = "x86",

        # The architecture of compiler binaries
        [Parameter()]
        [ValidateSet("x86", "amd64")]
        [string] $HostArchitecture = "x86"
    )

    if (-not (Test-Path Env:$envVar))
    {
        Write-Warning "Environment variable $envVar is undefined"
        return;
    }

    $vsvars32FullPath = Join-Path (Get-Item Env:$envVar).Value $BatFile

    Use-VSEnv -LiteralPath $vsvars32FullPath -Architecture $Architecture -HostArchitecture $HostArchitecture
}


<#
.SYNOPSIS
Find and use Visual Studio 2012 (10.0).
#>
function Use-VS2010
{
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Use-VSEnvComnToolsVariable 'VS100COMNTOOLS' 'vsvars32.bat'
}

<#
.SYNOPSIS
Find and use Visual Studio 2012 (11.0).
#>
function Use-VS2012
{
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Use-VSEnvComnToolsVariable 'VS110COMNTOOLS' 'vsvars32.bat'
}

<#
.SYNOPSIS
Find and use Visual Studio 2013 (12.0).
#>
function Use-VS2013
{
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Use-VSEnvComnToolsVariable 'VS120COMNTOOLS' 'vsvars32.bat'
}

<#
.SYNOPSIS
Find and use Visual Studio 2015 (14.0).
#>
function Use-VS2015
{
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Use-VSEnvComnToolsVariable 'VS140COMNTOOLS' 'VsDevCmd.bat'
}

<#
.SYNOPSIS
Find and use Visual Studio 2017 (15.0).
#>
function Use-VS2017
{
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Use-VisualStudioInstance -Version 2017
}

<#
.SYNOPSIS
Find and use Visual Studio 2019 (16.0).
#>
function Use-VS2019
{
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        # The architecture for compiled binaries/libraries
        [Parameter()]
        [ValidateSet("x86", "amd64", "arm", "arm64")]
        [string] $Architecture = "x86",

        # The architecture of compiler binaries
        [Parameter()]
        [ValidateSet("x86", "amd64")]
        [string] $HostArchitecture = "x86"
    )

    Use-VisualStudioInstance -Version 2019 -Architecture $Architecture -HostArchitecture $HostArchitecture
}

<#
.SYNOPSIS
Find and use Visual Studio 2022 (17.0).
#>
function Use-VS2022
{
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        # The architecture for compiled binaries/libraries
        [Parameter()]
        [ValidateSet("x86", "amd64", "arm", "arm64")]
        [string] $Architecture = "x86",

        # The architecture of compiler binaries
        [Parameter()]
        [ValidateSet("x86", "amd64")]
        [string] $HostArchitecture = "x86"
    )

    Use-VisualStudioInstance -Version 2022 -Architecture $Architecture -HostArchitecture $HostArchitecture
}

<#
.SYNOPSIS
Sets up the environment to use the given Visual Studio instance.
#>
function Use-VisualStudioInstance
{
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Version')]
    param
    (
        # The instance to use.
        [Parameter(ParameterSetName = 'Instance', Position = 0, Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [PSObject] $Instance,

        # The version to use.
        [Parameter(ParameterSetName = 'Version', Position = 0, Mandatory, ValueFromPipeline)]
        [string] $Version,

        # The architecture for compiled binaries/libraries
        [Parameter()]
        [ValidateSet("x86", "amd64", "arm", "arm64")]
        [string] $Architecture = "x86",

        # The architecture of compiler binaries
        [Parameter()]
        [ValidateSet("x86", "amd64")]
        [string] $HostArchitecture = "x86"
    )

    process
    {
        switch ($PSCmdlet.ParameterSetName)
        {
            'Instance' {}
            'Version'
            {
                # PSCRAP: can't assign to Instance directly b/c it will set a MetadataError if it does.
                $instanceForVersion = Get-VisualStudioInstance -Version $Version
                if (!$instanceForVersion)
                {
                    # Don't need to write error, Get-VisualStudioInstance should have done that.
                    return
                }

                $Instance = $instanceForVersion
            }
        }

        $vsvars32 = $Instance | Get-ChildItem -Filter 'Common7\Tools\VsDevCmd.bat'
        if (!$vsvars32)
        {
            # Fallback to crawling
            Write-Verbose "Common7\Tools\VsDevCmd.bat not found, searching full instance."
            $vsvars32 = $Instance | Get-ChildItem -Depth 3 -Include 'VsDevCmd.bat', 'vsvars32.bat' | Select-Object -First 1
            if (!$vsvars32)
            {
                Write-Error "Cannot find vsdevcmd.bat or vsvars32.bat for $Instance"
                return
            }
        }

        Write-Verbose "Found ${vsvars32}"
        if ($PSCmdlet.ShouldProcess("Version: ${vsvars32}, Path: ${vsvars32}", "Use Visual Studio version"))
        {
            Use-VSEnv -LiteralPath $vsvars32 -Architecture $Architecture -HostArchitecture $HostArchitecture
        }
    }
}

<#
.SYNOPSIS
Clears the environment of any Visual Studio instance set by this tool.
#>
function Clear-VisualStudioInstance
{
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Restore-Env
    $Script:Environment = $null
}