# Public artifact publication contract

## Scope and ownership

This repository is the public distribution boundary for reusable Microsoft
Intune, Defender, Purview, and Entra deployment accelerators. It must contain
no customer exports or internal publication-system details.

| Path | Owner | Rule |
|---|---|---|
| `templates/<solution-area>/<component>/<stable-artifact-id>/**` | Publication automation | Generated; never edited by hand |
| `catalog.json` | Publication automation | Generated discovery index |
| `generated-manifest.json` | Publication automation | Generated integrity and provenance record |
| `schemas/**` | Repository maintainers | Hand-maintained public contract |
| `scripts/**`, `tests/**`, `.github/**` | Repository maintainers | Hand-maintained validation and governance |
| `README.md`, `CONTRIBUTING.md`, `SECURITY.md`, `SUPPORT.md`, `docs/**`, `LICENSE` | Repository maintainers | Hand-maintained governance and guidance |

Publication automation must fail rather than modify a hand-maintained path.
Human governance pull requests must not edit generated paths. A pull request
combining both classes must be split.

## Artifact layout and identity

The canonical path is:

```text
templates/<solution-area>/<component>/<stable-artifact-id>/
  template.json
  metadata.json
  README.md
  deployment/       # optional
  scripts/          # optional
```

Solution-area path values are `intune`, `defender`, `purview`, and `entra`.
Components and stable IDs use lowercase ASCII kebab-case. A stable artifact ID
is globally unique, opaque to mutable product branding, and never reused. It
must equal `metadata.json`'s `id`; solution area and component must also match
the path.

A rename changes display text, not the ID or path. If a path must change, the
old artifact is deprecated and a new ID is published with an explicit
replacement relationship. Silent moves are prohibited.

## Required files

- `template.json` is the sanitized deployable configuration. It must not
  contain live tenant identifiers or environment-specific values.
- `metadata.json` conforms to
  [`schemas/artifact-metadata.schema.json`](../schemas/artifact-metadata.schema.json).
- `README.md` documents Summary, Deployment, Validation, Pilot, Rollback, and
  Limitations. It must explain operator-visible effects and safe adoption.
- Optional deployment inputs conform to
  [`schemas/deployment-inputs.schema.json`](../schemas/deployment-inputs.schema.json).
- Optional scripts must be non-interactive, syntax-valid, least-privilege,
  fail on errors, and avoid downloading or executing unverified content.

Metadata records stable ID, schema and artifact versions, solution area,
component, platform/scope/impact, prerequisites, licensing, permissions,
dependencies and incompatibilities, deployment, validation, pilot, rollback,
compatibility, limitations, public Microsoft references, last validation date,
and public-safe checksums/provenance.

## Versions and compatibility

Artifact versions use SemVer:

- **Patch**: documentation, metadata, or implementation correction with no
  intended deployment behavior change.
- **Minor**: backward-compatible capability or optional input.
- **Major**: behavior, required input, permission, scope, or rollback change
  requiring operator review or migration.

`schemaVersion` is versioned independently. Compatibility metadata declares
supported products/platforms and any minimum versions. Deprecation requires a
reason, date, replacement ID when available, and at least one published minor
release of notice before removal. Emergency security or legal removal may
shorten that period but must be explicit in the manifest and pull request.

Removal is never inferred from absence. A publication is merged over the full
protected-branch inventory: artifacts not present in an incoming partial
bundle remain unchanged in the tree and catalog. Every deleted generated path must have
a `generated-manifest.json` removal event containing the artifact ID, prior
version, accountable owner, reason, and effective date. Reviewers must specifically approve
generated-path deletions. Removed IDs cannot be reused.
The public validator compares removal IDs and prior versions with metadata from
the protected base revision, and rejects duplicate, fabricated, or unused
removal events. `catalog.json` and `generated-manifest.json` cannot be deleted.

## Deterministic publication

Generated text uses UTF-8 without BOM, LF line endings, stable property/order
rules, and a trailing newline. Catalog artifacts are ordered by stable ID;
manifest files are ordered by normalized path and removals by stable ID. The
manifest declares every generated file except itself and records its exact byte
length and lowercase SHA-256 digest. No undeclared generated file is permitted.
`catalog.json` is derived from metadata and must not carry private source-system
identifiers.

Public provenance is limited to a publisher name, public repository/revision
when appropriate, publication timestamp, and content digests. Internal
repository names, workflow URLs, runner paths, tenant IDs, build logs, and
employee/customer identities are prohibited.

File hashes and provenance fields carried in the pull request are
self-attestations, not proof of origin. The public validator recomputes hashes
from checked-out bytes and verifies structural consistency. A cryptographic
upstream identity binding remains a blocking administrator decision: before
claiming source authenticity, administrators must approve a public-safe GitHub
OIDC/artifact-attestation issuer identity and enforce verification against the
protected-base policy. The internal repository/workflow identity must not be
published merely to satisfy that check. Until then, verified properties are
only content integrity, schema/semantic validity, and the public Git history;
the upstream publisher identity is trusted by review and branch controls.

The generated path allowlist lives in the CODEOWNER-protected
`.github/publication-path-policy.json`. Pull-request validation loads this
policy and validator from the protected base revision when available, so a
publisher cannot expand its own write scope. Every publication change must
match exactly one allowlist expression.

## Generated pull requests

The publisher opens a pull request; it never pushes directly to the protected
branch. A generated pull request uses the title prefix
`[Generated publication]`, includes `<!-- generated-publication -->`, and has
these report headings:

```markdown
## Publication summary
## Artifacts
## Removals
## Validation
```

Use `None` under Removals when no artifacts are removed. The report describes
public outcomes only and must not reveal internal repository, workflow, tenant,
or operator details. The same leakage and public-link checks applied to
generated files also apply to the pull request title and body. Independent
public-repository validation recomputes all
checksums and does not trust an internal validation result.
