# Example - Android (Compose / KMP)

A minimal tapwright config for a Jetpack Compose or Kotlin Multiplatform Android app that
ships English + German strings.

## Setup

```bash
cd /path/to/your-android-app
/path/to/tapwright/install.sh
cp /path/to/tapwright/examples/android-compose/tapwright.config.yml ./tapwright.config.yml
export TAPWRIGHT_QA_PASSWORD='...'     # never commit the password
```

Adjust `package_id`, `launch`, and the Gradle `install` task to match your module.

## Try `/exec`

```
/exec log in and open the account screen on android
```

The agent greps `values/strings.xml` + `values-de/strings.xml` for "Log in"/"Anmelden" and
"Account"/"Konto", builds a step plan, launches `com.example.shop.debug`, and drives it.
Because `known_flows.login` exists, it reuses that path (still verified against the dump).

## Try `/test`

Create `specs/account/test-plan.md` (see `pack/templates/test-plan.md`) with an E-1 that
opens the account screen and asserts a settings label, then:

```
/test account
```

Report + DSL land under `specs/account/runs/android/<run_id>/`.

## Notes

- Prefer a `*.debug` build so `adb install` / `pm clear` are unrestricted.
- If `tap_text` matches system UI, set `export PKG=com.example.shop.debug` before sourcing
  `adb-helpers.sh` to bias matches to your app.
