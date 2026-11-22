# roller-radar

Persönlicher Fork von [Swiftfin](https://github.com/jellyfin/Swiftfin) (MPL-2.0).

## Build

Gebaut wird ausschließlich per GitHub Actions (`.github/workflows/build.yml`)
auf einem macOS-Runner – ohne Codesigning. Ergebnis ist das Artifact
`Swiftfin-unsigned-ipa`, das per Sideloadly/SideStore mit der eigenen Apple ID
signiert und installiert wird.

## Basis

Upstream-Stand `cde99607` (2026-10-24) – der letzte Commit, der noch mit
Xcode 26.6 baut. Neuere Swiftfin-Commits verlangen Xcode 27, das auf den
GitHub-gehosteten macOS-Runnern nicht verfügbar ist.
