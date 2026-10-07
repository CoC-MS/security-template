# Config overview - Shared - Full

This package contains all resources classified as Shared, for every tier and licence.

> [!WARNING]
> Shared is supporting content and is already included in the whole-build Full package. Do not import both. Microsoft Intune imports can create duplicate policies rather than reconcile packages.

This package contains cross-platform, tenant-wide, and unknown-platform resources, including resources without tier and licence markers.

WARNING: The platform could not be determined for 4 file(s). Review the unknownPlatformFiles list in build-manifest.json before import.

Workload folders are directly inside this Shared package; import only the supporting resources required by your deployment. Review tenant-specific values, licences, dependencies, and assignments before import. Do not bulk import assignments. Import to a pilot group and validate the outcome before wider deployment.
