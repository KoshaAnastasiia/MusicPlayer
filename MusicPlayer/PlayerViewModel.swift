//
//  PlayerViewModel.swift
//  MusicPlayer
//
//  Created by kosha on 24.07.2024.
//

import SwiftUI
import MediaPlayer

@Observable class PlayerViewModel: NSObject {
    private(set) var data: Data = .init(count: 0)
    private(set) var title = ""
    
    var percentProgress: CGFloat = 0
    var currentTime: TimeInterval = 0
    
    private(set) var timeMisingToPlay: String = ""
    private(set) var isPlaying = false
    private(set) var isFinished = false
    
    var percentVolume: Float = 0 {
        didSet {
            setVolume(percentVolume)
        }
    }
    
    private(set) var audioSessionOutputs: String = ""
    var isTapped = false
    
    private(set) var songs: [String]
    
    private let audioSession = AVAudioSession.sharedInstance()
    private var indexCurrentSong = 0
    private var player: AVAudioPlayer!
    private var masterVolumeSlider: UISlider!
    private var notificationCenter = NotificationCenter.default
    
    init(_ songs: [String]) {
        self.songs = songs
        super.init()

        let masterVolumeView = MPVolumeView()
        masterVolumeSlider = masterVolumeView.subviews.compactMap({ $0 as? UISlider }).first

        setupRemoteTransportControls()
    }
    
    func onAppear() {
        do {
            try audioSession.setCategory(.playback)
        } catch {
            print("Setting category to AVAudioSessionCategoryPlayback failed.")
        }

        let url = Bundle.main.path(forResource: self.songs[self.indexCurrentSong], ofType: "mp3")

        self.player = try! AVAudioPlayer(contentsOf: URL(fileURLWithPath: url!))

        self.player.delegate = self

        self.getArtworkAndTitle()
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { (_) in
            Task.detached(priority: .background) {
                await MainActor.run {
                    if self.player.isPlaying && !self.isTapped && !self.isTapped {
                        self.percentProgress = self.player.currentTime / self.player.duration
                    }
                }
            }
        }

        let masterVolumeView = MPVolumeView()
        masterVolumeSlider = masterVolumeView.subviews.compactMap({ $0 as? UISlider }).first
        self.percentVolume = audioSession.outputVolume

        notificationCenter.addObserver(self,
                                       selector: #selector(systemVolumeDidChange),
                                       name: Notification.Name("SystemVolumeDidChange"),
                                       object: nil
        )

        updateOutputDevices()

        notificationCenter.addObserver(self,
                                       selector: #selector(audioSessionRouteChanged),
                                       name: AVAudioSession.routeChangeNotification,
                                       object: audioSession)
    }

    func onDisappear() {
        notificationCenter.removeObserver(self, name: Notification.Name("SystemVolumeDidChange"), object: nil)
        notificationCenter.removeObserver(self, name: AVAudioSession.routeChangeNotification, object: audioSession)
    }
    
    func setVolume(_ volume: Float) {
        self.player?.volume = volume
    }

    var playerCurrentTime: Double {
        get { return self.player.currentTime }
        set {
            guard newValue >= 0 && newValue <= self.player.duration && !self.isTapped else {
                return
            }

            self.player.currentTime = newValue
            self.percentProgress = self.player.currentTime / self.player.duration
            self.updateNowPlaying()
        }
    }
    
    var playerDuration: Double {
        if self.player == nil {
            return 00
        }
        return self.player.duration
    }
    
    var playerCurrentTimeStr: String {
        if self.player == nil {
            return ""
        }
        let formatter = DateComponentsFormatter()
        formatter.zeroFormattingBehavior = .pad
        formatter.allowedUnits = [.minute, .second]
        return formatter.string(from: percentProgress * self.player.duration) ?? ""
//        return formatter.string(from: self.player.currentTime) ?? ""
    }
    
    var missingTimeSeconds: Double {
        if self.player == nil {
            return 0
        }
        return (1 - percentProgress) * self.player.duration
    }
    
    var playerMissingTimeStr: String {
        if self.player == nil {
            return ""
        }
        let formatter = DateComponentsFormatter()
        formatter.zeroFormattingBehavior = .pad
        formatter.allowedUnits = [.minute, .second]
        let tmpResult = formatter.string(from: missingTimeSeconds)
        if tmpResult == nil {
            return ""
        } else {
            return tmpResult!
        }
    }

    func skipBackward() {
        withAnimation {
            self.playerCurrentTime = max(0, self.playerCurrentTime - 15)
        }
    }
    
    func skipForward() {
        withAnimation {
            self.playerCurrentTime = min(self.playerDuration, self.playerCurrentTime + 30)
        }
    }

    func decrementSong() {
        withAnimation {
            if self.indexCurrentSong > 0 {
                self.indexCurrentSong -= 1
                self.changeCurrentSong()
            }
        }
    }
    
    func incrementSong() {
        withAnimation {
            if self.indexCurrentSong != self.songs.count - 1 {
                self.indexCurrentSong += 1
                self.changeCurrentSong()
            }
        }
    }
    
    func nextSong() {
        if self.isFinished {
            self.indexCurrentSong += 1
            self.player.currentTime = 0
            self.percentProgress = 0
            self.isFinished = false
            self.changeCurrentSong()
            playOrPause()
        }
    }

    func playOrPause() {
        if self.player.isPlaying {
            self.player.pause()
            self.isPlaying = false
        } else {
            if self.isFinished {
                self.player.currentTime = 0
                self.percentProgress = 0
                self.isFinished = false
            }

            do {
                try audioSession.setActive(true)
            } catch {
                print("error")
            }

            self.player.prepareToPlay()
            self.player.play()
            self.isPlaying = true
        }
    }

    private func getArtworkAndTitle() {
        Task {
        self.data = .init(count: 0)
        self.title = "???"

        let asset = AVAsset(url: self.player.url!)
            do {
                let commonMetadata = try await asset.load(.commonMetadata)
                   for i in commonMetadata {
                       if i.commonKey?.rawValue == "artwork" {
                           if let iValue = try? await i.load(.value) as? Data {
                               let data = iValue
                               self.data = data
                           }
                       }
                       if i.commonKey?.rawValue == "title" {
                           if let iValue = try? await i.load(.value) as? String {
                               let title = iValue
                               self.title = title
                           }
                       }
                   }
                   
                   self.updateNowPlaying()
            } catch {
                debugPrint(error)
            }
        }

    }

    @objc func systemVolumeDidChange(notification: NSNotification) {
        guard let userInfo = notification.userInfo,
              let percVolume = userInfo["Volume"] as? Float else {
            return
        }

        Task.detached(priority: .background) {
            await MainActor.run {
                self.percentVolume = percVolume
            }
        }
    }

    func increaseVolume() {
        self.percentVolume = min(self.percentVolume + 0.1, 1)
    }
    func decreaseVolume() {
        self.percentVolume = max(self.percentVolume - 0.1, 0)
    }

    private func changeCurrentSong() {
        let url = Bundle.main.path(forResource: self.songs[self.indexCurrentSong], ofType: "mp3")
        self.player = try! AVAudioPlayer(contentsOf: URL(fileURLWithPath: url!))
        self.player.delegate = self
        self.getArtworkAndTitle()
        self.percentProgress = 0

        if self.isPlaying {
            do {
                try audioSession.setActive(true)
            } catch {
                print("error")
            }

            self.player.prepareToPlay()
            self.player.play()
        }
    }

    private func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [unowned self] _ in
            if !self.isPlaying {
                self.player.play()
                self.isPlaying = true
                return .success
            }
            return .commandFailed
        }

        commandCenter.pauseCommand.addTarget { [unowned self] _ in
            if self.isPlaying {
                self.player.pause()
                self.isPlaying = false
                return .success
            }
            return .commandFailed
        }
    }

    private func updateNowPlaying() {
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = self.title
        nowPlayingInfo[MPMediaItemPropertyMediaType] = MPMediaType.anyAudio.rawValue

        let image = UIImage(data: self.data)!
        nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in
            return image
        }

        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = self.player.currentTime
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = NSNumber(value: self.player.duration)
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = self.player.rate
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = NSNumber(value: self.player.currentTime)

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    private func updateOutputDevices() {
        let availableOutputs = audioSession.currentRoute.outputs
        let firstOutput = availableOutputs.first
        let otherOutputs = availableOutputs.dropFirst()
        audioSessionOutputs = otherOutputs.map(\.portName).reduce(firstOutput?.portName, { ( $0 ?? "" ) + ", " + $1 }) ?? ""
    }

    @objc func audioSessionRouteChanged(notification: Notification) {
        updateOutputDevices()
    }
}

extension PlayerViewModel: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        self.isPlaying = false
        self.isFinished = true
    }

    func audioPlayerBeginInterruption(_ player: AVAudioPlayer) {
        self.isPlaying = false
    }
}

