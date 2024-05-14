import SwiftUI

@main
struct WhisperCppDemoApp: App {
    @State private var audioProcessor = RealTimeWhisper()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(audioProcessor)
        }
    }
}
