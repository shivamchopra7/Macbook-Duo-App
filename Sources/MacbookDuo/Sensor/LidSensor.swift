import Foundation
import IOKit.hid
import FoldCore

/// The HID report layout was identified by Sam Henri Gold's LidAngleSensor.
/// This reader performs bounded feature reads on a dedicated queue, never the UI thread.
final class LidSensor {
    private let queue = DispatchQueue(label: "com.shivamchopra.macbookduo.sensor", qos: .userInteractive)
    private var manager: IOHIDManager?
    private var device: IOHIDDevice?
    private var timer: DispatchSourceTimer?
    private var failures = 0
    private var pollHz = 60
    private var discovery = SensorDiscovery()
    private var stopped = true
    var onReading: ((Double?) -> Void)?
    /// Called once discovery has given up: this Mac has no lid-angle sensor.
    var onUnsupported: (() -> Void)?

    func setPollingRate(_ rate: Int) {
        let rate = max(1,rate)
        queue.async { [weak self] in
            guard let self, self.pollHz != rate else { return }
            self.pollHz = rate
            self.timer?.schedule(deadline:.now(),repeating:1.0/Double(rate),leeway:.milliseconds(2))
        }
    }

    func start() {
        queue.async { [weak self] in
            guard let self else { return }
            self.stopped = false
            self.discovery.reset()
            self.attemptDiscovery()
        }
    }

    /// Discovery can come up empty right after launch or a wake even on a Mac
    /// that has the sensor, so an empty result is retried a few times before
    /// the hardware is reported as unsupported.
    private func attemptDiscovery() {
        queue.async { [weak self] in
            guard let self, !self.stopped, self.timer == nil else { return }
            let manager = IOHIDManagerCreate(kCFAllocatorDefault, 0)
            IOHIDManagerSetDeviceMatching(manager, [kIOHIDDeviceUsagePageKey: 0x20,
                                                   kIOHIDDeviceUsageKey: 0x8A] as CFDictionary)
            guard IOHIDManagerOpen(manager, 0) == kIOReturnSuccess else {
                self.discoveryFailed(); return
            }
            self.manager = manager
            let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> ?? []
            guard let device = devices.first, IOHIDDeviceOpen(device, 0) == kIOReturnSuccess else {
                self.cleanUp(); self.discoveryFailed(); return
            }
            self.device = device
            self.failures = 0
            self.discovery.reset()
            let timer = DispatchSource.makeTimerSource(queue: self.queue)
            timer.schedule(deadline:.now(),repeating:1.0/Double(self.pollHz),leeway:.milliseconds(2))
            timer.setEventHandler { [weak self] in self?.read() }
            self.timer = timer
            timer.resume()
        }
    }

    func stop() { queue.async { [weak self] in self?.stopped = true; self?.cleanUp() } }

    private func discoveryFailed() {
        deliver(nil)
        switch discovery.failed() {
        case .retry(let delay):
            queue.asyncAfter(deadline:.now()+delay) { [weak self] in self?.attemptDiscovery() }
        case .unsupported:
            DispatchQueue.main.async { [weak self] in self?.onUnsupported?() }
        }
    }

    private func read() {
        guard let device else { return }
        var bytes = [UInt8](repeating: 0, count: 8)
        var count = bytes.count
        let result = IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, 1, &bytes, &count)
        if result == kIOReturnSuccess, let angle = FoldMath.decodeReport(Array(bytes.prefix(count))) {
            failures = 0; deliver(angle)
        } else {
            failures += 1
            if failures == 15 { deliver(nil) }
        }
    }

    private func deliver(_ angle: Double?) {
        DispatchQueue.main.async { [weak self] in self?.onReading?(angle) }
    }

    private func cleanUp() {
        timer?.cancel(); timer = nil
        if let device { IOHIDDeviceClose(device, 0) }
        if let manager { IOHIDManagerClose(manager, 0) }
        device = nil; manager = nil
    }
}
