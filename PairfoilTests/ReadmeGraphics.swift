//
//  ReadmeGraphics.swift
//  PairfoilTests
//
//  The README's images: a hero and a grid of features, in the style of
//  Apple's product pages. Real app screens with sample data, laid out in
//  SwiftUI and rendered off-screen, so nothing comes to the front.
//  Skipped unless PAIRFOIL_README_DIR is set:
//
//    TEST_RUNNER_PAIRFOIL_README_DIR=/path xcodebuild test ... \
//      -only-testing:PairfoilTests/ReadmeGraphics
//

import Testing
import SwiftUI
import AppKit
import ScreenCaptureKit
@testable import Pairfoil

@MainActor
@Suite struct ReadmeGraphics {
    static let outputDirectory = ProcessInfo.processInfo.environment["PAIRFOIL_README_DIR"]

    @Test(.enabled(if: outputDirectory != nil))
    func renderGraphics() async throws {
        let dir = URL(fileURLWithPath: Self.outputDirectory!)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        Permissions.shared.showForDemo(notifications: .allowed, accessibility: .off, localNetwork: .allowed)

        let shots = Shots(
            overview: try await capture(MainWindowView(appModel: .mock(), initialSection: .overview),
                                        size: CGSize(width: 1040, height: 660)),
            messages: try await capture(MainWindowView(appModel: .mock(), initialSection: .messages),
                                        size: CGSize(width: 1040, height: 660)),
            notifications: try await capture(MainWindowView(appModel: .mock(), initialSection: .notifications),
                                             size: CGSize(width: 1040, height: 660)),
            popover: try await capture(MenuBarView(appModel: .mock()).fixedSize(), size: nil, titled: false),
            permissions: try await capture(PermissionsSettings(viewModel: .mock()), size: CGSize(width: 560, height: 470))
        )

        try write(Hero(shots: shots), size: CGSize(width: 1600, height: 900), to: dir.appendingPathComponent("hero.jpg"))
        try write(Features(shots: shots), size: CGSize(width: 1600, height: 1900), to: dir.appendingPathComponent("features.jpg"))
    }

    // MARK: - Capturing

    /// Draws a real window off-screen. It reports itself key, so selections
    /// and prominent buttons draw in their active colours, without Pairfoil
    /// ever coming to the front.
    private final class StandInKeyWindow: NSWindow {
        override var isKeyWindow: Bool { true }
        override var isMainWindow: Bool { true }
        override var canBecomeKey: Bool { true }
    }

    private func capture<V: View>(_ view: V, size: CGSize?, titled: Bool = true) async throws -> NSImage {
        // No focus rings: a key window focuses its first control, which a
        // person looking at the window wouldn't see.
        let hosting = NSHostingController(rootView: AnyView(
            (size.map { AnyView(view.frame(width: $0.width, height: $0.height)) } ?? AnyView(view))
                .focusEffectDisabled()
        ))
        let window = StandInKeyWindow(contentViewController: hosting)
        window.styleMask = titled ? [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView] : [.borderless]
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .aqua)
        // Opaque, so glass has something to show through even without a
        // window behind it; the corners are rounded when it's laid out.
        window.backgroundColor = .windowBackgroundColor
        window.isOpaque = true
        window.title = "Pairfoil"
        if let size { window.setContentSize(size) }
        window.setFrameOrigin(NSPoint(x: 80, y: 80))
        // Focused, so the window draws as the one in use: active sidebar,
        // accent-coloured selection and an undimmed toolbar.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        defer { window.close() }

        try await Task.sleep(for: .milliseconds(1200))
        window.makeFirstResponder(nil)
        try await Task.sleep(for: .milliseconds(300))

        let content = try await SCShareableContent.currentProcess
        guard let scWindow = content.windows.first(where: { $0.windowID == CGWindowID(window.windowNumber) }) else {
            Issue.record("ScreenCaptureKit didn't list the window \(window.windowNumber)")
            throw CaptureFailed()
        }
        let filter = SCContentFilter(desktopIndependentWindow: scWindow)
        let configuration = SCStreamConfiguration()
        configuration.width = Int(filter.contentRect.width * CGFloat(filter.pointPixelScale))
        configuration.height = Int(filter.contentRect.height * CGFloat(filter.pointPixelScale))
        configuration.showsCursor = false
        configuration.ignoreShadowsSingleWindow = true
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        return NSImage(cgImage: image, size: NSSize(width: filter.contentRect.width, height: filter.contentRect.height))
    }

    private struct CaptureFailed: Error {}

    private func write<V: View>(_ view: V, size: CGSize, to url: URL) throws {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height)
            .environment(\.colorScheme, .light))
        renderer.scale = 2
        guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let jpeg = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.88]) else {
            throw CaptureFailed()
        }
        try jpeg.write(to: url)
    }
}

// MARK: - Pieces

private struct Shots {
    let overview: NSImage
    let messages: NSImage
    let notifications: NSImage
    let popover: NSImage
    let permissions: NSImage
}

private enum Palette {
    static let page = Color(red: 0.961, green: 0.961, blue: 0.969)   // #F5F5F7
    static let ink = Color(red: 0.114, green: 0.114, blue: 0.122)    // #1D1D1F
    static let secondary = Color(red: 0.431, green: 0.431, blue: 0.451) // #6E6E73
}

private struct Screenshot: View {
    let image: NSImage
    var radius: CGFloat = 12

    var body: some View {
        Image(nsImage: image)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .clipShape(.rect(cornerRadius: radius, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 24, y: 12)
    }
}

private struct AppIcon: View {
    var size: CGFloat
    var body: some View {
        Image(nsImage: NSApp.applicationIconImage)
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
    }
}

/// The phone icon from the menu bar, drawn at any size.
private struct MenuBarPhone: View {
    let count: Int
    var height: CGFloat

    var body: some View {
        Image(nsImage: MenuBarIcon.image(count: count, isConnected: true))
            .renderingMode(.template)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(height: height)
    }
}

/// A red badge like the Dock's.
private struct Badge: View {
    let text: String
    var size: CGFloat
    var body: some View {
        Text(text)
            .font(.system(size: size * 0.6, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, size * 0.28)
            .frame(minWidth: size, minHeight: size)
            .background(Capsule().fill(Color(red: 1, green: 0.23, blue: 0.19)))
    }
}

private struct Tile<Content: View>: View {
    let eyebrow: String
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(eyebrow)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Palette.secondary)
            Text(title)
                .font(.system(size: 30, weight: .bold))
                .tracking(-0.4)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 22)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.white, in: .rect(cornerRadius: 28, style: .continuous))
    }
}

// MARK: - Hero

private struct Hero: View {
    let shots: Shots

    var body: some View {
        ZStack(alignment: .topLeading) {
            Palette.page

            // The menu bar, with the phone showing what's waiting.
            HStack(spacing: 22) {
                Image(systemName: "apple.logo").font(.system(size: 16, weight: .medium))
                Text("Pairfoil").font(.system(size: 14, weight: .bold))
                ForEach(["Edit", "View", "Window", "Help"], id: \.self) { Text($0).font(.system(size: 14)) }
                Spacer()
                MenuBarPhone(count: 3, height: 17)
                Image(systemName: "wifi").font(.system(size: 14, weight: .medium))
                Image(systemName: "battery.75percent").font(.system(size: 16))
                Text("Sun 22 Nov  4:20 PM").font(.system(size: 14))
            }
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 22)
            .frame(height: 32)
            .background(.white.opacity(0.85))

            VStack(alignment: .leading, spacing: 18) {
                Text("Your Android phone.\nOn your Mac.")
                    .font(.system(size: 64, weight: .bold))
                    .tracking(-1.2)
                    .foregroundStyle(Palette.ink)
                Text("Notifications you can reply to, texts, files and the clipboard, in a native Mac app.")
                    .font(.system(size: 24))
                    .foregroundStyle(Palette.secondary)
                    .frame(width: 520, alignment: .leading)
            }
            .padding(.leading, 80)
            .padding(.top, 120)

            Screenshot(image: shots.overview, radius: 14)
                .frame(width: 900)
                .offset(x: 640, y: 300)

            Screenshot(image: shots.popover, radius: 16)
                .frame(width: 300)
                .offset(x: 1230, y: 44)

            // The Dock, with Pairfoil's badge.
            HStack(spacing: 14) {
                ZStack(alignment: .topTrailing) {
                    AppIcon(size: 72)
                    Badge(text: "7", size: 26).offset(x: 6, y: -4)
                }
            }
            .padding(10)
            .background(.white.opacity(0.75), in: .rect(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.black.opacity(0.06)))
            .shadow(color: .black.opacity(0.12), radius: 18, y: 6)
            .offset(x: 80, y: 760)
        }
        .clipped()
    }
}

// MARK: - Features

private struct Features: View {
    let shots: Shots
    private let gap: CGFloat = 20

    var body: some View {
        VStack(alignment: .leading, spacing: gap) {
            Text("Everything on your phone,\nright where you work.")
                .font(.system(size: 52, weight: .bold))
                .tracking(-1)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(Palette.ink)
                .padding(.bottom, 20)

            HStack(spacing: gap) {
                Tile(eyebrow: "Messages", title: "Read and reply to texts, with photos and files.") {
                    Screenshot(image: shots.messages)
                }
                .frame(width: 960)
                Tile(eyebrow: "Menu bar", title: "See what's waiting at a glance.") {
                    VStack(spacing: 40) {
                        HStack(spacing: 18) {
                            MenuBarPhone(count: 3, height: 30)
                            Image(systemName: "wifi").font(.system(size: 24, weight: .medium))
                            Image(systemName: "battery.75percent").font(.system(size: 28))
                            Text("4:20 PM").font(.system(size: 24))
                        }
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, 24)
                        .frame(height: 56)
                        .background(Palette.page, in: .rect(cornerRadius: 14, style: .continuous))
                        HStack(spacing: 34) {
                            ForEach([(0, "Nothing"), (3, "3 waiting"), (12, "Over 9")], id: \.0) { count, label in
                                VStack(spacing: 10) {
                                    MenuBarPhone(count: count, height: 56).foregroundStyle(Palette.ink)
                                    Text(label).font(.system(size: 15)).foregroundStyle(Palette.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .frame(height: 560)

            HStack(spacing: gap) {
                Tile(eyebrow: "Notifications", title: "Grouped by app. Reply from the banner.") {
                    Screenshot(image: shots.notifications)
                }
                Tile(eyebrow: "Dock", title: "A badge for notifications and unread texts.") {
                    ZStack(alignment: .topTrailing) {
                        AppIcon(size: 160)
                        Badge(text: "7", size: 52).offset(x: 10, y: -6)
                    }
                }
                .frame(width: 380)
            }
            .frame(height: 560)

            HStack(spacing: gap) {
                Tile(eyebrow: "Permissions", title: "Every permission in one place.") {
                    Screenshot(image: shots.permissions)
                }
                Tile(eyebrow: "Files", title: "Your phone in Finder. Videos start right away.") {
                    VStack(spacing: 14) {
                        Image(systemName: "externaldrive.fill.badge.wifi")
                            .font(.system(size: 92, weight: .light))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Palette.ink)
                        Text("Drop files on the window to send them.")
                            .font(.system(size: 17))
                            .foregroundStyle(Palette.secondary)
                    }
                }
                VStack(spacing: gap) {
                    Tile(eyebrow: "Size", title: "3.7 MB. Not 87.") {
                        Text("The disk image, next to KDE Connect for macOS.")
                            .font(.system(size: 17))
                            .foregroundStyle(Palette.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                    Tile(eyebrow: "Private", title: "No cloud, no account.") {
                        Text("Phone and Mac talk directly, over Wi-Fi or your Tailscale network, with TLS.")
                            .font(.system(size: 17))
                            .foregroundStyle(Palette.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                }
            }
            .frame(height: 480)
        }
        .padding(60)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.page)
    }
}
