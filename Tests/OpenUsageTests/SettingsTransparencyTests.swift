import AppKit
import SwiftUI
import XCTest
@testable import OpenUsage

@MainActor
final class SettingsTransparencyTests: XCTestCase {
    func testSecretCodeRevealsWorkingTogglesAndPartyExitHidesThem() async throws {
        let (host, transparency) = try await makeSettings()
        // Launch at Login, Increase Transparency, then the three notification switches.
        let initial = switches(in: host)
        XCTAssertEqual(initial.count, 5)
        let increase = try XCTUnwrap(initial.dropFirst().first)
        increase.performClick(nil)
        XCTAssertTrue(transparency.increaseTransparency)

        transparency.toggleSecretCode()
        try await settle(host)
        let revealed = switches(in: host)
        XCTAssertEqual(revealed.count, 7)
        XCTAssertFalse(increase.isEnabled)
        let party = try XCTUnwrap(revealed.dropFirst(2).first)
        let drunk = try XCTUnwrap(revealed.dropFirst(3).first)
        XCTAssertEqual(party.state, .on)
        XCTAssertEqual(drunk.state, .off)
        drunk.performClick(nil)
        XCTAssertEqual(transparency.effectiveStyle, .drunk)
        try await settle(host)
        drunk.performClick(nil)
        XCTAssertEqual(transparency.effectiveStyle, .party)

        try await settle(host)
        drunk.performClick(nil)
        party.performClick(nil)
        try await settle(host)
        XCTAssertFalse(transparency.drunkMode)
        XCTAssertEqual(transparency.effectiveStyle, .increased)
        XCTAssertEqual(switches(in: host).count, initial.count)
        XCTAssertTrue(increase.isEnabled)
    }

    func testPartyControlsRemainAvailableWhenAccessibilityPausesEffects() async throws {
        let (host, transparency) = try await makeSettings(reduceTransparency: true)
        transparency.toggleSecretCode()
        try await settle(host)
        XCTAssertEqual(transparency.effectiveStyle, .opaque)
        let revealed = switches(in: host)
        XCTAssertEqual(revealed.count, 7)
        let party = try XCTUnwrap(revealed.dropFirst(2).first)
        XCTAssertTrue(party.isEnabled)
        party.performClick(nil)
        XCTAssertFalse(transparency.secretCodeActive)
    }

    private func makeSettings(reduceTransparency: Bool = false) async throws -> (NSView, PopoverTransparencyStore) {
        let suite = "OpenUsageTests.SettingsTransparency.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        let container = await AppContainer(
            accounts: AccountStore(defaults: defaults, vault: InMemoryCredentialVault()),
            defaults: defaults
        )
        let transparency = PopoverTransparencyStore(
            defaults: defaults, reduceTransparency: reduceTransparency, increaseContrast: false
        )
        container.layout.screen = .settings
        let view = SettingsScreen()
            .environment(container)
            .environment(container.layout)
            .environment(container.dataStore)
            .environment(transparency)
            .frame(width: PanelMetrics.width, height: 1_000)
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(origin: .zero, size: host.fittingSize)
        let window = NSWindow(contentRect: host.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.setFrameOrigin(NSPoint(x: -20_000, y: -20_000))
        window.orderFrontRegardless()
        addTeardownBlock { window.close() }
        try await settle(host)
        return (host, transparency)
    }

    private func settle(_ host: NSView) async throws {
        try await Task.sleep(for: .milliseconds(100))
        host.layoutSubtreeIfNeeded()
    }

    private func switches(in view: NSView) -> [NSSwitch] {
        if let toggle = view as? NSSwitch { return [toggle] }
        return view.subviews.flatMap { switches(in: $0) }
    }
}
