import SwiftUI
import AVFoundation

struct ContentView: View {
//    @StateObject var whisperState = WhisperActor()
//    @State var audioProcessor = RealTimeWhisper()
    @Environment(RealTimeWhisper.self) var audioProcessor
    
    var body: some View {
        NavigationStack {
            VStack {
                HStack {
                    Button("start realtime", action: {
                        Task {
                            // Example usage:
                            audioProcessor.canStop = true
                            do {
                                try audioProcessor.startRealTimeProcessingAndPlayback()
                            } catch {
                                print("Error starting real-time processing and playback: \(error.localizedDescription)")
                            }
                        }
                    }).buttonStyle(.bordered)
                        .disabled(audioProcessor.canStop)
                    
                    Button("stop realtime", action: {
                        Task {
                            audioProcessor.stopRecord()
                            audioProcessor.canStop = false
                        }
                    }).buttonStyle(.bordered)
                        .disabled(!audioProcessor.canStop)
                }
                
                ScrollView {
                    Text(verbatim: audioProcessor.transcribedText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .navigationTitle("Whisper SwiftUI Demo")
            .padding()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
