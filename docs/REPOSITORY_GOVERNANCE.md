# Repository governance and administrator setup

## Required protected-branch controls

Repository administrators must configure a ruleset for the default branch:

- require pull requests and prohibit direct pushes, force pushes, and branch
  deletion;
- require the `Validate public publication` status check to pass and require
  branches to be up to date;
- require at least one approval and all applicable CODEOWNER approvals;
- dismiss stale approvals after new commits and require approval of the most
  recent push by someone other than the pusher;
- require conversation resolution, signed commits where organizational policy
  supports it, and linear history;
- restrict bypass to a small audited emergency administrator group;
- require explicit CODEOWNER review for any deletion under `templates/**`,
  `catalog.json`, or `generated-manifest.json`.
- require the human approver to differ from the publication requester and
  pusher; the publisher identity cannot approve or merge;
- protect the validation workflow, validator, and publication path policy with
  CODEOWNERS, and where available enforce the validation workflow through an
  organization ruleset so pull requests cannot substitute their own check.

Ruleset configuration is an external administrator action and cannot be
enforced by files in this repository alone.

## Publication identity and environment

Publication automation must use a dedicated GitHub App or fine-grained token,
not a personal access token. Grant repository contents **read and write** and
pull requests **read and write** only; do not grant administration, issues,
members, secrets, or organization-wide access. Scope installation to this
repository and rotate credentials according to organizational policy.

Use a protected `public-publication` GitHub environment with required
maintainer approval. Store the credential only in that environment. The
publisher may create a branch and pull request but cannot push to the default
branch, approve its own pull request, modify workflows/governance, or bypass
rulesets.

The validator uses no `pull_request_target` trigger and receives no publication
credential or repository secret. Never execute generated scripts during pull
request validation; syntax and prohibited-pattern checks are static.

## Releases

Release tags use `publication-v<major>.<minor>.<patch>`, are created from the
protected default branch after validation, and are immutable. A release notes
the artifact additions, updates, deprecations, and removals. Artifact versions
remain independent SemVer values recorded in metadata.

## Yank and security-advisory revocation

For an unsafe published artifact, privately coordinate through GitHub Security
Advisories and the repository security contact. Prepare a generated removal
event with owner, reason, effective date, and replacement when available;
remove it from the catalog through the normal reviewed publication pull
request; and publish a release that identifies affected artifact versions and
safe remediation without disclosing embargoed details. For urgent active risk,
administrators may use the audited emergency bypass only to merge an approved
yank pull request after independent validation—never to push directly.
Do not delete or rewrite historical tags. Mark affected releases and artifact
versions as withdrawn, retain the immutable audit trail, and publish follow-up
advisory details when disclosure is safe.

## Blocking setup requirements

Before production publication:

1. Replace `security@example.com` in `SECURITY.md` with an authoritative,
   monitored private reporting channel and define acknowledgement/remediation
   expectations. No authoritative address currently exists in this repository.
2. Replace the placeholder professional-services route in `SUPPORT.md` if a
   more specific authoritative public route is approved.
3. Create the branch ruleset and protected environment described above.
4. Configure the least-privilege publication identity and verify it cannot
   modify hand-maintained paths or merge directly.
5. Confirm the `@CoC-MS/security-template-maintainers` CODEOWNERS team exists
   and has appropriate review access; update CODEOWNERS to an authoritative
   team if it does not.
6. Approve a public-safe attestation issuer identity and verification policy.
   Binding validation to a private repository/workflow would disclose internal
   architecture; this repository intentionally does not invent or expose that
   identity.
