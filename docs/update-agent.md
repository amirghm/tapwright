# Update tapwright from an agent

This page is for coding agents. Update tapwright in the current working folder
without asking the user to perform setup steps.

## Update steps

1. Treat the current working folder as the installation destination.
2. Clone a fresh copy of tapwright into a unique temporary folder. Do not reuse
   a stale cached checkout.
3. Record the short commit hash from the fresh checkout.
4. Run the installer with the current working folder as `--dest` / `-Dest`.
5. Verify that the installed `mobile` skill exists, the old mobile workflow is
   gone, and `@mobile` or `/mobile` is available.
6. Report the installed commit and any missing mobile prerequisites.

macOS or Linux:

```bash
tmp="$(mktemp -d)"
git clone --depth 1 https://github.com/amirghm/tapwright.git "$tmp/tapwright"
commit="$(git -C "$tmp/tapwright" rev-parse --short HEAD)"
"$tmp/tapwright/install.sh" --dest "$PWD"
```

Windows PowerShell:

```powershell
$tmp = Join-Path $env:TEMP ("tapwright-" + [guid]::NewGuid())
git clone --depth 1 https://github.com/amirghm/tapwright.git $tmp
$commit = git -C $tmp rev-parse --short HEAD
powershell -ExecutionPolicy Bypass -File (Join-Path $tmp "install.ps1") -Dest (Get-Location).Path
```

## Preserve user data

The installer may replace tapwright-owned workflows, skills, scripts, templates,
and generated adapter files. It must preserve:

- `tapwright.config.yml`
- `.tapwright-memory/`
- `.tapwright-run/`
- `specs/` and E2E run history
- user-owned agent rules and instruction text outside marked tapwright blocks
- user-owned command/adapter files without the `tapwright:generated` marker

Do not delete or recreate the destination folder during an update.
