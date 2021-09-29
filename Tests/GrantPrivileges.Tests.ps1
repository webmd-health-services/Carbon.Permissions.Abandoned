
#Requires -Version 5.1
Set-StrictMode -Version 'Latest'

& (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Test.ps1' -Resolve)

$failed = $false
$servicePath = Join-Path -Path $PSScriptRoot -ChildPath '\Functions\Service\NoOpService.exe' -Resolve
$testCredentials = New-Credential -Username 'CarbonGrantPrivilege' -Password 'a1b2c3d4e5#!'

function Init
{
    $Global:Error.Clear()
    $script:failed = $false
}

function Reset
{
    Uninstall-User -Username 'CarbonGrantPrivilege'
}

function GivenUser
{
    param(
        [Parameter(Mandatory=$true)]
        [System.Management.Automation.PSCredential]$User,

        [String]$Description
    )
    Install-User -Credential $User -Description $Description
}

function GivenService
{
    param(
        [Parameter(Mandatory=$true)]
        [String]$Service,

        [Parameter(Mandatory=$true)]
        [String]$Path,

        [Parameter(Mandatory=$true)]
        [String]$StartupType,

        [Parameter(Mandatory=$true)]
        [System.Management.Automation.PSCredential]$User
    )
    try 
    {
        Install-Service -Name $Service `
                        -Path $Path `
                        -StartupType $StartupType `
                        -Credential $User
    }
    catch 
    {
       $script:failed = $true 
    }
}


function StartService
{
    param(
        [Parameter(Mandatory=$true)]
        [String]$Service

    )
    Start-Service -Name $Service
}
function StopService
{
    param(
        [Parameter(Mandatory=$true)]
        [String]$Service
    )
    Stop-Service $Service
}

function WhenGrantingPrivilege
{
    param(
        [Parameter(Mandatory=$true)]
        [String]$Privilege,

        [Parameter(Mandatory=$true)]
        [String]$To
    )
    try
    {
        Grant-Privilege -Identity $To `
                        -Privilege $Privilege
    }
    catch
    {
        $script:failed = $true
    }
}

function WhenRevokingPrivilege
{
    param(
        [Parameter(Mandatory=$true)]
        [String]$Privilege,

        [Parameter(Mandatory=$true)]
        [String]$To
    )
    try
    {
        Revoke-Privilege -Identity $To -Privilege $Privilege
    }
    catch
    {
        $script:failed = $true
    }
}

function ThenPrivilegeGranted
{
    param(
        [Parameter(Mandatory=$true)]
        [String]$Privilege,

        [Parameter(Mandatory=$true)]
        [String]$To
    )

    Test-Privilege -Identity $To -Privilege $Privilege | Should -BeTrue
    Get-Privilege -Identity $To | Where-Object { $_ -eq $Privilege } | Should -Not -BeNullOrEmpty
}


function ThenPrivilegeRevoked
{
    param(
        [Parameter(Mandatory=$true)]
        [String]$Privilege,

        [Parameter(Mandatory=$true)]
        [String]$To
    )

    Test-Privilege -Identity $To -Privilege $Privilege | Should -BeFalse
    Get-Privilege -Identity $To | Where-Object { $_ -eq $Privilege } | Should -BeNullOrEmpty
}

Describe 'GrantPrivileges.when privilege of service is granted to user.' {
    AfterEach { Reset }
    It 'should return that privilege has been granted.' {
        Init
        GivenUser -User $testCredentials -Description "Account to test Privileges."
        GivenService -Service 'CarbonGrantPrivilegeTest' -Path $servicePath -StartupType 'Manual' -User $testCredentials
        WhenGrantingPrivilege -Privilege 'SeBatchLogonRight' -To 'CarbonGrantPrivilege'
        ThenPrivilegeGranted -Privilege 'SeBatchLogonRight' -To 'CarbonGrantPrivilege'
    }
}

Describe 'GrantPrivileges.when granted privilege of service is revoked from user.' {
    AfterEach { Reset }
    It 'should return that privilege has been revoked.' {
        Init
        GivenUser -User $testCredentials -Description "Account to test Privileges."
        GivenService -Service 'CarbonGrantPrivilegeTest' -Path $servicePath -StartupType 'Manual' -User $testCredentials
        WhenGrantingPrivilege -Privilege 'SeBatchLogonRight' -To 'CarbonGrantPrivilege'
        WhenRevokingPrivilege -Privilege 'SeBatchLogonRight' -To 'CarbonGrantPrivilege'
        ThenPrivilegeRevoked -Privilege 'SeBatchLogonRight' -To 'CarbonGrantPrivilege'
    }
}

Describe 'GrantPrivileges.when service is stopped, privilege is revoked then granted.' {
    AfterEach { Reset }
    It 'should correctly execute through the chain of commands.' {
        Init
        GivenUser -User $testCredentials -Description "Account to test Privileges."
        GivenService -Service 'CarbonGrantPrivilegeTest' -Path $servicePath -StartupType Manual -User $testCredentials
        StopService 'CarbonGrantPrivilegeTest'
        WhenRevokingPrivilege -Privilege 'SeBatchLogonRight' -To 'CarbonGrantPrivilege'
        ThenPrivilegeRevoked -Privilege 'SeBatchLogonRight' -To 'CarbonGrantPrivilege'
        WhenGrantingPrivilege -Privilege 'SeBatchLogonRight' -To 'CarbonGrantPrivilege'
        ThenPrivilegeGranted -Privilege 'SeBatchLogonRight' -To 'CarbonGrantPrivilege'
    }
}

Describe 'GrantPrivileges.when identity is not found.' {
    It 'should write an error and not provide privilege to user.' {
        Init
        GivenUser -User $testCredentials -Description "Account to test Privileges."
        GivenService -Service 'CarbonGrantPrivilegeTest' -Path $Path -StartupType Manual -User $testCredentials
        { Grant-Privilege -Identity 'IDONOTEXIST' -Privilege 'SeBatchLogonRight' -ErrorAction Stop } |
            Should -Throw "Identity 'IDONOTEXIST' not found"
    }
}

Describe 'GrantPrivileges.when name of privilege is given as UPPERCASE.' {
    It 'should write an error and not provide privilege to user.' {
        Init
        GivenUser -User $testCredentials -Description "Account to test Privileges."
        GivenService -Service 'CarbonGrantPrivilegeTest' -Path $Path -StartupType Manual -User $testCredentials
        { Grant-Privilege -Identity 'CarbonGrantPrivilege' -Privilege 'SESERVICELOGONRIGHT' -ErrorAction Stop } |
            Should -Throw "Failed to grant 04-PF2TDC14\CarbonGrantPrivilege SESERVICELOGONRIGHT privilege(s): No such privilege. Indicates a specified privilege does not exist.  *Privilege names are **case-sensitive**.*"
    }
}