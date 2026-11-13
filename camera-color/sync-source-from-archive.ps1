#requires -Version 5.1
<#
  XETABON X10Pro Color Lab: publish verified source/runtime files to the linked GitHub repository.
  Download X10Pro_ColorLab_runtime_sources_v1.2-v1.3.1.tar.gz from the ChatGPT artifact first.
  This script clones the remote main branch, verifies input checksums, stages only camera-color/src,
  commits, and pushes without force. It never connects to the camera or flashes firmware.
#>
[CmdletBinding()]
param(
  [string]$ArchivePath = (Join-Path $PSScriptRoot 'X10Pro_ColorLab_runtime_sources_v1.2-v1.3.1.tar.gz'),
  [string]$RepoUrl = 'https://github.com/nile1801/X10Pro.git'
)
$ErrorActionPreference = 'Stop'
$expectedArchive = '1b4040d76f48dc4489f5875df72dd39a6ef32490aab9942c234cc456b4db81c4'
$expectedArm = 'cb8c071eb7b9c976a32bf7a5628e5ddc18444a868127e2aa52ba3b87eeee8f56'
$expectedUI = 'b089e82dc85b8cb8a8696a5a558e9b17f97c1ca406c8f9f8a3a4a12c1b99f8c3'

function Assert-Command([string]$exe) {
  if (-not (Get-Command $exe -ErrorAction SilentlyContinue)) {
    throw "Missing command: $exe"
  }
}
function Assert-Hash([string]$file, [string]$hash) {
  if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
    throw "File not found: $file"
  }
  $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $file).Hash.ToLowerInvariant()
  if ($actual -ne $hash.ToLowerInvariant()) {
    throw "SHA256 mismatch for $file : $actual"
  }
}
function Assert-Exit([string]$stage) {
  if ($LASTEXITCODE -ne 0) { throw "$stage failed (exit $LASTEXITCODE)" }
}

Assert-Command git
Assert-Command tar
$archive = (Resolve-Path -LiteralPath $ArchivePath).Path
Assert-Hash $archive $expectedArchive

$work = Join-Path ([IO.Path]::GetTempPath()) ('X10Pro-source-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work -Force | Out-Null
$checkout = Join-Path $work 'X10Pro'
Write-Host "Cloning latest main to $checkout"
& git clone --branch main --single-branch $RepoUrl $checkout
Assert-Exit 'git clone'

$dest = Join-Path $checkout 'camera-color/src'
if (Test-Path -LiteralPath $dest) {
  throw "Target already exists: $dest. Inspect existing source before changing it."
}
New-Item -ItemType Directory -Path $dest -Force | Out-Null
& tar -xzf $archive -C $dest
Assert-Exit 'tar extraction'

Assert-Hash (Join-Path $dest 'v1.3/device/tp9963_color5_step.arm') $expectedArm
Assert-Hash (Join-Path $dest 'v1.3.1/camera.html') $expectedUI
Assert-Hash (Join-Path $dest 'v1.3/device/controller.sh') '327f8b5f1108824874cdb529328de852028a7f47a5eb76abe82cbbae46a484ef'

& git -C $checkout add -- camera-color/src
Assert-Exit 'git add'
& git -C $checkout diff --cached --stat
Assert-Exit 'git diff'
& git -C $checkout commit -m 'feat(camera-color): publish verified v1.2-v1.3.1 runtime source'
Assert-Exit 'git commit'
& git -C $checkout push origin main
Assert-Exit 'git push'
& git -C $checkout log -1 --format='%H %s'
Write-Host "SUCCESS: source committed and pushed. Working clone: $checkout"
