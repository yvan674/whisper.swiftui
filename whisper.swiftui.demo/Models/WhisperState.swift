import Foundation
import SwiftUI
import AVFoundation

@MainActor
class WhisperState: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var isModelLoaded = false
    @Published var messageLog = ""
    @Published var translateText = ""
    @Published var canTranscribe = false
    @Published var isRecording = false
    
    private var whisperContext: WhisperContext?
    
    private var modelUrl: URL? {
        Bundle.main.url(forResource: "ggml-small", withExtension: "bin", subdirectory: "models")
    }
    
    private var mySampleUrl: URL!
    
    private enum LoadError: Error {
        case couldNotLocateModel
    }
    
    override init() {
        super.init()
        do {
            try loadModel()
            canTranscribe = true
        } catch {
            print(error.localizedDescription)
            messageLog += "\(error.localizedDescription)\n"
        }
    }
    
    private func loadModel() throws {
        messageLog += "Loading model...\n"
        if let modelUrl {
            whisperContext = try WhisperContext(path: modelUrl)
            messageLog += "Loaded model \(modelUrl.lastPathComponent)\n"
        } else {
            messageLog += "Could not locate model\n"
        }
    }
    
    func transcribeData(_ data: [Float]) async {
        if (!canTranscribe) {
            return
        }
        guard let whisperContext else {
            return
        }
        
        canTranscribe = false
        await whisperContext.fullTranscribe(samples: data)
        let text = await whisperContext.getTranscription()
        messageLog += "Done: \(text)\n"
        translateText = "\(text) "
        canTranscribe = true
    }
}
