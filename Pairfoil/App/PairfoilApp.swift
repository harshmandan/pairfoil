//
//  PairfoilApp.swift
//  Pairfoil
//

import SwiftUI

@main
struct PairfoilApp: App {
    @State private var appModel: PairfoilAppModel

    init() {
        // AppKit adds Enter Full Screen to a View menu on its own, which
        // would keep a View menu Pairfoil doesn't otherwise have. The window's
        // green button and Window › Full Screen Tile still do it.
        UserDefaults.standard.register(defaults: ["NSFullScreenMenuItemEverywhere": false])
        let isTesting = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        if !isTesting { TetherMigration.runIfNeeded() }
        #if DEBUG
        // `-PairfoilDemoData` fills the UI with sample devices for screenshots and
        // design work, without touching the network.
        // `-PairfoilDemoRinging` also shows the Ring panel, without sound.
        // `-PairfoilDemoCall` also shows the incoming-call card.
        if ProcessInfo.processInfo.arguments.contains("-PairfoilDemoData") {
            _appModel = State(initialValue: .mock())
            PhoneFilesController.shared.showDemoDrive(for: "mock_phone")
            if ProcessInfo.processInfo.arguments.contains("-PairfoilDemoRinging") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    MacRinger.shared.showDemoPanel(deviceName: "Pixel 9 Pro")
                }
            }
            if ProcessInfo.processInfo.arguments.contains("-PairfoilDemoCall") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    CallCard.shared.showDemo()
                }
            }
            return
        }
        #endif

        _appModel = State(initialValue: .shared)

        // Unit tests run inside a copy of the app. Starting the services there
        // would connect to the phone next to the real Pairfoil and unmount its
        // phone drive as a "leftover".
        if isTesting { return }

        QuitOnTerminateSignal.install()
        // Eagerly initialize identity on main thread
        _ = DeviceIdentity.shared
        // Start background discovery and network services
        PairfoilService.shared.start()
        // Receive what's shared from the Share menu
        ShareInbox.shared.start()
        // Look for a newer release once a day
        UpdateController.shared.start()
        // Serve the phone's storage to Finder
        PhoneFilesController.shared.start()
    }

    /// Demo data opens the main window at `-PairfoilDemoSection <section>`
    /// (overview when not given).
    private static var demoSection: DeviceSection? {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("-PairfoilDemoData") else { return nil }
        return UserDefaults.standard.string(forKey: "PairfoilDemoSection").flatMap(DeviceSection.init) ?? .overview
        #else
        return nil
        #endif
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(appModel: appModel)
                .pairfoilMotionPreference()
        } label: {
            Image(nsImage: MenuBarIcon.image(count: appModel.waitingCount,
                                             isConnected: !appModel.connectedDevices.isEmpty))
        }
        .menuBarExtraStyle(.window)

        Window("Pairfoil", id: "main") {
            MainWindowView(appModel: appModel, initialSection: Self.demoSection ?? .overview)
                .pairfoilMotionPreference()
        }
        .defaultSize(width: 1040, height: 700)
        .defaultLaunchBehavior(Self.demoSection == nil ? .automatic : .presented)
        .windowToolbarStyle(.unified)
        .commands {
            PairfoilCommands(appModel: appModel)
        }

        Settings {
            SettingsView(viewModel: .shared)
                .pairfoilMotionPreference()
        }
    }
}
