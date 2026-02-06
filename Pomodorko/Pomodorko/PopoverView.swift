import SwiftUI
import KeyboardShortcuts
import LaunchAtLogin

private enum ChildView {
    case intervals, settings, about
}

struct PKPopoverView: View {
    @StateObject private var timer = PKTimer()
    @State private var activeChildView = ChildView.intervals
    @State private var currentStatusLabel = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Timer display and buttons
            if timer.timer == nil {
                // Idle state - single start button
                Button {
                    timer.startStop()
                    PKStatusItem.shared?.closePopover(nil)
                } label: {
                    Text(Personality.startLabel)
                        .foregroundColor(.white)
                        .font(.system(.body).monospacedDigit())
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            } else {
                // Timer is running or paused
                // Timer display
                Text(timer.timeLeftString)
                    .font(.system(.title, design: .monospaced))
                    .frame(maxWidth: .infinity)

                // State indicator
                HStack {
                    Spacer()
                    Text(currentStatusLabel)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .onChange(of: timer.currentState) { newState in
                    updateStatusLabel(for: newState)
                }
                .onAppear {
                    updateStatusLabel(for: timer.currentState)
                }

                // Two-button layout
                if timer.isPaused {
                    // Paused state
                    Button {
                        timer.resume()
                    } label: {
                        Text(Personality.resumeLabel)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)

                    Button {
                        timer.resetSession()
                    } label: {
                        Text(Personality.resetLabel)
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)
                } else {
                    // Running state
                    Button {
                        timer.pause()
                    } label: {
                        Text(Personality.pauseLabel)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)

                    Button {
                        timer.skipToNextPhaseAndPause()
                    } label: {
                        Text(Personality.stopLabel)
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)
                }
            }

            // Tab picker
            Picker("", selection: $activeChildView) {
                Text("Timer").tag(ChildView.intervals)
                Text("Settings").tag(ChildView.settings)
                Text("About").tag(ChildView.about)
            }
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .pickerStyle(.segmented)

            // Content area
            GroupBox {
                switch activeChildView {
                case .intervals:
                    IntervalsView()
                        .environmentObject(timer)
                case .settings:
                    SettingsView()
                        .environmentObject(timer)
                case .about:
                    AboutView()
                }
            }

            // Quit button
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Text("Quit Pomodorko")
                Spacer()
                Text("\u{2318}Q").foregroundColor(.gray)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q")
        }
        .padding(12)
    }

    private func updateStatusLabel(for state: PKStateMachineStates) {
        switch state {
        case .work:
            currentStatusLabel = Personality.randomWorkingLabel()
        case .shortRest, .longRest:
            currentStatusLabel = Personality.randomBreakLabel()
        case .idle:
            currentStatusLabel = ""
        }
    }
}

// MARK: - Intervals View (Timer Settings with Sliders)

private struct IntervalsView: View {
    @EnvironmentObject var timer: PKTimer

    var body: some View {
        VStack(spacing: 12) {
            SliderRow(
                label: "Work",
                value: Binding(
                    get: { Double(timer.workIntervalLength) },
                    set: { timer.workIntervalLength = Int($0) }
                ),
                range: 1...60,
                unit: "min"
            )

            SliderRow(
                label: "Short Break",
                value: Binding(
                    get: { Double(timer.shortRestIntervalLength) },
                    set: { timer.shortRestIntervalLength = Int($0) }
                ),
                range: 1...60,
                unit: "min"
            )

            SliderRow(
                label: "Long Break",
                value: Binding(
                    get: { Double(timer.longRestIntervalLength) },
                    set: { timer.longRestIntervalLength = Int($0) }
                ),
                range: 1...60,
                unit: "min"
            )

            SliderRow(
                label: "Intervals/Set",
                value: Binding(
                    get: { Double(timer.workIntervalsInSet) },
                    set: { timer.workIntervalsInSet = Int($0) }
                ),
                range: 1...10,
                unit: ""
            )

            Spacer().frame(minHeight: 0)
        }
        .padding(4)
    }
}

// MARK: - Slider Row Component

private struct SliderRow: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(value))\(unit.isEmpty ? "" : " \(unit)")")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.primary)
            }
            Slider(value: $value, in: range, step: 1)
        }
    }
}

// MARK: - Settings View

private struct SettingsView: View {
    @EnvironmentObject var timer: PKTimer

    var body: some View {
        VStack(spacing: 8) {
            // Keyboard shortcut
            KeyboardShortcuts.Recorder(for: .startStopTimer) {
                Text("Hotkey")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Toggle(isOn: $timer.stopAfterBreak) {
                Text("Stop after break")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .toggleStyle(.switch)

            Toggle(isOn: $timer.showTimerInMenuBar) {
                Text("Show timer in menu bar")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .toggleStyle(.switch)
            .onChange(of: timer.showTimerInMenuBar) { _ in
                timer.updateTimeLeft()
            }

            LaunchAtLogin.Toggle {
                Text("Launch at login")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .toggleStyle(.switch)

            Divider()

            // Volume slider
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Sound Effect Volume")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.1f", timer.soundPlayer.volume))
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.primary)
                }
                Slider(value: $timer.soundPlayer.volume, in: 0...2)
                    .gesture(TapGesture(count: 2).onEnded {
                        timer.soundPlayer.volume = 1.0
                    })
            }

            Spacer().frame(minHeight: 0)
        }
        .padding(4)
    }
}

// MARK: - About View

private struct AboutView: View {
    var body: some View {
        VStack(spacing: 12) {
            // App icon placeholder (brain)
            Image(systemName: "brain.head.profile")
                .font(.system(size: 40))
                .foregroundColor(.accentColor)

            Text("Pomodorko")
                .font(.headline)

            Text("v6.9")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            VStack(spacing: 4) {
                Text("Built by TCB Media, LLC")
                    .font(.caption)

                Text("Don't email me for tech support.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("Just fix it :)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Button {
                if let url = URL(string: "https://github.com/the-curated-brain/pomodorko") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Text("GitHub")
                    .font(.caption)
            }
            .buttonStyle(.link)

            Divider()

            VStack(spacing: 2) {
                Text("Icons by Lucide")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Button {
                    if let url = URL(string: "https://lucide.dev") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Text("lucide.dev")
                        .font(.caption2)
                }
                .buttonStyle(.link)
                Text("ISC License")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer().frame(minHeight: 0)
        }
        .padding(8)
    }
}

#Preview {
    PKPopoverView()
}
