//
//  Extensions.swift
//  Reality Synthesizer
//
//  Created by Tony Morales on 4/2/22.
//

import SwiftUI

extension CVPixelBuffer {
    func texture(withFormat pixelFormat: MTLPixelFormat, planeIndex: Int, addToCache cache: CVMetalTextureCache) -> MTLTexture? {
        
        let width = CVPixelBufferGetWidthOfPlane(self, planeIndex)
        let height = CVPixelBufferGetHeightOfPlane(self, planeIndex)
        
        var cvtexture: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(nil, cache, self, nil, pixelFormat, width, height, planeIndex, &cvtexture)
        guard let texture = cvtexture else { return nil }
        return CVMetalTextureGetTexture(texture)
    }
}

extension View {
    func calcAspect(orientation: UIImage.Orientation, texture: MTLTexture?) -> CGFloat {
        guard let texture = texture else { return 1 }
        switch orientation {
        case .up:
            return CGFloat(texture.width) / CGFloat(texture.height)
        case .down:
            return CGFloat(texture.width) / CGFloat(texture.height)
        case .left:
            return  CGFloat(texture.height) / CGFloat(texture.width)
        case .right:
            return  CGFloat(texture.height) / CGFloat(texture.width)
        default:
            return CGFloat(texture.width) / CGFloat(texture.height)
        }
    }
    
    var rotationAngle: Double {
        var angle = 0.0
        switch viewOrientation {
        
        case .up:
            angle = -Double.pi / 2
        case .down:
            angle = Double.pi / 2
        case .left:
            angle = Double.pi
        case .right:
            angle = 0
        default:
            angle = 0
        }
        return angle
    }
    
    var viewOrientation: UIImage.Orientation {
        var result = UIImage.Orientation.up
       
        guard let currentWindowScene = UIApplication.shared.connectedScenes.first(
            where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        else { return result }
        
        let interfaceOrientation = currentWindowScene.interfaceOrientation
        switch interfaceOrientation {
        case .portrait:
            result = .right
        case .portraitUpsideDown:
            result = .left
        case .landscapeLeft:
            result = .down
        case .landscapeRight:
            result = .up
        default:
            result = .up
        }
            
        return result
    }
}
