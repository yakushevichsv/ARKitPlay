//
//  PhysicsSimulation.swift
//  ARKitPlay
//
//  Created by Siarhei Yakushevich on 5/26/18.
//  Copyright © 2018 Siarhei Yakushevich. All rights reserved.
//

import Foundation
import SceneKit

final class PhysicsSimulation {
    class func pathForArtResource(_ name: String) -> String {
        let rootFolder = "art.scnassets/\(name)"
        return rootFolder
    }
    
    class func loadParticleSystemWithName(_ name: String) -> SCNParticleSystem {
        var path = "effects/\(name).scnp"
        path = self.pathForArtResource(path)
        path = Bundle.main.path(forResource: path, ofType: nil)!
        let newSystem = NSKeyedUnarchiver.unarchiveObject(withFile: path) as! SCNParticleSystem
        
        let lastPathComponent: String?
        if let particleImageURL = newSystem.particleImage as? URL {
            lastPathComponent = particleImageURL.lastPathComponent
        } else if let particleImagePath = newSystem.particleImage as? String {
            lastPathComponent = URL(string: particleImagePath)!.lastPathComponent
        } else {
            lastPathComponent = nil
        }
        if let component = lastPathComponent {
            path = "effects/components/\(component)"
            path = self.pathForArtResource(path)
            let url = Bundle.main.url(forResource: path, withExtension: nil)
            newSystem.particleImage = url
        }
        return newSystem
    }
    
}
