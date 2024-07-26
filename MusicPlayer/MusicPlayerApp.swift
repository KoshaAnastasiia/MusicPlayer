//
//  MusicPlayerApp.swift
//  MusicPlayer
//
//  Created by kosha on 24.07.2024.
//

import SwiftUI
import AVFAudio

@main
struct MusicPlayerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var playerViewModel = PlayerViewModel(["tagmp3_sample1",
                                                          "tagmp3_sample2",
                                                          "tagmp3_sample3",
                                                          "tagmp3_sample4"])
    
    var body: some Scene {
        WindowGroup {
            PlayerView(volume: $playerViewModel.percentVolume)
                .environment(playerViewModel)
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    private var backgroundCompletionHandler: (() -> Void)? = nil

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback)
        } catch {
            print("Setting category to AVAudioSessionCategoryPlayback failed.")
        }

        return true
    }
}
