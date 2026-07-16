# Supported stacks & glob presets

tapwright is stack-agnostic: it drives the OS, not your framework. What changes per stack is
**where the user-visible strings and navigation live** - i.e. the `string_globs` and
`nav_globs` you set in `tapwright.config.yml`. Pick the block matching your app.

## Android (native, XML resources)

```yaml
string_globs:
  - "**/src/main/res/values*/strings.xml"
nav_globs:
  - "**/*Navigation*.kt"
  - "**/*NavGraph*.kt"
  - "**/nav_graph*.xml"
```

Labels: `<string name="key">Text</string>`. `values-de/`, `values-fr/` etc. hold locales  - 
list them in `locales`.

## Kotlin Multiplatform / Compose Multiplatform

```yaml
string_globs:
  - "**/composeResources/values*/strings.xml"
  - "**/commonMain/**/values*/strings.xml"
nav_globs:
  - "**/*Navigation*.kt"
  - "**/*NavHost*.kt"
```

## iOS (native, Swift)

```yaml
string_globs:
  - "**/*.strings"       # Localizable.strings
  - "**/*.xcstrings"     # String Catalogs
nav_globs:
  - "**/*Coordinator*.swift"
  - "**/*Router*.swift"
  - "**/*View.swift"
```

Labels: `.strings` = `"key" = "Text";`; `.xcstrings` = JSON string catalogs.

## React Native / Expo

```yaml
string_globs:
  - "**/locales/**/*.json"
  - "**/i18n/**/*.json"
  - "**/translations/**/*.json"
nav_globs:
  - "**/*Navigator*.{ts,tsx,js,jsx}"
  - "**/*Routes*.{ts,tsx,js,jsx}"
  - "**/App.{tsx,jsx}"
```

Note: RN apps still run as native Android/iOS builds - driving is identical; only the glob
locations differ.

## Flutter

```yaml
string_globs:
  - "**/l10n/*.arb"
  - "**/lib/**/*_strings.dart"
nav_globs:
  - "**/*router*.dart"
  - "**/*routes*.dart"
```

## No config / mixed

Omit `tapwright.config.yml` (or leave globs at defaults) and the agent probes the built-in
preset union across all of the above. It's slower and noisier, so pin your stack's globs
once you know them.

## What tapwright does NOT need

- No `testID` / accessibility-id instrumentation required (it reads the live hierarchy).
- No SDK linked into your app, no build-time hooks.
- No model API key - the reasoning runs in your coding agent.
