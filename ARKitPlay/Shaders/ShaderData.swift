//
//  ShaderData.swift
//  ARKitPlay
//
//  Created by Siarhei Yakushevich on 6/17/18.
//  Copyright © 2018 Siarhei Yakushevich. All rights reserved.
//

import Foundation

class ShaderData {
    var filename: String
    var shaderProgram: String
    
    init?(filename: String) {
        self.filename = filename
        let path = Bundle.main.path(forResource: filename, ofType: nil)
        if let path = path {
            let url = URL(fileURLWithPath: path)
            if let shader = try? String.init(contentsOf: url) {
                self.shaderProgram = shader
                return
            }
        }
        return nil
    }
}
