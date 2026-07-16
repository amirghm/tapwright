# Install tapwright from an agent

This page is for coding agents. If a user sends you this link, install tapwright
into the current mobile app repo and help them run `@mobile inspect`.

## What tapwright installs

tapwright adds a small set of repo-local files:

- `@mobile`
- compatibility workflows for `/exec` and `/test`
- Android `adb` helpers
- iOS `simctl` / `idb` helpers
- E2E report and DSL templates
- a starter `tapwright.config.yml`

It does not install a daemon, SDK, model, or cloud service.

## Install steps for the agent

1. Confirm you are in the user's mobile app repo.
2. Download or clone tapwright to a temporary/cache location.
3. Run the installer with the app repo as the destination:

   ```bash
   /path/to/tapwright/install.sh --dest /path/to/mobile-app
   ```

4. If `tapwright.config.yml` was created, help the user fill:
   - Android `package_id`, `launch`, and install command/APK path
   - iOS `bundle_id`, scheme/config/build command
   - `string_globs`, `nav_globs`, and `locales`
5. Check prerequisites only as needed:
   - Android: `adb devices -l`
   - iOS: `xcrun simctl list devices available`, `which idb`
6. Suggest the first command:

   ```text
   @mobile inspect
   ```

## Preferred install command

Clone the repo, then run the installer from inside the user's app repo.

```bash
git clone https://github.com/amirghm/tapwright.git /tmp/tapwright
/tmp/tapwright/install.sh --dest "$PWD"
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

Use `@mobile`:

```text
@mobile inspect
@mobile automate log in and open settings
@mobile test CHECKOUT --ios --headless
```
