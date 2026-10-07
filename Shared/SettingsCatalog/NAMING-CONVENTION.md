# Settings Catalog Naming Convention

Use this format for every Settings Catalog policy:

```text
<Licence> - <Company> - <Impact> - <Tier> - <Version> - <Platform> - <Category> - <Policy purpose> - <Scope>
```

Use ` - ` as the separator. Do not use `/` because Intune does not support it in policy names.

| Field | Meaning | Example |
| --- | --- | --- |
| `Licence` | Licence requirement for the policy | `BP`, `E3-E5` |
| `Company` | Company that provides the template | `ALSO` |
| `Impact` | Expected implementation impact | `LI`, `MI`, `HI` |
| `Tier` | Baseline tier | `Basic`, `Adv` |
| `Version` | Policy version | `v1.0` |
| `Platform` | Target operating system or platform | `Windows`, `Android Enterprise`, `macOS` |
| `Category` | Intune configuration area | `Device Security`, `Microsoft Edge` |
| `Policy purpose` | Concise description of the configuration | `Threat Scan` |
| `Scope` | Assignment scope | `D`, `U` |

## Example

```text
BP - ALSO - LI - Basic - v1.0 - Android Enterprise - Device Restriction - Threat Scan - D
```

The corresponding file must be named:

```text
BP - ALSO - LI - Basic - v1.0 - Android Enterprise - Device Restriction - Threat Scan - D.json
```

## Required consistency

For each policy, keep the following values synchronized:

1. The `.json` filename uses the complete policy name plus `.json`.
2. The JSON `name` value exactly matches the filename without `.json`.
3. Every policy-name reference in the JSON `description` uses the same value as `name`.

Do not include lifecycle or legacy prefixes such as `[TESTING]` or `NS` in the filename, JSON `name`, or JSON `description`.
