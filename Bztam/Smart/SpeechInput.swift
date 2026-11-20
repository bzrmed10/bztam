import AVFoundation
import Speech
import SwiftUI

/// "Say it": dictation for the Add sheet, in French or English, on device when the phone supports it.
@MainActor
@Observable
final class SpeechInput {
    var isListening = false
    var transcript = ""
    var denied = false

    private var engine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    private struct RequestBox: @unchecked Sendable { let request: SFSpeechAudioBufferRecognitionRequest }

    func toggle() async {
        if isListening { stop() } else { await start() }
    }

    func start() async {
        let speech = await withCheckedContinuation { (c: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { @Sendable status in c.resume(returning: status) }
        }
        let mic = await AVAudioApplication.requestRecordPermission()
        guard speech == .authorized, mic else { denied = true; return }

        let locale = Locale(identifier: L10n.code == "fr" ? "fr-FR" : L10n.code == "ar" ? "ar-SA" : "en-US")
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else { denied = true; return }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
            let engine = AVAudioEngine()
            let input = engine.inputNode
            let box = RequestBox(request: request)
            input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { @Sendable buffer, _ in
                box.request.append(buffer)
            }
            engine.prepare()
            try engine.start()

            transcript = ""
            self.engine = engine
            self.request = request
            isListening = true
            task = recognizer.recognitionTask(with: request) { @Sendable [weak self] result, error in
                let text = result?.bestTranscription.formattedString
                let finished = (result?.isFinal ?? false) || error != nil
                Task { @MainActor in
                    if let text { self?.transcript = text }
                    if finished { self?.stop() }
                }
            }
        } catch {
            stop()
        }
    }

    func stop() {
        guard isListening || engine != nil else { return }
        engine?.stop()
        engine?.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.finish()
        engine = nil
        request = nil
        task = nil
        isListening = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
