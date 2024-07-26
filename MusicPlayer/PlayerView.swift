//
//  PlayerView.swift
//  MusicPlayer
//
//  Created by kosha on 24.07.2024.
//

import SwiftUI

struct PlayerView: View {
    @Environment(PlayerViewModel.self) private var playerViewModel
    @GestureState private var isTapped = false
    @Binding var volume: Float
    
    private let initialVolume: CGFloat = 20
    
    private let maxOffset: CGFloat = 250
    private let minOffset: CGFloat = 0
    
    @State private var initialTrial: Bool = true
    @State private var newVolume: CGFloat = 0
    
    var body: some View {
        GeometryReader { metrics in
            VStack(spacing: 0) {
                ZStack {
                    Color.white
                    Image(uiImage: playerViewModel.data.count == 0 ? UIImage(systemName: "hourglass")! : UIImage(data: playerViewModel.data)!)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(10)
                        .padding(.horizontal, 50)
                }.background(ignoresSafeAreaEdges: .top)
                    .padding(.bottom, 25)
                Text(playerViewModel.title)
                    .font(.title)
                    .padding(.bottom, 25)
                makeControlButtons()
                    .padding(.bottom, 50)
                makeTimeProgress(metrics: metrics)
                    .padding(.bottom, 50)
                makeVolumeProgress()
                Spacer()
            }.onAppear {
                playerViewModel.onAppear()
                playerViewModel.playOrPause()
            }
            .onDisappear {
                playerViewModel.onDisappear()
            }
            .onChange(of: playerViewModel.isFinished) { oldValue, newValue in
                playerViewModel.nextSong()
            }
        }
    }
    
    @ViewBuilder private func makeControlButtons() -> some View {
        HStack(spacing: 50) {
            Button(action: { playerViewModel.decrementSong() },
                   label: {
                Image(systemName: "backward.fill")
                    .font(.body)
                    .foregroundColor(.primary)
            })
            Button(action: { playerViewModel.skipBackward() },
                   label: {
                Image(systemName: "gobackward.15")
                    .font(.body)
                    .foregroundColor(.primary)
            })
            
            Button(action: { playerViewModel.playOrPause() },
                   label: {
                Image(systemName: (playerViewModel.isPlaying && !playerViewModel.isFinished) ? "pause.fill" : "play.fill")
                    .font(.body)
                    .foregroundColor(.primary)
            })
            
            Button(action: { playerViewModel.skipForward() },
                   label: {
                Image(systemName: "goforward.30")
                    .font(.body)
                    .foregroundColor(.primary)
            })
            Button(action: { playerViewModel.incrementSong() },
                   label: {
                Image(systemName: "forward.fill")
                    .font(.body)
                    .foregroundColor(.primary)
            })
        }.frame(height: 50)
    }
    
    @ViewBuilder private func makeTimeProgress(metrics: GeometryProxy) -> some View {
        VStack(spacing: 20) {
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 8)
                Capsule()
                    .fill(Color.red)
                    .frame(width: playerViewModel.percentProgress * metrics.size.width, height: 8)
                Circle()
                    .fill(Color.red)
                    .frame(width: 18, height: 18)
                    .padding(.leading, playerViewModel.percentProgress * metrics.size.width - 9)
            }
            .gesture(DragGesture()
                .onChanged({ (value) in
                    let x = value.location.x
                    let percentProgress = x / metrics.size.width
                    playerViewModel.percentProgress = min(1, max(0, percentProgress))
                }).onEnded({ (value) in
                    playerViewModel.isTapped = false
                    let x = value.location.x
                    let percent = min(1, max(0, x / metrics.size.width))
                    playerViewModel.playerCurrentTime = Double(percent) * playerViewModel.playerDuration
                })
                    .updating($isTapped) { (_, isTapped, _) in isTapped = true}
            )
            .onChange(of: isTapped) { _, newValue in playerViewModel.isTapped = newValue }
            .frame(height: 10)
            HStack {
                Text(playerViewModel.playerCurrentTimeStr)
                Spacer()
                Text("-" + playerViewModel.playerMissingTimeStr)
            }
            .font(.body)
            .foregroundColor(.primary)
        }
        .padding(.horizontal, 15)
    }
    
    @ViewBuilder private func makeVolumeProgress() -> some View {
        HStack(spacing: 0) {
            Button(action: { playerViewModel.decreaseVolume() },
                   label: {
                Image(systemName: "speaker.wave.1")
                    .font(.body)
                    .foregroundColor(.primary)
            })
            Spacer()
            Slider(value: $volume)
                .tint(Color.red)
            Spacer()
            Button(action: { playerViewModel.increaseVolume() },
                   label: {
                Image(systemName: "speaker.wave.3")
                    .font(.body)
                    .foregroundColor(.primary)
            })
        }.padding(.horizontal, 15)
    }
    
    public init(volume: Binding<Float>) {
        _volume = volume
    }
}

#Preview {
    PlayerView(volume: .constant(Float(0)))
}
