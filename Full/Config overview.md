# Config overview - All - Full

This package contains all resources across every platform, tier, and licence.

> [!WARNING]
> This whole-build package includes every platform and Shared resources. Do not import it together with a platform package, Shared, or another Full package. Microsoft Intune imports can create duplicate policies rather than reconcile packages.

This package includes every platform, including shared and unknown-platform resources.

WARNING: The platform could not be determined for 4 file(s). Review the unknownPlatformFiles list in build-manifest.json before import.

Platform folders are directly inside this whole-build package; the separate Shared package remains available as supporting content. Review tenant-specific values, licences, dependencies, and assignments before import. Do not bulk import assignments. Import to a pilot group and validate the outcome before wider deployment.
