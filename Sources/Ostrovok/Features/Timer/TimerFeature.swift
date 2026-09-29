import AppKit
import Combine
import SwiftUI

/// A simple countdown timer (pomodoro-style). Pure Foundation — no permissions
/// or private APIs.
@MainActor
final class TimerModel: ObservableObject, Feature {
    let id = "timer"
    let titleKey = "feature.timer"
    let symbolName = "timer"

    @Published private(set) var remaining: TimeInterval = 25 * 60
    @Published private(set) var isRunning = false

    private var endDate: Date?
    private var timer: Timer?

    private var currentRemaining: TimeInterval {
        guard let endDate else { return remaining }
        return max(0, endDate.timeIntervalSinceNow)
    }

    func startPause() {
        isRunning ? pause() : start()
    }

    func start() {
        guard !isRunning else { return }
        endDate = Date().addingTimeInterval(remaining)
        isRunning = true
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func pause() {
        guard isRunning else { return }
        remaining = currentRemaining
        endDate = nil
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    func reset() {
        pause()
        remaining = 25 * 60
    }

    private func tick() {
        let value = currentRemaining
        if value <= 0 {
            remaining = 0
            pause()
        } else {
            remaining = value
        }
    }

    // MARK: - Feature

    var expandedView: AnyView { AnyView(TimerView(model: self)) }

    static func formatInterval(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded())
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

struct TimerView: View {
    @ObservedObject var model: TimerModel

    var body: some View {
        VStack(spacing: 12) {
            Text(TimerModel.formatInterval(model.remaining))
                .font(.system(size: 40, weight: .light, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)

            HStack(spacing: 16) {
                Button { model.startPause() } label: {
                    Image(systemName: model.isRunning ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 32))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)

                Button { model.reset() } label: {
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                        .font(.system(size: 26))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
