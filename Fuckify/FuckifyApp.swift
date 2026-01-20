//
//  FuckifyApp.swift
//  Fuckify
//
//  Created by Safiya Hooda on 2025-11-08.
//

import SwiftUI
import SQLiteData

@main
struct FuckifyApp: App {
    init() {
        // Initialize SQLite database and prepare dependencies
        prepareDependencies {
            $0.defaultDatabase = try! appDatabase()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
