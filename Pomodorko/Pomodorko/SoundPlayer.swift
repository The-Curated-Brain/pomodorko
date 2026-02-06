import AppKit
import SwiftUI

/// Sound player for Pomodorko timer events
class PKSoundPlayer: ObservableObject {
    private static let volumeKey = "soundEffectVolume"

    @Published var volume: Double {
        didSet {
            UserDefaults.standard.set(volume, forKey: Self.volumeKey)
        }
    }

    // Keep references to sounds while they're playing
    private var activeSounds: [NSSound] = []

    init() {
        // Load saved volume, default to 1.0 if not set
        if UserDefaults.standard.object(forKey: Self.volumeKey) != nil {
            self.volume = UserDefaults.standard.double(forKey: Self.volumeKey)
        } else {
            self.volume = 1.0
        }
    }

    /// End of work → short break: two submarine sounds
    func playWorkComplete() {
        playSound("Submarine")
        // Play second submarine after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.playSound("Submarine")
        }
    }

    /// End of set → long break: funk sound
    func playSetComplete() {
        playSound("Funk")
    }

    /// End of break → back to work: blow sound
    func playBreakComplete() {
        playSound("Blow")
    }

    private func playSound(_ name: String) {
        let path = "/System/Library/Sounds/\(name).aiff"
        guard let sound = NSSound(contentsOfFile: path, byReference: true) else {
            return
        }
        sound.volume = Float(volume)

        // Keep a reference so sound isn't deallocated while playing
        activeSounds.append(sound)
        sound.play()

        // Clean up after sound finishes (estimate based on typical system sound length)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.activeSounds.removeAll { $0 == sound }
        }
    }
}
