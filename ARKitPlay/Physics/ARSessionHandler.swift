//
//  ARSessionHandler.swift
//  ARKitPlay
//
//  Created by Siarhei Yakushevich on 6/23/18.
//  Copyright © 2018 Siarhei Yakushevich. All rights reserved.
//

import Foundation
import ARKit

class ARSessionHandler: NSObject {
    var didChaneState:((_ state: ARCamera.TrackingState) -> Void)?
}

// MARK: - ARSessionDelegate
extension ARSessionHandler: ARSessionDelegate {
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        //debugPrint(#function)
        debugPrint(#function + "Error \(error)")
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        //debugPrint(#function)
        session.pause()
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        //debugPrint(#function)
        
        if let configuration = session.configuration {
            session.run(configuration, options: .resetTracking)
        }
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        didChaneState?(camera.trackingState)
    }
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        //debugPrint(#function)
    }
    
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        // debugPrint(#function)
    }
}
