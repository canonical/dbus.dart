# dbus.dart Contribution Guide

If you have a problem, please [file an issue](https://github.com/canonical/dbus.dart/issues/new).

If you have a solution, then we accept contributions via [pull requests](https://github.com/canonical/dbus.dart/pulls).
All contributions require the author(s) to sign the [contributor license agreement](http://www.ubuntu.com/legal/contributors/).

Thanks for your help!

## Releasing

Releases are automated with [release-please](https://github.com/googleapis/release-please)
and published to [pub.dev](https://pub.dev/packages/dbus) from GitHub Actions.

1. Use [Conventional Commits](https://www.conventionalcommits.org/) for pull
   request titles and commits (`feat:`, `fix:`, `chore:`, ...). Only `feat:`,
   `fix:`, `perf:` and `revert:` commits appear in the changelog, and `feat!:`
   or `BREAKING CHANGE:` marks a breaking change. If the repository allows
   squash merging, prefer it: release-please reads every commit on `main`, so a
   merge commit plus its branch commits can add the same change to the
   changelog twice.
2. After changes land on `main`, the `Release` workflow opens (and keeps
   updating) a `chore: release X.Y.Z` pull request that bumps the version in
   `pubspec.yaml` and updates `CHANGELOG.md`.
3. Merge that pull request to release. The workflow creates the `vX.Y.Z` tag and
   GitHub release, and then the `Publish` workflow publishes the package to
   pub.dev using OIDC (no secrets are involved).

Publishing can also be started manually by pushing a `vX.Y.Z` tag that matches
the version in `pubspec.yaml`. If the `Release` workflow creates the release but
fails to start the publish run, retry it with:

```console
gh workflow run publish.yml --ref vX.Y.Z
```

Consider protecting `v*` tags with a repository ruleset so that only release
managers can create matching tags: anyone who can push a matching tag can
publish to pub.dev.
