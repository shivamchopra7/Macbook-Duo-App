import AppKit
import OSLog

extension AppModel {
    func observeWorkspace() {
        let nc = NSWorkspace.shared.notificationCenter
        notifications.append(nc.addObserver(forName:NSWorkspace.activeSpaceDidChangeNotification,object:nil,queue:.main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                // Drop pixels from the previous Space and resume from a fresh frame.
                // Changing desktops never changes the user's enabled state.
                self.hideOverlay();self.capture.stop()
                self.logger.notice("Desktop changed; following remains enabled: \(self.enabled,privacy:.public).")
                self.update()
            }
        })
        let sleepEvents: [(Notification.Name, Int)] = [
            (NSWorkspace.willSleepNotification,0), (NSWorkspace.screensDidSleepNotification,1),
            (NSWorkspace.sessionDidResignActiveNotification,2)]
        let wakeEvents: [(Notification.Name, Int)] = [
            (NSWorkspace.didWakeNotification,0), (NSWorkspace.screensDidWakeNotification,1),
            (NSWorkspace.sessionDidBecomeActiveNotification,2)]
        for (name,kind) in sleepEvents {
            notifications.append(nc.addObserver(forName:name,object:nil,queue:.main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    if kind == 0 { self.systemAwake = false }
                    if kind == 1 { self.displayAwake = false }
                    if kind == 2 { self.sessionActive = false }
                    self.resetStillness()
                    self.hideOverlay();self.capture.stop();self.sensor.stop()
                }
            })
        }
        for (name,kind) in wakeEvents {
            notifications.append(nc.addObserver(forName:name,object:nil,queue:.main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    if kind == 0 { self.systemAwake = true }
                    if kind == 1 { self.displayAwake = true }
                    if kind == 2 { self.sessionActive = true }
                    // A display wake must not reactivate another user's session.
                    guard self.systemAwake,self.displayAwake,self.sessionActive else { return }
                    self.lidAngle = nil;self.sensorAt = ProcessInfo.processInfo.systemUptime
                    self.resetStillness();self.updateStillnessStatus()
                    self.sensor.start()
                }
            })
        }
        notifications.append(NotificationCenter.default.addObserver(forName:NSApplication.didChangeScreenParametersNotification,object:nil,queue:.main) { [weak self] _ in
            MainActor.assumeIsolated { self?.hideOverlay();self?.capture.stop();self?.panel?.close();self?.panel = nil;self?.screenID = nil }
        })
        notifications.append(nc.addObserver(forName:NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,object:nil,queue:.main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reducedMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
        })
    }
}
