//
//  TetherMigration.swift
//  Pairfoil
//
//  Pairfoil was called Tether. The first time it starts, it copies what Tether
//  kept: settings, the paired phones, and this Mac's identity, so a phone
//  paired with Tether stays paired. Tether's own copy is left alone.
//
//  Until this has run, what Tether kept wins over anything Pairfoil already
//  has: Pairfoil can only have made its own identity in a launch that came
//  before this copy, and keeping that one would unpair every phone.
//

import AppKit

enum TetherMigration {
    private static let doneKey = "pairfoil_copied_from_tether"
    private static let oldBundleID = "com.subhashh.Tether"

    static func runIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: doneKey) else { return }
        // So it doesn't write while its things are copied.
        quitTether()
        copySettings(into: defaults)
        copySupportFolder()
        defaults.set(true, forKey: doneKey)
    }

    /// Tether's keys used its name; Pairfoil's use the new one.
    static func renamed(_ key: String) -> String {
        key.replacingOccurrences(of: "tether", with: "pairfoil")
            .replacingOccurrences(of: "Tether", with: "Pairfoil")
    }

    private static func quitTether() {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: oldBundleID)
        guard !running.isEmpty else { return }
        running.forEach { $0.terminate() }
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline, !running.allSatisfy(\.isTerminated) {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
    }

    private static func copySettings(into defaults: UserDefaults) {
        guard let old = defaults.persistentDomain(forName: oldBundleID), !old.isEmpty else { return }
        for (key, value) in old {
            defaults.set(value, forKey: renamed(key))
        }
        PairfoilLog("[Migration] Copied \(old.count) settings from Tether")
    }

    private static func copySupportFolder() {
        let root = URL.applicationSupportDirectory
        let old = root.appendingPathComponent("Tether", isDirectory: true)
        let new = root.appendingPathComponent("Pairfoil", isDirectory: true)
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(at: old, includingPropertiesForKeys: nil) else { return }
        try? fm.createDirectory(at: new, withIntermediateDirectories: true)
        // Mounts holds mount points, made as needed; one may have a phone
        // drive mounted on it, and replacing it would delete through it.
        for item in items where item.lastPathComponent != "Mounts" {
            let target = new.appendingPathComponent(item.lastPathComponent)
            do {
                if fm.fileExists(atPath: target.path) { try fm.removeItem(at: target) }
                try fm.copyItem(at: item, to: target)
            } catch {
                PairfoilLog("[Migration] Couldn't copy \(item.lastPathComponent): \(error.localizedDescription)")
            }
        }
        PairfoilLog("[Migration] Copied Tether's identity, contacts and drive data")
    }
}
