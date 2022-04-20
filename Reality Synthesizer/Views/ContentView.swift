//
//  ContentView.swift
//  Reality Synthesizer
//
//  Created by Tony Morales on 4/1/22.
//

import SwiftUI

struct ContentView: View {
    @StateObject var conductor = MIDIConductor()
    @StateObject var manager = CameraManager()
    
    @State private var depths: [Float] = [0]
    @State private var notes: [Int] = [0]
    @State private var selectedSynth: RealitySynth = .radiate
    
    private var synths: [RealitySynth] = [.radiate, .wave]
    
    var body: some View {
        ZStack {
            Group {
                if selectedSynth == .radiate {
                    MetalTextureRadiateView(
                        depths: $depths,
                        notes: $notes,
                        rotationAngle: rotationAngle,
                        capturedData: manager.capturedData
                    )
                } else if selectedSynth == .wave {
                    MetalPointCloudWaveView(
                        depths: $depths,
                        notes: $notes,
                        rotationAngle: rotationAngle,
                        capturedData: manager.capturedData
                    )
                }
            }
            .aspectRatio(calcAspect(orientation: viewOrientation,
                                    texture: manager.capturedData.depth),
                         contentMode: .fill)
            
            VStack {
                Picker(selection: $selectedSynth, label: EmptyView()) {
                    ForEach(synths, id: \.self) {
                        Text($0.rawValue)
                    }
                }
                .padding(.top, 50)
                .padding(.trailing, 60)
                
                Text("Note: \(conductor.data.noteOn)")
                Spacer()
            }
        }
        .onChange(of: conductor.data.noteOn, perform: { newNote in
            guard newNote != 0 else { return }
            depths.insert(0, at: 0)
            notes.insert(newNote, at: 0)
        })
        .onAppear {
            conductor.start()
        }
        .onDisappear {
            conductor.stop()
        }
    }
}
