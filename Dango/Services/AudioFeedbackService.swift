import AppKit
import AVFoundation
import os

@MainActor
final class AudioFeedbackService: NSObject, AVAudioPlayerDelegate {

    static let shared = AudioFeedbackService()

    private let logger = Logger(subsystem: "com.mateusz.dango", category: "audio")

    private struct AudioLayer {
        let sequenceID: UUID
        let player: AVAudioPlayer
    }

    private var activeAudioLayers: [AudioLayer] = []

    private nonisolated override init() {
        super.init()
    }

    func playTransitionClick(rings: Int = 1) {
        guard SessionStore.shared.audioEnabled else { return }
        purgeFinishedAudioLayers()

        #if SWIFT_PACKAGE
        let moduleURL = Bundle.module.url(forResource: "chime_bell", withExtension: "mp3")
        #else
        let moduleURL: URL? = nil
        #endif
        guard let assetURL = Bundle.main.url(forResource: "chime_bell", withExtension: "mp3") ?? moduleURL else {
            logger.error("chime_bell.mp3 asset missing from bundle resources")
            NSSound(named: "Glass")?.play()
            return
        }

        let totalChimes = max(rings, 1)
        let overlapInterval: TimeInterval = 0.38
        let sequenceID = UUID()

        for step in 0..<totalChimes {
            Task { @MainActor in
                if step > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(Double(step) * overlapInterval * 1_000_000_000))
                }
                self.playLayer(step: step, assetURL: assetURL, sequenceID: sequenceID)
            }
        }
    }

    private func playLayer(step: Int, assetURL: URL, sequenceID: UUID) {
        do {
            let player = try AVAudioPlayer(contentsOf: assetURL)
            player.delegate = self
            player.volume = Float(max(1.0 - (Double(step) * 0.28), 0.12))
            activeAudioLayers.append(AudioLayer(sequenceID: sequenceID, player: player))
            player.prepareToPlay()
            player.play()
        } catch {
            logger.error("Failed to initialize audio layer for step \(step): \(error.localizedDescription)")
        }
    }

    func stopAll() {
        activeAudioLayers.forEach { $0.player.stop() }
        activeAudioLayers.removeAll()
    }

    // MARK: - AVAudioPlayerDelegate

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let id = ObjectIdentifier(player)
        Task { @MainActor in
            self.activeAudioLayers.removeAll { ObjectIdentifier($0.player) == id }
        }
    }

    private func purgeFinishedAudioLayers() {
        activeAudioLayers.removeAll { !$0.player.isPlaying }
    }
}
