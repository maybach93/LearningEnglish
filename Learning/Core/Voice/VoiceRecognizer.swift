//
//  VoiceRecognizer.swift
//  Learning
//
//  Created by Vitalii Poponov on 6/26/20.
//

import Foundation
import Combine
import Speech
import AVFoundation

struct DefaultError: Error {
    
}
class VoiceRecognizer {
    
    //MARK: - Private variables
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    //MARK: - Public
    
    public func startRecognizing() -> AnyPublisher<String, DefaultError> {
        let authorization = Future<Void, DefaultError> { promise in

            SFSpeechRecognizer.requestAuthorization {
                (authStatus) in
                switch authStatus {
                case .authorized:
                    promise(.success(()))
                default:
                    promise(.failure(DefaultError()))
                }
            }
        }
        return authorization.flatMap({ _ in self.startRecording() }).eraseToAnyPublisher()
    }
    
    public func stop() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
    }
    
    //MARK: Private
    
    private func startRecording() -> Future<String, DefaultError> {
        return Future<String, DefaultError> {[unowned self] promise in
            #if targetEnvironment(simulator)
            promise(.failure(DefaultError()))
            #else

            if let recognitionTask = recognitionTask {
                recognitionTask.cancel()
                self.recognitionTask = nil
            }
            
            let audioSession = AVAudioSession.sharedInstance()
            try? audioSession.setCategory(AVAudioSession.Category.record)
            try? audioSession.setMode(AVAudioSession.Mode.measurement)
            try? audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            
            guard let recognitionRequest = recognitionRequest else {
                promise(.failure(DefaultError()))
                return
            }
    
            recognitionRequest.shouldReportPartialResults = false
            
            let inputNode = audioEngine.inputNode
            
            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                var isFinal = false
                
                
                if let result = result {
                    promise(.success(result.bestTranscription.formattedString))
                    isFinal = result.isFinal
                }
                
                if error != nil || isFinal {
                    self?.audioEngine.stop()
                    inputNode.removeTap(onBus: 0)
                    
                    self?.recognitionRequest = nil
                    self?.recognitionTask = nil
                }
            }
            
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
                self?.recognitionRequest?.append(buffer)
            }

            audioEngine.prepare()
            
            try? audioEngine.start()
            #endif
        }
    }
}
