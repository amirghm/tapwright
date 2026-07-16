param(
  [ValidateSet("inspect", "automate", "manual", "debug", "record", "replay", "compare", "run")]
  [string]$Mode = "run",
  [string]$Root = ".tapwright-run"
)

$ErrorActionPreference = "Stop"
$now = (Get-Date).ToUniversalTime()
$parent = Join-Path $Root $now.ToString("yyyy-MM-dd")
$name = "$($now.ToString('HH-mm-ssZ'))-$Mode"
$runDir = Join-Path $parent $name
$suffix = 2

while (Test-Path $runDir) {
  $runDir = Join-Path $parent "$name-$suffix"
  $suffix++
}

New-Item -ItemType Directory -Force -Path (Join-Path $runDir "resources") | Out-Null
Write-Output $runDir
