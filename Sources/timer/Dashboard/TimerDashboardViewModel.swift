import Foundation
import SwiftTUI

class TimerViewModel: ObservableObject {
    @Published var timers: [TimerDashboardEntry] = []
    private let manager: TimerManager
    private var refreshTimer: DispatchSourceTimer?
    
    init(manager: TimerManager) {
        self.manager = manager
        self._timers = .init(initialValue: makeDashboardEntries(manager: manager))
        startRefreshTimer()
    }
    
    deinit {
        refreshTimer?.cancel()
    }
    
    func refresh() {
        DispatchQueue.main.async {
            self.timers = makeDashboardEntries(manager: self.manager)
        }
    }
    
    private func startRefreshTimer() {
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .background))
        timer.schedule(deadline: .now() + .seconds(10), repeating: .seconds(10))
        timer.setEventHandler { [weak self] in
            self?.refresh()
        }
        timer.resume()
        refreshTimer = timer
    }
}
