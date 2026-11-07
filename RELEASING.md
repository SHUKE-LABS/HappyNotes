# Releasing HappyNotes

## Version identity

Every generated release tag uses the form `vX.Y.Z`.

- The Version workflow creates a tag for every `master` commit. A conventional `feat` commit bumps the minor version; every other commit bumps the patch version.
- Use the workflow's `release_as` input for a deliberate version jump. The requested version must be strictly greater than the latest `vX.Y.Z` tag.
- `pubspec.yaml` contains the placeholder `0.0.0+1`. Store builds override it with `--build-name` and `--build-number`; the tag supplies the release version.

## Mobile build numbers

The mobile release workflow uses `N = github.run_number + 100` as the build number. One workflow run builds both Android and iOS, so both platforms share the same `N`.

Do not rename the mobile release workflow: renaming it resets `github.run_number`. If it must be renamed, raise the offset above the last shipped build number before shipping another build.

## Channels and cadence

Web remains continuous as described in [#47](https://github.com/SHUKE-LABS/HappyNotes/issues/47). Mobile releases use a chosen existing version tag:

1. Build TestFlight and Google Play internal releases.
2. Author-test the dogfood builds.
3. Promote to production with an App Store phased release and a Google Play staged rollout.

Target a cadence of at most once every two weeks, or sooner when enough user-visible changes have accumulated.

## Hotfixes

Hotfixes are trunk-only: fix the issue on `master`, let the Version workflow create the next tag, and ship that tag. Do not create release branches.

## GitHub Releases

Only tags shipped to the stores receive a GitHub Release. The Releases page is therefore the store release history. Attach APK assets to the GitHub Release; release assets are not billed like Actions artifacts.

## API compatibility

Follow the API compatibility rule in [HappyNotes.Api#66](https://github.com/SHUKE-LABS/HappyNotes.Api/issues/66) before shipping a mobile version.

After the API version-policy endpoint from HappyNotes.Api#66 is deployed to production, update its `ClientVersionPolicy` values for the platform being released:

- Set `LatestVersion` and `LatestBuild` to the version/build that has reached the store.
- Raise `MinSupportedBuild` only after the replacement build is available in the store and the old build can be retired.
- Set the platform's `StoreUrl` to its App Store or Google Play listing.
- Smoke-test `GET /ClientVersionPolicy/Get?platform=ios` and `platform=android` in production before shipping the client. The response must be HTTP 200 and include all four policy fields.

## Store-launch baseline

After this foundation lands, run the Version workflow manually with `release_as=2.0.0` on the merged `master` commit. This creates the store-launch baseline above both the legacy `1.1.4` release and the existing `v0.x` tags.
