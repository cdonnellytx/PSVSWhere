@{
    RootModule = 'PSVSWhere.psm1'
    ModuleVersion = '1.0.0'
    GUID = '4ffb668e-bf60-4f97-aa04-7115cd3b075b'
    Author = 'Chris R. Donnelly', 'Eduardo Sousa'
    Description = 'Functions loading Visual Studio environment variables'
    PowerShellVersion = '5.0'
    DotNetFrameworkVersion = '4.0'
    CLRVersion = '4.0'
    FunctionsToExport = @(
        'Get-VisualStudioInstance',
        'Use-VisualStudioInstance',
        'Clear-VisualStudioInstance',
        'Use-VS2010',
        'Use-VS2012',
        'Use-VS2013',
        'Use-VS2015',
        'Use-VS2017',
        'Use-VS2019',
        'Use-VS2022'
    )
    AliasesToExport = @()
    HelpInfoURI = 'https://github.com/cdonnellytx/PSVSWhere'
    PrivateData = @{
        Tags = 'VisualStudio'
        ProjectUri = 'https://github.com/cdonnellytx/PSVSWhere'
        PSData = @{ Prerelease = 'beta3' }
    }
}
