//
//  Models.swift
//  ARKitPlay
//
//  Created by Siarhei Yakushevich on 9/9/18.
//  Copyright © 2018 Siarhei Yakushevich. All rights reserved.
//

import Foundation
import SceneKit
import ARKit

enum TouchType {
    case move
    case pinch
    case unknown
}

enum TapState {
    case none
    case all
    
    mutating func switchState() {
        var state = self
        if state == .all {
            state = .none
        } else {
            assert(state == .none)
            state = .all
        }
        self = state
    }
}

struct Category {
    static let Selected = 2
}

struct HitTestRay {
    let origin: float3
    let direction: float3
}

struct FeatureHitTestResult {
    let position: float3
    let distanceToRayOrigin: Float
    let featureHit: float3
    let featureDistanceToHitResult: Float
}

enum CategoryBitMask: Int {
    case building
}
