
#Requires -Version 5.1
Set-StrictMode -Version 'Latest'

& (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Test.ps1' -Resolve)

Import-Module -Name 'Carbon' 

$CarbonTestUser = New-Credential 'CarbonTestUser' -Password 'Tt6QM1lmDrFSf'
$script:failed = $false
$tempDir = $null
$identity = $null
$dirPath = $null
$filePath = $null
$tempKeyPath = $null
$keyPath = $null
$childKeyPath = $null
$privateKeypath = Join-Path -Path $PSScriptRoot `
                            -ChildPath '\Functions\Cryptography\CarbonTestPrivateKey.pfx' `
                            -Resolve

function Init
{
    $script:identity = $CarbonTestUser.UserName
    $script:dirPath = New-Item -Path $TestDrive -ItemType Directory -Name 'Directory' -Force
    $null = New-Item -Path $dirPath -ItemType 'File' -Name 'File1'
    $script:filePath = Join-Path -Path $dirPath -ChildPath 'File1'
    $script:tempKeyPath = 'hkcu:\Software\Carbon\Test'
    $script:keyPath = Join-Path -Path $tempKeyPath -ChildPath 'Test-Permission'
    Install-RegistryKey -Path $keyPath
    $script:childKeyPath = Join-Path -Path $keyPath -ChildPath 'ChildKey'
}

function Reset
{
    $Global:Error.Clear()
    $script:failed = $false
    $script:dirPath = $null
    $script:filePath = $null
    $script:tempKeyPath = $null
    $script:keyPath = $null
    $script:childKeyPath = $null
}

function GivenUser
{
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$User,

        [String]$Description
    )
    Install-User -Credential $User -Description $Description
}

function WhenGrantingPermission
{
    param(
        [Parameter(Mandatory)]
        [String]$Permission,

        [Parameter(Mandatory)]
        [String]$To,

        [Parameter(Mandatory)]
        [String]$On,

        [Parameter(Mandatory)]
        [String]$ApplyTo
    )

    try
    {
        Grant-Permission -Path $On `
                         -Identity $To `
                         -Permission $Permission `
                         -ApplyTo $ApplyTo
    }
    catch
    {
        $script:failed = $true
    }
}
function CreateTempDirectoryTree
{
    Grant-Permission -Identity $identity `
                     -Permission ReadAndExecute `
                     -Path $dirPath `
                     -ApplyTo 'ChildLeaves'

    Grant-Permission -Identity $identity `
                     -Permission 'ReadKey','WriteKey' `
                     -Path $keyPath `
                     -ApplyTo 'ChildLeaves'
}

function TestExistingPath
{
    if ( -not (Test-Permission -Path $dirPath `
                               -Identity $identity `
                               -Permission 'FullControl') )
    {
        $script:failed = $true
    }
}

function TestPermission
{
    param(

        [Parameter(Mandatory)]
        [String]$givenPath,

        [Parameter(Mandatory)]
        [String]$givenIdentity,

        [Parameter(Mandatory)]
        [String]$givenPermission,

        [Switch]$Exact,

        [Switch]$Inherited
    )

    if ( -not ( Test-Permission -Path $givenPath `
                                -Identity $givenIdentity `
                                -Permission $givenPermission `
                                -Exact:$Exact `
                                -Inherited:$Inherited ) )
    {
        $script:failed = $true
    }
}

function TestPermissionOnPrivateKey
{
    param(
        [Parameter(Mandatory)]
        [String]$Identity
    )

    $cert = Install-Certificate -Path $privateKeyPath `
                                -StoreLocation LocalMachine `
                                -StoreName My 

    try 
    {
        $certPath = Join-Path -Path 'cert:\LocalMachine\My' -ChildPath $cert.Thumbprint

        Grant-Permission -Path $certPath `
                         -Identity $Identity `
                         -Permission 'GenericAll'

        TestPermission -givenPath $certPath `
                       -givenIdentity $Identity `
                       -givenPermission 'GenericRead'

        TestPermission -givenPath $certPath `
                       -givenIdentity $Identity `
                       -givenPermission 'GenericAll'
    }
    finally
    {
        Uninstall-Certificate -Thumbprint $cert.Thumbprint `
                              -StoreLocation LocalMachine `
                              -StoreName My
    }
}

function TestPermissiononPublicKey
{
    param(
        [Parameter(Mandatory)]
        [String]$Identity
    )

    $cert = Get-ChildItem 'cert:\*\*' -Recurse | 
            Where-Object { -not $_.HasPrivateKey} |
            Select-Object -First 1
    
    $certPath = Join-Path -Path 'cert:\' -ChildPath (Split-Path -NoQualifier -Path $cert.PSPath)

    if((-not $cert ) -or ( -not $certPath ))
    {
        $script:failed = $true
        return
    }

    TestPermission -givenPath $certPath `
                   -givenIdentity $Identity `
                   -givenPermission 'FullControl'

    TestPermission -givenPath $certPath `
                   -givenIdentity $Identity `
                   -givenPermission 'FullControl' `
                   -Exact
}

function ThenTestsPassed
{
    $script:failed | Should -BeFalse
    $Global:Error | Should -BeNullOrEmpty
}

function ThenTestsFailed
{
    $script:failed | Should -BeTrue
}

Describe 'TestPermission.when given an existing path and a valid identity with correct permissions.' {
    AfterEach { Reset }
    It 'should work as expected.' {
        Init
        GivenUser -User $CarbonTestUser -Description 'User to test TestPermission.'
        WhenGrantingPermission -Permission 'FullControl' -To $identity -On $dirPath -ApplyTo 'ChildLeaves'
        WhenGrantingPermission -Permission 'FullControl' -To $identity -On $keyPath -ApplyTo 'ChildLeaves'
        TestPermission -givenPath $dirPath -givenIdentity $identity -givenPermission 'FullControl'
        ThenTestsPassed
    }
}

Describe 'TestPermission.when given an existing path and a valid identity with incorrect permissions.' {
    AfterEach { Reset }
    It 'should not return true.' {
        Init
        CreateTempDirectoryTree
        TestPermission -givenPath $dirPath -givenIdentity $identity -givenPermission 'Write'
        ThenTestsFailed
    }
}

Describe 'TestPermission.when given non-existing path and a valid identity and permissions.' {
    AfterEach { Reset }
    It 'should throw path not found error.' {
        Init
        CreateTempDirectoryTree
        { Test-Permission -Path 'C:I\Do\Not\Exist' -Identity $identity -Permission 'FullControl' -ErrorAction Stop } |
            Should -Throw "Unable to test CarbonTestUser's FullControl permissions: path 'C:I\Do\Not\Exist' not found."
    }
}
Describe 'TestPermission.when given an existing path and a valid identity with correct exact permissions.' {
    AfterEach { Reset }
    It 'should not return true. ' {
        Init
        CreateTempDirectoryTree
        TestPermission -givenPath $dirPath -givenIdentity $identity -givenPermission 'ReadAndExecute' -Exact
        ThenTestsPassed
    }
}
Describe 'TestPermission.when given an existing path and a valid identity with improper exact permissions.' {
    AfterEach { Reset }
    It 'should not return true. ' {
        Init
        CreateTempDirectoryTree
        TestPermission -givenPath $dirPath -givenIdentity $identity -givenPermission 'Read' -Exact
        ThenTestsFailed
    }
}

Describe 'TestPermission.when given inherited permission without inheritance flag.' {
    AfterEach { Reset }
    It 'should return true. ' {
        Init
        CreateTempDirectoryTree
        TestPermission -givenPath $filePath -givenIdentity $identity -givenPermission 'ReadAndExecute' -Inherited -Exact
        ThenTestsPassed
    }

}
Describe 'TestPermission.when given inherited permission without inheritance flag.' {
    AfterEach { Reset }
    It 'should exclude inherited permission and fail.' {
        Init 
        CreateTempDirectoryTree
        TestPermission -givenPath $filePath -givenIdentity $identity -givenPermission 'ReadAndExecute' -Exact
        ThenTestsFailed
    }
}
Describe 'TestPermission.when given inheritance and propagation flags on file. ' {
    AfterEach { Reset }
    It 'should ignore flags and issue warning. '{
        Init
        CreateTempDirectoryTree
        { Test-Permission -givenPath $filePath -givenIdentity $identity -givenPermission 'ReadAndExecute' -Exact -ApplyTo SubContainers -WarningVariable 'warning' -WarningAction SilentlyContinue}
        ThenTestsPassed
    }
}
Describe 'TestPermission.when given ungranted permission on registry. ' {
    AfterEach { Reset }
    It 'should return false. ' {
        Init
        CreateTempDirectoryTree
        TestPermission -givenPath $keyPath -givenIdentity $identity -givenPermission 'Delete'
        ThenTestsFailed
    }
}
Describe 'TestPermission.when checking correct granted permission on registry. ' {
    AfterEach { Reset }
    It 'should return true. ' {
        Init
        CreateTempDirectoryTree
        TestPermission -givenPath $keyPath -givenIdentity $identity -givenPermission 'ReadKey'
        ThenTestsPassed
    }
}

Describe 'TestPermission.when checking exact correct permissions on registry. ' {
    AfterEach { Reset }
    It 'should return true. ' {
        Init
        CreateTempDirectoryTree
        { Test-Permission -Path $keyPath -Identity $identity -Permission 'ReadKey','WriteKey' -Exact } |
            Should -BeTrue
    }
}

Describe 'TestPermission.when checking granted inheritance flags. ' {
    AfterEach { Reset }
    It 'should return true. ' {
        Init
        CreateTempDirectoryTree
        { Test-Permission -Path $dirPath -Identity $identity -Permission 'ReadAndExecute' -ApplyTo ContainerandLeaves }| Should -BeTrue
        { Test-Permission -Path $dirPath -Identity $identity -Permission 'ReadAndExecute' -ApplyTo ChildLeaves } | 
            Should -BeTrue
    }
}

Describe 'TestPermission.when checking granted exact inheritance flags. ' {
    AfterEach { Reset }
    It 'should return true. ' {
        Init 
        CreateTempDirectoryTree
        { Test-Permission -path $dirPath -Identity $identity -Permission 'ReadAndExecute' -ApplyTo ChildLeaves -Exact -ErrorAction Stop} |
            Should -BeTrue
    }
}

Describe 'TestPermission.when checking permission on a private key with correct permissions. ' { 
    AfterEach { Reset }
    It 'should return true. ' {
        Init
        CreateTempDirectoryTree
        TestPermissionOnPrivateKey -Identity $identity
        ThenTestsPassed
    }
}

Describe 'TestPermission.when checking permission on a public key with correct permissions. ' { 
    AfterEach { Reset }
    It 'should return true. ' {
        Init
        CreateTempDirectoryTree
        TestPermissionOnPublicKey -Identity $identity
        ThenTestsPassed
    }
}