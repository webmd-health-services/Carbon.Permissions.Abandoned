
#Requires -Version 5.1
Set-StrictMode -Version 'Latest'

& (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Test.ps1' -Resolve)
. (Join-Path -Path $PSScriptRoot -ChildPath '\Functions\TempDirectory\New-TempDirectoryTree.ps1' -Resolve)

$CarbonTestUser = New-Credential 'CarbonTestUser' -Password 'Tt6QM1lmDrFSf'
$tempDir = $null
$identity = $null
$dirPath = $null
$filePath = $null
$tempKeyPath = $null
$keyPath = $null
$childKeyPath = $null
$privateKeypath = Join-Path -Path $PSScriptRoot -ChildPath '\Functions\Cryptography\CarbonTestPrivateKey.pfx' -Resolve


function Init
{
    $Global:Error.Clear()
    $script:identity = $CarbonTestUser.UserName
    $script:failed = $false
    $script:dirPath = $null
    $script:filePath = $null
    $script:tempKeyPath = $null
    $script:keyPath = $null
    $script:childKeyPath = $null
}

function CreateTempDirectoryTree
{
    $script:tempDir = New-TempDirectoryTree -Prefix 'Carbon-Test-TestPermission' @'
+ Directory
  * File
'@
    $script:dirPath = Join-Path -Path $tempDir -ChildPath 'Directory'
    $script:filePath = Join-Path -Path $dirPath -ChildPath 'File'
    $script:tempKeyPath = 'hkcu:\Software\Carbon\Test'
    $script:keyPath = Join-Path -Path $tempKeyPath -ChildPath 'Test-Permission'
    Grant-Permission -Identity $identity -Permission ReadAndExecute -Path $dirPath -ApplyTo 'ChildLeaves'

    Install-RegistryKey -Path $keyPath
    $script:childKeyPath = Join-Path -Path $keyPath -ChildPath 'ChildKey'
    Grant-Permission -Identity $identity -Permission 'ReadKey','WriteKey' -Path $keyPath -ApplyTo 'ChildLeaves'
}

function TestExistingPath
{
    if ( -not (Test-Permission -Path $dirPath -Identity $identity -Permission 'FullControl') )
    {
        $script:failed = $true
    }
}

function TestPermission
{
    param(

        [Parameter(Mandatory=$true)]
        [String]$givenPath,

        [Parameter(Mandatory=$true)]
        [String]$givenIdentity,

        [Parameter(Mandatory=$true)]
        [String]$givenPermission,

        [Switch]$Exact,

        [Switch]$Inherited
    )

    if ( -not ( Test-Permission -Path $givenPath -Identity $givenIdentity -Permission $givenPermission -Exact:$Exact -Inherited:$Inherited ) )
    {
        $script:failed = $true
    }
}

function TestPermissionOnPrivateKey
{
    param(
        [Parameter(Mandatory=$true)]
        [String]$Identity
    )

    $cert = Install-Certificate -Path $privateKeyPath -StoreLocation LocalMachine -StoreName My 
    try 
    {
        $certPath = Join-Path -Path 'cert:\LocalMachine\My' -ChildPath $cert.Thumbprint
        Grant-Permission -Path $certPath -Identity $Identity -Permission 'GenericAll'

        TestPermission -givenPath $certPath `
                       -givenIdentity $Identity `
                       -givenPermission 'GenericRead'

        TestPermission -givenPath $certPath `
                       -givenIdentity $Identity `
                       -givenPermission 'GenericAll'
    }
    finally
    {
        Uninstall-Certificate -Thumbprint $cert.Thumbprint -StoreLocation LocalMachine -StoreName My
    }
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
    It 'should work as expected.' {
        Init
        CreateTempDirectoryTree
        TestPermission -givenPath $dirPath -givenIdentity $identity -givenPermission 'ReadAndExecute'
        ThenTestsPassed
    }
}

Describe 'TestPermission.when given an existing path and a valid identity with incorrect permissions.' {
    It 'should not return true.' {
        Init
        CreateTempDirectoryTree
        TestPermission -givenPath $dirPath -givenIdentity $identity -givenPermission 'Write'
        ThenTestsFailed
    }
}

Describe 'TestPermission.when given non-existing path and a valid identity and permissions.' {
    It 'should throw path not found error.' {
        Init
        CreateTempDirectoryTree
        { Test-Permission -Path 'C:I\Do\Not\Exist' -Identity $identity -Permission 'FullControl' -ErrorAction Stop } |
            Should -Throw "Unable to test CarbonTestUser's FullControl permissions: path 'C:I\Do\Not\Exist' not found."
    }
}
Describe 'TestPermission.when given an existing path and a valid identity with correct exact permissions.' {
    It 'should not return true. ' {
        Init
        CreateTempDirectoryTree
        TestPermission -givenPath $dirPath -givenIdentity $identity -givenPermission 'ReadAndExecute' -Exact
        ThenTestsPassed
    }
}
Describe 'TestPermission.when given an existing path and a valid identity with improper exact permissions.' {
    It 'should not return true. ' {
        Init
        CreateTempDirectoryTree
        TestPermission -givenPath $dirPath -givenIdentity $identity -givenPermission 'Read' -Exact
        ThenTestsFailed
    }
}

Describe 'TestPermission.when given inherited permission without inheritance flag.' {
    It 'should return true. ' {
        Init
        CreateTempDirectoryTree
        TestPermission -givenPath $filePath -givenIdentity $identity -givenPermission 'ReadAndExecute' -Inherited -Exact
        ThenTestsPassed
    }

}
Describe 'TestPermission.when given inherited permission without inheritance flag.' {
    It 'should exclude inherited permission and fail.' {
        Init 
        CreateTempDirectoryTree
        TestPermission -givenPath $filePath -givenIdentity $identity -givenPermission 'ReadAndExecute' -Exact
        ThenTestsFailed
    }
}
Describe 'TestPermission.when given inheritance and propagation flags on file. ' {
    It 'should ignore flags and issue warning. '{
        Init
        CreateTempDirectoryTree
        { Test-Permission -givenPath $filePath -givenIdentity $identity -givenPermission 'ReadAndExecute' -Exact -ApplyTo SubContainers -WarningVariable 'warning' -WarningAction SilentlyContinue}
        ThenTestsPassed
    }
}
Describe 'TestPermission.when given ungranted permission on registry. ' {
    It 'should return false. ' {
        Init
        CreateTempDirectoryTree
        TestPermission -givenPath $keyPath -givenIdentity $identity -givenPermission 'Delete'
        ThenTestsFailed
    }
}
Describe 'TestPermission.when checking correct granted permission on registry. ' {
    It 'should return true. ' {
        Init
        CreateTempDirectoryTree
        TestPermission -givenPath $keyPath -givenIdentity $identity -givenPermission 'ReadKey'
        ThenTestsPassed
    }
}

Describe 'TestPermission.when checking exact correct permissions on registry. ' {
    It 'should return true. ' {
        Init
        CreateTempDirectoryTree
        { Test-Permission -Path $keyPath -Identity $identity -Permission 'ReadKey','WriteKey' -Exact } |
            Should -BeTrue
    }
}

Describe 'TestPermission.when checking granted inheritance flags. ' {
    It 'should return true. ' {
        Init
        CreateTempDirectoryTree
        { Test-Permission -Path $dirPath -Identity $identity -Permission 'ReadAndExecute' -ApplyTo ContainerandLeaves } |
            Should -BeTrue
        { Test-Permission -Path $dirPath -Identity $identity -Permission 'ReadAndExecute' -ApplyTo ChildLeaves } | 
            Should -BeTrue
    }
}

Describe 'TestPermission.when checking granted exact inheritance flags. ' {
    It 'should return true. ' {
        Init 
        CreateTempDirectoryTree
        { Test-Permission -path $dirPath -Identity $identity -Permission 'ReadAndExecute' -ApplyTo ChildLeaves -Exact -ErrorAction Stop} |
            Should -BeTrue
    }
}

Describe 'TestPermission.when checking permission on a private key with correct permissions. ' { 
    It 'should return true. ' {
        Init
        CreateTempDirectoryTree
        TestPermissionOnPrivateKey -Identity $identity
        ThenTestsPassed
    }
}