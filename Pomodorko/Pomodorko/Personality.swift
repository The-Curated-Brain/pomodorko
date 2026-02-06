import Foundation

/// The personality engine for Pomodorko - a mix of J. Kenji López-Alt and Doc Brown
struct Personality {

    // MARK: - Button Labels

    static let startLabel = "Start Pomodorking"
    static let stopLabel = "Stop Pomodorking"
    static let pauseLabel = "Pause Pomodorking"
    static let resumeLabel = "Resume Pomodorking"
    static let resetLabel = "Reset Entire Session"

    static let workingLabels = [
        "SCIENCE IN PROGRESS",
        "BRAIN AT WORK",
        "COOKING...",
        "EXPERIMENTING..."
    ]

    static let breakLabels = [
        "REFUELING THE BRAIN",
        "COOLDOWN MODE",
        "RECHARGING..."
    ]

    // MARK: - Notifications

    static let workCompleteMessages = [
        (title: "GREAT SCOTT!", body: "You did it! Time for a break."),
        (title: "Hypothesis Confirmed!", body: "Hard work pays off. Rest now."),
        (title: "Experiment Complete!", body: "Your brain needs coolant."),
        (title: "Excellent Work!", body: "The science is sound. Take a breather."),
        (title: "SUCCESS!", body: "That's some quality mise en place right there.")
    ]

    static let longBreakMessages = [
        (title: "MAJOR BREAKTHROUGH!", body: "You've earned a proper rest."),
        (title: "FOUR INTERVALS!", body: "That's some serious mise en place for success!"),
        (title: "Great Scott!", body: "You've generated 1.21 gigawatts of productivity!"),
        (title: "Set Complete!", body: "Your neurons have performed admirably.")
    ]

    static let breakOverMessages = [
        (title: "Back to the Lab!", body: "Your neurons are recharged!"),
        (title: "Break's Over!", body: "Time to make some serious progress!"),
        (title: "The Flux Capacitor is Ready!", body: "Let's GO!"),
        (title: "Neurons Refueled!", body: "The experiment continues!"),
        (title: "Ready for Action!", body: "Your brain is primed and ready.")
    ]

    // MARK: - Random Selection

    static func randomWorkingLabel() -> String {
        workingLabels.randomElement()!
    }

    static func randomBreakLabel() -> String {
        breakLabels.randomElement()!
    }

    static func randomWorkCompleteMessage() -> (title: String, body: String) {
        workCompleteMessages.randomElement()!
    }

    static func randomLongBreakMessage() -> (title: String, body: String) {
        longBreakMessages.randomElement()!
    }

    static func randomBreakOverMessage() -> (title: String, body: String) {
        breakOverMessages.randomElement()!
    }
}
