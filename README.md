# ALSO Security Templates
## About the Security Templates

The ALSO Security Templates project is designed to help partners implement
Microsoft security solutions faster, more consistently and at scale.

The repository brings together tested configuration templates, policies,
scripts, automation and practical documentation for Microsoft Intune,
Defender, Purview, and Entra. Instead of starting every customer implementation from
scratch, partners can use the project as a structured starting point and
adapt the content to the customer's requirements.

Our goal is to reduce repetitive configuration work, simplify deployment
and make Microsoft security capabilities easier to adopt across customer
environments.

The project is built around three principles:

- **Make deployment easier** by providing ready-to-use starting points
- **Improve consistency** through reusable and tested configurations
- **Help partners scale** by reducing the time required for each implementation

The templates are deployment accelerators, not universal configurations.
Partners remain responsible for reviewing, testing and adapting the content
before deploying it in a customer environment.

## Who this project is for

The ALSO Security Templates project is intended primarily for:

- Microsoft partners
- Managed service providers
- Security consultants
- Microsoft 365 administrators
- Endpoint and identity administrators
- Technical teams responsible for customer implementation and operations

The project assumes that the implementing partner understands the relevant
Microsoft products and can evaluate the impact of configuration changes in
a customer environment.

The templates do not replace technical assessment, solution design,
professional judgement or customer-specific implementation planning.

## Published artifact contract

Public artifacts are published under
`templates/<solution-area>/<component>/<stable-artifact-id>/`. Each artifact
contains `template.json`, `metadata.json`, and `README.md`, with optional
deployment files or scripts. The generated `catalog.json` and
`generated-manifest.json` provide discovery and integrity information.

The supported solution-area path names are `intune`, `defender`, `purview`,
and `entra`. See [the publication contract](docs/PUBLICATION_CONTRACT.md) for
the stable-ID, versioning, compatibility, documentation, and generated-path
rules. Governance files, schemas, validation, and repository policy remain
hand-maintained.

The catalog is currently empty while the first controlled artifact publication
is prepared. Once populated, start with [`catalog.json`](catalog.json), follow
an artifact's `path` to its public `README.md`, review its metadata and
prerequisites, and use only the deployment/import procedure documented there.
Validator fixtures under `tests/fixtures/**` are synthetic test data and are
not published artifacts.

Repository releases use immutable `publication-v<major>.<minor>.<patch>` tags.
See the [release process](docs/RELEASE_PROCESS.md) for the human approval,
versioning, validation, and verification requirements.

## Important usage notice

The ALSO Security Template provides tested configuration templates,
policies, scripts, automation and supporting documentation intended
to accelerate Microsoft security deployments.

ALSO makes reasonable efforts to test and validate the content before
it is published. However, every customer environment is different.
Licensing, existing configurations, integrations, device platforms,
network architecture, regulatory requirements and other environmental
variables may affect how the solution operates.

ALSO cannot guarantee that the content is suitable for every customer
environment or that it will operate without errors, interruptions,
conflicts or unintended effects.

## The implementing partner is responsible for:

- Reviewing the configuration, policy or script
- Confirming product licensing and technical prerequisites
- Assessing compatibility with the customer's existing environment
- Testing the content in a dedicated test or pilot environment
- Planning an appropriate staged rollout
- Monitoring the results and validating the intended outcome
- Maintaining a documented rollback or recovery plan

The partner should not deploy the solution directly across an entire
production environment without prior validation.

Use of this project is at the user's own risk. To the extent permitted
by applicable law, ALSO is not liable for loss, damage, service
interruption, data loss, configuration changes, security incidents or
other consequences resulting from the use or application of this
project.

This notice does not replace the terms and conditions of the Apache
License 2.0. If there is a conflict, the Apache License 2.0 governs.

## Recommended deployment approach

All templates, policies and scripts should follow a controlled deployment
process:

1. **Review**  
   Understand what the configuration changes, which services it affects
   and which licences or prerequisites it requires.

2. **Test**  
   Deploy the content in a dedicated test tenant or non-production
   environment.

3. **Pilot**  
   Apply the change to a small and representative pilot group.

4. **Validate**  
   Confirm that the expected security and operational outcomes are
   achieved without conflicts or unintended effects.

5. **Roll out**  
   Expand the deployment gradually using a controlled, staged approach.

6. **Monitor**  
   Monitor deployment status, user impact, alerts and operational results.

7. **Recover**  
   Maintain a documented rollback or recovery approach for each
   production deployment.

## Reporting issues

Partners, consultants, administrators, and contributors can use the [issue forms](../../issues/new/choose) to report bugs, request improvements, or correct documentation and licensing guidance.

Choose the form that best matches your report:

- **Bug report** - for reproducible problems with templates, scripts, validation, deployment tooling, or documentation.
- **Feature or policy request** - for a new capability, configuration policy, automation, validation check, or integration.
- **Documentation or licensing correction** - for inaccurate, missing, outdated, or unclear public guidance.

Before submitting, search existing issues to avoid duplicates. Include only the details needed to understand and reproduce the problem, using a sanitized test example where possible.

Do not include customer information, tenant identifiers, user details, credentials, secrets, access tokens, certificates, or sensitive logs. Do not report security vulnerabilities in a public issue; follow the repository's private reporting process in `SECURITY.md`. For usage questions and implementation guidance, see `SUPPORT.md`.

## Disclaimer and limitation of liability

The materials in this repository, including policies, configuration
templates, scripts, automation, documentation and examples, are provided
on an "as is" and "as available" basis.

Although ALSO performs testing and validation before publication, ALSO
does not warrant or guarantee that the materials are error-free, suitable
for a particular purpose, compatible with every customer environment or
capable of producing a specific security, compliance or operational
outcome.

Customer environments may contain variables outside ALSO's knowledge or
control, including existing configurations, third-party products,
licensing limitations, unsupported platforms, network dependencies,
regulatory requirements and changes to Microsoft products or services.

The implementing partner is responsible for evaluating the materials,
confirming all prerequisites and dependencies, testing in a non-production
environment, conducting a controlled pilot, planning a staged rollout and
maintaining appropriate rollback and recovery procedures.

To the extent permitted by applicable law, ALSO shall not be liable for
any direct, indirect, incidental, special, consequential or other loss or
damage arising from the use of, inability to use or deployment of the
materials in this repository.

This disclaimer supplements the Apache License 2.0. It does not replace,
amend or override the terms contained in the LICENSE file.
