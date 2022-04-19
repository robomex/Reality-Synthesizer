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
    
    @State private var depth0: Float = 0
    @State private var selectedSynth: RealitySynth = .radiate
    
    private var synths: [RealitySynth] = [.radiate, .wave]
    
    var body: some View {
        ZStack {
            Group {
                if selectedSynth == .radiate {
                    MetalTextureRadiateView(
                        depth0: $depth0,
                        rotationAngle: rotationAngle,
                        capturedData: manager.capturedData
                    )
                } else if selectedSynth == .wave {
                    MetalPointCloudWaveView(
                        depth0: $depth0,
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
        .onChange(of: conductor.data.noteOn, perform: { newValue in
            depth0 = 0
        })
        .onAppear {
            conductor.start()
        }
        .onDisappear {
            conductor.stop()
        }
    }
}
