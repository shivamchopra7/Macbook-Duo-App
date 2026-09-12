import AppKit
import SwiftUI
import MetalKit
import Carbon
import FoldCore
import ScreenCaptureKit
import OSLog
import IOKit.ps
import ServiceManagement

@MainActor final class AppModel: ObservableObject {
    @Published var lidAngle: Double?
    @Published var enabled = false
    @Published var checkingPermission = false
    @Published var status = AppBrand.text("Preview is ready. Enable %@ to use your desktop.")
    @Published var hasPermission = CGPreflightScreenCaptureAccess()
    @Published var followLid = UserDefaults.standard.object(forKey:"followLid") as? Bool ?? true {
        didSet { UserDefaults.standard.set(followLid,forKey:"followLid") }
    }
    @Published var appearance = AppAppearance(rawValue:UserDefaults.standard.string(forKey:"appearance") ?? "system") ?? .system {
        didSet {
            UserDefaults.standard.set(appearance.rawValue,forKey:"appearance")
            NSApp.appearance = appearance.native
        }
    }
    /// The menu bar icon is optional. Hiding it never changes following or capture;
    /// reopening Macbook Duo from Applications or Spotlight always restores this window.
    @Published var showInMenuBar = UserDefaults.standard.object(forKey:"showInMenuBar") as? Bool ?? true {
        didSet {
            guard oldValue != showInMenuBar else { return }
            UserDefaults.standard.set(showInMenuBar,forKey:"showInMenuBar")
            menuBarVisibilityChanged?(showInMenuBar)
        }
    }
    /// Choosing an effect only saves and redraws. It never starts a full-screen demo.
    @Published var effect = FoldEffect.resolve(persisted:UserDefaults.standard.string(forKey:"effect")) {
        didSet {
            guard oldValue != effect else { return }
            UserDefaults.standard.set(effect.persistedIdentifier,forKey:"effect")
            wakePreview()
            update()
        }
    }
    @Published var previewAngle = 72.0
    @Published var clearAngle = UserDefaults.standard.object(forKey:"clearAngle") as? Double ?? 105 {
        didSet { UserDefaults.standard.set(clearAngle,forKey:"clearAngle");resetStillness();wakePreview();update() }
    }
    @Published var perspective = UserDefaults.standard.object(forKey:"perspective") as? Double ?? 0.7 {
        didSet { UserDefaults.standard.set(perspective,forKey:"perspective") }
    }
    @Published var blur = UserDefaults.standard.object(forKey:"blur") as? Double ?? 0.65 {
        didSet { UserDefaults.standard.set(blur,forKey:"blur") }
    }
    @Published var shadow = UserDefaults.standard.object(forKey:"shadow") as? Double ?? 0.65 {
        didSet { UserDefaults.standard.set(shadow,forKey:"shadow") }
    }
    @Published var intensity = EffectOptions(intensity:UserDefaults.standard.object(forKey:"effectIntensity") as? Double ?? EffectOptions.default.intensity).intensity {
        didSet { UserDefaults.standard.set(intensity,forKey:"effectIntensity");wakePreview() }
    }
    @Published var segments = EffectOptions(segments:UserDefaults.standard.object(forKey:"effectSegments") as? Int ?? EffectOptions.default.segments).segments {
        didSet { UserDefaults.standard.set(segments,forKey:"effectSegments");wakePreview() }
    }
    @Published var curve = FoldCurve.resolve(persisted:UserDefaults.standard.string(forKey:"effectCurve")) {
        didSet { UserDefaults.standard.set(curve.rawValue,forKey:"effectCurve");wakePreview();update() }
    }
    @Published var responseTime = EffectOptions(responseTime:UserDefaults.standard.object(forKey:"effectResponse") as? Double ?? EffectOptions.default.responseTime).responseTime {
        didSet { UserDefaults.standard.set(responseTime,forKey:"effectResponse");applyTiming() }
    }
    @Published var clearDuration = EffectOptions(clearDuration:UserDefaults.standard.object(forKey:"effectClearDuration") as? Double ?? EffectOptions.default.clearDuration).clearDuration {
        didSet { UserDefaults.standard.set(clearDuration,forKey:"effectClearDuration");applyTiming() }
    }
    /// The validated, clamped view of the option properties above.
    var options: EffectOptions {
        EffectOptions(intensity:intensity,segments:segments,curve:curve,responseTime:responseTime,clearDuration:clearDuration)
    }
    func resetOptions() {
        let defaults = EffectOptions.default
        intensity = defaults.intensity;segments = defaults.segments;curve = defaults.curve
        responseTime = defaults.responseTime;clearDuration = defaults.clearDuration
        perspective = 0.7;blur = 0.65;shadow = 0.65
    }
    private func applyTiming() {
        liveAnimation.apply(options)
        previewRenderer?.apply(options:options)
    }
    @Published var clearWhenStill = UserDefaults.standard.object(forKey:"clearWhenStill") as? Bool ?? true {
        didSet {
            if oldValue != clearWhenStill {
                UserDefaults.standard.set(clearWhenStill,forKey:"clearWhenStill")
                resetStillness()
                updateStillnessStatus()
                update()
            }
        }
    }
    @Published private(set) var lidIsStill = false
    @Published var stillnessDelay = UserDefaults.standard.object(forKey:"stillnessDelay") as? Double ?? 2 {
        didSet { UserDefaults.standard.set(stillnessDelay,forKey:"stillnessDelay") }
    }
    @Published var demoRunning = false
    @Published var previewPlaying = false
    @Published var sensorAvailable = false
    /// True once discovery has given up: this Mac has no lid-angle sensor.
    @Published var sensorUnsupported = false

    /// Developer aid for previewing the no-sensor interface on a Mac that has
    /// one. Compiled out of the App Store build, so it cannot ship.
    private var simulatesMissingSensor: Bool {
        #if APPSTORE
        false
        #else
        CommandLine.arguments.contains("--simulate-no-sensor")
        #endif
    }
    @Published var overlayVisible = false
    @Published var fps = 60
    @Published var reducedMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    let sensor = LidSensor()
    let capture = DesktopCapture()
    let device = MTLCreateSystemDefaultDevice()
    var previewRenderer: FoldRenderer? {
        didSet { previewRenderer?.apply(options:options) }
    }
    weak var previewView: MTKView?
    var renderer: FoldRenderer?
    var panel: OverlayPanel?
    var metalView: MTKView?
    private var timer: Timer?
    private var enableTask: Task<Void, Never>?
    let logger = Logger(subsystem:"com.shivamchopra.macbookduo",category:"lifecycle")
    var hotKey: EventHotKeyRef?
    var escapeKey: EventHotKeyRef?
    var hotKeyHandler: EventHandlerRef?
    var localKeyMonitor: Any?
    var sessionActive = true
    var systemAwake = true
    var displayAwake = true
    var sensorAt: TimeInterval = 0
    var waitingForSensor = false
    private var stillness = LidStillness()
    var liveAnimation = FoldVisualAnimation()
    private var motionReference = LidMotionReference()
    var overlayRevealed = false
    var powerCheckedAt: TimeInterval = -.infinity
    var demoStart: TimeInterval?
    var previewStart: TimeInterval?
    var idleSince: TimeInterval?
    var screenID: CGDirectDisplayID?
    var notifications: [NSObjectProtocol] = []
    var syntheticCheckPath: URL?
    var sensorPollRate = 0
    var presentedFrames = 0
    var showWindow: (() -> Void)?
    var overlayVisibilityChanged: ((Bool) -> Void)?
    var menuBarVisibilityChanged: ((Bool) -> Void)?

    /// Login registration lives in the system, not in our preferences. The switch
    /// reports what macOS actually holds, so a rejected change cannot show as applied.
    @Published private(set) var launchAtLogin = SMAppService.mainApp.status == .enabled

    func setLaunchAtLogin(_ on: Bool) {
        guard on != launchAtLogin else { return }
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            logger.notice("Open at login requested: \(on,privacy:.public)")
        } catch {
            status = L10n.format("Could not change Open at login: %@",error.localizedDescription)
            logger.error("Open at login failed: \(error.localizedDescription,privacy:.public)")
        }
        refreshLaunchAtLogin()
    }

    /// The user can also remove Macbook Duo in System Settings. Re-read before showing the state.
    func refreshLaunchAtLogin() {
        let actual = SMAppService.mainApp.status == .enabled
        if launchAtLogin != actual { launchAtLogin = actual }
    }

    init() {
        NSApp.appearance = appearance.native
        liveAnimation.apply(options)
        sensor.onReading = { [weak self] angle in
            guard let self else { return }
            let angleChanged = self.lidAngle != angle
            if angleChanged { self.lidAngle = angle }
            if self.sensorAvailable != (angle != nil) { self.sensorAvailable = angle != nil }
            if angle != nil, self.sensorUnsupported { self.sensorUnsupported = false }
            self.sensorAt = ProcessInfo.processInfo.systemUptime
            let settled = self.stillness.observe(angle:angle,at:self.sensorAt,delay:self.stillnessDelay)
            self.motionReference.observe(angle:angle,isStill:settled,clearWhenStill:self.clearWhenStill)
            let stillnessChanged = self.lidIsStill != settled
            if stillnessChanged {
                self.lidIsStill = settled
                self.updateStillnessStatus()
                if self.enabled && self.clearWhenStill && !self.demoRunning {
                    self.logger.notice("Lid stillness changed: \(settled,privacy:.public)")
                }
            }
            if angle == nil && self.enabled { self.pause(L10n.text("Lid sensor unavailable. Use the preview or reconnect the sensor.")) }
            // Keep every freshness/stillness observation, but avoid repeating
            // display discovery for identical 30 Hz sensor reports. The timer
            // still handles deadlines and the missing-report safety check.
            if angleChanged || stillnessChanged || self.waitingForSensor { self.update() }
        }
        sensor.onUnsupported = { [weak self] in
            guard let self, !self.sensorUnsupported else { return }
            self.sensorUnsupported = true
            self.status = L10n.text("Unsupported MacBook: no lid-angle sensor. Replay and Preview angle still show every effect.")
        }
        capture.onFirstFrame = { [weak self] in self?.update() }
        capture.onUnavailable = { [weak self] in self?.hideOverlay() }
        capture.onFailure = { [weak self] reason in self?.pause(L10n.format("Capture stopped: %@",reason)) }
        registerHotKey()
        if simulatesMissingSensor {
            sensorUnsupported = true
            status = L10n.text("Unsupported MacBook: no lid-angle sensor. Replay and Preview angle still show every effect.")
        } else {
            sensor.start()
        }
        timer = Timer(timeInterval:0.1,repeats:true) { [weak self] _ in
            MainActor.assumeIsolated { self?.update() }
        }
        RunLoop.main.add(timer!,forMode:.common)
        observeWorkspace()
    }

    private var fixedReference: Double { min(140,max(60,clearAngle.isFinite ? clearAngle : 105)) }
    var liveReference: Double { motionReference.reference(clearAngle:clearAngle) }

    private var previewState: FoldVisualState {
        if let start = previewStart {
            let t = ProcessInfo.processInfo.systemUptime-start
            if t <= 5 { return .at(angle:demoAngle(t/5),reference:fixedReference,curve:curve) }
        }
        if followLid { return liveState }
        return .at(angle:previewAngle,reference:fixedReference,curve:curve)
    }

    /// Both views read the same physical and optical state, including the clear handoff.
    func animatedState(preview: Bool) -> FoldVisualState? {
        if preview && (!followLid || previewPlaying) { return nil }
        let state = liveAnimation.sample(target:overlayVisible ? liveState : .clear,
                                         at:ProcessInfo.processInfo.systemUptime)
        if overlayVisible && overlayRevealed, let panel, panel.alphaValue != CGFloat(state.coverage) {
            panel.alphaValue = state.coverage
        }
        return state
    }

    func wakePreview() {
        if !overlayVisible { liveAnimation.prime(at:ProcessInfo.processInfo.systemUptime) }
        if let previewView { previewRenderer?.wake(previewView) }
    }

    func uniforms(preview: Bool) -> FoldUniforms {
        var u = FoldUniforms()
        let visual = preview ? previewState : liveState
        u.progress = Float(visual.progress);u.defocus = Float(visual.defocus);u.tilt = Float(visual.tilt)
        u.referenceAngle = Float(visual.referenceAngle)
        u.perspective = Float(perspective);u.blur = Float(blur);u.shadow = Float(shadow)
        u.intensity = options.shaderIntensity;u.segments = options.shaderSegments
        u.fadeOnly = reducedMotion ? 1 : 0
        u.effect = effect.shaderIndex // The desktop and its preview always share one selection.
        return u
    }

    var demoDuration: Double { syntheticCheckPath == nil ? 8 : 20 }

    var liveProgress: Double { liveState.progress }

    private var liveState: FoldVisualState {
        guard enabled,sessionActive,systemAwake,displayAwake,!waitingForSensor else { return .clear }
        if let start = demoStart {
            let t = min(1,(ProcessInfo.processInfo.systemUptime-start)/demoDuration)
            return .at(angle:demoAngle(t),reference:fixedReference,curve:curve)
        }
        if shouldClearForStillness { return .clear }
        guard let angle = lidAngle else { return .clear }
        return .at(angle:angle,reference:liveReference,curve:curve)
    }

    private func demoAngle(_ t: Double) -> Double { clearAngle + 8 - sin(min(1,max(0,t)) * .pi) * (clearAngle-12) }

    var shouldClearForStillness: Bool { clearWhenStill && lidIsStill && !demoRunning }

    func resetStillness() { stillness.reset(); motionReference.reset(); lidIsStill = false }

    func updateStillnessStatus() {
        guard enabled, !demoRunning else { return }
        status = shouldClearForStillness
            ? L10n.text("Lid is still. Move it to animate again.")
            : L10n.text("Following your lid. Close it gently to see the effect.")
    }

    func enable(startDesktopTest: Bool = false) {
        guard !checkingPermission else { return }
        guard device != nil else { status = L10n.text("This Mac does not have a supported Metal GPU.");return }
        guard sensorAvailable else {
            status = L10n.text(sensorUnsupported ? "Unsupported MacBook: no lid-angle sensor. Replay and Preview angle still show every effect."
                                                 : "No working lid angle sensor was found. The preview still works.")
            return
        }
        checkingPermission = true
        status = L10n.text("Checking screen access…")
        enableTask = Task { [weak self] in
            guard let self else { return }
            defer { self.checkingPermission = false }
            do {
                // Ask the API we actually use. Core Graphics preflight can retain an old
                // permission result and must not block an otherwise authorized SCK session.
                try await capture.verifyAccess()
                guard !Task.isCancelled else { return }
                self.hasPermission = true
                self.enabled = true
                self.status = L10n.text("Following your lid. Close it gently to see the effect.")
                self.updateStillnessStatus()
                self.logger.notice("Enable succeeded: ScreenCaptureKit access verified.")
                if startDesktopTest { self.beginDesktopTest() } else { self.update() }
            } catch {
                guard !Task.isCancelled else { return }
                self.enabled = false
                let failure = error as NSError
                if failure.domain == SCStreamErrorDomain && failure.code == SCStreamError.Code.userDeclined.rawValue {
                    self.hasPermission = false
                    self.status = L10n.text("Screen access was not accepted. Allow the copy of the app in Applications, then quit and reopen it. If its permission was already on for an older build, remove that old entry and add the current app.")
                } else {
                    self.status = L10n.format("Could not enable screen capture: %@",error.localizedDescription)
                }
                self.logger.error("Enable failed: \(failure.domain,privacy:.public) / \(failure.code)")
            }
        }
    }

    func pause(_ message: String = L10n.text("Paused. Your desktop is clear.")) {
        logger.notice("Following paused: \(message,privacy:.public)")
        enableTask?.cancel();enableTask = nil;checkingPermission = false
        if let path = syntheticCheckPath {
            let report: [String:Any] = ["generatedArtworkOnly":true,"screenCaptureStarted":capture.isRunning,
                "drawnFrames":renderer?.drawnFrames ?? 0,"presentedFrames":presentedFrames,
                "skippedFrames":renderer?.skippedFrames ?? 0,"preferredFPS":metalView?.preferredFramesPerSecond ?? 0,
                "stopReason":message,"overlayWasVisible":overlayVisible,"gpuTimeMS":renderer?.lastGPUTimeMS ?? 0]
            if let data = try? JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]) {
                do { try data.write(to:path,options:.withoutOverwriting) }
                catch { logger.error("Overlay check report was not written: \(error.localizedDescription,privacy:.public)") }
            }
            syntheticCheckPath = nil
            renderer?.reportsEveryPresentation = false
        }
        enabled = false;demoStart = nil;demoRunning = false
        hideOverlay();capture.stop();status = message
    }

    func playPreview() { previewStart = ProcessInfo.processInfo.systemUptime;previewPlaying = true }

    func testDesktop() {
        if !enabled { enable(startDesktopTest:true);return }
        beginDesktopTest()
    }

    private func beginDesktopTest() {
        demoStart = ProcessInfo.processInfo.systemUptime;demoRunning = true
        status = L10n.text("Eight-second desktop test. Press Esc to stop.")
        update()
    }

    /// Exercises the real overlay with generated pixels. Never requests or starts screen capture.
    func checkOverlay(output: String) {
        do {
            let report = try DiagnosticPaths.newFile(output)
            guard let screen = builtInScreen(), let device else { throw AppError.message(L10n.text("Built-in display or GPU unavailable.")) }
            try prepareOverlay(on:screen)
            let factory = try FoldRenderer(device:device)
            capture.frames.put(try factory.makeSyntheticFrame())
            syntheticCheckPath = report;presentedFrames = 0
            renderer?.reportsEveryPresentation = true
            enabled = true;demoStart = ProcessInfo.processInfo.systemUptime;demoRunning = true
            status = L10n.text("Testing the overlay with generated artwork. Esc stops the test.")
            update()
        } catch { pause(error.localizedDescription) }
    }

    func openPrivacy() {
        NSWorkspace.shared.open(URL(string:"x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
    }

    func retrySensor() { sensor.stop();sensor.start() }

    func shutdown() {
        pause();sensor.stop();timer?.invalidate()
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let hotKeyHandler { RemoveEventHandler(hotKeyHandler) }
        if let localKeyMonitor { NSEvent.removeMonitor(localKeyMonitor) }
    }
}
