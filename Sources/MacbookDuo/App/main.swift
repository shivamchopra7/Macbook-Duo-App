import AppKit
import FoldCore

MainActor.assumeIsolated {
if let index = CommandLine.arguments.firstIndex(of:"--update-handoff-check"), index+3 < CommandLine.arguments.count {
    Task {
        do {
            try await UpdateInstallation.checkHandoff(archive:URL(fileURLWithPath:CommandLine.arguments[index+1]),
                                                     manifest:URL(fileURLWithPath:CommandLine.arguments[index+2]),version:CommandLine.arguments[index+3])
            exit(0)
        } catch { fputs("Handoff check failed: \(error.localizedDescription)\n",stderr);exit(1) }
    }
    dispatchMain()
}
if let index = CommandLine.arguments.firstIndex(of:"--update-package-check"), index+4 < CommandLine.arguments.count {
    do {
        try UpdateInstallation.checkPackage(archive:URL(fileURLWithPath:CommandLine.arguments[index+1]),
                                            manifest:URL(fileURLWithPath:CommandLine.arguments[index+2]),
                                            version:CommandLine.arguments[index+3],output:URL(fileURLWithPath:CommandLine.arguments[index+4],isDirectory:true))
        print("Package checksum, bounded extraction, bundle identity, version, macOS, architecture, and code signature verified.");exit(0)
    } catch { fputs("Package check failed: \(error.localizedDescription)\n",stderr);exit(1) }
}
if let index = CommandLine.arguments.firstIndex(of:"--update-installer-fixture"), index+1 < CommandLine.arguments.count {
    do { try UpdateInstallation.checkInstallerFixture(output:URL(fileURLWithPath:CommandLine.arguments[index+1],isDirectory:true));print("Installer fixture passed: LaunchServices, ready handshake, replacement, and failed-launch rollback.");exit(0) }
    catch { fputs("Installer fixture failed: \(error.localizedDescription)\n",stderr);exit(1) }
}
if CommandLine.arguments.contains("--update-fixture-fail"), Bundle.main.bundleIdentifier == "com.shivamchopra.macbookduo.update-fixture" { exit(42) }
if let index = CommandLine.arguments.firstIndex(of:"--update-fixture-ready"), index+1 < CommandLine.arguments.count,
   Bundle.main.bundleIdentifier == "com.shivamchopra.macbookduo.update-fixture" {
    let ready = URL(fileURLWithPath:CommandLine.arguments[index+1])
    guard ready.lastPathComponent == "ready", ready.deletingLastPathComponent().lastPathComponent.hasPrefix("MacbookDuo-update-fixture-"),
          ready.deletingLastPathComponent().resolvingSymlinksInPath() == Bundle.main.bundleURL.deletingLastPathComponent().resolvingSymlinksInPath() else { exit(1) }
    do { try Data("ready".utf8).write(to:ready,options:.withoutOverwriting) } catch { exit(1) }
    let app = NSApplication.shared;app.setActivationPolicy(.accessory);app.run();exit(0)
}
if let index = CommandLine.arguments.firstIndex(of:"--finish-update"), index+1 < CommandLine.arguments.count {
    exit(UpdateInstallation.finishUpdate(token:CommandLine.arguments[index+1]))
}
if CommandLine.arguments.contains("--update-check") {
    Task { @MainActor in
        do {
            if let update = try await AppUpdater.findUpdate() {
                print("Update available: \(update.tag) — \(update.releasePage.absoluteString)")
            } else { print("No newer stable Macbook Duo release is available.") }
            exit(0)
        } catch { fputs("Update check failed: \(error.localizedDescription)\n",stderr);exit(1) }
    }
    dispatchMain()
}
if CommandLine.arguments.contains("--sensor-check") {
    // Reads the lid sensor for up to three seconds and reports whether the
    // HID device is reachable from this build (sandbox and entitlement checks).
    let sensor = LidSensor()
    let deadline = Date().addingTimeInterval(3)
    var outcome: Int32?
    sensor.onReading = { angle in
        if let angle { print("Lid angle: \(Int(angle))°"); outcome = 0 }
        else { fputs("Sensor unavailable: IOHIDManagerOpen/IOHIDDeviceOpen failed or no device matched.\n",stderr); outcome = 1 }
    }
    sensor.start()
    while outcome == nil, Date() < deadline { RunLoop.main.run(until:Date().addingTimeInterval(0.05)) }
    sensor.stop()
    if outcome == nil { fputs("Sensor unavailable: no report within 3 s.\n",stderr) }
    exit(outcome ?? 1)
}
if CommandLine.arguments.contains("--render-check") {
    do { try RenderCheck.run();exit(0) } catch { fputs("Render check failed: \(error)\n",stderr);exit(1) }
}
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()

}
