
#Requires -Version 5.1
Set-StrictMode -Version 'Latest'

& (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Test.ps1' -Resolve)

$tempDir = New-TempDir
$identity = $null
$dirPath = $null
$filePath = $null
$tempKeyPath = $null
$keyPath = $null
$childKeyPath = $null
#$privateKeyPath = Join-Path -Path $PSScriptRoot -ChildPath '..\Cryptography\CarbonTestPrivateKey.pfx' -Resolve

function Init 
{
    #& (Join-Path -Path $tempDir -ChildPath '..\Initialize-Test.ps1' -Resolve)

    #$script:identity = $CarbonTestUser.UserName
    $tempDir = New-TempDirectoryTree -Prefix 'Carbon-Test-TestPermission' @'
+ Directory
  * File
'@

    $dirPath = Join-Path -Path $tempDir -ChildPath 'Directory'
    $filePath = Join-Path -Path $dirPath -ChildPath 'File'
    Grant-Permission -Identity $identity -Permission ReadAndExecute -Path $dirPath -ApplyTo 'ChildLeaves'

    $tempKeyPath = 'hkcu:\Software\Carbon\Test'
    $keyPath = Join-Path -Path $tempKeyPath -ChildPath 'Test-Permission'
    Install-RegistryKey -Path $keyPath
    $childKeyPath = Join-Path -Path $keyPath -ChildPath 'ChildKey'
    Grant-Permission -Identity $identity -Permission 'ReadKey','WriteKey' -Path $keyPath -ApplyTo 'ChildLeaves'
}

function Reset 
{
    Remove-Item -Path $tempDir -Recurse
    Remove-Item -Path $tempKeyPath -Recurs   
}

function ShouldHandleNonExistentPath
{
    $Error.Clear()
    Assert-Null (Test-Permission -path 'C:\I\Do\Not\Exist' -Identity $identity -Permission 'FullControl' -ErrorAction SilentlyContinue)
    Assert-Equal 2 $Error.Count
}
function ShouldCheckUngrantedPermissionOnFileSystem
{
    Assert-False (Test-Permission -Path $dirPath -Identity $identity -Permission 'Write')
}

function ShouldCheckGrantedPermissionOnFileSystem
{
    Assert-True (Test-Permission -Path $dirPath -Identity $identity -Permission 'Read')
}

function ShouldCheckExactPartialPermissionOnFileSystem
{
    Assert-False (Test-Permission -Path $dirPath -Identity $identity -Permission 'Read' -Exact)
}

function ShouldCheckExactPermissionOnFileSystem
{
    Assert-True (Test-Permission -Path $dirPath -Identity $identity -Permission 'ReadAndExecute' -Exact)
}

function ShouldExcludeInheritedPermission
{
    Assert-False (Test-Permission -Path $filePath -Identity $identity -Permission 'ReadAndExecute')
}

function ShouldIncludeInheritedPermission
{
    Assert-True (Test-Permission -Path $filePath -Identity $identity -Permission 'ReadAndExecute' -Inherited)
}

function ShouldExcludeInheritedPartialPermission
{
    Assert-False (Test-Permission -Path $filePath -Identity $identity -Permission 'ReadAndExecute' -Exact)
}

function ShouldIncludeInheritedExactPermission
{
    Assert-True (Test-Permission -Path $filePath -Identity $identity -Permission 'ReadAndExecute' -Inherited -Exact)
}

function ShouldIgnoreInheritanceAndPropagationFlagsOnFile
{
    $warning = @()
    Assert-True (Test-CPermission -Path $filePath -Identity $identity -Permission 'ReadAndExecute' -ApplyTo SubContainers -Inherited -WarningVariable 'warning' -WarningAction SilentlyContinue)
    Assert-NotNull $warning
    Assert-Like $warning[0] 'Can''t test inheritance/propagation rules on a leaf.*'
}

function ShouldCheckUngrantedPermissionOnRegistry
{
    Assert-False (Test-Permission -Path $keyPath -Identity $identity -Permission 'Delete')
}

function ShouldCheckGrantedPermissionOnRegistry
{
    Assert-True (Test-Permission -Path $keyPath -Identity $identity -Permission 'ReadKey')
}

function ShouldCheckExactPartialPermissionOnRegistry
{
    Assert-False (Test-Permission -Path $keyPath -Identity $identity -Permission 'ReadKey' -Exact)
}

function ShouldCheckExactPermissionOnRegistry
{
    Assert-True (Test-Permission -Path $keyPath -Identity $identity -Permission 'ReadKey','WriteKey' -Exact)
}

function ShouldCheckUngrantedInheritanceFlags
{
    Assert-False (Test-Permission -Path $dirPath -Identity $identity -Permission 'ReadAndExecute' -ApplyTo ContainerAndSubContainersAndLeaves )
}

function ShouldCheckGrantedInheritanceFlags
{
    Assert-True (Test-Permission -Path $dirPath -Identity $identity -Permission 'ReadAndExecute' -ApplyTo ContainerAndLeaves)
    Assert-True (Test-Permission -Path $dirPath -Identity $identity -Permission 'ReadAndExecute' -ApplyTo ChildLeaves )
}


function ShouldCheckExactUngrantedInheritanceFlags
{
    Assert-False (Test-Permission -Path $dirPath -Identity $identity -Permission 'ReadAndExecute' -ApplyTo ContainerAndLeaves -Exact)
}

function ShouldCheckExactGrantedInheritanceFlags
{
    Assert-True (Test-Permission -Path $dirPath -Identity $identity -Permission 'ReadAndExecute' -ApplyTo ChildLeaves -Exact)
}

function ShouldCheckPermissionOnPrivateKey
{
    $cert = Install-Certificate -Path $privateKeyPath -StoreLocation LocalMachine -StoreName My -NoWarn
    try
    {
        $certPath = Join-Path -Path 'cert:\LocalMachine\My' -ChildPath $cert.Thumbprint
        Grant-Permission -Path $certPath -Identity $identity -Permission 'GenericAll'
        Assert-True (Test-Permission -Path $certPath -Identity $identity -Permission 'GenericRead')
        Assert-False (Test-Permission -Path $certPath -Identity $identity -Permission 'GenericRead' -Exact)
        Assert-True (Test-Permission -Path $certPath -Identity $identity -Permission 'GenericAll','GenericRead' -Exact)
    }
    finally
    {
        Uninstall-Certificate -Thumbprint $cert.Thumbprint -StoreLocation LocalMachine -StoreName My -NoWarn
    }
}

function ShouldCheckPermissionOnPublicKey
{
    $cert = Get-ChildItem 'cert:\*\*' -Recurse | Where-Object { -not $_.HasPrivateKey } | Select-Object -First 1
    Assert-NotNull $cert
    $certPath = Join-Path -Path 'cert:\' -ChildPath (Split-Path -NoQualifier -Path $cert.PSPath)
    Assert-True (Test-Permission -Path $certPath -Identity $identity -Permission 'FullControl')
    Assert-True (Test-Permission -Path $certPath -Identity $identity -Permission 'FullControl' -Exact)
}

Describe 'TestPermission.when test' {
    #AfterEach  { Reset }
    It 'should pass' {
        Init
        ShouldCheckPermissionOnPublicKey
    }
}