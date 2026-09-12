import AppKit
import MetalKit
import Carbon
import FoldCore
import OSLog
import IOKit.ps

extension AppModel {
    func builtInScreen() -> NSScreen? {
        NSScreen.screens.first { screen in
            guard let n = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return false }
            return CGDisplayIsBuiltin(n.uint32Value) != 0 && CGDisplayIsActive(n.uint32Value) != 0
        }
    }

    func prepareOverlay(on screen: NSScreen) throws {
        guard let device else { throw AppError.message(L10n.text("Metal is unavailable.")) }
        let displayID = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as! NSNumber).uint32Value
        if screenID != displayID || panel?.frame != screen.frame {
            hideOverlay();panel?.close();panel = nil;renderer = nil;metalView = nil;capture.stop()
        }
        screenID = displayID
        guard panel == nil else { return }
        let panel = OverlayPanel(contentRect:screen.frame,styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false,screen:screen)
        panel.level = NSWindow.Level(rawValue:Int(CGWindowLevelForKey(.statusWindow))+1)
        panel.isOpaque = true;panel.backgroundColor = .black;panel.hasShadow = false
        panel.ignoresMouseEvents = true;panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces,.fullScreenAuxiliary,.stationary,.ignoresCycle]
        panel.isReleasedWhenClosed = false
        panel.sharingType = .none
        panel.setFrame(screen.frame,display:false)
        let renderer = try FoldRenderer(device:device)
        renderer.frames = capture.frames
        renderer.parameters = { [weak self] in self?.uniforms(preview:false) ?? FoldUniforms() }
        renderer.animatedState = { [weak self] in self?.animatedState(preview:false) }
        renderer.onFailure = { [weak self] reason in self?.pause(reason) }
        renderer.onPresented = { [weak self] in
            guard let self, self.enabled, self.overlayVisible, self.capture.frames.hasFrame else { return }
            // Reveal once after texture readiness. Later completions must never
            // undo the animated fade; FoldRenderer discards older generations.
            if !self.overlayRevealed {
                self.overlayRevealed = true
                self.panel?.alphaValue = self.liveAnimation.value.coverage
                self.logger.notice("Overlay texture ready; following the shared transition.")
            }
            self.presentedFrames += 1
        }
        let view = MTKView(frame:NSRect(origin:.zero,size:screen.frame.size),device:device)
        renderer.configure(view);view.isPaused = true
        panel.contentView = view
        self.panel = panel;self.metalView = view;self.renderer = renderer
    }

    func update() {
        let now = ProcessInfo.processInfo.systemUptime
        updateFrameRate(at:now)
        if !overlayVisible { liveAnimation.prime(at:now) }
        if let start = previewStart, now-start > 5 {
            previewStart = nil;previewPlaying = false;previewAngle = clearAngle+8
        }
        if let start = demoStart, now-start > demoDuration {
            if syntheticCheckPath != nil { pause(L10n.text("Synthetic overlay test completed."));return }
            demoStart = nil;demoRunning = false
            status = L10n.text("Desktop test finished. Following your lid.")
            updateStillnessStatus()
            logger.notice("Desktop test completed; overlay is clearing.")
        }
        guard enabled, sessionActive, systemAwake, displayAwake else { return }
        if now-sensorAt > 1 {
                // Delivery gaps need not mean the HID device has disconnected.
                // Fail open immediately and resume when fresh readings arrive.
            hideOverlay()
            if capture.isRunning { capture.stop() }
            if !waitingForSensor {
                waitingForSensor = true
                status = L10n.text("Waiting for the lid sensor. Your desktop is clear.")
                logger.notice("Sensor reports delayed: overlay cleared; awaiting fresh readings.")
            }
            return
        }
        if waitingForSensor {
            waitingForSensor = false;updateStillnessStatus()
            logger.notice("Fresh sensor reports received; automatic following resumed.")
        }
        let target = liveProgress
        let shouldCapture = demoRunning || (!shouldClearForStillness && (lidAngle ?? 180) < liveReference+14)
        guard shouldCapture || capture.isRunning || overlayVisible else { return }
        guard let screen = builtInScreen(), let display = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
              CGDisplayIsInMirrorSet(display.uint32Value) == 0 else {
            pause(L10n.text("Macbook Duo needs an active, unmirrored built-in display."));return
        }
        if shouldCapture {
            idleSince = nil
            do { try prepareOverlay(on:screen) } catch { pause(error.localizedDescription);return }
            if !capture.isRunning && syntheticCheckPath == nil {
                let width = Int(screen.frame.width*screen.backingScaleFactor)
                let height = Int(screen.frame.height*screen.backingScaleFactor)
                Task {
                    guard enabled,sessionActive,systemAwake,displayAwake,!shouldClearForStillness,
                          ProcessInfo.processInfo.systemUptime-sensorAt <= 1 else { return }
                    do { try await capture.start(displayID:display.uint32Value,width:width,height:height,fps:min(60,fps)) }
                    catch { if enabled { pause(L10n.format("Cannot capture the desktop: %@",error.localizedDescription)) } }
                }
            }
        } else if capture.isRunning {
            if idleSince == nil { idleSince = now }
            if now-(idleSince ?? now) > 1.2 && !overlayVisible { capture.stop() }
        }
        if target > 0.0001, capture.frames.hasFrame {
            if !overlayVisible {
                // Require a working escape route before putting anything over the desktop.
                guard registerEscape() else { pause(L10n.text("Could not register Esc. Close other keyboard utilities and try again."));return }
                renderer?.resetProgress(to:0)
                liveAnimation.reset()
                panel?.alphaValue = 0; overlayRevealed = false
                overlayVisible = true
                overlayVisibilityChanged?(true)
                panel?.orderFrontRegardless()
                // Let MTKView own and retire its drawable. Start with a paused,
                // explicit view draw, then use the display-paced render loop.
                metalView?.isPaused = true
                metalView?.draw()
                metalView?.isPaused = false
            }
        }
        if overlayVisible {
            let state = animatedState(preview:false) ?? .clear
            if !capture.frames.hasFrame {
                hideOverlay()
            } else if target == 0 && state.isClear {
                // Coverage has already reached zero: swapping to the desktop can
                // no longer expose an old or black drawable, even if the GPU is late.
                panel?.alphaValue = 0
                hideOverlay()
                logger.notice("Clear transition finished; overlay handed back to desktop.")
            }
        }
        if shouldClearForStillness && !overlayVisible && capture.isRunning {
            capture.stop(); idleSince = nil
            logger.notice("Stationary lid: overlay cleared and capture stopped.")
        }
    }

    func hideOverlay() {
        panel?.orderOut(nil);panel?.alphaValue = 0;metalView?.isPaused = true
        metalView?.releaseDrawables()
        overlayVisible = false; overlayRevealed = false
        renderer?.releaseTransientResources()
        liveAnimation.reset()
        overlayVisibilityChanged?(false)
        if let escapeKey { UnregisterEventHotKey(escapeKey);self.escapeKey = nil }
    }

    private func updateFrameRate(at now: TimeInterval) {
        if now-powerCheckedAt >= 2 {
            powerCheckedAt = now
            let info = ProcessInfo.processInfo
            let externalPower: Bool
            if let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() {
                externalPower = IOPSGetProvidingPowerSourceType(snapshot)?.takeUnretainedValue() as String? == kIOPSACPowerValue
            } else { externalPower = false }
            let rate = FoldFramePacing.rate(maximum:builtInScreen()?.maximumFramesPerSecond ?? 60,
                externalPower:externalPower,lowPower:info.isLowPowerModeEnabled,
                thermalPressure:info.thermalState == .serious || info.thermalState == .critical,moving:true)
            if fps != rate {
                fps = rate
                logger.notice("Motion refresh cap: \(rate) Hz; capture stays at most 60 Hz.")
            }
        }
        let pollRate = FoldFramePacing.sensorRate(renderRate:fps,enabled:enabled,still:lidIsStill)
        if sensorPollRate != pollRate {
            sensorPollRate = pollRate
            sensor.setPollingRate(pollRate)
        }
        let rate = demoRunning || !lidIsStill ? fps : min(60,fps)
        if metalView?.preferredFramesPerSecond != rate { metalView?.preferredFramesPerSecond = rate }
    }
}
