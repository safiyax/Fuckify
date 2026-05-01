# Feature Flags API Integration
## Overview
Implement a feature flagging system that fetches boolean flags from a remote API based on the app's version, build number, and platform.
## API Endpoint
GET https://dev.coitalcomra.de/api/feature-flags
## Required Query Parameters
- `version` - App version in semver format (e.g., `"1.0.0"`)
- `build` - Build number as integer (e.g., `1`)
- `platform` - Platform identifier, must be `"ios"` or `"android"`
## Example Request
```swift
let url = URL(string: "https://dev.coitalcomra.de/api/feature-flags?version=1.0.0&build=1&platform=ios")!
Response Format
The API returns a flat JSON object where:
- Keys are dot-separated feature flag identifiers
- Values are booleans (true = enabled, false = disabled)
{
  "settings.personalization.appIconPicker": false,
  "settings.personalization.activities": true,
  "settings.personalization.protectionMethods": true,
  "settings.personalization.positions": true,
  "settings.personalization.security": true,
  "settings.data.importExport": true,
  "settings.data.deleteData": true,
  "settings.more.about": true,
  "settings.more.supportApp": true,
  "settings.more.experiments": false,
  "settings.more.debugMenu": false,
  "settings.data.importExport.csvImportPartners": false,
  "settings.data.importExport.csvImportEncounters": false,
  "settings.data.importExport.csvExportPartners": false,
  "settings.data.importExport.csvExportEncounters": false,
  "settings.data.importExport.importDatabase": true,
  "settings.data.importExport.exportDatabase": true,
  "settings.personalization.appIconPicker.spicyIcons": false
}
Current Feature Flags (18 total)
Settings > Personalization
- settings.personalization.appIconPicker - Show app icon picker
- settings.personalization.activities - Show activities row
- settings.personalization.protectionMethods - Show protection methods row
- settings.personalization.positions - Show positions row
- settings.personalization.security - Show security row
- settings.personalization.appIconPicker.spicyIcons - Show spicy icons in app icon picker
Settings > Data
- settings.data.importExport - Show Import & Export row
- settings.data.deleteData - Show Delete Data row
Settings > Data > Import/Export (sub-features)
- settings.data.importExport.csvImportPartners - CSV import partners option
- settings.data.importExport.csvImportEncounters - CSV import encounters option
- settings.data.importExport.csvExportPartners - CSV export partners option
- settings.data.importExport.csvExportEncounters - CSV export encounters option
- settings.data.importExport.importDatabase - Database import option
- settings.data.importExport.exportDatabase - Database export option
Settings > More
- settings.more.about - Show About row
- settings.more.supportApp - Show Support row
- settings.more.experiments - Show Experiments row
- settings.more.debugMenu - Show Developer/Debug Menu
Error Handling
- 404: No feature flag configuration exists for the specified version/build/platform combination
- 400: Missing or invalid query parameters
- 500: Server error
Implementation Requirements
1. Service Layer: Create a FeatureFlagsService that:
   - Fetches flags on app launch
   - Caches the response locally
   - Provides a lookup method: isEnabled(_ key: String) -> Bool
   - Has a safe default (return false if flag not found or network fails)
2. Model: Create a FeatureFlags type to decode the response
      typealias FeatureFlags = [String: Bool]
   
3. Usage Pattern: Flags should be checked at UI render time
      if featureFlags.isEnabled("settings.personalization.appIconPicker") {
       // Show app icon picker row
   }
   
4. Naming Convention: 
   - Flags use dot-notation hierarchy: <area>.<section>.<feature>.<variant>
   - Represents logical feature grouping, not UI presentation details
   - Example: settings.data.importExport.csvImportPartners
5. Version/Build Source:
   - version: Bundle.main.infoDictionary?["CFBundleShortVersionString"]
   - build: Bundle.main.infoDictionary?["CFBundleVersion"]
   - platform: Always "ios" for iOS app
Nice-to-Haves
- Periodic background refresh
- Offline fallback (last cached response)
- Debug UI to view/override flags in dev builds (already built just needs to be updated from posthog impl)
- Type-safe flag keys via enum
