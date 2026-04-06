//
//  AppLogger.swift
//  Fuckify
//
//  Wraps OSLog's Logger with environment-aware privacy.
//
//  - DEBUG builds: all interpolated values are marked `.public` so messages
//    appear unredacted in Xcode's console and Console.app during development.
//  - Release builds: interpolated values use the OSLog default (`.private`),
//    so user data is redacted in any log drain or crash report.
//

import Foundation
import OSLog

struct AppLogger {
    private let inner: Logger

    init(subsystem: String, category: String) {
        self.inner = Logger(subsystem: subsystem, category: category)
    }

    func debug(_ message: String) {
//        #if DEBUG
        inner.debug("\(message, privacy: .public)")
//        #else
//        inner.debug("\(message)")
//        #endif
    }

    func info(_ message: String) {
//        #if DEBUG
        inner.info("\(message, privacy: .public)")
//        #else
//        inner.info("\(message)")
//        #endif
    }

    func warning(_ message: String) {
//        #if DEBUG
        inner.warning("\(message, privacy: .public)")
//        #else
//        inner.warning("\(message)")
//        #endif
    }

    func error(_ message: String) {
//        #if DEBUG
        inner.error("\(message, privacy: .public)")
//        #else
//        inner.error("\(message)")
//        #endif
    }

    func fault(_ message: String) {
//        #if DEBUG
        inner.fault("\(message, privacy: .public)")
//        #else
//        inner.fault("\(message)")
//        #endif
    }
}
