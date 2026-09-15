# Release process

This procedure governs human-authorized releases of the public publication.
It does not authorize automation to approve, merge, tag, or publish a release.

## Release authority and prerequisites

A designated release manager creates the tag and GitHub Release only after a
different authorized maintainer has approved the generated publication pull
request. The publication requester, pusher, and automation identity cannot
approve or release their own change.

Before a release:

1. Complete every blocking administrator requirement in
   [`REPOSITORY_GOVERNANCE.md`](REPOSITORY_GOVERNANCE.md), including branch and
   tag protection, CODEOWNER review, the protected publication environment,
   publication identity restrictions, and enabled GitHub private vulnerability
   reporting.
2. Merge the generated publication pull request through protected `main`
   without bypassing required review or validation.
3. Record the exact merge commit on `main`. Do not release a pull request head,
   an unmerged commit, or a moving branch reference.
4. Confirm both `Validate public publication` jobs succeeded for that exact
   merge commit's `push` run on `main`.
5. Review `catalog.json`, `generated-manifest.json`, every changed artifact
   README and metadata file, and every removal record at that commit.
6. Confirm a public-only implementer can discover, deploy or import, validate,
   pilot, and roll back each changed artifact without internal context.

The current empty catalog and `publicationVersion` `1.0.0` manifest are
**unreleased preparation**. Do not tag or release the empty bootstrap commit.
The first release is created only after at least one real artifact has passed
the controlled publication process.

## Publication version

Release tags use `publication-vX.Y.Z`. At the tagged commit, `X.Y.Z` must
exactly equal `generated-manifest.json`'s `publicationVersion`. Publication
versions and artifact versions are independent:

- increment **patch** by exactly one for a release containing only compatible
  corrections to previously published content;
- increment **minor** by exactly one and reset patch to zero for new artifacts,
  backward-compatible capabilities, or deprecation notices;
- increment **major** by exactly one and reset minor and patch to zero for a
  removal or other release-level breaking change.

Generated publication pull requests cannot skip versions, regress versions, or
reuse the current version. The sole exception is the first real artifact
publication: it retains the unreleased empty bootstrap's `1.0.0` version so the
first tag can be `publication-v1.0.0`. Governance-only pull requests do not
change `publicationVersion`.

## Create the release

After all prerequisites pass, the release manager:

1. Resolves and records the exact protected-`main` merge SHA.
2. Confirms the intended `publication-vX.Y.Z` tag does not already exist and
   matches the manifest version at that SHA.
3. Creates an annotated tag at that exact SHA. Sign the tag when the
   organization provides an approved signing identity and verification policy;
   never claim a signature when that facility is unavailable.
4. Pushes the tag using the authorized human release identity under the
   repository's immutable `publication-v*` tag rules.
5. Creates a non-draft, non-prerelease GitHub Release from that tag only after
   verifying the pushed tag resolves to the recorded SHA.

Release notes must include:

- the publication version and exact commit;
- every added, updated, deprecated, and removed artifact ID with its independent
  artifact version;
- material prerequisites, compatibility changes, permissions, deployment
  impact, limitations, and migration or replacement guidance;
- the successful validation run for the tagged commit;
- links to the immutable catalog and generated manifest at the tag; and
- any known safe operational caveats, without internal provenance or sensitive
  information.

Do not include internal repository names, workflow URLs, tenant/customer data,
private build logs, credentials, or employee identities.

## Post-release verification

From a fresh public checkout or archive of the tag:

1. Confirm the tag resolves to the recorded protected-`main` merge SHA.
2. Confirm the GitHub Release is public and references the same immutable tag.
3. Run `pwsh -NoProfile -File scripts/Validate-Publication.ps1`.
4. Confirm catalog paths resolve and manifest byte lengths and hashes validate.
5. Follow each changed artifact's public README through discovery, deployment
   or import, validation, pilot, and rollback using synthetic test data.
6. Record verification evidence in the release record or approved operational
   system.

## Failure, withdrawal, and recovery

If tag or release creation fails before publication, stop and correct the
release record; do not move, reuse, or overwrite a published tag. If an
incorrect tag was pushed but no public release was published, follow the
organization's audited release incident process rather than rewriting it
silently.

For an unsafe published artifact, use the private security-advisory and yank
process in [`REPOSITORY_GOVERNANCE.md`](REPOSITORY_GOVERNANCE.md). Merge the
removal or remediation through the normal independently validated and approved
publication pull request, publish a new version, mark affected releases and
artifact versions as withdrawn, and retain all historical tags and audit
records.
