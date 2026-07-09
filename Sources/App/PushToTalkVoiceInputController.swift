import AppKit
@preconcurrency import AVFoundation
import Foundation
@preconcurrency import Speech

private final class PushToTalkVoiceAudioEngine: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.bmux.push-to-talk-voice.audio")
    private let engine = AVAudioEngine()
    private var tapInstalled = false

    func start(
        tapBlock: @escaping @Sendable (AVAudioPCMBuffer, AVAudioTime) -> Void,
        onReady: @escaping @Sendable (Bool) -> Void
    ) {
        queue.async { [self] in
            do {
                let inputNode = engine.inputNode
                let format = inputNode.outputFormat(forBus: 0)
                guard format.channelCount > 0, format.sampleRate > 0 else {
                    teardownLocked()
                    onReady(false)
                    return
                }
                if tapInstalled {
                    inputNode.removeTap(onBus: 0)
                    tapInstalled = false
                }
                inputNode.installTap(onBus: 0, bufferSize: 1024, format: format, block: tapBlock)
                tapInstalled = true
                engine.prepare()
                try engine.start()
                onReady(true)
            } catch {
                teardownLocked()
                onReady(false)
            }
        }
    }

    func stop() {
        queue.async { [self] in
            teardownLocked()
        }
    }

    private func teardownLocked() {
        dispatchPrecondition(condition: .onQueue(queue))
        if engine.isRunning {
            engine.stop()
        }
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
    }
}

@MainActor
final class PushToTalkVoiceInputController {
    private enum State: Equatable {
        case idle
        case requestingPermission(Int)
        case startingAudio(Int)
        case listening(Int)
        case stopping(Int)
        case unavailable

        var isActive: Bool {
            switch self {
            case .requestingPermission, .startingAudio, .listening, .stopping:
                return true
            case .idle, .unavailable:
                return false
            }
        }

        var token: Int? {
            switch self {
            case .requestingPermission(let token),
                 .startingAudio(let token),
                 .listening(let token),
                 .stopping(let token):
                return token
            case .idle, .unavailable:
                return nil
            }
        }
    }

    private enum AuthorizationResolution {
        case granted
        case denied
        case undetermined
    }

    private enum FailureReason {
        case permissionDenied
        case unavailable
    }

    private let recognizer: SFSpeechRecognizer?
    private let audioEngine = PushToTalkVoiceAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var latestTranscript = ""
    private var startToken = 0
    private var finalizeTimeout: Task<Void, Never>?
    private weak var targetWindow: NSWindow?
    private var holdKeyCode: UInt16?
    private var state: State = .idle

    private static let finalizeTimeoutNanoseconds: UInt64 = 2_500_000_000

    init(recognizer: SFSpeechRecognizer? = SFSpeechRecognizer()) {
        self.recognizer = recognizer
        if recognizer == nil {
            state = .unavailable
        }
    }

    @discardableResult
    func beginHold(event: NSEvent, preferredWindow: NSWindow?) -> Bool {
        if event.isARepeat {
            return state.isActive
        }
        if state.isActive {
            return true
        }
        holdKeyCode = event.keyCode
        return start(preferredWindow: preferredWindow)
    }

    @discardableResult
    func stopIfMatchingRelease(event: NSEvent) -> Bool {
        guard let holdKeyCode, event.keyCode == holdKeyCode else {
            return false
        }
        self.holdKeyCode = nil
        stopAndInsert()
        return true
    }

    @discardableResult
    func toggle(preferredWindow: NSWindow?) -> Bool {
        if state.isActive {
            holdKeyCode = nil
            return stopAndInsert()
        }
        holdKeyCode = nil
        return start(preferredWindow: preferredWindow)
    }

    @discardableResult
    private func start(preferredWindow: NSWindow?) -> Bool {
        guard !state.isActive else { return true }
        guard recognizer != nil else {
            presentFailure(.unavailable, preferredWindow: preferredWindow)
            state = .unavailable
            return true
        }

        startToken &+= 1
        let token = startToken
        targetWindow = preferredWindow ?? NSApp.keyWindow ?? NSApp.mainWindow
        latestTranscript = ""
        state = .requestingPermission(token)

        switch Self.resolvedAuthorization() {
        case .granted:
            beginRecognition(token: token)
        case .denied:
            failStart(.permissionDenied, token: token)
        case .undetermined:
            Self.requestAuthorization { [weak self] granted in
                Task { @MainActor in
                    self?.handleAuthorizationResult(granted, token: token)
                }
            }
        }
        return true
    }

    @discardableResult
    private func stopAndInsert() -> Bool {
        switch state {
        case .idle, .unavailable:
            return false
        case .requestingPermission, .startingAudio:
            cancel()
            return true
        case .listening(let token):
            state = .stopping(token)
            request?.endAudio()
            audioEngine.stop()
            scheduleFinalizeTimeout(token: token)
            return true
        case .stopping:
            return true
        }
    }

    private func cancel() {
        startToken &+= 1
        finalizeTimeout?.cancel()
        finalizeTimeout = nil
        task?.cancel()
        task = nil
        request = nil
        latestTranscript = ""
        holdKeyCode = nil
        targetWindow = nil
        audioEngine.stop()
        if state != .unavailable {
            state = .idle
        }
    }

    private nonisolated static func resolvedAuthorization() -> AuthorizationResolution {
        let speech = SFSpeechRecognizer.authorizationStatus()
        let mic = AVCaptureDevice.authorizationStatus(for: .audio)
        guard speech != .notDetermined, mic != .notDetermined else {
            return .undetermined
        }
        return (speech == .authorized && mic == .authorized) ? .granted : .denied
    }

    private nonisolated static func requestAuthorization(_ completion: @escaping @Sendable (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { speechStatus in
            guard speechStatus == .authorized else {
                completion(false)
                return
            }
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                completion(granted)
            }
        }
    }

    private func handleAuthorizationResult(_ granted: Bool, token: Int) {
        guard state == .requestingPermission(token) else { return }
        guard granted else {
            failStart(.permissionDenied, token: token)
            return
        }
        beginRecognition(token: token)
    }

    private func beginRecognition(token: Int) {
        guard state == .requestingPermission(token),
              let recognizer,
              recognizer.isAvailable else {
            failStart(.unavailable, token: token)
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        self.request = request
        state = .startingAudio(token)

        audioEngine.start(tapBlock: makeTapBlock(request: request)) { [weak self] started in
            Task { @MainActor in
                self?.handleAudioReady(started, token: token)
            }
        }
    }

    private func handleAudioReady(_ started: Bool, token: Int) {
        guard state == .startingAudio(token) else { return }
        guard started, let recognizer, let request else {
            failStart(.unavailable, token: token)
            return
        }

        task = recognizer.recognitionTask(with: request, resultHandler: makeRecognitionResultHandler(token: token))
        state = .listening(token)
    }

    private nonisolated func makeTapBlock(
        request: SFSpeechAudioBufferRecognitionRequest
    ) -> @Sendable (AVAudioPCMBuffer, AVAudioTime) -> Void {
        // `append(_:)` is the Speech framework's documented path for feeding
        // buffers from an audio tap; the request is retained by the controller.
        nonisolated(unsafe) weak let weakRequest: SFSpeechAudioBufferRecognitionRequest? = request
        return { buffer, _ in
            weakRequest?.append(buffer)
        }
    }

    private nonisolated func makeRecognitionResultHandler(
        token: Int
    ) -> @Sendable (SFSpeechRecognitionResult?, Error?) -> Void {
        return { [weak self] result, error in
            let transcript = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let failed = error != nil
            Task { @MainActor in
                self?.handleRecognitionResult(
                    transcript: transcript,
                    isFinal: isFinal,
                    failed: failed,
                    token: token
                )
            }
        }
    }

    private func handleRecognitionResult(
        transcript: String?,
        isFinal: Bool,
        failed: Bool,
        token: Int
    ) {
        guard state.token == token else { return }
        if let transcript, !transcript.isEmpty {
            latestTranscript = transcript
        }

        if isFinal {
            finishAndInsert(token: token)
            return
        }

        if failed {
            switch state {
            case .stopping:
                finishAndInsert(token: token)
            default:
                cancel()
                NSSound.beep()
            }
        }
    }

    private func scheduleFinalizeTimeout(token: Int) {
        finalizeTimeout?.cancel()
        // Speech can fail to produce a final callback after endAudio(); the
        // timeout commits the latest partial so push-to-talk never gets stuck.
        finalizeTimeout = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.finalizeTimeoutNanoseconds)
            await MainActor.run {
                self?.finishAndInsert(token: token)
            }
        }
    }

    private func finishAndInsert(token: Int) {
        guard state.token == token else { return }
        finalizeTimeout?.cancel()
        finalizeTimeout = nil
        let transcript = latestTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        let window = targetWindow

        task?.cancel()
        task = nil
        request = nil
        latestTranscript = ""
        holdKeyCode = nil
        targetWindow = nil
        state = .idle
        audioEngine.stop()

        guard !transcript.isEmpty else { return }
        if !Self.insert(transcript, into: window) {
            NSSound.beep()
        }
    }

    private func failStart(_ reason: FailureReason, token: Int) {
        guard state.token == token || state == .unavailable else { return }
        let window = targetWindow
        cancel()
        if reason == .unavailable {
            state = .unavailable
        }
        presentFailure(reason, preferredWindow: window)
    }

    private func presentFailure(_ reason: FailureReason, preferredWindow: NSWindow?) {
        NSSound.beep()
        let alert = NSAlert()
        alert.alertStyle = .warning
        switch reason {
        case .permissionDenied:
            alert.messageText = String(localized: "voiceInput.permissionDenied.title", defaultValue: "Voice Input Needs Permission")
            alert.informativeText = String(
                localized: "voiceInput.permissionDenied.message",
                defaultValue: "Allow microphone and speech recognition access in System Settings to use push-to-talk."
            )
        case .unavailable:
            alert.messageText = String(localized: "voiceInput.unavailable.title", defaultValue: "Voice Input Unavailable")
            alert.informativeText = String(
                localized: "voiceInput.unavailable.message",
                defaultValue: "Speech recognition is not available for the current language or microphone input."
            )
        }
        alert.addButton(withTitle: String(localized: "common.ok", defaultValue: "OK"))
        if let preferredWindow {
            alert.beginSheetModal(for: preferredWindow)
        } else {
            alert.runModal()
        }
    }

    private static func insert(_ text: String, into preferredWindow: NSWindow?) -> Bool {
        guard let window = preferredWindow
            ?? NSApp.keyWindow
            ?? NSApp.mainWindow
            ?? NSApp.windows.first(where: { $0.isVisible })
            ?? NSApp.windows.first,
              let firstResponder = window.firstResponder else {
            return false
        }
        if let client = firstResponder as? NSTextInputClient {
            client.insertText(text, replacementRange: NSRange(location: NSNotFound, length: 0))
        } else {
            firstResponder.insertText(text)
        }
        return true
    }
}
