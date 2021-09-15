
#Requires -Version 5.1
Set-StrictMode -Version 'Latest'

& (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Test.ps1' -Resolve)

$failed = $false
$serviceName = 'CarbonGrantPrivilegeTest'
$servicePath = Join-Path -Path $PSScriptRoot -ChildPath 'Service\NoOpService.exe' -Resolve
$testCredentials = New-Credential -Username "CarbonGrantPrivilege" -Password "a1b2c3d4e5#!"
$invalidIdentity = "IDONOTEXIST"
$privilege = "SeBatchLogonRight"
$invalidPrivilege = "SESERVICELOGONRIGHT"


function Init
{
    $Global:Error.Clear()
    $script:failed = $false
}

function Reset
{
    Uninstall-User -Username $testCredentials.UserName
}

function InstallUser
{
    Install-User -Credential $testCredentials `
                 -Description 'Account for testing Carbon Grant-Privileges functions.'
}

function InstallService
{
    Install-Service  -Name $serviceName `
                     -Path $servicePath `
                     -StartupType Manual `
                     -Credential $testCredentials
}

function GrantPrivilege
{
    param(
        [String]$givenIdentity,

        [String]$givenPrivilege
    )

    if ( -not (Grant-Privilege -Identity $givenIdentity -Privilege $givenPrivilege -ErrorAction SilentlyContinue) )
    {
        $script:failed = $true
        $failed = $true
    }

}

function RevokePrivilege
{
    Revoke-Privilege -Identity $testCredentials.UserName `
                     -Privilege SeServiceLogonRight
}

function ThenPermissionGranted
{
    $failed | Should -BeFalse
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

Describe 'GrantPrivileges.when privilege of service is granted to user' {
    It 'should grant permission to the user' {
        Init
        InstallUser
        InstallService
        { Grant-Privilege -Identity $testCredentials.UserName -Privilege $privilege -ErrorAction Stop }
        ThenPermissionGranted
        Reset
    }
}

Describe 'GrantPrivileges.when identity is not found' {
    It 'should write an error and not grant permission to user' {
        Init
        InstallUser
        InstallService
        { Grant-Privilege -Identity $invalidIdentity -Privilege $privilege -ErrorAction Stop } |
            Should -Throw "Identity 'IDONOTEXIST' not found"
    }
}

Describe 'GrantPrivileges.when name of privilege is given as UPPERCASE' {
    It 'should write an error an not grant permission to user' {
        Init
        InstallUser
        InstallService
        { Grant-Privilege -Identity $testCredentials.UserName -Privilege $invalidPrivilege -ErrorAction Stop } |
            Should -Throw "Failed to grant 04-PF2TDC14\CarbonGrantPrivilege SESERVICELOGONRIGHT privilege(s): No such privilege. Indicates a specified privilege does not exist.  *Privilege names are **case-sensitive**.*"
    }
}