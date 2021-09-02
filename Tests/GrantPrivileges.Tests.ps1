
#Requires -Version 5.1
Set-StrictMode -Version 'Latest'

& (Join-Path -Path $PSScriptRoot -ChildPath '\Initialize-Test.ps1' -Resolve)

$username = 'CarbonGrantPrivilege'
$password = 'a1b2c3d4#'
$serviceName = 'CarbonGrantPrivilege'
$servicePath = Join-Path $TestDir ..\Service\NoOpService.exe -Resolve

function InstallUser
{
    Install-User -Username $username -Password $password -Description 'Account for testing Carbon Grant-Privileges functions.'
}
function UninstallUser
{
    Uninstall-User -Username $username
}

function InstallService
{
    Install-Service -Name $serviceName 
                    -Path $servicePath 
                    -StartupType Manual 
                    -Username $username 
                    -Password $password
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
    Grant-Privilege -Identity $username -Privilege SeServiceLogonRight
}

function RevokePrivilege
{
    Revoke-Privilege -Identity $username -Privilege SeServiceLogonRight
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