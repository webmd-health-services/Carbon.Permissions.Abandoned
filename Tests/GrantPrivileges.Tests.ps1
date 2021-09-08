
#Requires -Version 5.1
Set-StrictMode -Version 'Latest'

& (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Test.ps1' -Resolve)

$testCredentials = New-Credential -Username "CarbonGrantPrivilege" -Password "a1b2c3d4e5#!"
$serviceName = 'CarbonGrantPrivilegeTest'
$servicePath = Join-Path -Path $PSScriptRoot -ChildPath 'Service\NoOpService.exe' -Resolve

function InstallUser
{
    Install-User -Credential $testCredentials 
                 -Description 'Account for testing Carbon Grant-Privileges functions.'
}
function UninstallUser
{
    Uninstall-User -Credential $testCredentials
}

function InstallService
{
    Install-Service  -Name $serviceName 
                     -Path $servicePath
                     -StartupType Manual 
                     -Credential $testCredentials
}

function StartService
{
    Start-Service $serviceName
}

function StopService
{
    Stop-Service $serviceName
}

function GrantPrivilege
{
    Grant-Privilege -Identity $testCredentials.UserName -Privilege SeServiceLogonRight
}

function RevokePrivilege
{
    Revoke-Privilege -Identity $testCredentials.UserName -Privilege SeServiceLogonRight
}

function ThenPermissionGranted
{
    $failed | Should -BeFalse
    $Global:Error | Should -BeNullOrEmpty
}

Describe 'GrantPrivileges.when privilege of service is granted to user' {
    It 'should grant permission to the user'{
        InstallUser
        InstallService
        GrantPrivilege
        ThenPermissionGranted
    }
}