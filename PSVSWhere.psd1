@{
    RootModule = 'PSVSWhere.psm1'
    ModuleVersion = '0.1.0'
    GUID = '4ffb668e-bf60-4f97-aa04-7115cd3b075b'
    Author = 'Chris R. Donnelly', 'Eduardo Sousa'
    Description = 'Functions loading Visual Studio environment variables'
    PowerShellVersion = '5.0'
    DotNetFrameworkVersion = '4.0'
    CLRVersion = '4.0'
    FunctionsToExport = @(
        'Get-VisualStudioInstance',
        'Set-VisualStudioInstance',
        'Set-VS2010',
        'Set-VS2012',
        'Set-VS2013',
        'Set-VS2015',
        'Set-VS2017',
        'Set-VS2019',
        'Set-VS2022',
        'Set-WAIK')
    AliasesToExport = @()
    HelpInfoURI = 'https://github.com/cdonnellytx/PSVSWhere'
    PrivateData = @{
        Tags = 'VisualStudio'
        ProjectUri = 'https://github.com/cdonnellytx/PSVSWhere'
        PSData = @{ Prerelease = 'alpha' }
    }
}
