# Publish a verified original X10Pro research dump to the current GitHub repo.
# Run in PowerShell from a clone of nile1801/X10Pro with authenticated git.
param(
    [Parameter(Mandatory = $true)]
    [string]$FirmwarePath
)
$ErrorActionPreference = 'Stop'
$expected = '3e6e293df65a49b46dc9c6f1fade05f76ec9d74793ca148f853cb717a363d4fa'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$source = (Resolve-Path -LiteralPath $FirmwarePath).Path
$sha = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant()
if ($sha -ne $expected) {
    throw "SHA-256 mismatch. Expected $expected, got $sha. Refusing to publish."
}
$remote = (& git -C $repo remote get-url origin 2>&1).Trim()
if ($LASTEXITCODE -ne 0 -or $remote -notmatch '(^|[:/])nile1801/X10Pro(\.git)?$') {
    throw "Git origin is not nile1801/X10Pro: $remote"
}
$destDir = Join-Path $repo 'firmware/raw'
New-Item -ItemType Directory -Force -Path $destDir | Out-Null
$dest = Join-Path $destDir 'x10pro_rgb_20261105_204720.tar.gz'
if ($source -ne $dest) {
    Copy-Item -LiteralPath $source -Destination $dest -Force
}
$actual = (Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actual -ne $expected) { throw 'Destination hash mismatch. Aborting.' }
Write-Host "Verified firmware research dump: $actual"
Write-Warning 'This archive may include proprietary OEM binaries and security-sensitive defaults. Repository is PUBLIC. Ensure you have rights and accept publishing it.'
$consent = Read-Host 'Type PUBLISH to commit and push this archive to public GitHub'
if ($consent -cne 'PUBLISH') {
    Write-Host 'Canceled. The archive remains local and was not pushed.'
    exit 0
}
& git -C $repo add -- 'firmware/raw/x10pro_rgb_20261105_204720.tar.gz'
if ($LASTEXITCODE -ne 0) { throw 'git add failed' }
& git -C $repo commit -m 'research(firmware): archive original partial X10Pro device dump'
if ($LASTEXITCODE -ne 0) { throw 'git commit failed or no changes' }
& git -C $repo push origin main
if ($LASTEXITCODE -ne 0) { throw 'git push failed. Commit remains local.' }
Write-Host 'Firmware dump published to GitHub.'
