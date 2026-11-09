# RIFT releases

Public Windows installer distribution for RIFT. The RIFT website, application source and user-entered data remain private.

## Download

[RIFT 0.6.0 for Windows x64](https://github.com/hughgathercole0-glitch/rift-releases/releases/tag/v0.6.0-preview.1) is available as an unsigned preview. The release includes SHA256SUMS.txt.

SHA-256: `3b51e7eb45d7d67bf241a8e51f245e572408e346d68c6af4ce37ca24e20ee793`

Installation and startup of that exact installer passed on a native Windows runner: [validation run](https://github.com/hughgathercole0-glitch/rift-releases/actions/runs/42576506017). This does not establish compatibility with every Windows PC. The preview contains the task dashboard and encrypted shipping/payment-label vault. Retailer auto-checkout is not implemented.

Direct asset uploads from the connected integration returned HTTP 401. The workflow now verifies the binary chunks, installs and launches the application, and publishes release assets from the Windows runner.

## Automatic updates

RIFT 0.6.0 includes an in-app form for configuring a signed update source without reinstalling. No live trusted production update feed is enabled yet. Stable signed releases need a valid NSIS installer, its `.blockmap` and electron-updater `latest.yml` at:

`https://github.com/hughgathercole0-glitch/rift-releases/releases/latest/download/`

The separate Windows update workflow uses disposable test certificates within its runner. Those certificates and signed test installers are never published. Test trust is not public publisher trust. A verified signing provider and a production-signed acceptance test are still required.

Previews remain prereleases. Existing published versions must not be overwritten.
