# Alerter 26.5 - Timeout Fix for Custom App Icons

Alerter 26.5 fixes an annoying bug where notifications using `--app-icon` would ignore the `--timeout` flag entirely. If you've been wondering why your timed notifications were sticking around forever when paired with a custom icon, this release solves it.

## What's New

- **`--timeout` now works correctly with `--app-icon`.** Previously, setting a custom app icon would silently break the auto-dismissal timer - the notification would stay on screen indefinitely instead of disappearing after the specified timeout. You can now combine both flags without any issues. ([#62](https://github.com/vjeantet/alerter/issues/62))  🙏 Merci @fbartho for your contribution !

## Upgrading

Install or update via Homebrew:

```bash
brew upgrade vjeantet/tap/alerter
```

Or via MacPorts:

```bash
sudo port upgrade alerter
```
