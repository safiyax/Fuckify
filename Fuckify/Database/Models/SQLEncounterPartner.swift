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
struct SQLEncounterPartner {
    let id: UUID
    var encounterId: UUID
    var partnerId: UUID
}
