//
//  MetalPointCloudView.swift
//  Reality Synthesizer
//
//  Created by Tony Morales on 4/3/22.
//

import SwiftUI
import MetalKit

struct MetalPointCloudWaveView: UIViewRepresentable, MetalRepresentable {
    @Binding var depths: [Float]
    @Binding var notes: [Int]
    
    var rotationAngle: Double
    var capturedData: CameraCapturedData
    
    func makeCoordinator() -> MTKPointCloudWaveCoordinator {
        MTKPointCloudWaveCoordinator(parent: self)
    }
}

final class MTKPointCloudWaveCoordinator: MTKCoordinator<MetalPointCloudWaveView> {
    let waveSpeed: Float = 0.1
    
    override func preparePipelineAndDepthState() {
        guard let metalDevice = mtkView.device else { fatalError("Expected a Metal device.") }
        do {
            let library = MetalEnvironment.shared.metalLibrary
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            pipelineDescriptor.vertexFunction = library.makeFunction(name: "pointCloudVertexWaveShader")
            pipelineDescriptor.fragmentFunction = library.makeFunction(name: "pointCloudFragmentShader")
            pipelineDescriptor.vertexDescriptor = createMetalVertexDescriptor()
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
    
    func createMetalVertexDescriptor() -> MTLVertexDescriptor {
        let mtlVertexDescriptor: MTLVertexDescriptor = MTLVertexDescriptor()
        // Store position in `attribute[[0]]`.
        mtlVertexDescriptor.attributes[0].format = .float2
        mtlVertexDescriptor.attributes[0].offset = 0
        mtlVertexDescriptor.attributes[0].bufferIndex = 0
        
        // Set stride to twice the `float2` bytes per vertex.
        mtlVertexDescriptor.layouts[0].stride = 2 * MemoryLayout<SIMD2<Float>>.stride
        mtlVertexDescriptor.layouts[0].stepRate = 1
        mtlVertexDescriptor.layouts[0].stepFunction = .perVertex
        
        return mtlVertexDescriptor
    }
    
    func calcCurrentPMVMatrix(viewSize: CGSize) -> matrix_float4x4 {
        let projection: matrix_float4x4 = makePerspectiveMatrixProjection(fovyRadians: Float.pi / 3.0,
                                                                          aspect: Float(viewSize.width) / Float(viewSize.height),
                                                                          nearZ: 10.0, farZ: 8000.0)
        
        var orientationOrig: simd_float4x4 = simd_float4x4()
        // Since the camera stream is rotated clockwise, rotate it back.
        orientationOrig.columns.0 = [0, -1, 0, 0]
        orientationOrig.columns.1 = [-1, 0, 0, 0]
        orientationOrig.columns.2 = [0, 0, 1, 0]
        orientationOrig.columns.3 = [0, 0, 0, 1]
        
        var translationOrig: simd_float4x4 = simd_float4x4()
        // Move the object forward to enhance visibility.
        translationOrig.columns.0 = [1, 0, 0, 0]
        translationOrig.columns.1 = [0, 1, 0, 0]
        translationOrig.columns.2 = [0, 0, 1, 0]
        translationOrig.columns.3 = [0, 0, +0, 1]
        
        var translationCamera: simd_float4x4 = simd_float4x4()
        translationCamera.columns.0 = [1, 0, 0, 0]
        translationCamera.columns.1 = [0, 1, 0, 0]
        translationCamera.columns.2 = [0, 0, 1, 0]
        translationCamera.columns.3 = [0, 0, 0, 1]

        let pmv = projection * translationCamera * translationOrig * orientationOrig
        return pmv
    }
    
    override func draw(in view: MTKView) {
        guard parent.capturedData.depth != nil else {
            print("Depth data not available; skipping a draw.")
            return
        }
        guard let commandBuffer = metalCommandQueue.makeCommandBuffer() else { return }
        guard let passDescriptor = view.currentRenderPassDescriptor else { return }
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor) else { return }
        encoder.setDepthStencilState(depthState)
        encoder.setVertexTexture(parent.capturedData.depth, index: 0)
        encoder.setVertexTexture(parent.capturedData.colorY, index: 1)
        encoder.setVertexTexture(parent.capturedData.colorCbCr, index: 2)
        // Camera-intrinsics units are in full camera-resolution pixels.

        
        var waveLocations: [Float] = parent.depths.map { $0 * waveSpeed }
        let waveLocationsPseudoCount: Int = waveLocations.count > 0 ? waveLocations.count : 1
        var waveLocationsCount: Int = waveLocations.count
        var floatNotes: [Float] = parent.notes.map { Float($0) }
        
        let depthResolution = simd_float2(x: Float(parent.capturedData.depth!.width), y: Float(parent.capturedData.depth!.height))
        let scaleRes = simd_float2(x: Float( parent.capturedData.cameraReferenceDimensions.width) / depthResolution.x,
                                   y: Float(parent.capturedData.cameraReferenceDimensions.height) / depthResolution.y )
        var cameraIntrinsics = parent.capturedData.cameraIntrinsics
        cameraIntrinsics[0][0] /= scaleRes.x
        cameraIntrinsics[1][1] /= scaleRes.y

        cameraIntrinsics[2][0] /= scaleRes.x
        cameraIntrinsics[2][1] /= scaleRes.y
        var pmv = calcCurrentPMVMatrix(viewSize: CGSize(width: view.frame.size.width, height: view.frame.size.height))
        encoder.setVertexBytes(&pmv, length: MemoryLayout<matrix_float4x4>.stride, index: 0)
        encoder.setVertexBytes(&cameraIntrinsics, length: MemoryLayout<matrix_float3x3>.stride, index: 1)
        encoder.setVertexBytes(&waveLocations, length: waveLocationsPseudoCount * MemoryLayout<Float>.stride, index: 2)
        encoder.setVertexBytes(&waveLocationsCount, length: MemoryLayout<Int>.stride, index: 3)
        encoder.setVertexBytes(&floatNotes, length: waveLocationsPseudoCount * MemoryLayout<Float>.stride, index: 4)
        encoder.setRenderPipelineState(pipelineState)
        encoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: Int(depthResolution.x * depthResolution.y))
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

/// A helper function that calculates the projection matrix given fovY in radians, aspect ration and nearZ and farZ planes.
func makePerspectiveMatrixProjection(fovyRadians: Float, aspect: Float, nearZ: Float, farZ: Float) -> simd_float4x4 {
    let yProj: Float = 1.0 / tanf(fovyRadians * 0.5)
    let xProj: Float = yProj / aspect
    let zProj: Float = farZ / (farZ - nearZ)
    let proj: simd_float4x4 = simd_float4x4(SIMD4<Float>(xProj, 0, 0, 0),
                                           SIMD4<Float>(0, yProj, 0, 0),
                                           SIMD4<Float>(0, 0, zProj, 1.0),
                                           SIMD4<Float>(0, 0, -zProj * nearZ, 0))
    return proj
}
