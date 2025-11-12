import Foundation
import SwiftTUI

class TimerViewModel: ObservableObject {
    @Published var timers: [TimerDashboardEntry] = []
    private let manager: TimerManager
    private var refreshTimer: Foundation.Timer?
    
    init(manager: TimerManager) {
        self.manager = manager
        self._timers = .init(initialValue: makeDashboardEntries(manager: manager))
        
        refreshTimer = Foundation.Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            self.refresh()
        }
    }
    
    deinit {
        refreshTimer?.invalidate()
    }
    
    func refresh() {
        timers = makeDashboardEntries(manager: manager)
    }
}
