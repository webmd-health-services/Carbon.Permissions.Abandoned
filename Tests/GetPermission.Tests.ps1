
#Requires -Version 5.1
Set-StrictMode -Version 'Latest'

& (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Test.ps1' -Resolve)

$failed = $false
$user = 'CarbonTestUser1'
$testGroup = 'CarbonTestGroup1'
$password = 'a1z2b3y4!'
$testCredentials = New-Credential -Username $user -Password $password
$containerPath = $null
$childPath = $null
$testFile = $null

function Init
{
    $Global:Error.Clear()
    $script:failed = $false
    $script:containerPath = $null
    $script:childPath = $null
    $script:testFile = $null
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

function GivenGroup
{
    param(
        [Parameter(Mandatory=$true)]
        [String]$Group,

        [String]$Description
    )
    Install-Group -Name $Group -Description $Description
}

function GivenPathTo
{
    param(
        [Parameter(Mandatory=$true)]
        [String]$Item
    )
    $script:containerPath = 'Carbon-Test-GetPermissions-{0}' -f ([IO.Path]::GetRandomFileName())
    $script:containerPath = Join-Path -Path $TestDrive -ChildPath $containerPath

    if( -not ( Test-Path $containerPath ) )
    {
        New-Item -Path $containerPath -ItemType Directory -Force 
    }

    $script:testFile = New-Item -Path $containerPath `
                                -Name -$Item `
                                -ItemType File `
                                -Force

    $script:childPath = $testFile
}

function WhenGrantingPermission
{
    param(
        [Parameter(Mandatory=$true)]
        [String]$Permission,

        [Parameter(Mandatory=$true)]
        [String]$To,

        [Parameter(Mandatory=$true)]
        [String]$On
    )
    try
    {
        Grant-Permission -Path $On `
                         -Identity $To `
                         -Permission $Permission
    }
    catch
    {
        $script:failed = $true
    }
}

function ThenGrantedPermission
{
    param(

        [Parameter(Mandatory=$true)]
        [String]$Permission,
    
        [Parameter(Mandatory=$true)]
        [String]$To,
    
        [Parameter(Mandatory=$true)]
        [String]$On,

        [Switch]$Inherited
    )

    $perms = Get-Permission -Path $On `
                            -Identity $To `
                            -Inherited:$Inherited

    if( -not ( $perms ) )
    {
        $script:failed = $true
        return
    }

    $checkPerms = $perms | Where-Object { $_.IdentityReference.Value -like "*\$($To)" }
    
    if( (-not ( $checkPerms ) ) -or ( -not ( $checkPerms.FileSystemRights -Match $Permission ) ) -or ( -not ( $checkPerms -is [Security.AccessControl.FileSystemAccessRule]) ) )
    {
        $script:failed = $true
        return
    }
}


function CheckSpecificUserPermissions
{
    $perms = Get-Permission -Path $childPath -Identity $testGroup
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
    $perms = Get-Permission -Path $childPath -Identity $testGroup -Inherited
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
function ThenTestPassed
{
    $script:failed | Should -BeFalse
    $Global:Error | Should -BeNullOrEmpty
}

function ThenTestFailed
{
    $failed | Should -BeTrue
}

Describe 'GetPermission.when given a user that has been given correct permissions.' {
    It 'should grant the permission as expected.' {
        Init
        GivenUser -User $testCredentials -Description 'User to test credentials.'
        GivenPathTo -Item "test.txt"
        WhenGrantingPermission -Permission 'Read' -To $testCredentials.Username -On $testFile
        ThenGrantedPermission -Permission 'Read' -To $testCredentials.Username -On $testFile
        ThenTestPassed
    }
}
Describe 'GetPermission.when given a user that not been given permission to a file.' {
    It 'should not return true.' {
        Init
        GivenUser -User $testCredentials -Description 'User to test credentials.'
        GivenPathTo -Item "test.txt"
        WhenGrantingPermission -Permission 'Read' -To $testCredentials.Username -On $testFile
        ThenGrantedPermission -Permission 'Write' -To $testCredentials.Username -On $testFile
        ThenTestFailed
    }
}

Describe 'GetPermission.when given a group that has been given correct permissions.' {
    It 'should grant permission as expected. ' {
        Init
        GivenGroup -Group $testGroup -Description 'Group to test credentials.'
        GivenPathTo -Item "test.txt"
        WhenGrantingPermission -Permission 'Read' -To $testGroup -On $testFile
        ThenGrantedPermission -Permission 'Read' -To $testGroup -On $testFile
        ThenTestPassed
    }
}

Describe 'GetPermission.when given a group that has not been given correct permissions.' {
    It 'should not return true. ' {
        Init
        GivenGroup -Group $testGroup -Description 'Group to test credentials.'
        GivenPathTo -Item "test.txt"
        WhenGrantingPermission -Permission 'Read' -To $testGroup -On $testFile
        ThenGrantedPermission -Permission 'Write' -To $testGroup -On $testFile
        ThenTestFailed
    }
}

Describe 'GetPermission.when given a user that has been given inherited permissions.' {
    It 'should grant the permission as expected.' {
        Init
        GivenUser -User $testCredentials -Description 'User to test credentials.'
        GivenPathTo -Item "test.txt"
        WhenGrantingPermission -Permission 'Read' -To $testCredentials.Username -On $testFile
        ThenGrantedPermission -Permission 'Read' -To $testCredentials.Username -On $testFile -Inherited
        ThenTestPassed
    }
}
Describe 'GetPermission.when given a group that has been given correct permissions.' {
    It 'should grant permission as expected. ' {
        Init
        GivenGroup -Group $testGroup -Description 'Group to test credentials.'
        GivenPathTo -Item "test.txt"
        WhenGrantingPermission -Permission 'Read' -To $testGroup -On $testFile
        ThenGrantedPermission -Permission 'Read' -To $testGroup -On $testFile
        ThenTestPassed
    }
}


Describe 'GetPermission.when attempting to give specific user permissions.' {
    It 'should give correct inherited permissions.' {
        Init
        GivenUser -User $testCredentials -Description 'User to test credentials.'
        GivenGroup -Group $testGroup -Description 'Group to test credentials.'
        GivenPathTo -Item "test.txt"
        WhenGrantingPermission -Permission 'Read' -To $testCredentials.Username -On $testFile
        ThenGrantedPermission -Permission 'Read' -To $testCredentials.Username -On $testFile
        CheckSpecificUserPermissions
        ThenTestPassed
    }
}

Describe 'GetPermission.when attempting to give specific inherited group permissions.' {
    It 'should give correct inherited permissions' {
        Init
        GivenGroup -Group $testGroup -Description 'Group to test credentials.'
        GivenPathTo -Item "test.txt"
        WhenGrantingPermission -Permission 'Read' -To $testGroup -On $testFile
        ThenGrantedPermission -Permission 'Read' -To $testGroup -On $testFile -Inherited
        CheckSpecificInheritedUserPermissions
        ThenTestPassed
    }
}
Describe 'GetPermission.when attempting to give private certificate permission permissions' {
    It 'should give permission' {
        Init
        GivenUser -User $testCredentials -Description 'User to test credentials.'
        GivenPathTo -Item "test.txt"
        WhenGrantingPermission -Permission 'Read' -To $testCredentials.Username -On $testFile
        CheckSpecificUserPermissions
        CheckPrivateCertPermission
        ThenTestPassed
    }
}
Describe 'GetPermission.when attempting to give a specific identity certificate permissions' {
    It 'should give permission' {
        Init
        GivenUser -User $testCredentials -Description 'User to test credentials.'
        GivenPathTo -Item "test.txt"
        WhenGrantingPermission -Permission 'Read' -To $testCredentials.Username -On $testFile
        CheckSpecificIdentityCertPermission
        ThenTestPassed
    }
}