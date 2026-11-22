//
//  PairfoilLog.swift
//  Pairfoil
//
//  Logging goes to the system log, where Console shows it. Debug builds also
//  keep a file, /tmp/pairfoil.log, for reading during development: one open
//  handle, rotated at 5 MB, readable only by this user. Log lines carry no
//  personal text (clipboard, messages, replies, links); say what happened
//  and how much, not what it said.
//

import Foundation
import os

nonisolated private let logger = Logger(subsystem: "com.harshmandan.Pairfoil", category: "app")

nonisolated func PairfoilLog(_ message: String) {
    logger.log("\(message, privacy: .public)")
    #if DEBUG
    LogFile.shared.append(message)
    #endif
}

#if DEBUG
private nonisolated final class LogFile: @unchecked Sendable {
    static let shared = LogFile()

    private let url = URL(fileURLWithPath: "/tmp/pairfoil.log")
    private let limit: UInt64 = 5 * 1024 * 1024
    private let queue = DispatchQueue(label: "com.harshmandan.pairfoil.log", qos: .utility)
    private let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private var handle: FileHandle?

    func append(_ message: String) {
        let date = Date()
        queue.async {
            let line = "[\(self.formatter.string(from: date))] \(message)\n"
            guard let handle = self.openHandle(), let data = line.data(using: .utf8) else { return }
            handle.write(data)
            if handle.offsetInFile > self.limit { self.rotate() }
        }
    }

    private func openHandle() -> FileHandle? {
        if let handle { return handle }
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil, attributes: [.posixPermissions: 0o600])
        }
        handle = try? FileHandle(forWritingTo: url)
        handle?.seekToEndOfFile()
        return handle
    }

    /// Keeps one older file, pairfoil.log.1, and starts a fresh one.
    private func rotate() {
        try? handle?.close()
        handle = nil
        let old = url.appendingPathExtension("1")
        try? FileManager.default.removeItem(at: old)
        try? FileManager.default.moveItem(at: url, to: old)
    }
}
#endif
