
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

function TestNonExistentPath
{
    if ( -not (Test-Permission -path 'C:I\Do\Not\Exist' -Identity $identity -Permission 'FullControl' -ErrorAction SilentlyContinue))
    {
        $script:failed = $false
    }
    else 
    {
        $script:failed = $true
    }
}

function CheckUngrantedPermissionOnFileSystem
{
    if(Test-Permission -Path $dirPath -Identity $identity -Permission 'Write')
    {
        $script:failed = $true
    }
}

function ThenTestsPassed
{
    $script:failed | Should -BeFalse
    $Global:Error | Should -BeNullOrEmpty
}


Describe 'TestPermission.when test' {
    It 'should pass in theory' {
        Init
        CreateTempDirectoryTree
        #TestNonExistentPath
        CheckUngrantedPermissionOnFileSystem
        ThenTestsPassed
    }
}