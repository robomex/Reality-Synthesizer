//
//  MIDIConductor.swift
//  Reality Synthesizer
//
//  Created by Tony Morales on 4/2/22.
//

import AudioKit
import DunneAudioKit
import SwiftUI

class MIDIConductor: ObservableObject {
    @Published var data = MIDIData()
    
    let engine = AudioEngine()
    let midi = MIDI()
    let synth = Synth(masterVolume: 0.5,
                      pitchBend: 1.0,
                      vibratoDepth: 0.0,
                      filterCutoff: 1.0,
                      filterStrength: 1.0,
                      filterResonance: 0.0,
                      attackDuration: 0.1,
                      decayDuration: 0.5,
                      sustainLevel: 1.0,
                      releaseDuration: 0.2,
                      filterEnable: true)
    
    var mixer = Mixer()
    
    init() {
        mixer.addInput(synth)
        engine.output = mixer
    }

    func start() {
        midi.openInput()
        midi.addListener(self)
        do {
            try engine.start()
        } catch {
            print("Unable to start AudioEngine")
        }
    }

    func stop() {
        midi.closeAllInputs()
        engine.stop()
    }
    
    // MARK: -  Synth Methods
    
    func playNote(noteNumber: UInt8, velocity: UInt8) {
        synth.play(noteNumber: noteNumber, velocity: velocity)
        data.noteOff = 0
    }

    func stopNote(noteNumber: UInt8) {
        synth.stop(noteNumber: noteNumber)
        data.noteOn = 0
    }
}
