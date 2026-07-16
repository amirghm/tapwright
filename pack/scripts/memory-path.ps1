param(
  [Parameter(Mandatory = $true)]
  [ValidateSet("android", "ios")]
  [string]$Platform,
  [Parameter(Mandatory = $true)]
  [string]$AppId,
  [string]$Root = ".tapwright-memory"
)

$ErrorActionPreference = "Stop"

if ($AppId -notmatch '^[A-Za-z0-9._-]+$') {
  throw "memory-path: invalid package or bundle id"
}

$memoryDir = Join-Path (Join-Path $Root $Platform) $AppId
$graph = Join-Path $memoryDir "app-map.yaml"
New-Item -ItemType Directory -Force -Path $memoryDir | Out-Null

if (-not (Test-Path $graph)) {
  $now = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
  @"
schema_version: 1
app:
  platform: $Platform
  id: $AppId
  versions: []
created_at: $now
updated_at: $now
nodes: {}
edges: []
gates: []
"@ | Set-Content -Path $graph -NoNewline
}

Write-Output $graph
