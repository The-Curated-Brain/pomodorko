import Combine
import KeyboardShortcuts
import SwiftState
import SwiftUI

extension KeyboardShortcuts.Name {
    static let startStopTimer = Self("startStopTimer")
}

class PKTimer: ObservableObject {
    // MARK: - Settings (persisted via AppStorage)
    @AppStorage("stopAfterBreak") var stopAfterBreak = false
    @AppStorage("showTimerInMenuBar") var showTimerInMenuBar = true
    @AppStorage("workIntervalLength") var workIntervalLength = 25
    @AppStorage("shortRestIntervalLength") var shortRestIntervalLength = 5
    @AppStorage("longRestIntervalLength") var longRestIntervalLength = 15
    @AppStorage("workIntervalsInSet") var workIntervalsInSet = 4
    @AppStorage("overrunTimeLimit") var overrunTimeLimit = -60.0

    // MARK: - Components
    private var stateMachine = PKStateMachine(state: .idle)
    public var soundPlayer = PKSoundPlayer()

    // MARK: - State
    private var consecutiveWorkIntervals: Int = 0
    private var finishTime: Date!
    private var timerFormatter = DateComponentsFormatter()
    private var shouldPauseAfterTransition = false
    private var remainingSecondsWhenPaused: TimeInterval = 0
    private var cancellables = Set<AnyCancellable>()

    @Published var timeLeftString: String = ""
    @Published var timer: DispatchSourceTimer?
    @Published var currentState: PKStateMachineStates = .idle
    @Published var isPaused: Bool = false

    init() {
        setupStateMachine()
        setupTimerFormatter()
        setupKeyboardShortcut()
        setupCLIHandlers()

        // Forward soundPlayer changes to this object
        soundPlayer.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        PKLogger.shared.logAppStart()
        writeStatusFile()
    }

    // MARK: - State Machine Setup

    private func setupStateMachine() {
        // State transitions for startStop event
        stateMachine.addRoutes(event: .startStop, transitions: [
            .idle => .work,
            .work => .idle,
            .shortRest => .idle,
            .longRest => .idle
        ])

        // Timer fired during work -> go to rest
        // Note: consecutiveWorkIntervals is checked BEFORE onWorkFinish increments it
        // So we compare against workIntervalsInSet - 1
        stateMachine.addRoutes(event: .timerFired, transitions: [.work => .shortRest]) { [weak self] _ in
            guard let self = self else { return false }
            return self.consecutiveWorkIntervals < self.workIntervalsInSet - 1
        }
        stateMachine.addRoutes(event: .timerFired, transitions: [.work => .longRest]) { [weak self] _ in
            guard let self = self else { return false }
            return self.consecutiveWorkIntervals >= self.workIntervalsInSet - 1
        }

        // Timer fired during rest
        stateMachine.addRoutes(event: .timerFired, transitions: [.shortRest => .idle, .longRest => .idle]) { [weak self] _ in
            self?.stopAfterBreak ?? false
        }
        stateMachine.addRoutes(event: .timerFired, transitions: [.shortRest => .work, .longRest => .work]) { [weak self] _ in
            !(self?.stopAfterBreak ?? false)
        }

        // Skip rest
        stateMachine.addRoutes(event: .skipRest, transitions: [.shortRest => .work, .longRest => .work])

        // State handlers
        stateMachine.addAnyHandler(.any => .work, handler: onWorkStart)
        stateMachine.addAnyHandler(.work => .shortRest, order: 0, handler: onWorkFinish)
        stateMachine.addAnyHandler(.work => .longRest, order: 0, handler: onWorkFinish)
        stateMachine.addAnyHandler(.work => .idle, order: 0, handler: onWorkCancelled)
        stateMachine.addAnyHandler(.any => .shortRest, handler: onShortRestStart)
        stateMachine.addAnyHandler(.any => .longRest, handler: onLongRestStart)
        stateMachine.addAnyHandler(.shortRest => .work, order: 0, handler: onRestFinish)
        stateMachine.addAnyHandler(.longRest => .work, order: 0, handler: onRestFinish)
        stateMachine.addAnyHandler(.any => .idle, handler: onIdleStart)

        // Log all transitions
        stateMachine.addAnyHandler(.any => .any) { [weak self] ctx in
            self?.currentState = ctx.toState
        }

        stateMachine.addErrorHandler { ctx in
            print("State machine error: \(ctx)")
        }
    }

    private func setupTimerFormatter() {
        timerFormatter.unitsStyle = .positional
        timerFormatter.allowedUnits = [.minute, .second]
        timerFormatter.zeroFormattingBehavior = .pad
    }

    private func setupKeyboardShortcut() {
        KeyboardShortcuts.onKeyUp(for: .startStopTimer, action: { [weak self] in
            self?.startStop()
        })
    }

    // MARK: - Public Actions

    func startStop() {
        stateMachine <-! .startStop
    }

    func skipRest() {
        stateMachine <-! .skipRest
    }

    func pause() {
        guard timer != nil, !isPaused else { return }
        isPaused = true
        remainingSecondsWhenPaused = max(0, finishTime.timeIntervalSince(Date()))
        timer?.suspend()
        updateTimeLeft()
        PKLogger.shared.log(event: "paused", details: "state=\(currentState)")
    }

    func resume() {
        guard timer != nil, isPaused else { return }
        isPaused = false
        finishTime = Date().addingTimeInterval(remainingSecondsWhenPaused)
        timer?.resume()
        PKLogger.shared.log(event: "resumed", details: "state=\(currentState)")
    }

    func resetSession() {
        shouldPauseAfterTransition = false
        stateMachine <-! .startStop
    }

    func skipToNextPhaseAndPause() {
        shouldPauseAfterTransition = true

        switch currentState {
        case .work:
            // Fire timerFired to transition work -> rest
            stateMachine <-! .timerFired

        case .shortRest, .longRest:
            // Check if should go to idle or work
            if stopAfterBreak && currentState == .longRest {
                shouldPauseAfterTransition = false  // Can't pause in idle
                stateMachine <-! .startStop  // Goes to idle
            } else {
                stateMachine <-! .skipRest  // Goes to work
            }

        case .idle:
            break
        }
    }

    func updateTimeLeft() {
        if isPaused {
            // Show frozen time when paused
            timeLeftString = timerFormatter.string(from: remainingSecondsWhenPaused) ?? "00:00"
        } else if let finishTime = finishTime {
            timeLeftString = timerFormatter.string(from: Date(), to: finishTime) ?? "00:00"
        } else {
            timeLeftString = ""
        }

        if timer != nil, showTimerInMenuBar {
            PKStatusItem.shared?.setTitle(title: timeLeftString)
        } else {
            PKStatusItem.shared?.setTitle(title: nil)
        }

        writeStatusFile()
    }

    private func writeStatusFile() {
        let status: [String: Any] = [
            "state": currentState.rawValue,
            "completedIntervals": consecutiveWorkIntervals,
            "totalIntervals": workIntervalsInSet,
            "timeLeft": timeLeftString,
            "isPaused": isPaused,
            "isRunning": timer != nil,
            "workMinutes": workIntervalLength,
            "shortBreakMinutes": shortRestIntervalLength,
            "longBreakMinutes": longRestIntervalLength
        ]

        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let pomodorkoDir = cacheDir.appendingPathComponent("Pomodorko")
        try? FileManager.default.createDirectory(at: pomodorkoDir, withIntermediateDirectories: true)

        let statusFile = pomodorkoDir.appendingPathComponent("status.json")
        if let data = try? JSONSerialization.data(withJSONObject: status, options: []) {
            try? data.write(to: statusFile)
        }
    }

    // MARK: - Timer Management

    private func startTimer(seconds: Int) {
        finishTime = Date().addingTimeInterval(TimeInterval(seconds))

        let queue = DispatchQueue(label: "PomodorkoTimer")
        timer = DispatchSource.makeTimerSource(flags: .strict, queue: queue)
        timer!.schedule(deadline: .now(), repeating: .seconds(1), leeway: .never)
        timer!.setEventHandler(handler: onTimerTick)
        timer!.setCancelHandler(handler: onTimerCancel)
        timer!.resume()
    }

    private func stopTimer() {
        if isPaused {
            // Must resume before cancelling a suspended timer
            timer?.resume()
            isPaused = false
        }
        timer?.cancel()
        timer = nil
        finishTime = nil
        remainingSecondsWhenPaused = 0
    }

    private func onTimerTick() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let finishTime = self.finishTime else { return }
            self.updateTimeLeft()
            let timeLeft = finishTime.timeIntervalSince(Date())
            if timeLeft <= 0 {
                // Handle overrun (e.g., machine sleep)
                if timeLeft < self.overrunTimeLimit {
                    self.stateMachine <-! .startStop
                } else {
                    self.stateMachine <-! .timerFired
                }
            }
        }
    }

    private func onTimerCancel() {
        DispatchQueue.main.async { [weak self] in
            self?.updateTimeLeft()
        }
    }

    // MARK: - State Handlers

    private func onWorkStart(context _: PKStateMachine.Context) {
        PKStatusItem.shared?.setIcon(name: .work)
        startTimer(seconds: workIntervalLength * 60)
        PKLogger.shared.logWorkStart(duration: workIntervalLength)

        if shouldPauseAfterTransition {
            shouldPauseAfterTransition = false
            pause()
        }
    }

    private func onWorkFinish(context _: PKStateMachine.Context) {
        consecutiveWorkIntervals += 1
        PKLogger.shared.logWorkEnd(completed: true)
    }

    private func onWorkCancelled(context _: PKStateMachine.Context) {
        PKLogger.shared.logWorkEnd(completed: false)
        PKLogger.shared.logStopped()
    }

    private func onShortRestStart(context _: PKStateMachine.Context) {
        soundPlayer.playWorkComplete()
        PKStatusItem.shared?.setIcon(name: .break)
        startTimer(seconds: shortRestIntervalLength * 60)
        PKLogger.shared.logBreakStart(type: "short", duration: shortRestIntervalLength)

        if shouldPauseAfterTransition {
            shouldPauseAfterTransition = false
            pause()
        }
    }

    private func onLongRestStart(context _: PKStateMachine.Context) {
        soundPlayer.playSetComplete()
        PKStatusItem.shared?.setIcon(name: .break)
        consecutiveWorkIntervals = 0
        startTimer(seconds: longRestIntervalLength * 60)
        PKLogger.shared.logBreakStart(type: "long", duration: longRestIntervalLength)

        if shouldPauseAfterTransition {
            shouldPauseAfterTransition = false
            pause()
        }
    }

    private func onRestFinish(context ctx: PKStateMachine.Context) {
        let skipped = ctx.event == .skipRest
        soundPlayer.playBreakComplete()
        PKLogger.shared.logBreakEnd(skipped: skipped)
    }

    private func onIdleStart(context _: PKStateMachine.Context) {
        stopTimer()
        PKStatusItem.shared?.setIcon(name: .idle)
        consecutiveWorkIntervals = 0
        writeStatusFile()
    }
}
