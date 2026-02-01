//
//  EncounterActivityWidgetBundle.swift
//  EncounterActivityWidget
//
//  Created by Safiya Hooda on 2026-02-01.
//

import WidgetKit
import SwiftUI

@main
struct EncounterActivityWidgetBundle: WidgetBundle {
    var body: some Widget {
        EncounterActivityWidget()
        EncounterActivityWidgetControl()
        EncounterActivityWidgetLiveActivity()
    }
}
