
#Requires -Version 5.1
Set-StrictMode -Version 'Latest'

& (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Test.ps1' -Resolve)

$testCredentials = New-CCredential -UserName "CarbonGrantPrivilege" -Password "a1b2c3d34#"
$serviceName = 'CarbonGrantPrivilege'
#$servicePath = Join-Path $TestDir ..\Service\NoOpService.exe -Resolve

function InstallUser
{
    Install-CUser -Credential $testCredentials -Description 'Account for testing Carbon Grant-Privileges functions.'
    #Install-CUser -Username $username -Password $password -Description 'Account for testing Carbon Grant-Privileges functions.'
}
function UninstallUser
{
    Uninstall-CUser -Credential $testCredentials
    #Uninstall-CUser -Username $username
}

function InstallService
{
    Install-CService -Name $serviceName 
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