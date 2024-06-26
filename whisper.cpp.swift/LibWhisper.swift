import Foundation
import whisper

enum WhisperError: Error {
    case couldNotInitializeContext
}

/// Meets Whisper C++ constraint: Don't access from more than one thread at a time.
actor WhisperContext {
    private var context: OpaquePointer
    
    init(path: URL) throws {
        var params = whisper_context_default_params()
#if targetEnvironment(simulator)
        params.use_gpu = false
        print("Running on the simulator, using CPU")
#endif
        let context = whisper_init_from_file_with_params(path.path(), params)
        if let context {
            self.context = context
        } else {
            print("Couldn't load model at \(path.path())")
            throw WhisperError.couldNotInitializeContext
        }
    }
    
    deinit {
        whisper_free(context)
    }
    
    func fullTranscribe(samples: [Float]) {
        // Leave 2 processors free (i.e. the high-efficiency cores).
        let maxThreads = max(1, min(8, cpuCount() - 2))
        print("Selecting \(maxThreads) threads")
        
        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        
        params.print_realtime   = true
        params.print_progress   = false
        params.print_timestamps = true
        params.print_special    = false
        params.translate        = false
        params.n_threads        = Int32(maxThreads)
        params.offset_ms        = 0
        params.no_context       = true
        params.single_segment   = true
        params.no_timestamps    = true
        "auto".withCString { auto in
            params.language         = auto
        }
        
        whisper_reset_timings(context)
        print("About to run whisper_full")
        
        samples.withUnsafeBufferPointer { samples in
            if (whisper_full(context, params, samples.baseAddress, Int32(samples.count)) != 0) {
                print("Failed to run the model")
            } else {
                whisper_print_timings(context)
            }
        }
    }
    
    func getTranscription() -> String {
        var transcription = ""
        for i in 0..<whisper_full_n_segments(context) {
            transcription += String.init(cString: whisper_full_get_segment_text(context, i))
        }
        return transcription
    }
}

fileprivate func cpuCount() -> Int {
    ProcessInfo.processInfo.processorCount
}
