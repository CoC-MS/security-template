# 🛡️ ALSO Security Template

> A collection of Microsoft Intune policy exports and supporting artifacts designed to help partners accelerate secure, managed endpoint deployments across Windows, Windows Server, macOS, iOS/iPadOS, Android, and Linux.
>
> **Works with Microsoft 365 Business Premium and higher licences, depending on the policy.**

---

> [!IMPORTANT]
> **⚠️ Read this before importing policies.**
>
> Every export is a starting point. Review settings, tenant-specific values, licences, dependencies, and assignments before deployment. Import policies to a pilot group first and validate their outcome before expanding assignments.

| Resource | Description |
| --- | --- |
| 📖 **Naming Convention** | See [Policy naming](#-policy-naming) for the standard format and exceptions. |
| 🚀 **Before Importing** | See [Before importing](#-before-importing) for import order and configuration requirements. |
| 📥 **How to Import** | See [How to import](#-how-to-import) for the Intune Management Tool workflow. |
| 🪟 **Windows Server** | Copy the server-specific policy exports from [`Windows Server/SettingsCatalog`](Windows%20Server/SettingsCatalog). |
| ⚙️ **Settings Catalog** | See [Settings Catalog naming](SecurityTemplateDev/SettingsCatalog/NAMING-CONVENTION.md). |
| 🩺 **Device Health Scripts** | See [Device Health Scripts naming](SecurityTemplateDev/DeviceHealthScripts/NAMING-CONVENTION.md). |

---

## 📂 File structure

The template is organized by Intune workload:

```text
SecurityTemplateDev/
├── AdministrativeTemplates/
├── ADMXFiles/
├── AppConfigurationManagedApp/
├── AppConfigurationManagedDevice/
├── Applications/
├── AppProtection/
├── AssignmentFilters/
├── AuthenticationContext/
├── AuthenticationStrengths/
├── AutoPilot/
├── CompliancePolicies/
├── ComplianceScripts/
├── DeviceConfiguration/
├── DeviceHealthScripts/
├── DriverUpdateProfiles/
├── EnrollmentStatusPage/
├── HardwareConfigurations/
├── PolicySets/
├── PowerShellScripts/
├── QualityUpdatePolicies/
├── ReusableSettings/
├── SettingsCatalog/
└── UpdatePolicies/

Windows Server/
└── SettingsCatalog/
```

## 📦 Endpoint Configuration builds

Use `tools/New-EndpointConfigurationBuild.ps1` to generate import packages. The
reviewed source remains in `SecurityTemplateDev`, but every generated package
uses `EndpointConfiguration` as its root directory and preserves the workload
folder structure shown above.

```powershell
pwsh ./tools/New-EndpointConfigurationBuild.ps1
```

The default command creates `Basic-BP`, `Basic-E3-E5`, `Basic-E5`, `Adv-BP`,
`Adv-E3-E5`, `Adv-E5`, and `Full` packages under
`out/endpoint-configuration`. Licence builds are cumulative: `E3-E5` includes
`BP`, and `E5` includes `BP` and `E3-E5`. Basic and Adv packages contain only
files explicitly marked with both the matching tier and a supported licence.
Shared or unclassified resources are intentionally available only in Full.

> [!WARNING]
> **Choose one package for a tenant. Do not combine Basic, Adv, and Full, or
> import Full after another package.** Intune imports can create duplicate
> policies rather than reconcile packages. Each generated package includes a
> `BUILD-INFO.md` with the same warning and its exact scope.

Windows Server policies remain separate and are not included in these endpoint
configuration packages.

## 🌐 Platform coverage

The template contains configurations for the following platforms. Availability depends on the individual Intune workload and policy.

| Platform | Typical template content |
| --- | --- |
| 🪟 **Windows** | Configuration, security baseline, Defender, update rings, Autopilot, scripts, and hardware configuration. |
| 🖥️ **Windows Server** | Separate Settings Catalog exports for Windows Server security and Defender configurations. |
| 🍎 **macOS** | Device configuration, Microsoft Defender, Microsoft Edge, disk encryption, firewall, and single sign-on settings. |
| 📱 **iOS/iPadOS** | Device restrictions, passcode, VPN, update, and enrollment policies. |
| 🤖 **Android** | Enterprise and BYOD device configuration, enrollment, and security controls. |
| 🐧 **Linux** | Selected endpoint security configurations where supported by Intune. |

### Windows Server

Windows Server policies are intentionally kept outside `SecurityTemplateDev` in [`Windows Server/SettingsCatalog`](Windows%20Server/SettingsCatalog). This lets partners copy and paste the server-specific exports independently, without mixing them with workstation policies.

## ✨ Notable capabilities

- **Weekly scheduled restart:** a Windows Settings Catalog policy schedules an automatic reboot at 00:00 every Wednesday.
- **Automatic disk cleanup:** a Windows Settings Catalog policy cleans files in Downloads and Recycle Bin that have not been used for 365 days.
- **Windows Hotpatch:** the template includes Hotpatch remediation, VBS prerequisite settings, and the Windows Hotpatch quality-update policy used with Windows Autopatch.

## 📖 Policy naming

Most policy exports use this format:

```text
<Licence> - <Company> - <Impact> - <Tier> - <Version> - <Platform> - <Category> - <Policy purpose> - <Scope>
```

### Naming components

| Component | Description | Examples |
| --- | --- | --- |
| `Licence` | Minimum licence requirement | `BP`, `E3-E5`, `E5` |
| `Company` | Template provider | `ALSO` |
| `Impact` | Expected implementation impact | `LI`, `MI`, `HI` |
| `Tier` | Baseline tier | `Basic`, `Adv` |
| `Version` | Policy version | `v1.0`, `v3.6` |
| `Platform` | Target platform | `Windows`, `macOS`, `Android` |
| `Category` | Intune or security area | `Device Security`, `Defender` |
| `Policy purpose` | What the policy configures | `Disable AutoRun` |
| `Scope` | Assignment scope when applicable | `D`, `U` |

`D` identifies a device-targeted policy and `U` identifies a user-targeted policy. Use ` - ` as the separator; do not use `/` because Intune does not support it in policy names.

### Short-name exceptions

Some Intune resources have restrictive name-length limits. Compliance policies, assignment filters, and similar general resources therefore use a shorter `ALSO`-prefixed name rather than the complete convention. The short name is intentional and allows successful Intune import and management.

Autopilot profiles are also an exception. Intune requires underscore-delimited names:

```text
<Licence>_<Company>_<Impact>_<Tier>_<Version>_<Platform>_Autopilot Profile_<Purpose>
```

## 🚀 Before importing

1. Review each policy's settings and description, especially tenant-specific values, assignments, update rings, and security controls.
2. Import required ADMX files from `SecurityTemplateDev/ADMXFiles` before importing Administrative Template policies that depend on them.
3. Configure the OneDrive ShortPath Administrative Template for the customer's intended OneDrive folder path before assigning it. It requires the OneDrive and Windows ADMX files.
4. Copy Windows Server exports from `Windows Server/SettingsCatalog` only when deploying to Windows Server.
5. Import to a pilot group, validate the result in Intune, then expand assignments in stages.

## 📥 How to import

This template uses the same import workflow as the ALSO Microsoft Security Conditional Access templates: [Micke M Intune Management Tool](https://github.com/Micke-K/IntuneManagement).

1. Download and extract the Intune Management Tool.
2. Start `start.cmd`. The tool opens a command window and its web interface; local administrator rights are not required on Windows or macOS.
3. Select the sign-in icon in the upper-right corner and authenticate to the target Microsoft Intune tenant with an account that has the required Intune permissions.
4. Import the required ADMX files from `SecurityTemplateDev/ADMXFiles` before importing dependent Administrative Template policies.
5. In the tool, browse to the reviewed export file and import the matching JSON resource. For Device Health Scripts, keep each JSON file with its paired `_DetectionScript.ps1` and `_RemediationScript.ps1` files.
6. Review the imported policy in Intune before assignment. Update tenant-specific values, groups, filters, OneDrive folder paths, update rings, and scope as required.
7. Assign the policy to a pilot group. Confirm the deployment result and user impact before expanding to production.

> [!WARNING]
> Bulk importing the template without assignments is supported. Do not bulk import assignments: policies can contain security controls, restart behavior, update deadlines, and tenant-specific values that must be reviewed and approved before assignment to the target environment.
