import AVFoundation
import Speech
import SwiftUI

/// Drives on-device speech-to-text for the search bars. Owns the audio engine,
/// the `SFSpeechRecognizer` task, and the two runtime permissions (microphone +
/// speech recognition). Transcription is streamed back through the `onTranscript`
/// closure passed to `toggle(onTranscript:)`, so callers just write it into their
/// own search-query binding.
@MainActor
@Observable
final class VoiceSearchController {
    enum Status {
        case idle, listening, denied, unavailable
    }

    private(set) var status: Status = .idle
    var isListening: Bool { status == .listening }

    /// Non-nil when something went wrong (permission denied, unavailable, etc.).
    /// Views surface this in an alert; clearing it dismisses the alert.
    var errorMessage: String?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var onTranscript: ((String) -> Void)?

    /// Tapping the mic toggles dictation: stop if we're listening, otherwise
    /// request permissions and start.
    func toggle(onTranscript: @escaping (String) -> Void) {
        if isListening {
            stop()
        } else {
            self.onTranscript = onTranscript
            Task { await start() }
        }
    }

    private func start() async {
        errorMessage = nil

        guard let recognizer, recognizer.isAvailable else {
            status = .unavailable
            errorMessage = "Voice search isn't available on this device right now."
            return
        }

        guard await Self.requestSpeechAuthorization() == .authorized else {
            status = .denied
            errorMessage = "Enable Speech Recognition in Settings to use voice search."
            return
        }

        guard await Self.requestMicrophonePermission() else {
            status = .denied
            errorMessage = "Enable Microphone access in Settings to use voice search."
            return
        }

        do {
            try beginRecognition(using: recognizer)
            status = .listening
        } catch {
            cleanup()
            status = .idle
            errorMessage = "Couldn't start voice search. Please try again."
        }
    }

    private func beginRecognition(using recognizer: SFSpeechRecognizer) throws {
        // Tear down any lingering task before starting a fresh one.
        task?.cancel()
        task = nil

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        self.request = request

        let inputNode = audioEngine.inputNode
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                if let result {
                    self.onTranscript?(result.bestTranscription.formattedString)
                }
                if error != nil || (result?.isFinal ?? false) {
                    self.stop()
                }
            }
        }

        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak request] buffer, _ in
            request?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    func stop() {
        cleanup()
        if status == .listening {
            status = .idle
        }
    }

    private func cleanup() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private static func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
    }

    private static func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
        }
    }
}

/// The trailing mic control used by every search bar. Wraps a
/// `VoiceSearchController`, pulses while listening, and streams the transcript
/// into the bound search text.
struct MicButton: View {
    @Binding var text: String
    var tint: Color = .secondary

    @State private var voice = VoiceSearchController()

    var body: some View {
        Button {
            voice.toggle { transcript in text = transcript }
        } label: {
            Image(systemName: "mic.fill")
                .foregroundStyle(voice.isListening ? Color.red : tint)
                .symbolEffect(.pulse, isActive: voice.isListening)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(voice.isListening ? "Stop voice search" : "Start voice search")
        .alert(
            "Voice Search",
            isPresented: Binding(
                get: { voice.errorMessage != nil },
                set: { if !$0 { voice.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(voice.errorMessage ?? "")
        }
    }
}
