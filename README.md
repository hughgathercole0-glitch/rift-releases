# RIFT releases

Public Windows installer distribution for RIFT. The RIFT website, source checkout and user-entered browser data are not published in this repository.

## Current status

A Windows x64 preview is being prepared. Preview installers are unsigned and untested on Windows; they do not provide verified retailer auto-checkout. Do not treat a draft release as a working download or update feed.

## Automatic updates

Stable signed releases need the NSIS installer, its `.blockmap` file and electron-updater `latest.yml`. The intended generic feed is:

`https://github.com/hughgathercole0-glitch/rift-releases/releases/latest/download/`

This is a planned feed, not a claim that signed update metadata is already available. Publisher signing and a real old-to-new Windows update test are required before enabling it.

Previews should remain prereleases. Existing published versions must not be overwritten.
