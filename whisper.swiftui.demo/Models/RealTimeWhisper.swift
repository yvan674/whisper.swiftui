import AVFoundation


//@MainActor
@Observable
class RealTimeWhisper {
    var messageLog = ""
    var transcribedText = ""
    var canTranscribe = false
    var canStop = false
    
    private let audioEngine = AVAudioEngine()
    private let audioSession = AVAudioSession.sharedInstance()
    private var audioBuffer: AVAudioPCMBuffer?
    private var lastBuffer: AVAudioPCMBuffer?
    private var audioPlayer: AVAudioPlayer?
    
    private let outputFormat: AVAudioFormat
    private var formatConverter: AVAudioConverter?
    
    private var dataFloats = [Float]()
    
    
    private var whisperContext: WhisperContext?
    
    init() {
        var modelUrl: URL? {
            Bundle.main.url(forResource: "ggml-small", withExtension: "bin", subdirectory: "models")
        }
        do {
            if let path = modelUrl {
                self.whisperContext = try WhisperContext(path: path)
                print("Loaded model \(path.lastPathComponent)\n")
            } else {
                print("Could not locate model")
            }
            
            self.canTranscribe = true
        } catch {
            print(error.localizedDescription)
        }
        
        // Initialize output format
        /// Output format required by Whisper. This is mono 16khz Float32 PCM formatted audio.
        self.outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: true
        )!  // We know this format works, so we can assert here.
    }
    
    func startRealTimeProcessingAndPlayback() throws {
        try audioSession.setCategory(.playAndRecord, mode: .default)
        
        // 请求录音权限
        
        AVAudioApplication.requestRecordPermission { granted in
            if granted {
                // Permission is granted
                // 用户已授予录音权限，继续启动实时处理和播放
                do {
                    try self.audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                    
                    let inputNode = self.audioEngine.inputNode
                    
                    let format = inputNode.inputFormat(forBus: 0)
                    
                    self.formatConverter = AVAudioConverter(from: format, to: self.outputFormat)!
                    
                    inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, time in
                        DispatchQueue.main.async {
                            do {
                                let duration = Double(buffer.frameCapacity) / buffer.format.sampleRate
                                let outputBufferCapacity = AVAudioFrameCount(self.outputFormat.sampleRate * duration)
                                let outputBuffer = AVAudioPCMBuffer(
                                    pcmFormat: self.outputFormat,
                                    frameCapacity: outputBufferCapacity
                                )!
                                var error: NSError? = nil
                                guard let formatConverter = self.formatConverter else {
                                    return
                                }
                                let status = self.formatConverter!.convert(
                                    to: outputBuffer,
                                    error: &error,
                                    withInputFrom: { inNumPackets, outStatus in
                                        outStatus.pointee = AVAudioConverterInputStatus.haveData
                                        return buffer
                                    }
                                )
                                switch status {
                                    case .error:
                                        if let conversionError = error {
                                          print("Error converting audio file: \(conversionError)")
                                        }
                                        return
                                    default: break
                                }
                                self.formatConverter?.reset()
                                
                                let oneFloat = try self.decodePCMBuffer(outputBuffer)
                                self.dataFloats += oneFloat
                                let tempDateFloats = self.dataFloats
                                Task {
                                    await self.transcribeData(tempDateFloats)
                                }
                            } catch {
                                print("Write error: \(error.localizedDescription)")
                            }
                        }
                    }
                    
                    // 启动音频引擎
                    
                    try self.audioEngine.start()
                    
                    print("Real-time audio processing and playback started.")
                } catch {
                    print("Error starting real-time processing and playback: \(error.localizedDescription)")
                }
            } else {
                // 用户未授予录音权限
                // User has not granted permission
                print("User denied record permission.")
            }
        }
    }
    
    func decodePCMBuffer(_ buffer: AVAudioPCMBuffer) throws -> [Float] {
        guard let floatChannelData = buffer.floatChannelData else {
            throw NSError(domain: "Invalid PCM Buffer", code: 0, userInfo: nil)
        }
        
        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)
        
        var floats = [Float]()
        
        for frame in 0..<frameLength {
            for channel in 0..<channelCount {
                let floatData = floatChannelData[channel]
                let index = frame * channelCount + channel
                let floatSample = floatData[index]
                floats.append(max(-1.0, min(floatSample, 1.0)))
            }
        }
        
        return floats
    }
    
    func stopRecord() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
    }
    
    private func transcribeData(_ data: [Float]) async {
        if (!canTranscribe) {
            return
        }
        
        canTranscribe = false
        guard let w = whisperContext else {
            return
        }
        await w.fullTranscribe(samples: data)
        let text = await w.getTranscription()
        messageLog += "Done: \(text)\n"
        transcribedText = "\(text) "
        canTranscribe = true
    }
}
