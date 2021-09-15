
#Requires -Version 5.1
Set-StrictMode -Version 'Latest'

& (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Test.ps1' -Resolve)

$failed = $false
$user = 'CarbonTestUser1'
$group1 = 'CarbonTestGroup1'
$password = 'a1z2b3y4!'
$testCredentials = New-Credential -Username $user -Password $password
$containerPath = $null
$childPath = $null

function Init
{
    $Global:Error.Clear()
    $script:failed = $false
    $script:containerPath = $null
    $script:childPath = $null
}

function InstallUserandGroup
{
    Install-User -Credential $testCredentials -Description 'Account for testing Carbon Get-Permission'
    Install-Group -Name $group1 -Description 'Group for testing Get-Permission'
}

function SetUpPath
{
    $script:containerPath = 'Carbon-Test-GetPermissions-{0}' -f ([IO.Path]::GetRandomFileName())
    $script:containerPath = Join-Path -Path $env:Temp -ChildPath $containerPath

    if( -not ( Test-Path $containerPath ) )
    {
        New-Item -Path $containerPath -ItemType Directory -Force 
    }
    $script:childPath = New-Item -Path $containerPath -Name 'Child1' -ItemType File -Force
}

function GrantPrivilege
{
    Grant-Permission -Path $containerPath -Identity $group1 -Permission Read
    Grant-Permission -Path $childPath -Identity $user -Permission Read
}

function CheckNormalPermissions
{
    $perms = Get-Permission -Path $childPath
    if( -not ( $perms ) )
    {
        $script:failed = $true
        return
    }

    $group1Perms = $perms | Where-Object { $_.IdentityReference.Value -like "*\$group1" }
    if( $group1Perms )
    {
        $script:failed = $true
        return
    }

    $userPerms = $perms | Where-Object { $_.IdentityReference.Value -like "*\$user" }
    if( (-not ( $userPerms ) ) -or ( -not ( $userPerms -is [Security.AccessControl.FileSystemAccessRule]) ) )
    {
        $script:failed = $true
        return
    }
}

function CheckInheritedPermissions
{
    $perms = Get-Permission -Path $childPath -Inherited
    if( -not ( $perms ) )
    {
        $script:failed = $true
        return
    }
    
    $group1Perms = $perms | Where-Object { $_.IdentityReference.Value -like "*\$group1" }

    if( ( -not ( $group1Perms ) ) -or ( -not ( $group1Perms -is [Security.AccessControl.FileSystemAccessRule]) ) )
    {
        $script:failed = $true
        return
    }

    $userPerms = $perms | Where-Object { $_.IdentityReference.Value -like "*\$user" }
    if( ( -not ( $userPerms) ) -or ( -not ($userPerms -is [Security.AccessControl.FileSystemAccessRule]) ) )
    {
        $script:failed = $true
        return
    }
}

function CheckSpecificUserPermissions
{
    $perms = Get-Permission -Path $childPath -Identity $group1
    if( $perms )
    {
        $script:failed = $true
        return
    }

    $perms = @( Get-Permission -Path $childPath -Identity $user )
    if( -not ( $perms[0] -is [Security.AccessControl.FileSystemAccessRule] ) )
    {
        $script:failed = $true
        return
    }
}

function CheckPrivateCertPermission
{
    $foundPermission = $false
    Get-ChildItem -Path 'cert:\*\*' -Recurse |
        Where-Object { -not $_.PsIsContainer } |
        Where-Object { $_.HasPrivateKey } |
        Where-Object { $_.PrivateKey } |
        ForEach-Object { Join-Path -Path 'cert:' -ChildPath (Split-Path -NoQualifier -Path $_.PSPath) } |
        ForEach-Object { Get-Permission -Path $_ } |
        ForEach-Object {
            $foundPermission = $true
            if( (-not $_) -and ( $_ -isNot [Security.AccessControl.CryptoKeyAccessRule]) )
            {
                $script:failed = $true
                return
            }
        }
    if( -not $foundPermission )
    {
        $script:failed = $false
        return
    }
}

function CheckSpecificInheritedUserPermissions
{
    $perms = Get-Permission -Path $childPath -Identity $group1 -Inherited
    if( ( -not $perms ) -or ( -not ( $perms -is [Security.AccessControl.FileSystemAccessRule] ) ) )
    {
        $script:failed = $true
        return
    }
}

function CheckSpecificIdentityCertPermission
{
    Get-ChildItem -Path 'cert:\*\*' -Recurse |
    Where-Object { -not $_.PsIsContainer } |
    Where-Object { $_.HasPrivateKey } |
    Where-Object { $_.PrivateKey } |
    ForEach-Object { Join-Path -Path 'cert:' -ChildPath (Split-Path -NoQualifier -Path $_.PSPath) } |
    ForEach-Object { 
        [object[]]$rules = Get-Permission -Path $_
        foreach( $rule in $rules )
        {
            [object[]]$identityRule = Get-Permission -Path $_ -Identity $rule.IdentityReference.Value
            if( (-not $identityRule) -or ( $identityRule.Count -ge $rules.Count ) )
            {
                $script:failed = $true
                return
            }
        }
    }
}

function ThenPermissionGranted
{
    $script:failed | Should -BeFalse
    $Global:Error | Should -BeNullOrEmpty
}

function ThenPermissionDenied
{
    param(
        $WithErrorThatMatches
    )

    $failed | Should -BeTrue
    $Global:Error | Should -not -BeNullOrEmpty
    $Global:Error | Should -Match $WithErrorThatMatches
}

Describe 'GetPermission.when given permission information' {
    It 'should grant permission as expected' {
        Init
        InstallUserandGroup
        SetUpPath
        GrantPrivilege
        CheckNormalPermissions
        ThenPermissionGranted
    }
}

Describe 'GetPermission.when given inherited permissions' {
    It 'should give correct inherited permissions' {
        Init
        InstallUserandGroup
        SetUpPath
        GrantPrivilege
        CheckInheritedPermissions
        ThenPermissionGranted
    }
}

Describe 'GetPermission.when attempting to give specific user permissions' {
    It 'should give correct inherited permissions' {
        Init
        InstallUserandGroup
        SetUpPath
        GrantPrivilege
        CheckSpecificUserPermissions
        ThenPermissionGranted
    }
}

Describe 'GetPermission.when attempting to give specific inherited user permissions' {
    It 'should give correct inherited permissions' {
        Init
        InstallUserandGroup
        SetUpPath
        GrantPrivilege
        CheckSpecificInheritedUserPermissions
        ThenPermissionGranted
    }
}
Describe 'GetPermission.when attempting to give private certificate permission permissions' {
    It 'should give permission' {
        Init
        InstallUserandGroup
        SetUpPath
        GrantPrivilege
        CheckPrivateCertPermission
        ThenPermissionGranted
    }
}
Describe 'GetPermission.when attempting to give a specific identity certificate permissions' {
    It 'should give permission' {
        Init
        InstallUserandGroup
        SetUpPath
        GrantPrivilege
        CheckSpecificIdentityCertPermission
        ThenPermissionGranted
    }
}