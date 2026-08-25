import AppKit

@MainActor
enum Sounds {
    private static let completeSound: NSSound? = {
        guard let url = Bundle.main.url(forResource: "complete", withExtension: "wav") else {
            return nil
        }
        let sound = NSSound(contentsOf: url, byReference: true)
        sound?.volume = 0.6
        return sound
    }()

    static func complete() {
        completeSound?.stop()
        completeSound?.play()
    }
}
