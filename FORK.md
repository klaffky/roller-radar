# roller-radar

Persönlicher Fork von [Swiftfin](https://github.com/jellyfin/Swiftfin) (MPL-2.0).

## Build

Gebaut wird ausschließlich per GitHub Actions (`.github/workflows/build.yml`)
auf einem macOS-Runner – ohne Codesigning. Ergebnis ist das Artifact
`Swiftfin-unsigned-ipa`, das per Sideloadly/SideStore mit der eigenen Apple ID
signiert und installiert wird.
