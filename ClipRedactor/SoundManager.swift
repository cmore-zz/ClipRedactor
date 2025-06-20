import AVFoundation


class SoundManager {
    static let shared = SoundManager()
    private var player: AVAudioPlayer?

    private init() {
        if let url = Bundle.main.url(forResource: "bubble-sound-trimmed", withExtension: "m4a") {
            player = try? AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            player?.volume = 0.3
        }
    }

    func play() {
        player?.play()
    }
}
