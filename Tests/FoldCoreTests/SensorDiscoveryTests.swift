import Foundation
import Testing
@testable import FoldCore

@Test func discoveryRetriesBeforeCallingTheSensorAbsent() {
    var discovery = SensorDiscovery(maximumAttempts: 4, retryDelay: 0.75)
    #expect(discovery.attempts == 0)
    #expect(!discovery.hasGivenUp)
    for attempt in 1...3 {
        #expect(discovery.failed() == .retry(after: 0.75), "attempt \(attempt) must keep looking")
        #expect(!discovery.hasGivenUp)
    }
    #expect(discovery.failed() == .unsupported)
    #expect(discovery.hasGivenUp)
    // Staying given up is what stops the interface flickering between states.
    #expect(discovery.failed() == .unsupported)
}

@Test func findingTheSensorRestartsTheBudget() {
    var discovery = SensorDiscovery(maximumAttempts: 2, retryDelay: 0.5)
    #expect(discovery.failed() == .retry(after: 0.5))
    discovery.reset()
    #expect(discovery.attempts == 0)
    #expect(!discovery.hasGivenUp)
    #expect(discovery.failed() == .retry(after: 0.5), "a reconnect gets the full budget again")
    #expect(discovery.failed() == .unsupported)
}

@Test func discoveryClampsUnusableConfiguration() {
    var single = SensorDiscovery(maximumAttempts: 0, retryDelay: 1)
    #expect(single.maximumAttempts == 1)
    #expect(single.failed() == .unsupported, "one attempt is the minimum and settles immediately")

    for bad in [0.0, -1.0, Double.nan, Double.infinity] {
        #expect(SensorDiscovery(retryDelay: bad).retryDelay == SensorDiscovery.defaultDelay)
    }
    #expect(SensorDiscovery().maximumAttempts == SensorDiscovery.defaultAttempts)
    #expect(SensorDiscovery().retryDelay == SensorDiscovery.defaultDelay)
}
