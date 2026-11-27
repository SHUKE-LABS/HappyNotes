# Releasing HappyNotes

## Version identity

Every generated release tag uses the form `vX.Y.Z`.

- The Version workflow creates a tag for every `master` commit. A conventional `feat` commit bumps the minor version; every other commit bumps the patch version.
- Use the workflow's `release_as` input for a deliberate version jump. The requested version must be strictly greater than the latest `vX.Y.Z` tag.
- `pubspec.yaml` contains the placeholder `0.0.0+1`. Store builds override it with `--build-name` and `--build-number`; the tag supplies the release version.

## Mobile build numbers

The Android mobile release workflow uses `N = github.run_number + 100` for both the APK and AAB. The tag supplies the Android `versionName`; `N` is each artifact's `versionCode`.

Do not rename the mobile release workflow: renaming it resets `github.run_number`. If it must be renamed, raise the offset above the last shipped build number before shipping another build.

## Channels and cadence

Web remains continuous as described in [#47](https://github.com/SHUKE-LABS/HappyNotes/issues/47). Android releases use a chosen existing version tag:

1. Dispatch `.github/workflows/mobile_release.yml` with the existing `vX.Y.Z` tag.
2. The workflow builds the signed APK and matching AAB, then uploads the AAB to the Google Play **internal** track for `com.shukebeta.happynotes`.
3. The workflow creates or updates the tag's GitHub Release with the APK. `release_notes`, when supplied, are used as the Play `en-US` "What's new" text after truncation to 500 characters and are also included in the GitHub Release body.
4. Author-test the signed APK and the internal-track build before promoting it.

The Play upload commits the internal-track changes without sending them for review automatically. If Play Console shows changes waiting for review, the release owner must send them for review there.

Promotion beyond the internal track remains manual in Play Console, including any staged rollout. The workflow does not promote to production or build an iOS release.

The upload action uses `status: completed`. If the first post-merge dispatch is rejected with Play's `Only releases with status draft may be created on draft app` error, use `status: draft` for that one onboarding dispatch, then restore `completed` before normal releases.

Do not re-run a workflow run after its AAB has uploaded successfully: a re-run keeps the same `github.run_number`, so Play may reject the duplicate `versionCode`. Dispatch the same tag as a new workflow run instead; it receives a new build number and updates the existing GitHub Release in place. Because Play upload happens before the GitHub Release step, a failed Play upload does not publish an APK-only release.

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
