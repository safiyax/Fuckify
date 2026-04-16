//
//  SQLEncounterPartner.swift
//  Fuckify
//
//  Created by Zeeshan Hooda on 2026-01-05.
//

import Foundation
import SQLiteData

/// Junction table representing Encounter-Partner many-to-many relationship
@Table("encounterPartner")
struct SQLEncounterPartner: Identifiable {
    let id: UUID
    var encounterId: UUID
    var partnerId: UUID
    var positionTypeId: UUID?   // Optional position for this partner in this encounter
    var hadOrgasm: Bool         // Whether this partner had an orgasm
}
