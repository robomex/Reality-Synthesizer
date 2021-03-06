//
//  MetalTextureColorThresholdDepthView.swift
//  Reality Synthesizer
//
//  Created by Tony Morales on 4/3/22.
//

import SwiftUI
import MetalKit

struct MetalTextureRadiateView: UIViewRepresentable, MetalRepresentable {
    @Binding var depths: [Float]
    @Binding var notes: [Int]
    
    var rotationAngle: Double
    var capturedData: CameraCapturedData

    func makeCoordinator() -> MTKRadiateTextureCoordinator {
        MTKRadiateTextureCoordinator(parent: self)
    }
}

final class MTKRadiateTextureCoordinator: MTKCoordinator<MetalTextureRadiateView> {
    let speedFactor: Float = 0.1
    
    override func preparePipelineAndDepthState() {
        guard let metalDevice = mtkView.device else { fatalError("Expected a Metal device.") }
        do {
            let library = MetalEnvironment.shared.metalLibrary
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            pipelineDescriptor.vertexFunction = library.makeFunction(name: "planeVertexShader")
            pipelineDescriptor.fragmentFunction = library.makeFunction(name: "planeFragmentShaderColorRadiate")
            pipelineDescriptor.vertexDescriptor = createPlaneMetalVertexDescriptor()
            pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
            pipelineState = try metalDevice.makeRenderPipelineState(descriptor: pipelineDescriptor)
            
            let depthDescriptor = MTLDepthStencilDescriptor()
            depthDescriptor.isDepthWriteEnabled = true
            depthDescriptor.depthCompareFunction = .less
            depthState = metalDevice.makeDepthStencilState(descriptor: depthDescriptor)
        } catch {
            print("Unexpected error: \(error).")
        }
    }
    
    override func draw(in view: MTKView) {
        guard parent.capturedData.colorY != nil && parent.capturedData.colorCbCr != nil else {
            print("There's no content to display.")
            return
        }
        guard let commandBuffer = metalCommandQueue.makeCommandBuffer() else { return }
        guard let passDescriptor = view.currentRenderPassDescriptor else { return }
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor) else { return }
        // Vertex and Texture coordinates data (x,y,u,v) * 4 ordered for triangle strip
        let vertexData: [Float] = [-1, -1, 1, 1,
                                    1, -1, 1, 0,
                                   -1,  1, 0, 1,
                                    1,  1, 0, 0]
        
        var radiateLocations: [Float] = parent.depths.map { $0 * speedFactor }
        let radiateLocationsPseudoCount: Int = radiateLocations.count > 0 ? radiateLocations.count : 1
        var radiateLocationsCount: Int = radiateLocations.count
        var noteWidths: [Float] = parent.notes.map { abs((Float($0) - 95) / 95) }
        var floatNotes: [Float] = parent.notes.map { Float($0) }
        
        encoder.setVertexBytes(vertexData, length: vertexData.count * MemoryLayout<Float>.stride, index: 0)
        encoder.setFragmentBytes(&radiateLocations, length: radiateLocationsPseudoCount * MemoryLayout<Float>.stride, index: 0)
        encoder.setFragmentBytes(&radiateLocationsCount, length: MemoryLayout<Int>.stride, index: 1)
        encoder.setFragmentBytes(&floatNotes, length: radiateLocationsPseudoCount * MemoryLayout<Float>.stride, index: 2)
        encoder.setFragmentBytes(&noteWidths, length: radiateLocationsPseudoCount * MemoryLayout<Float>.stride, index: 3)
        encoder.setFragmentTexture(parent.capturedData.colorY!, index: 0)
        encoder.setFragmentTexture(parent.capturedData.colorCbCr!, index: 1)
        encoder.setFragmentTexture(parent.capturedData.depth!, index: 2)
        encoder.setDepthStencilState(depthState)
        encoder.setRenderPipelineState(pipelineState)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
        commandBuffer.present(view.currentDrawable!)
        commandBuffer.commit()
        guard parent.depths.count > 0 else { return }
        for depth in 0...(parent.depths.count - 1) {
            parent.depths[depth] += 1
            if parent.depths[depth] > 200 {
                parent.depths.remove(at: depth)
                parent.notes.remove(at: depth)
                return
            }
        }
    }
}
