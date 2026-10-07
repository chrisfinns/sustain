import AudioToolbox
import AVFoundation
import Observation
import SustainCore

/// Plays scale exercises, and single keys while you hold them, on the General MIDI piano that ships with macOS.
/// The audio engine starts on first use, so opening a practice card costs nothing.
@Observable
final class ScalePlayer {
    private(set) var isPlaying = false
    /// What's playing, kept so the keyboard can light up as it goes.
    private(set) var notes: [ScaleNote] = []
    /// Keys held down on the on-screen keyboard.
    private(set) var held: Set<Int> = []
    /// False when the built-in piano didn't load and a plain tone plays instead.
    private(set) var hasPiano = true
    private(set) var problem: String?

    @ObservationIgnored private var engine: AVAudioEngine?
    @ObservationIgnored private var sampler: AVAudioUnitSampler?
    @ObservationIgnored private var sequencer: AVAudioSequencer?
    @ObservationIgnored private var endTask: Task<Void, Never>?

    /// Apple's General MIDI sound bank. Program 0 is the acoustic grand.
    private static let bank = URL(fileURLWithPath: "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls")

    /// Seconds since the exercise started, or nil when nothing is playing.
    var position: Double? {
        isPlaying ? sequencer?.currentPositionInSeconds : nil
    }

    func play(_ exercise: ScaleExercise) {
        stop()
        guard let sampler = ready(), let sequencer else { return }
        for t in sequencer.tracks { _ = sequencer.removeTrack(t) }
        let track = sequencer.createAndAppendTrack()
        track.destinationAudioUnit = sampler
        let notes = exercise.notes
        for n in notes {
            // Lift a little before the next note so repeated pitches are heard, and keep the chord under the voice.
            let length = sequencer.beats(forSeconds: n.length * 0.9)
            for p in n.pitches {
                track.addEvent(AVMIDINoteEvent(channel: 0, key: UInt32(p), velocity: n.pitches.count > 1 ? 64 : 92, duration: length),
                               at: sequencer.beats(forSeconds: n.start))
            }
        }
        sequencer.currentPositionInBeats = 0
        sequencer.prepareToPlay()
        do {
            try sequencer.start()
        } catch {
            problem = "The piano couldn't start: \(error.localizedDescription)"
            return
        }
        self.notes = notes
        isPlaying = true
        let total = exercise.duration
        endTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(total + 0.5))
            if !Task.isCancelled { self?.stop() }
        }
    }

    func stop() {
        endTask?.cancel()
        endTask = nil
        sequencer?.stop()
        // All notes off, so nothing rings on after Stop.
        sampler?.sendController(123, withValue: 0, onChannel: 0)
        isPlaying = false
    }

    func toggle(_ exercise: ScaleExercise) {
        isPlaying ? stop() : play(exercise)
    }

    /// Hold a key on the keyboard to hear that note, for finding a pitch.
    func press(_ note: Int) {
        guard !held.contains(note), let sampler = ready() else { return }
        held.insert(note)
        sampler.startNote(UInt8(note), withVelocity: 92, onChannel: 0)
    }

    func release(_ note: Int) {
        guard held.remove(note) != nil else { return }
        sampler?.stopNote(UInt8(note), onChannel: 0)
    }

    /// Leaving the practice card: silence everything and let go of the audio device.
    func shutdown() {
        stop()
        held.removeAll()
        engine?.stop()
    }

    /// Builds the engine the first time, and restarts it if it stopped (shutdown, or the output device changed).
    private func ready() -> AVAudioUnitSampler? {
        if engine == nil {
            let engine = AVAudioEngine()
            let sampler = AVAudioUnitSampler()
            engine.attach(sampler)
            engine.connect(sampler, to: engine.mainMixerNode, format: nil)
            do {
                try sampler.loadSoundBankInstrument(at: Self.bank, program: 0,
                                                    bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
                                                    bankLSB: UInt8(kAUSampler_DefaultBankLSB))
            } catch {
                hasPiano = false
            }
            self.engine = engine
            self.sampler = sampler
            sequencer = AVAudioSequencer(audioEngine: engine)
        }
        guard let engine, let sampler else { return nil }
        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                problem = "Sustain couldn't open the audio output: \(error.localizedDescription)"
                return nil
            }
        }
        problem = nil
        return sampler
    }
}
