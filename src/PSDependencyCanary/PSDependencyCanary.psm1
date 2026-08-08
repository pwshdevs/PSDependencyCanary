# Dot source public/private functions. Missing or empty directories are valid.
$getScriptFiles = {
    param([Parameter(Mandatory)][string]$Directory)

    $directoryPath = Join-Path -Path $PSScriptRoot -ChildPath $Directory
    if (Test-Path -LiteralPath $directoryPath -PathType Container) {
        Get-ChildItem -LiteralPath $directoryPath -Filter '*.ps1' -File -Recurse -ErrorAction Stop |
            Sort-Object -Property FullName
    }
}

$public  = @(& $getScriptFiles -Directory 'Public')
$private = @(& $getScriptFiles -Directory 'Private')
foreach ($import in @($public + $private)) {
    try {
        . $import.FullName
    } catch {
        throw "Unable to dot source [$($import.FullName)]: $($_.Exception.Message)"
    }
}

Export-ModuleMember -Function $public.Basename
