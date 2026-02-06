import Foundation

/// CSV Logger for Pomodorko state transitions
/// Format: timestamp,event,details
class PKLogger {
    private let logHandle: FileHandle?
    private let dateFormatter: ISO8601DateFormatter

    static let shared = PKLogger()

    private init() {
        dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let fileManager = FileManager.default

        // Create Pomodorko cache directory if needed
        let cacheDir = fileManager
            .urls(for: .cachesDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("Pomodorko")

        if !fileManager.fileExists(atPath: cacheDir.path) {
            try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        }

        let logPath = cacheDir.appendingPathComponent("pomodorko.log").path

        // Create file with CSV header if it doesn't exist
        if !fileManager.fileExists(atPath: logPath) {
            let header = "timestamp,event,details\n"
            guard fileManager.createFile(atPath: logPath, contents: header.data(using: .utf8)) else {
                print("Cannot create log file")
                logHandle = nil
                return
            }
        }

        logHandle = FileHandle(forUpdatingAtPath: logPath)
        guard logHandle != nil else {
            print("Cannot open log file")
            return
        }
    }

    func log(event: String, details: String = "") {
        guard let logHandle = logHandle else { return }

        let timestamp = dateFormatter.string(from: Date())
        // Escape details for CSV (wrap in quotes if contains comma)
        let escapedDetails = details.contains(",") ? "\"\(details)\"" : details
        let line = "\(timestamp),\(event),\(escapedDetails)\n"

        do {
            try logHandle.seekToEnd()
            try logHandle.write(contentsOf: line.data(using: .utf8)!)
            try logHandle.synchronize()
        } catch {
            print("Cannot write to log file: \(error)")
        }
    }

    // Convenience methods
    func logAppStart() {
        log(event: "app_start", details: "Pomodorko launched")
    }

    func logWorkStart(duration: Int) {
        log(event: "work_start", details: "duration=\(duration)min")
    }

    func logWorkEnd(completed: Bool) {
        log(event: "work_end", details: completed ? "completed" : "stopped")
    }

    func logBreakStart(type: String, duration: Int) {
        log(event: "break_start", details: "type=\(type),duration=\(duration)min")
    }

    func logBreakEnd(skipped: Bool) {
        log(event: "break_end", details: skipped ? "skipped" : "completed")
    }

    func logStopped() {
        log(event: "stopped", details: "user stopped timer")
    }
}
