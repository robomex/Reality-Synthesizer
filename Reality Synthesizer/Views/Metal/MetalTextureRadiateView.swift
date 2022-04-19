//
//  MetalTextureColorThresholdDepthView.swift
//  Reality Synthesizer
//
//  Created by Tony Morales on 4/3/22.
//

import SwiftUI
import Combine
import MetalKit
import Metal

struct MetalTextureRadiateView: UIViewRepresentable, MetalRepresentable {
    @Binding var depth0: Float
    
    var rotationAngle: Double
    var capturedData: CameraCapturedData

    func makeCoordinator() -> MTKColorThresholdDepthTextureCoordinator {
        MTKColorThresholdDepthTextureCoordinator(parent: self)
    }
}

final class MTKColorThresholdDepthTextureCoordinator: MTKCoordinator<MetalTextureRadiateView> {
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
        
        var helper: Float = parent.depth0 * speedFactor
        
        encoder.setVertexBytes(vertexData, length: vertexData.count * MemoryLayout<Float>.stride, index: 0)
        encoder.setFragmentBytes(&helper, length: MemoryLayout<Float>.stride, index: 0)
        encoder.setFragmentTexture(parent.capturedData.depth!, index: 2)
        encoder.setFragmentTexture(parent.capturedData.colorY!, index: 0)
        encoder.setFragmentTexture(parent.capturedData.colorCbCr!, index: 1)
        encoder.setDepthStencilState(depthState)
        encoder.setRenderPipelineState(pipelineState)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
        commandBuffer.present(view.currentDrawable!)
        commandBuffer.commit()
        parent.depth0 += 1
    }
}
