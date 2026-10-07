# Device Health Scripts Naming Convention

Use this format for each Device Health Script set:

```text
<Licence> - <Company> - <Impact> - <Tier> - <Version> - <Platform> - <Category> - <Policy purpose>
```

Use ` - ` as the separator. Do not use `/` because Intune does not support it in policy names.

| Field | Meaning | Example |
| --- | --- | --- |
| `Licence` | Licence requirement for the script | `E3-E5`, `E5` |
| `Company` | Company that provides the template | `ALSO` |
| `Impact` | Expected implementation impact | `LI`, `MI`, `HI` |
| `Tier` | Baseline tier | `Basic`, `Adv` |
| `Version` | Script version | `v1.0` |
| `Platform` | Target operating system or platform | `Windows` |
| `Category` | Intune or security area | `Defender`, `HPConnect` |
| `Policy purpose` | Concise description of the remediation | `Disable AutoRun` |

## Example

```text
E3-E5 - ALSO - LI - Adv - v1.0 - Windows - Defender - Secure Score - Disable AutoRun
```

The Device Health Script set must use the same base name:

```text
E3-E5 - ALSO - LI - Adv - v1.0 - Windows - Defender - Secure Score - Disable AutoRun.json
E3-E5 - ALSO - LI - Adv - v1.0 - Windows - Defender - Secure Score - Disable AutoRun_DetectionScript.ps1
E3-E5 - ALSO - LI - Adv - v1.0 - Windows - Defender - Secure Score - Disable AutoRun_RemediationScript.ps1
```

## Required consistency

1. The JSON filename uses the complete script name plus `.json`.
2. The JSON `displayName` exactly matches the filename without `.json`.
3. The detection and remediation filenames use that same base name and their respective suffixes.
4. Every embedded script-name reference in the JSON `description` uses the same licence-first order.

Do not include lifecycle or legacy prefixes such as `NS` in filenames, JSON `displayName`, or JSON `description`.
