# Contributing

Thank you for improving ALSO Security Templates.

## Choose the contribution path

- Report defects, requests, and documentation corrections with the repository
  issue forms. Never include customer or tenant data.
- Propose changes to governance, schemas, validation, or documentation in a
  normal pull request.
- Published artifacts are accepted only through the controlled publication
  process described in
  [docs/PUBLICATION_CONTRACT.md](docs/PUBLICATION_CONTRACT.md). Do not hand-edit
  generated paths.

## Pull request requirements

1. Keep changes focused and explain user-visible impact and compatibility.
2. Use synthetic, sanitized test data only. Do not commit tenant exports,
   identifiers, credentials, internal URLs, customer names, or private logs.
3. Update relevant documentation and tests.
4. Run `pwsh -NoProfile -File scripts/Validate-Publication.ps1` and
   `pwsh -NoProfile -File tests/Invoke-SelfTest.ps1`.
5. Obtain required CODEOWNER review. Authors cannot approve their own changes.

Artifact publication pull requests must include the
`<!-- generated-publication -->` marker and the publication report sections
defined by the publication contract. Publication automation may modify only
`templates/**`, `catalog.json`, and `generated-manifest.json`.

## Security

Do not disclose vulnerabilities publicly. Follow [SECURITY.md](SECURITY.md).
The security reporting address is an unresolved administrator setup item until
the placeholder in that file is replaced with an authoritative private channel.
