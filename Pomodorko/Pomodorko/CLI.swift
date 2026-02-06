import Foundation

/// CLI support for Pomodorko
/// Usage: pomodorko [command]
/// Commands: start, stop, toggle, pause, reset, status, set, help
struct CLI {
    enum Command: String {
        case start
        case stop
        case toggle
        case pause
        case reset
        case status
        case set
        case help
    }

    enum Setting: String {
        case work
        case short
        case long
        case intervals
    }

    /// Process command line arguments
    /// Returns true if a CLI command was handled (app should exit)
    static func processArguments() -> Bool {
        let args = Array(CommandLine.arguments.dropFirst()) // Skip executable name

        guard let commandStr = args.first else {
            return false // No CLI arguments, run normally
        }

        guard let command = Command(rawValue: commandStr.lowercased()) else {
            print("Unknown command: \(commandStr)")
            printUsage()
            return true
        }

        switch command {
        case .help:
            printUsage()
            return true

        case .set:
            return processSetCommand(args: Array(args.dropFirst()))

        case .status:
            printStatus()
            return true

        case .start, .stop, .toggle, .pause, .reset:
            // Send command to running instance via distributed notification
            let center = DistributedNotificationCenter.default()
            center.postNotificationName(
                NSNotification.Name("com.curatedbrain.pomodorko.\(command.rawValue)"),
                object: nil,
                userInfo: nil,
                deliverImmediately: true
            )
            print("Sent '\(command.rawValue)' command to Pomodorko")
            return true
        }
    }

    private static func printStatus() {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let statusFile = cacheDir.appendingPathComponent("Pomodorko/status.json")

        guard let data = try? Data(contentsOf: statusFile),
              let status = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("Pomodorko is not running (no status file found)")
            return
        }

        let state = status["state"] as? String ?? "idle"
        let completedIntervals = status["completedIntervals"] as? Int ?? 0
        let totalIntervals = status["totalIntervals"] as? Int ?? 4
        let timeLeft = status["timeLeft"] as? String ?? ""
        let isPaused = status["isPaused"] as? Bool ?? false
        let isRunning = status["isRunning"] as? Bool ?? false
        let workMinutes = status["workMinutes"] as? Int ?? 25
        let shortBreakMinutes = status["shortBreakMinutes"] as? Int ?? 5
        let longBreakMinutes = status["longBreakMinutes"] as? Int ?? 15

        print("Pomodorko Status")
        print("================")
        print("Total intervals: \(totalIntervals)")
        print("Work: \(workMinutes) min | Short break: \(shortBreakMinutes) min | Long break: \(longBreakMinutes) min")
        print("")

        if !isRunning {
            print("Status: Idle")
            return
        }

        print("Progress:")
        for i in 1...totalIntervals {
            let workStatus: String
            let breakStatus: String
            let isLastInterval = (i == totalIntervals)
            let breakType = isLastInterval ? "Long break" : "Break \(i)"

            if state == "longRest" {
                // All work intervals complete, on long break
                workStatus = "complete"
                if isLastInterval {
                    let pausedStr = isPaused ? " (paused)" : ""
                    breakStatus = "current - \(timeLeft) remaining\(pausedStr)"
                } else {
                    breakStatus = "complete"
                }
            } else if state == "work" {
                // On a work interval
                // completedIntervals = fully completed work intervals
                // Current work = completedIntervals + 1
                if i <= completedIntervals {
                    // Past intervals
                    workStatus = "complete"
                    breakStatus = "complete"
                } else if i == completedIntervals + 1 {
                    // Current work interval
                    let pausedStr = isPaused ? " (paused)" : ""
                    workStatus = "current - \(timeLeft) remaining\(pausedStr)"
                    breakStatus = "pending"
                } else {
                    workStatus = "pending"
                    breakStatus = "pending"
                }
            } else if state == "shortRest" {
                // On a short break after work #completedIntervals
                if i < completedIntervals {
                    // Past intervals (both work and break done)
                    workStatus = "complete"
                    breakStatus = "complete"
                } else if i == completedIntervals {
                    // This work done, this break is current
                    workStatus = "complete"
                    let pausedStr = isPaused ? " (paused)" : ""
                    breakStatus = "current - \(timeLeft) remaining\(pausedStr)"
                } else {
                    workStatus = "pending"
                    breakStatus = "pending"
                }
            } else {
                // Idle or unknown
                workStatus = "pending"
                breakStatus = "pending"
            }

            print("  Work \(i): \(workStatus)")
            print("  \(breakType): \(breakStatus)")
        }
    }

    private static func processSetCommand(args: [String]) -> Bool {
        guard args.count >= 2,
              let setting = Setting(rawValue: args[0].lowercased()),
              let value = Int(args[1]),
              value > 0 else {
            print("Usage: pomodorko set <setting> <minutes>")
            print("Settings: work, short, long, intervals")
            print("Example: pomodorko set work 25")
            return true
        }

        // Validate ranges
        let maxValue: Int
        let settingName: String
        switch setting {
        case .work:
            maxValue = 60
            settingName = "work interval"
        case .short:
            maxValue = 60
            settingName = "short break"
        case .long:
            maxValue = 60
            settingName = "long break"
        case .intervals:
            maxValue = 10
            settingName = "intervals per set"
        }

        guard value <= maxValue else {
            print("Error: \(settingName) must be between 1 and \(maxValue)")
            return true
        }

        let center = DistributedNotificationCenter.default()
        center.postNotificationName(
            NSNotification.Name("com.curatedbrain.pomodorko.set.\(setting.rawValue)"),
            object: nil,
            userInfo: ["value": value],
            deliverImmediately: true
        )
        print("Set \(settingName) to \(value)\(setting == .intervals ? "" : " minutes")")
        return true
    }

    private static func printUsage() {
        print("""
        Pomodorko - Command Line Interface

        Usage: pomodorko [command]

        Commands:
          start   - Start the timer (if not already running)
          stop    - Skip to next phase (paused)
          pause   - Pause/resume the current timer
          reset   - Reset entire session back to idle
          status  - Print current timer status
          help    - Show this help message

        Settings:
          set work <minutes>      - Set work interval (1-60)
          set short <minutes>     - Set short break (1-60)
          set long <minutes>      - Set long break (1-60)
          set intervals <count>   - Set intervals per set (1-10)

        For scripting:
          toggle  - Toggle timer on/off (for single-button bindings)

        Examples:
          pomodorko start
          pomodorko pause
          pomodorko set work 25
          pomodorko set short 5
        """)
    }
}

/// Extension to handle CLI commands in the timer
extension PKTimer {
    func setupCLIHandlers() {
        let center = DistributedNotificationCenter.default()

        center.addObserver(
            forName: NSNotification.Name("com.curatedbrain.pomodorko.start"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            if self?.timer == nil {
                self?.startStop()
            }
        }

        center.addObserver(
            forName: NSNotification.Name("com.curatedbrain.pomodorko.stop"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            if self?.timer != nil {
                self?.skipToNextPhaseAndPause()
            }
        }

        center.addObserver(
            forName: NSNotification.Name("com.curatedbrain.pomodorko.toggle"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.startStop()
        }

        center.addObserver(
            forName: NSNotification.Name("com.curatedbrain.pomodorko.pause"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            if self.isPaused {
                self.resume()
            } else {
                self.pause()
            }
        }

        center.addObserver(
            forName: NSNotification.Name("com.curatedbrain.pomodorko.reset"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.resetSession()
        }

        // Settings handlers
        center.addObserver(
            forName: NSNotification.Name("com.curatedbrain.pomodorko.set.work"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let value = notification.userInfo?["value"] as? Int {
                self?.workIntervalLength = value
            }
        }

        center.addObserver(
            forName: NSNotification.Name("com.curatedbrain.pomodorko.set.short"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let value = notification.userInfo?["value"] as? Int {
                self?.shortRestIntervalLength = value
            }
        }

        center.addObserver(
            forName: NSNotification.Name("com.curatedbrain.pomodorko.set.long"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let value = notification.userInfo?["value"] as? Int {
                self?.longRestIntervalLength = value
            }
        }

        center.addObserver(
            forName: NSNotification.Name("com.curatedbrain.pomodorko.set.intervals"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let value = notification.userInfo?["value"] as? Int {
                self?.workIntervalsInSet = value
            }
        }
    }
}
