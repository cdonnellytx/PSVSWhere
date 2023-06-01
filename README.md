# PSVSWhere

PowerShell module for loading Visual Studio Environment variables.

Derived from [PSVSEnv](https://github.com/ecsousa/PSVSEnv).

## Using

It provides the following function:

* `Use-VS2010`: Loads environment variables for Visual Studio 2010
* `Use-VS2012`: Loads environment variables for Visual Studio 2012
* `Use-VS2013`: Loads environment variables for Visual Studio 2013
* `Use-VS2015`: Loads environment variables for Visual Studio 2015
* `Use-VS2017`: Loads environment variables for Visual Studio 2017
* `Use-VS2019`: Loads environment variables for Visual Studio 2019
* `Use-VS2022`: Loads environment variables for Visual Studio 2022

Note: each one of these functions needs the related software installed.

## Installing

Windows 10 and later users:

```pwsh
Install-Module PSVSWhere -Scope CurrentUser
```

Otherwise, if you have [PsGet](http://psget.net/) installed:

```pwsh
Install-Module PSVSWhere
```

Or you can install it manually coping `PSVSWhere.psm1` to your modules folder (e.g. ` $Env:USERPROFILE\Documents\WindowsPowerShell\Modules\PSVSWhere\`)

