
function ConvertTo-ProviderAccessControlRights
{
    <#
    .SYNOPSIS
    Converts strings into the appropriate access control rights for a PowerShell provider (e.g. FileSystemRights or RegistryRights).

    .DESCRIPTION
    This is an internal Carbon function, so you're not getting anything more than the synopsis.

    .EXAMPLE
    ConvertTo-ProviderAccessControlRights -ProviderName 'FileSystem' -InputObject 'Read','Write'

    Demonstrates how to convert `Read` and `Write` into a `System.Security.AccessControl.FileSystemRights` value.
    #>
    [CmdletBinding()]
    param(
        # The provider name.
        [Parameter(Mandatory)]
        [ValidateSet('FileSystem','Registry','CryptoKey')]
        [String]$ProviderName,

        # The values to convert.
        [Parameter(Mandatory,ValueFromPipeline)]
        [String[]]$InputObject
    )

    begin
    {
        Set-StrictMode -Version 'Latest'

        Use-CallerPreference -Cmdlet $PSCmdlet -Session $ExecutionContext.SessionState

        $rights = 0
        $rightTypeName = 'Security.AccessControl.{0}Rights' -f $ProviderName
        $foundInvalidRight = $false
    }

    process
    {
        $InputObject | ForEach-Object { 
            $right = ($_ -as $rightTypeName)
            if( -not $right )
            {
                $allowedValues = [Enum]::GetNames($rightTypeName)
                Write-Error ("System.Security.AccessControl.{0}Rights value '{1}' not found.  Must be one of: {2}." -f $providerName,$_,($allowedValues -join ' '))
                $foundInvalidRight = $true
                return
            }
            $rights = $rights -bor $right
        }
    }

    end
    {
        if( $foundInvalidRight )
        {
            return $null
        }
        else
        {
            $rights
        }
    }
}
