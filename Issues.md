# How to report issues

Use GitHub issues to report non-sensitive problems, suggest improvements, or
correct public guidance in ALSO Security Templates.

**Do not report suspected security vulnerabilities in public issues.** Follow
the private reporting process in [SECURITY.md](SECURITY.md) instead. For usage
questions and implementation guidance, see [SUPPORT.md](SUPPORT.md).

## Before you start

Read the affected template's README and check its prerequisites, supported
platforms, licensing guidance, and deployment instructions. Search
[existing issues](https://github.com/CoC-MS/security-template/issues), including
closed issues, for the same problem. If a matching issue exists, add relevant,
sanitized details there rather than opening a duplicate.

Use a dedicated test environment when reproducing a problem. Do not make
changes in production solely to gather information for a report.

## Choose the right form

Open the [issue form chooser](https://github.com/CoC-MS/security-template/issues/new/choose)
and select the form that best matches your report:

| Form | When to use it |
| --- | --- |
| Bug report | A reproducible problem with a template, policy, script, import or export process, validation, workflow, or deployment tooling. |
| Feature or policy request | A new capability, configuration policy, automation, validation check, integration, or improvement to existing content. |
| Documentation or licensing correction | Inaccurate, missing, outdated, or unclear guidance, including broken links and licensing information. |

## Prepare your report

### Bug report

Include the affected solution area and component, the repository file path or
artifact ID, and the release tag, commit, or package version you used. Repository
release tags use `publication-v<major>.<minor>.<patch>`; for an individual
artifact, also include its version from `metadata.json` when available.

Describe your deployment method, relevant Microsoft license, and target
platform or operating system. Explain what you expected, what actually
happened, and the impact.

Provide the minimum numbered steps needed to reproduce the problem, relevant
sanitized error output, and any troubleshooting or workarounds already tried.
State whether you reproduced it in a test tenant; select **No** or **Not tested**
if you have not. Do not claim a reproduction you have not performed.

Describe operational effects on protection, compliance, access, or monitoring
without disclosing sensitive details. If you suspect a vulnerability, stop and
use [private vulnerability reporting](SECURITY.md) instead.

### Feature or policy request

Explain the general problem, the capability or policy you propose, and who
would use it. Include a sanitized example use case and the expected outcome.
Note any known license requirements, permissions, dependencies, policy
conflicts, or security considerations. If none are known, say so.

Indicate whether you can help test, contribute documentation or code, or
provide feedback.

### Documentation or licensing correction

Identify the document, file, heading, or public page URL and affected Microsoft
product. Summarize the current guidance, propose a correction, and explain why
it matters.

Include a public Microsoft Learn or other authoritative reference where
available, or enter **Not available**. Give the relevant public license or
subscription name, or **Not applicable**. Do not attach confidential agreements
or non-public pricing.

## Check for sensitive information

Review every field, code block, screenshot, and attachment before submitting.
Use synthetic examples rather than customer exports. Remove customer names,
tenant identifiers, user details, internal URLs, credentials, secrets, access
tokens, certificates, private configuration exports, and sensitive logs.
Include only the minimum error output needed to explain the problem.

If troubleshooting requires private operational or customer data, use your
organization's established secure support channel instead of this repository.

## Submit and follow up

1. Sign in to GitHub and open the selected form.
2. Keep the form's title prefix and add a short, specific description.
3. Complete all required fields and the confirmations that you checked
   existing issues and removed sensitive information.
4. Review the report, then submit it.
5. Watch for maintainer questions and add sanitized follow-up information to
   the same issue, including any workaround or resolution you discover.
