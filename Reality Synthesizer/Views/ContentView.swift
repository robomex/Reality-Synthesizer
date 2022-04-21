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
    
    @State private var depths: [Float] = []
    @State private var notes: [Int] = []
    @State private var selectedSynth: RealitySynth = .crazy
    
    private var synths: [RealitySynth] = [.crazy, .cycle, .radiate, .wave]
    
    var body: some View {
        ZStack {
            Group {
                if selectedSynth == .crazy {
                    MetalTextureCrazyView(
                        depths: $depths,
                        notes: $notes,
                        rotationAngle: rotationAngle,
                        capturedData: manager.capturedData
                    )
                } else if selectedSynth == .cycle {
                    MetalTextureCycleView(
                        depths: $depths,
                        notes: $notes,
                        rotationAngle: rotationAngle,
                        capturedData: manager.capturedData
                    )
                } else if selectedSynth == .radiate {
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
        .onChange(of: selectedSynth, perform: { newSynth in
            if newSynth == .cycle || newSynth == .crazy {
                depths.removeAll()
                notes.removeAll()
            }
        })
        .onChange(of: conductor.data.noteOff, perform: { noteTurnedOff in
            guard noteTurnedOff != 0 else { return }
            if (selectedSynth == .cycle || selectedSynth == .crazy),
               let index = notes.firstIndex(of: noteTurnedOff)
            {
                notes.remove(at: index)
                depths.remove(at: index)
                // ATM NOTE (4/20/22): Notes can get "stuck" when conductor.data.noteOff is
                // written to multiple times in the same frame (e.g. two keys are released at
                // approximately the same time). This workaround will "release" the stuck key
                // with a subsequent release of that same key. This is a very ugly fix – but an
                // actual, robust fix didn't come to me immediately.
                if let stuckIndexWorkaround = notes.firstIndex(of: noteTurnedOff) {
                    notes.remove(at: stuckIndexWorkaround)
                    depths.remove(at: stuckIndexWorkaround)
                }
            }
        })
        .onAppear {
            conductor.start()
        }
        .onDisappear {
            conductor.stop()
        }
    }
}
