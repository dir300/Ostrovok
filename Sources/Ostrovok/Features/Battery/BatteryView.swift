import SwiftUI

struct BatteryView: View {
    @ObservedObject var model: BatteryMonitor
    @EnvironmentObject private var settings: Settings

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: CGFloat(model.percentage) / 100)
                    .stroke(model.isCharging ? Color.green : Color.white, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text("\(model.percentage)%")
                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                    if model.isCharging {
                        Label(L10n.text("battery.charging", settings.language), systemImage: "bolt.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.green)
                    }
                }
                .foregroundStyle(.white)
            }
            .frame(width: 100, height: 100)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
