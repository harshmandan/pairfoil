//
//  ShareHandoff.swift
//  PairfoilShare
//
//  Writing side of the Share-menu hand-off. The reading side is
//  Pairfoil/Services/ShareInbox.swift; the names below must match it.
//

import AppKit

enum ShareHandoff {
    static let pasteboardName = NSPasteboard.Name("com.harshmandan.Pairfoil.share")
    static let devicesPasteboardName = NSPasteboard.Name("com.harshmandan.Pairfoil.devices")
    static let notificationName = Notification.Name("com.harshmandan.Pairfoil.shareRequest")
    static let appBundleIdentifier = "com.harshmandan.Pairfoil"

    enum Kind: String { case file, data, url, text }

    enum Key {
        static let kind = NSPasteboard.PasteboardType("com.harshmandan.pairfoil.kind")
        static let created = NSPasteboard.PasteboardType("com.harshmandan.pairfoil.created")
        static let path = NSPasteboard.PasteboardType("com.harshmandan.pairfoil.path")
        static let data = NSPasteboard.PasteboardType("com.harshmandan.pairfoil.data")
        static let name = NSPasteboard.PasteboardType("com.harshmandan.pairfoil.name")
        static let value = NSPasteboard.PasteboardType("com.harshmandan.pairfoil.value")
        static let device = NSPasteboard.PasteboardType("com.harshmandan.pairfoil.device")
        static let devices = NSPasteboard.PasteboardType("com.harshmandan.pairfoil.devices")
    }

    struct Device: Identifiable, Hashable {
        let id: String
        let name: String
        let symbol: String
    }

    /// Devices connected to a running Pairfoil, as it last published them.
    /// Empty when Pairfoil isn't running, since the list could be stale.
    static func connectedDevices() -> [Device] {
        guard !NSRunningApplication.runningApplications(withBundleIdentifier: appBundleIdentifier).isEmpty,
              let data = NSPasteboard(name: devicesPasteboardName).data(forType: Key.devices),
              let list = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] else { return [] }
        return list.compactMap { entry in
            guard let id = entry["id"], let name = entry["name"] else { return nil }
            return Device(id: id, name: name, symbol: entry["symbol"] ?? "iphone")
        }
    }

    enum Entry {
        case file(path: String)
        case data(Data, name: String)
        case url(String)
        case text(String)
    }

    /// - Parameter deviceId: the device chosen in the extension, or nil to let
    ///   Pairfoil use its current device.
    static func write(_ entries: [Entry], deviceId: String?) {
        let created = String(Date().timeIntervalSince1970)
        let items = entries.map { entry -> NSPasteboardItem in
            let item = NSPasteboardItem()
            item.setString(created, forType: Key.created)
            if let deviceId { item.setString(deviceId, forType: Key.device) }
            switch entry {
            case .file(let path):
                item.setString(Kind.file.rawValue, forType: Key.kind)
                item.setString(path, forType: Key.path)
            case .data(let data, let name):
                item.setString(Kind.data.rawValue, forType: Key.kind)
                item.setData(data, forType: Key.data)
                item.setString(name, forType: Key.name)
            case .url(let url):
                item.setString(Kind.url.rawValue, forType: Key.kind)
                item.setString(url, forType: Key.value)
            case .text(let text):
                item.setString(Kind.text.rawValue, forType: Key.kind)
                item.setString(text, forType: Key.value)
            }
            return item
        }

        let pasteboard = NSPasteboard(name: pasteboardName)
        pasteboard.clearContents()
        pasteboard.writeObjects(items)
    }

    /// Tells a running Pairfoil to pick up the items, or launches it to do so.
    static func deliver(appURL: URL) {
        if NSRunningApplication.runningApplications(withBundleIdentifier: appBundleIdentifier).isEmpty {
            // Pairfoil reads the pasteboard when it finishes launching.
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = false
            NSWorkspace.shared.openApplication(at: appURL, configuration: configuration)
        } else {
            DistributedNotificationCenter.default().postNotificationName(
                notificationName, object: nil, userInfo: nil, deliverImmediately: true
            )
        }
    }
}
