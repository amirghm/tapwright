# Install tapwright from an agent

This page is for coding agents. If a user sends you this link, install tapwright
into the current working folder. Use the mobile app repo when one exists, but do
not require source code or Git. Do not send the user a setup guide. Do the setup,
check what is available, and report only the result or the blocker.

## What tapwright installs

tapwright adds a small set of repo-local files:

- `@mobile`, with `/mobile` as a fallback
- compatibility workflows for `/exec` and `/test`
- Android `adb` helpers
- iOS `simctl` / `idb` helpers
- E2E report and DSL templates
- per-app App Memory helpers
- a starter `tapwright.config.yml`

It does not install a daemon, SDK, model, or cloud service.

## Install steps for the agent

1. Use the user's mobile app repo when available. If there is no repo, use the
   current folder as a standalone tapwright workspace.
2. Download or clone tapwright to a temporary/cache location.
3. Run the installer for the current OS with the working folder as the destination.

   macOS or Linux:

   ```bash
   /path/to/tapwright/install.sh --dest /path/to/mobile-app
   ```

   Windows PowerShell:

   ```powershell
   powershell -ExecutionPolicy Bypass -File C:\path\to\tapwright\install.ps1 -Dest C:\path\to\mobile-app
   ```

4. If `tapwright.config.yml` was created, fill as much as you can:
   - Android `package_id` from source or the selected/foreground app
   - iOS `bundle_id` from source or the selected Simulator app
   - build/install commands and source globs only when source exists
   - locales when known
   App Maps are created on the first mobile request under
   `.tapwright-memory/<platform>/<package-or-bundle-id>/`.
5. Check mobile tooling yourself:
   - Android: `adb devices -l`
   - iOS on macOS: `xcrun simctl list devices available`, `which idb`
   - Windows: Android only. Do not attempt iOS setup.
6. If a required tool is missing, try the normal package manager for that OS when safe and allowed.
   If you cannot install it, report the exact missing tool and stop before device interaction.
7. Suggest the first request:

   ```text
   @mobile what screen is my app showing?
   ```

## Preferred install command

Clone tapwright, then run the installer from the user's working folder.

```bash
git clone https://github.com/amirghm/tapwright.git /tmp/tapwright
/tmp/tapwright/install.sh --dest "$PWD"
```

On Windows:

```powershell
git clone https://github.com/amirghm/tapwright.git "$env:TEMP\tapwright"
powershell -ExecutionPolicy Bypass -File "$env:TEMP\tapwright\install.ps1" -Dest (Get-Location).Path
```

If the repo already exists locally, use that checkout instead of cloning.

## Safety

- Do not overwrite existing user instruction files. The installer updates only
  marked tapwright blocks.
- Do not touch physical devices without explicit user confirmation.
- Do not commit secrets in `tapwright.config.yml`; use `password_env`.
- If prerequisites are missing, report the missing tools and stop before device
  interaction.

## After install

Use `@mobile`. If the coding tool does not support it, use `/mobile` instead:

```text
@mobile what screen is my app showing?
@mobile log in with the QA account and find settings
@mobile check if checkout still works
```
