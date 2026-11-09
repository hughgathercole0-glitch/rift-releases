# RIFT releases

[Download RIFT 0.6.2 for Windows x64](https://github.com/hughgathercole0-glitch/rift-releases/releases/tag/v0.6.2-preview.1).

This public preview is unsigned. The release includes SHA256SUMS.txt and native-release.json. SHA-256: `feb98f90c96bc8c6165707d3058b03780922a46d58222f77df2f7948c192e93d`.

## Verified on Windows

[Validation run](https://github.com/hughgathercole0-glitch/rift-releases/actions/runs/42594829125) passed native installer generation, installation, startup, standalone uninstall and retained user data. An actual 0.6.0-to-0.6.2 update passed download/signature verification, explicit silent installation, relaunch, encrypted-vault recovery, 16 agent tests, interrupted-download rejection and unsigned-update rejection.

The update test used a disposable certificate trusted only in its runner. No test signing keys, roots, PFX files or test-signed installers are published. Passing this test does not provide trusted public publisher signing or establish compatibility with every PC.

The older 0.6.0/0.6.1 cross-built previews had defective uninstallers. This Windows-built installer repairs only those exact known defective files using its own correctly generated uninstaller, without disabling integrity checks. Older release notes identify the affected previews.

## Automatic updates

RIFT includes in-app signed-feed configuration without reinstalling. A production signing certificate and stable signed release are still needed before updates are live. The intended feed is:

`https://github.com/hughgathercole0-glitch/rift-releases/releases/latest/download/`

Future stable signed releases require an incremented application version, installer, blockmap and latest.yml. Do not overwrite existing releases or reuse a published preview's application version for the first stable update.

## Application scope

The preview provides the task dashboard, encrypted shipping/payment-label vault and manually recorded checkout history. Live retailer auto-checkout, account/payment integration and live challenge handling are not implemented. Agent tests use simulated retailers/providers and do not prove real checkout success.

The application source repository, RIFT website and user-entered data remain private. This repository contains public distribution files and validation scripts. Public Electron installers include the application code required to run them.
