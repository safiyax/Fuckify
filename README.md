# Fuckify

A private, personal sexual health and encounter tracking iOS application built with SwiftUI and SwiftData.

## Overview

Fuckify is a comprehensive iOS app designed to help users track their sexual health, partners, and encounters in a private and organized manner. All data is stored locally on your device with optional iCloud sync via CloudKit.

## Features

### Partner Management
- Add and manage sexual partners with detailed information
- Track partner details including:
  - Contact information (phone number)
  - PrEP status
  - Relationship type (Casual, Regular, Committed, One-Time, Other)
  - Date met
  - Personal notes
  - Color-coded avatars with initials
- Automatic tracking of last encounter date
- CSV import for bulk partner creation

### Encounter Tracking
- Log sexual encounters with comprehensive details:
  - Date of encounter
  - Duration
  - Activities (Oral, Vaginal, Anal, Manual, Kissing, Other)
  - Protection methods used (Condom, PrEP, Pull Out, None, Other)
  - Location
  - Rating (1-5 stars)
  - Orgasm tracking
  - Associated partners (supports multiple partners per encounter)
  - Personal notes
- CSV import for bulk encounter creation (automatically creates missing partners)

### Statistics & Insights
- Total encounter count
- Partner count
- Average encounter duration
- Recent activity (30-day view)
- Most common activities
- Most common protection methods
- Most frequent partner
- Average rating

### User Profile
- Personal information tracking:
  - Name and date of birth
  - PrEP status
  - Last STI test date
  - Personal notes

### Customization
- Customize which activities appear in encounter forms
- Customize which protection methods appear in encounter forms
- Manual color selection for partner avatars

### Data Management
- CSV import for bulk partner and encounter creation
- CSV export for data backup and migration
- Share exported data via AirDrop, email, or cloud storage
- Exported files are compatible with spreadsheet applications

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd Fuckify
```

2. Open the project in Xcode:
```bash
open Fuckify.xcodeproj
```

3. Build and run the project (⌘R)

## Data Models

### Partner
- **name**: String (required)
- **phoneNumber**: String (optional)
- **notes**: String (optional)
- **isOnPrep**: Boolean
- **relationshipType**: Enum (Casual, Regular, Committed, One-Time, Other)
- **dateMet**: Date (optional)
- **avatarColor**: String (auto-assigned, manually selectable)
- **dateAdded**: Date (auto)
- **lastEncounterDate**: Date (auto-updated)

### Encounter
- **date**: Date (required)
- **duration**: TimeInterval (in seconds)
- **activities**: Array of ActivityType
- **protectionMethods**: Array of ProtectionMethod
- **location**: String (optional)
- **notes**: String (optional)
- **rating**: Int (0-5)
- **reachedOrgasm**: Boolean
- **partners**: Array of Partner (optional, auto-creates if missing during import)
- **dateAdded**: Date (auto)

### ActivityType
Enum: `Oral`, `Vaginal`, `Anal`, `Manual`, `Kissing`, `Other`

### ProtectionMethod
Enum: `Condom`, `PrEP`, `PullOut`, `None`, `Other`

### RelationshipType
Enum: `Casual`, `Regular`, `Committed`, `OneTime`, `Other`

## CSV Import

### Partner Import Format

**CSV Header:**
```csv
name,phoneNumber,notes,isOnPrep,relationshipType,dateMet
```

**Example:**
```csv
name,phoneNumber,notes,isOnPrep,relationshipType,dateMet
John Doe,555-0123,Met at gym,true,Regular,2024-01-15
Jane Smith,555-0124,Friend of a friend,false,Casual,2024-02-20
```

**Field Details:**
- `name`: Required
- `phoneNumber`: Optional
- `notes`: Optional
- `isOnPrep`: `true` or `false` (optional, defaults to false)
- `relationshipType`: `Casual`, `Regular`, `Committed`, `One-Time`, or `Other` (optional, defaults to Casual)
- `dateMet`: YYYY-MM-DD format (optional)

### Encounter Import Format

**CSV Header:**
```csv
date,duration,activities,protectionMethods,location,notes,rating,reachedOrgasm,partnerNames
```

**Example:**
```csv
date,duration,activities,protectionMethods,location,notes,rating,reachedOrgasm,partnerNames
2024-01-15,30,"Oral, Kissing",Condom,Home,Great time,5,true,John Doe
2024-01-20,45,"Vaginal, Manual","Condom, PrEP",Hotel,Amazing night,5,true,"John Doe, Jane Smith"
2024-02-01,20,Oral,None,Home,,3,false,Jane Smith
```

**Field Details:**
- `date`: YYYY-MM-DD format (required)
- `duration`: Minutes (optional)
- `activities`: Comma-separated values in quotes (Oral, Vaginal, Anal, Manual, Kissing, Other) - optional
- `protectionMethods`: Comma-separated values in quotes (Condom, PrEP, Pull Out, None, Other) - optional
- `location`: Text (optional)
- `notes`: Text (optional)
- `rating`: 1-5 (optional)
- `reachedOrgasm`: `true` or `false` (optional, defaults to false)
- `partnerNames`: Comma-separated names in quotes (optional, automatically creates partners if they don't exist)

**Note:** For fields containing commas (activities, protectionMethods, partnerNames), wrap the entire field in quotes.

## CSV Export

The app provides CSV export functionality for both partners and encounters, accessible from Settings > Import & Export.

### Partner Export

Exports all partners to a CSV file with the following format:
```csv
name,phoneNumber,notes,isOnPrep,relationshipType,dateMet
```

The exported file can be:
- Saved to Files app
- Shared via AirDrop
- Sent via email or messages
- Uploaded to cloud storage

### Encounter Export

Exports all encounters to a CSV file with the following format:
```csv
date,duration,activities,protectionMethods,location,notes,rating,reachedOrgasm,partnerNames
```

**Export Features:**
- Automatically escapes fields containing commas, quotes, or newlines
- Uses standard CSV quoting for complex fields
- Converts duration from seconds to minutes for readability
- Includes all partner names associated with each encounter
- Compatible with spreadsheet applications (Excel, Numbers, Google Sheets)
- Can be re-imported into the app for data migration or backup

## Project Structure

```
Fuckify/
├── Encounter/
│   ├── Encounter.swift          # Encounter data model
│   ├── EncountersListView.swift # List of all encounters
│   ├── EncounterFormView.swift  # Add/edit encounter form
│   └── EncounterDetailView.swift # Encounter detail view
├── Partner/
│   ├── Partner.swift            # Partner data model
│   ├── PartnersListView.swift   # List of all partners
│   ├── PartnerFormView.swift    # Add/edit partner form
│   └── PartnerDetailView.swift  # Partner detail view
├── User/
│   ├── UserProfile.swift        # User profile data model
│   ├── ProfileView.swift        # User profile view
│   └── SettingsView.swift       # Settings and customization
├── ImportView.swift             # Main import selection view
├── EncounterImportView.swift    # CSV import for encounters
├── PartnerImportView.swift      # CSV import for partners
├── StatisticsView.swift         # Statistics dashboard
├── UserSettings.swift           # App settings manager
├── ContentView.swift            # Main tab view
├── Item.swift                   # Legacy item model
└── FuckifyApp.swift            # App entry point
```

## Technologies Used

- **SwiftUI**: Modern declarative UI framework
- **SwiftData**: Apple's persistence framework with CloudKit integration
- **UniformTypeIdentifiers**: CSV file type handling
- **UserDefaults**: User preferences and profile storage

## Privacy & Security

- All data is stored locally on your device
- Optional iCloud sync via CloudKit (can be disabled)
- No third-party analytics or tracking
- No data is shared with external servers
- App does not require internet connection to function

## CloudKit Integration

The app supports CloudKit sync for encounters and partners. CloudKit sync can be enabled/disabled in your device's iCloud settings.

**Requirements for CloudKit:**
- All model attributes must have default values
- All relationships must be optional
- Bidirectional relationships must declare inverses

## License

This project is licensed under the GNU General Public License v2.0 - see the [LICENSE.md](LICENSE.md) file for details.
