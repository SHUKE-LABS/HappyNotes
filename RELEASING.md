# Releasing HappyNotes

## Version identity

Every generated release tag uses the form `vX.Y.Z`.

- The Version workflow creates a tag for every `master` commit. A conventional `feat` commit bumps the minor version; every other commit bumps the patch version.
- Use the workflow's `release_as` input for a deliberate version jump. The requested version must be strictly greater than the latest `vX.Y.Z` tag.
- `pubspec.yaml` contains the placeholder `0.0.0+1`. Store builds override it with `--build-name` and `--build-number`; the tag supplies the release version.

## Mobile build numbers

The Android sideload workflow uses `N = github.run_number + 100` as the build number. The tag supplies the Android `versionName`; `N` is the APK `versionCode`.

Do not rename the mobile release workflow: renaming it resets `github.run_number`. If it must be renamed, raise the offset above the last shipped build number before shipping another build.

## Channels and cadence

Web remains continuous as described in [#47](https://github.com/SHUKE-LABS/HappyNotes/issues/47). Android sideload releases use a chosen existing version tag:

1. Dispatch `.github/workflows/mobile_release.yml` with the existing `vX.Y.Z` tag.
2. Author-test the signed APK from the GitHub Release.
3. Re-dispatch the same tag when a rebuilt APK or updated release notes are needed; the existing Release is updated in place.

The Play Store slice in [#59](https://github.com/SHUKE-LABS/HappyNotes/issues/59) remains parked until a Play developer account exists. This workflow does not upload an AAB or an iOS build.

Target a cadence of at most once every two weeks, or sooner when enough user-visible changes have accumulated.

## Hotfixes

Hotfixes are trunk-only: fix the issue on `master`, let the Version workflow create the next tag, and ship that tag. Do not create release branches.

## GitHub Releases

Each Android sideload dispatch creates or updates the GitHub Release for its tag and attaches the signed APK; release assets are not billed like Actions artifacts. The release body contains the `CHANGELOG.md` sections since the previous `v*` GitHub Release, plus any dispatch notes.

## API compatibility

Follow the API compatibility rule in [HappyNotes.Api#66](https://github.com/SHUKE-LABS/HappyNotes.Api/issues/66) before shipping a mobile version.

After the API version-policy endpoint from HappyNotes.Api#66 is deployed to production, update its `ClientVersionPolicy` values for the platform being released:

- Set `LatestVersion` and `LatestBuild` to the version/build that has reached the store.
- Raise `MinSupportedBuild` only after the replacement build is available in the store and the old build can be retired.
- Set the platform's `StoreUrl` to its App Store or Google Play listing.
- Smoke-test `GET /ClientVersionPolicy/Get?platform=ios` and `platform=android` in production before shipping the client. The response must be HTTP 200 and include all four policy fields.

## Store-launch baseline

After this foundation lands, run the Version workflow manually with `release_as=2.0.0` on the merged `master` commit. This creates the store-launch baseline above both the legacy `1.1.4` release and the existing `v0.x` tags.
