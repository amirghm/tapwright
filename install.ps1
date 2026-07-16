param(
  [string]$Dest = (Get-Location).Path,
  [string]$AgentDir = ""
)

$ErrorActionPreference = "Stop"

$SrcDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Pack = Join-Path $SrcDir "pack"

if (-not (Test-Path $Pack)) {
  throw "install: cannot find pack next to install.ps1 ($Pack)"
}

Set-Location $Dest

if ([string]::IsNullOrWhiteSpace($AgentDir)) {
  if (Test-Path ".cursor") {
    $AgentDir = ".cursor"
  } elseif (Test-Path ".claude") {
    $AgentDir = ".claude"
  } else {
    $AgentDir = ".agents"
  }
}

Write-Host "tapwright: installing into $Dest/$AgentDir"

# Remove the retired tapwright mobile workflow/helper skill from older installs.
$legacyWorkflow = Join-Path $AgentDir "workflows/mobile.md"
if ((Test-Path $legacyWorkflow) -and ((Get-Content $legacyWorkflow -Raw) -match "mobile-engine")) {
  Remove-Item $legacyWorkflow -Force
}
$legacySkill = Join-Path $AgentDir "skills/mobile-engine/SKILL.md"
if ((Test-Path $legacySkill) -and ((Get-Content $legacySkill -Raw) -match "(?m)^name: mobile-engine$")) {
  Remove-Item (Split-Path -Parent $legacySkill) -Recurse -Force
}

$dirs = @("workflows", "scripts", "templates")
foreach ($dir in $dirs) {
  New-Item -ItemType Directory -Force -Path (Join-Path $AgentDir $dir) | Out-Null
  Copy-Item -Path (Join-Path $Pack "$dir/*") -Destination (Join-Path $AgentDir $dir) -Recurse -Force
}

New-Item -ItemType Directory -Force -Path (Join-Path $AgentDir "skills") | Out-Null
Get-ChildItem -Path (Join-Path $Pack "skills") -Directory | Where-Object {
  Test-Path (Join-Path $_.FullName "SKILL.md")
} | ForEach-Object {
  Copy-Item -Path $_.FullName -Destination (Join-Path $AgentDir "skills") -Recurse -Force
}

Get-ChildItem -Path (Join-Path $AgentDir "workflows"), (Join-Path $AgentDir "skills") -Recurse -Filter "*.md" | ForEach-Object {
  $content = Get-Content $_.FullName -Raw
  $content = $content.Replace("pack/scripts/", "$AgentDir/scripts/")
  $content = $content.Replace("pack/templates/", "$AgentDir/templates/")
  Set-Content -Path $_.FullName -Value $content -NoNewline
}

function Refresh-MarkedBlock {
  param([string]$File, [string]$Name)
  $begin = "<!-- tapwright:$Name begin -->"
  $end = "<!-- tapwright:$Name end -->"
  $parent = Split-Path -Parent $File
  if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
  if (-not (Test-Path $File)) { New-Item -ItemType File -Force -Path $File | Out-Null }

  $lines = Get-Content $File
  $out = New-Object System.Collections.Generic.List[string]
  $skip = $false
  foreach ($line in $lines) {
    if ($line -eq $begin) { $skip = $true; continue }
    if ($line -eq $end) { $skip = $false; continue }
    if (-not $skip) { $out.Add($line) }
  }
  Set-Content -Path $File -Value $out
}

function Write-FileIfMissingOrTapwrightOwned {
  param([string]$File, [string]$Marker, [string]$Content)
  $parent = Split-Path -Parent $File
  if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
  if ((Test-Path $File) -and -not ((Get-Content $File -Raw) -match [regex]::Escape($Marker))) {
    Write-Host "tapwright: left existing $File untouched"
    return
  }
  Set-Content -Path $File -Value $Content -NoNewline
}

function Append-AgentsBlock {
  $file = "AGENTS.md"
  Refresh-MarkedBlock -File $file -Name "mobile"
  Add-Content -Path $file -Value @"
<!-- tapwright:mobile begin -->

## tapwright mobile

Use tapwright when the user runs `@mobile` or `/mobile`, or asks for mobile app inspection, automation, manual UI testing, debugging, E2E execution, recording, replay, or screenshot/design comparison.

- Primary experience: `@mobile`.
- If the coding tool does not support `@mobile`, use `/mobile` instead.
- Read `$AgentDir/skills/mobile/SKILL.md` before acting.
- `@mobile` controls the running app. If the user asks to create something inside an app, do it through that app's live UI; edit source only when explicitly requested.
- Route ad-hoc automation through `$AgentDir/skills/exec-engine/SKILL.md`.
- Route E2E specs through `$AgentDir/skills/test-engine/SKILL.md` and `$AgentDir/workflows/test.md`.
- Use Android/iOS device recipes from `$AgentDir/skills/device-interaction*/SKILL.md`.
- Before every task, read the per-app App Map under `.tapwright-memory/<platform>/<app-id>/app-map.yaml`; create it when missing and update it after the task.
- New tests and stable app data update map candidates immediately; only live-verified routes become trusted edges.
- Source code is optional. Use the App Map first, then the live UI; inspect source only when a target remains unresolved.
- Prefer emulators/simulators; ask before touching physical devices.
- Resolve UI targets from dumps/accessibility trees before screenshots or coordinates.

First useful request after install: @mobile what screen is my app showing?

<!-- tapwright:mobile end -->
"@
}

function Install-AgentAdapters {
  Append-AgentsBlock

  if (($AgentDir -eq ".claude") -or (Test-Path ".claude")) {
    Write-FileIfMissingOrTapwrightOwned ".claude/commands/mobile.md" "tapwright:generated" @"
---
description: tapwright mobile for Android/iOS inspection, automation, manual testing, debugging, recording, replay, compare, and E2E.
---

<!-- tapwright:generated -->

Read `$AgentDir/skills/mobile/SKILL.md` and execute the rest as a mobile request. Control the running app; do not edit source unless explicitly requested.
"@
  }

  if (($AgentDir -eq ".cursor") -or (Test-Path ".cursor")) {
    Write-FileIfMissingOrTapwrightOwned ".cursor/rules/tapwright-mobile.mdc" "tapwright:generated" @"
---
description: Use tapwright @mobile for mobile inspection, automation, manual testing, debugging, recording, replay, compare, and E2E.
alwaysApply: false
---

<!-- tapwright:generated -->

When the user runs @mobile or /mobile, read `$AgentDir/skills/mobile/SKILL.md`. Control the running app; do not edit source unless explicitly requested. Prefer emulators/simulators and ask before touching physical devices.
"@
  }

  if (Test-Path ".opencode") {
    Write-FileIfMissingOrTapwrightOwned ".opencode/agents/mobile.md" "tapwright:generated" @"
---
description: tapwright mobile agent for Android/iOS inspection, automation, manual testing, debugging, recording, replay, compare, and E2E.
---

<!-- tapwright:generated -->

Read `$AgentDir/skills/mobile/SKILL.md`, then control the running app with the installed device skills. Do not edit source unless explicitly requested. Prefer emulators/simulators; ask before touching physical devices.
"@
  }

  if (Test-Path ".github") {
    Refresh-MarkedBlock -File ".github/copilot-instructions.md" -Name "mobile"
    Add-Content -Path ".github/copilot-instructions.md" -Value @"
<!-- tapwright:mobile begin -->

## tapwright mobile

For `@mobile`, `/mobile`, mobile app inspection, automation, debugging, manual UI testing, record/replay, compare, or E2E requests, read `$AgentDir/skills/mobile/SKILL.md` and control the running app. Do not edit source unless explicitly requested. Prefer emulators/simulators and ask before interacting with physical devices.

<!-- tapwright:mobile end -->
"@
  }
}

if (-not (Test-Path "tapwright.config.yml")) {
  Copy-Item (Join-Path $SrcDir "config/tapwright.config.example.yml") "tapwright.config.yml"
  Write-Host "tapwright: wrote starter tapwright.config.yml"
} else {
  Write-Host "tapwright: tapwright.config.yml already exists, left untouched"
}

Install-AgentAdapters

Write-Host ""
Write-Host "Done. Installed tapwright into $AgentDir."
Write-Host "App Memory will be created per app under .tapwright-memory on the first request."
Write-Host "Fill what you know in tapwright.config.yml. Source code is optional."
Write-Host "Next request to try: @mobile what screen is my app showing?"
Write-Host "If @mobile is not supported, use /mobile instead."
