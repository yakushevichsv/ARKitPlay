//
//  ViewController.swift
//  ARKitPlay
//
//  Created by Siarhei Yakushevich on 5/12/18.
//  Copyright © 2018 Siarhei Yakushevich. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController {
    
    @IBOutlet var sceneView: ARSCNView!
    var dustPoof: SCNParticleSystem!
    weak var selectedNode: SCNNode?
    
    var unHighlightNode: SCNNode?
    
    let sessionHandler = ARSessionHandler()
    
    var tapState = TapState.none
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard ARWorldTrackingConfiguration.isSupported else {
            assertionFailure("World tracking is not supported!")
            return
        }
        
        sessionHandler.didChaneState = { [unowned self] (state) in
            switch state {
            case .normal:
                debugPrint("Normal tracking")
            case .limited(let reason):
                debugPrint("Limited \(reason)")
            default:
                debugPrint("State \(state)")
            }
        }
        
        // Set the view's delegate
        sceneView.delegate = self
        sceneView.session.delegateQueue = DispatchQueue.global(qos: .background)
        sceneView.automaticallyUpdatesLighting = false
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        sceneView.debugOptions = [.showCameras]
        setupCamera()
        setupLight()
        setupDustNode()
        
        setupGestures()
    }
    
    func setupGestures() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTap(gesture:)))
        tap.numberOfTapsRequired = 1
        
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(didTap(gesture:)))
        doubleTap.numberOfTapsRequired = 2
        
        let scaleTap = UIPinchGestureRecognizer(target: self, action: #selector(didPinch(gesture:)))
        sceneView.addGestureRecognizer(scaleTap)
        
        tap.require(toFail: doubleTap)
        sceneView.addGestureRecognizer(tap)
        sceneView.addGestureRecognizer(doubleTap)
        
        let panTap = UIPanGestureRecognizer(target: self, action: #selector(didPan(gesture:)))
        sceneView.addGestureRecognizer(panTap)
        panTap.require(toFail: tap)
    }
    
    @objc func didPinch(gesture: UIPinchGestureRecognizer) {
        
        guard let pointOfView = sceneView.pointOfView else {
            return
        }
        
        let nodes = sceneView.nodesInsideFrustum(of: pointOfView).filter { $0.name == "farmHouse" }
        
        let scale = gesture.scale
        
        
        for node in nodes {
            if !isHightlightedNode(node) { continue }
            
            var finalScale = node.simdScale
            finalScale *= Float(scale)
            node.simdScale = finalScale
        }
        
        gesture.scale = 1.0
    }
    
    func setupCamera() {
        guard let camera = sceneView.pointOfView?.camera else {
            fatalError("Expected a valid `pointOfView` from the scene.")
        }
        
        /*
         Enable HDR camera settings for the most realistic appearance
         with environmental lighting and physically based materials.
         */
        camera.wantsHDR = true
        camera.exposureOffset = -1
        camera.minimumExposure = -1
        camera.maximumExposure = 3
    }
    
    func setupLight() {
        defineDirectionalLight()
        defineAmbinientLight()
    }
    
    func defineDirectionalLight() {
        let myNode = SCNNode()
        let light = SCNLight()
        light.type = SCNLight.LightType.directional
        light.color = UIColor.white
        light.castsShadow = true
        myNode.light = light
        if light.castsShadow {
            light.shadowMode = .deferred
            light.automaticallyAdjustsShadowProjection = true
            light.shadowSampleCount = 64
            light.shadowRadius = 16
            //light.shadowMapSize = CGSize(width: 2048, height: 2048)
            light.shadowColor = UIColor.black.withAlphaComponent(0.5)
        }
        light.categoryBitMask = CategoryBitMask.building.rawValue
        myNode.position = SCNVector3(x: 0,y: 5,z: 0)
        myNode.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        
        // Add the lights to the container
        sceneView.scene.rootNode.addChildNode(myNode)
    }
    
    func defineAmbinientLight() {
        guard sceneView.automaticallyUpdatesLighting == false else { return }
        let lightNode = SCNNode()
        let light = SCNLight()
        light.type = .ambient
        light.castsShadow = false
        light.color = UIColor.white
        light.intensity = 500
        lightNode.light = light
        sceneView.scene.rootNode.addChildNode(lightNode)
    }
    
    func setupDustNode() {
        self.dustPoof = PhysicsSimulation.loadParticleSystemWithName("dust")
    }
    
    func addFarmHouseNode(at position: simd_float3) -> SCNNode! {
        guard let scene = SCNScene(named: "art.scnassets/farmhouse/farmhouse.scn")
            else { return nil}
        
        let foundNode = scene.rootNode
        let sizeTuple = foundNode.boundingBox
        
        let max: Float = 0.1 //meter...
        
        let scaleX = max/sizeTuple.max.x
        let scaleY = max/sizeTuple.max.y
        let scaleZ = max/sizeTuple.max.z
        
        //foundNode.eulerAngles.y = -.pi/2
        let scale = Swift.max(scaleZ, Swift.max(scaleX, scaleY))
        foundNode.scale = SCNVector3(x: scale, y: scale, z: scale)
        foundNode.simdPosition = position
        foundNode.categoryBitMask = CategoryBitMask.building.rawValue
        foundNode.name = "farmHouse"
        appendActions(node: foundNode)
        return foundNode
    }
    
    func appendActions(node: SCNNode) {
        let ePosition = node.simdPosition
        let upOffset: Float = 0.4
        
        node.simdLocalTranslate(by: simd_float3(x: 0, y: upOffset, z: 0))
        
        let vector = SCNVector3Make(ePosition.x, ePosition.y, ePosition.z)
        let moveDown = SCNAction.move(to: vector, duration: 1)
        
        let dustCopy = self.dustPoof!//.copy() as! SCNParticleSystem
        dustCopy.isLocal = true
        
        let boundingBox = node.boundingBox
        let width =  CGFloat(boundingBox.max.x * node.simdScale.x)
        let height = CGFloat(boundingBox.max.y * node.simdScale.y)
        let length = CGFloat(boundingBox.max.z * node.simdScale.z)
        
        let isVolume = false
        
        dustCopy.emitterShape = isVolume ? SCNBox(width: width, height: height, length: length, chamferRadius: 0)
                                         : SCNPlane(width: width, height: height)
        
        dustCopy.emittingDirection = SCNVector3Make(1, 0, 1) // up in local space...
        dustCopy.spreadingAngle = 360
        
        dustCopy.birthDirection = SCNParticleBirthDirection.random
        dustCopy.birthLocation = isVolume ? SCNParticleBirthLocation.volume
                                          : SCNParticleBirthLocation.surface
        
        let tempRotation = SCNAction.rotate(by: 30 * .pi/180, around: SCNVector3Make(0, 1, 0), duration: 0.1)
        let rotation = SCNAction.repeat(tempRotation, count: Int(moveDown.duration/tempRotation.duration))
        node.runAction(rotation, forKey: "rotation")
        
        node.runAction(moveDown) {
            if dustCopy.isLocal {
                
                node.addParticleSystem(dustCopy)
            }
            else {
                self.createFrom(particleSystem: dustCopy, node)
            }
        }
    }
    
    func createFrom(particleSystem: SCNParticleSystem, _ node: SCNNode) {
        let rotation = node.presentation.rotation
        let position = node.presentation.position
        
        let rotationMatrix =
            SCNMatrix4MakeRotation(rotation.w,
                                   rotation.x,
                                   rotation.y,
                                   rotation.z)
        let translationMatrix =
            SCNMatrix4MakeTranslation(position.x,
                                      position.y,
                                      position.z)
        let transformMatrix =
            SCNMatrix4Mult(rotationMatrix, translationMatrix)
        // 4
        let scene = self.sceneView.scene
        debugPrint("Position \(position) Rotation \(rotation)")
        scene.addParticleSystem(particleSystem, transform:
            transformMatrix)
    }
    
    @discardableResult func trackTouchBegan(postion: CGPoint) -> Bool {
        let options: [ SCNHitTestOption: Any] = [SCNHitTestOption.ignoreHiddenNodes: true]
        let results = sceneView.hitTest(postion, options: options)
        debugPrint(#function + "Results count \(results.count)")
        for result in results {
            let nodeName = result.node.name
            if nodeName == "farmHouse" {
                let node = result.node
                if selectedNode == node {
                    selectedNode = nil
                } else {
                    selectedNode = node
                }
                changeNodeSelectionState(node)
                return true
            }
        }
        return false
    }
    
    class func geometry(with name: String?, from node: SCNNode) -> SCNGeometry? {
        let geomName = (name ?? node.name)?.lowercased()
        
        if node.geometry?.name?.lowercased() == geomName {
            return node.geometry
        }
        
        for node in node.childNodes {
            if let geometry = self.geometry(with: geomName, from: node) {
                return geometry
            }
        }
        
        return nil
    }
    
    func findParentNodeOrSelf(node: SCNNode?) -> SCNNode? {
        guard let node = node else { return nil }
        
        let name = node.name
        var newNode: SCNNode? = node
        var retNode: SCNNode? = nil
        while (newNode?.name == name) {
            retNode = newNode
            newNode = newNode?.parent
        }
        return retNode ?? node
    }
    
     @discardableResult func handleTap(tapLocation: CGPoint) -> SCNNode? {
        
        let hitTestResults = sceneView.hitTest(tapLocation, types: [.existingPlaneUsingExtent, .featurePoint])
        
        guard let hitTestResult = hitTestResults.first(where: { $0.type != ARHitTestResult.ResultType.featurePoint }) ?? hitTestResults.first else { return nil }
        
        let translation = hitTestResult.worldTransform.translation
        let x = translation.x
        let y = translation.y
        let z = translation.z
        
        if let anchor = hitTestResult.anchor {
            if let node = sceneView.node(for: anchor) {
                node.isHidden = true
            }
        }
        else if hitTestResult.type == .featurePoint, let node = unHighlightNode {
            // Morpher on new position....
            let oldProjectedPosition = sceneView.projectPoint(node.worldPosition)
            var newProjectedPosition = oldProjectedPosition
            debugPrint("Old 2D Position x: \(oldProjectedPosition.x) y: \(oldProjectedPosition.y)")
            newProjectedPosition.x = Float(tapLocation.x)
            newProjectedPosition.y = Float(tapLocation.y)
            
            debugPrint("New 2D Position x: \(newProjectedPosition.x) y: \(newProjectedPosition.y)")
            
            let newPosition = sceneView.unprojectPoint(newProjectedPosition)
            
            debugPrint("Item X")
            
            let positionAction: SCNAction
            let duration: TimeInterval
            if distance(simd_float3([newPosition.x, newPosition.y, newPosition.z]), hitTestResult.worldTransform.translation) > 10/100.0 /* in memters */ {
                duration = 5
            } else {
                duration = 2
            }
            positionAction = SCNAction.move(to: newPosition, duration: duration)
            
            if let name = node.name?.lowercased() {
                let commonTemplate = "art.scnassets/%@/%@_%@.scn"
                let postfixs = ["shrinked", "expanded"]
                assert(node.geometry != nil)
                let sceneNames = postfixs.map { String(format: commonTemplate, name, name, $0 ) }
                let scenes = sceneNames.compactMap { SCNScene(named: $0) }
                let geometriesOpt = scenes.map { type(of: self).geometry(with: name, from: $0.rootNode) }
                let geometries = geometriesOpt.compactMap { $0 }
                debugPrint("Geometries count \(geometries.count)")
                let morpher = SCNMorpher()
                morpher.targets = geometries
                
                let value1: Double = 0
                let value2: Double = 1 - value1
                
                morpher.setWeight(CGFloat(value1), forTargetAt: 0)
                morpher.setWeight(CGFloat(value2), forTargetAt: 1)
                node.morpher = morpher
                
                let duration = positionAction.duration + max(1.0, 0.1 * positionAction.duration)
                let w0 = CABasicAnimation(keyPath: "morpher.weights[0]")
                w0.fromValue = value1
                w0.toValue = 1
                w0.duration = max(0.2, duration/100.0)
                w0.repeatCount = Float.greatestFiniteMagnitude
                w0.autoreverses = true
                
                
                let w1 = CABasicAnimation(keyPath: "morpher.weights[1]")
                w1.fromValue = value2
                w1.toValue = 1 - value2
                w1.duration = w0.duration
                w1.repeatCount = Float.greatestFiniteMagnitude
                w1.autoreverses = true
                
                let group = CAAnimationGroup()
                group.duration = duration
                group.animations = [w0, w1]
                
                let groupAnimation = SCNAnimation(caAnimation: group)
                node.addAnimation(groupAnimation, forKey: "weights")
            }
            
            if let actionNode = findParentNodeOrSelf(node: node) {
                actionNode.runAction(positionAction, forKey: "position-change") {
                    type(of: self).disposeMorpher(node: node)
                }
                return actionNode
            }
            
            return node
        }
        
        // TODO: Highlight node :
        // https://stackoverflow.com/questions/38637075/adding-a-border-around-scenekit-node
        
        let refNode = sceneView.scene.rootNode
        if let newNode = addFarmHouseNode(at: simd_float3(x,y, z)) {
            refNode.addChildNode(newNode)
            return newNode
        } else { assertionFailure(); return nil }
    }
    
    class func disposeMorpher(node: SCNNode) {
        node.morpher = nil
        node.removeAnimation(forKey: "weights")
    }
    
    private func changeNode(_ node: SCNNode, scale: Float, color: UIColor) {
        let cloneNode = node//node.clone()
        cloneNode.geometry?.firstMaterial?.fillMode = .fill
        cloneNode.simdScale = simd_float3(scale, scale, scale)
        cloneNode.geometry?.firstMaterial?.multiply.contents = color
    }
    
    @discardableResult func toggleHighlightNode(_ node: SCNNode) -> TapState {
        if isHightlightedNode(node) {
            unhighlightNode(node)
            return .none
        } else {
            highlightNode(node)
            return .all
        }
    }
    
    @objc func didTap(gesture: UITapGestureRecognizer) {
        let doubleTap = gesture.numberOfTapsRequired == 2
        let singleTap = gesture.numberOfTapsRequired == 1
        
        guard singleTap || doubleTap else { return }
        
        let tapLocation = gesture.location(in: sceneView)
        if singleTap {
            handleOneTap(location: tapLocation)
            debugPrint("Number of farm houses \(farmHouseNodes().count)")
        } else {
            assert(doubleTap)
            handleTwoTap(location: tapLocation)
        }
    }
    
    private func changeNodeStateOnTap(location: CGPoint) -> SCNNode? {
        
        let results = sceneView.hitTest(location, options: [SCNHitTestOption.ignoreHiddenNodes: true,
                                                            SCNHitTestOption.ignoreChildNodes: false,
                                                            SCNHitTestOption.searchMode: NSNumber(integerLiteral: SCNHitTestSearchMode.all.rawValue)])
        
        var foundNode: SCNNode?
        for i in 0..<results.count {
            let result = results[i]
            let currentNode = result.node
            if isSignificant(node: currentNode) {
                foundNode = currentNode
                break
            }
        }
        
        if var currentNode = foundNode {
            if let parent = currentNode.parent, isSignificant(node: parent) {
                currentNode = parent
            }
            changeNodeSelectionState(currentNode)
        }
        
        
        return foundNode
    }
    
    func isSignificant(node: SCNNode) -> Bool {
        return node.name == "farmHouse"
    }
    
    private func handleOneTap(location: CGPoint) {
        debugPrint(#function)
        let changedNode = changeNodeStateOnTap(location: location)
        guard changedNode == nil else {
            self.unHighlightNode = changedNode!
            return
        }
        
        handleTap(tapLocation: location)
    }
    
    private func handleTwoTap(location: CGPoint) {
        
        let changedNode = changeNodeStateOnTap(location: location)
        guard changedNode == nil else {
            self.unHighlightNode = changedNode!
            return
        }
        
        let nodes: [SCNNode]
        let selected: Bool
        
        tapState.switchState()
        if tapState == .all {
            if sceneView.technique == nil {
                applyTechnique()
            }
            
            nodes = farmHouseNodes()
            selected = true
            
        } else {
            assert(tapState == .none)
            resetTechnique()
            
            nodes = farmHouseSelectedNodes()
            selected = false
        }
        
        nodes.forEach { (node) in
            type(of: self).change(node: node, selected: selected)
        }
        
    }
    
    func farmHouseSelectedNodes() -> [SCNNode] {
        let name = "farmHouse"
        let names = [name].compactMap({ $0 })
        let set = Set<String>(names)
        return nodes(names: set, selected: true)
    }
    
    func farmHouseNodes() -> [SCNNode] {
        let name = "farmHouse"
        let names = [name].compactMap({ $0 })
        let set = Set<String>(names)
        return nodes(names: set, selected: false)
    }
    
    func nodes(names: Set<String>, selected: Bool) -> [SCNNode] {
        guard !names.isEmpty else {
            return sceneView?.scene.rootNode.childNodes ?? []
        }
        return sceneView?.scene.rootNode.childNodes(passingTest: { (node, stop) -> Bool in
            return node.name != nil &&
                names.contains(node.name!) &&
                (!selected || node.categoryBitMask == Category.Selected)
        }) ?? []
    }
    
    @discardableResult func changePositionForUnhighlighNode(for translation: CGPoint) -> Bool {
        guard let node = self.unHighlightNode else { return false }
        guard let pointOfView = sceneView.pointOfView, sceneView.isNode(node, insideFrustumOf: pointOfView) else {
            return false
        }
        
        let beforePosition = node.worldPosition
        let screenPosition = beforePosition
        var projectedPosition = sceneView.projectPoint(screenPosition)
        debugPrint("Position 3D before \(beforePosition)")
        
        debugPrint("Projected 2D before \(projectedPosition)")
        
        projectedPosition.x += Float(translation.x)
        projectedPosition.y += Float(translation.y)
        
        //debugPrint("Translation \(spacePoint)")
        
        let position = sceneView.unprojectPoint(projectedPosition)
        debugPrint("Position after \(position)")
        node.worldPosition = position
        return true
    }
    
    @objc func didPan(gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: sceneView)
        debugPrint(#function + " Location: \(location)")
        let translation = gesture.translation(in: sceneView)
        debugPrint(#function + " Translation: \(translation)")
        let state = gesture.state
        switch state {
        case .ended, .cancelled:
            if let node = self.unHighlightNode {
                toggleHighlightNode(node)
                unHighlightNode = nil
            }
        default:
            switch state {
            case .changed, .began:
                if !changePositionForUnhighlighNode(for: translation) {
                    if let resNode = changeNodeStateOnTap(location: location) {
                        unHighlightNode = resNode
                        changeNodeSelectionState(resNode)
                    }
                }
            default:
                break
            }
        }
        gesture.setTranslation(.zero, in: sceneView)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        var configuration: ARConfiguration! = sceneView.session.configuration
        if configuration == nil {
            let worldConfig = ARWorldTrackingConfiguration()
            worldConfig.planeDetection = [.horizontal]
            configuration = worldConfig
        }
        // Run the view's session
        sceneView.session.run(configuration, options: [.resetTracking])
        sceneView.session.delegate = sessionHandler
        sceneView.delegate = self
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
}


extension ViewController: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        // Create a SceneKit plane to visualize the plane anchor using its position and extent.
        let plane = SCNPlane(width: CGFloat(planeAnchor.extent.x), height: CGFloat(planeAnchor.extent.z))
        let planeNode = SCNNode(geometry: plane)
        
        planeNode.simdPosition = float3(planeAnchor.center.x, 0, planeAnchor.center.z)
        planeNode.eulerAngles.x = -.pi / 2
        
        // Make the plane visualization semitranent to clearly show real-world placement.
        planeNode.opacity = 0.25
        node.name = "plane"
        node.addChildNode(planeNode)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        // Update content only for plane anchors and nodes matching the setup created in `renderer(_:didAdd:for:)`.
        guard let planeAnchor = anchor as?  ARPlaneAnchor, node.name == "plane"
            else { return }
        
        guard let refNode = node.childNodes.first else {
            return
        }
        
        let geometry = refNode.geometry
        let isBox = geometry is SCNBox
        var definePosition = isBox
        if let plane = geometry as? SCNPlane {
            definePosition = true
            // Plane estimation may also extend planes, or remove one plane to merge its extent into another.
            plane.width = CGFloat(planeAnchor.extent.x)
            plane.height = CGFloat(planeAnchor.extent.z)
        }
        
        if definePosition {
            // Plane estimation may shift the center of a plane relative to its anchor's transform.
            refNode.simdPosition = planeAnchor.center
        }
    }
}

//MARK: - Highlight & Unhighlight

extension ViewController {
    func changeNodeSelectionState(_ node: SCNNode) {
        debugPrint("Node \(node)")
        let state = toggleHighlightNode(node)
        
        let selected: Bool
        
        if state == .all {
            if sceneView.technique == nil {
                applyTechnique()
            }
            selected = true
        } else {
            assert(state == .none)
            if farmHouseSelectedNodes().isEmpty {
                resetTechnique()
            }
            
            selected = false
        }
        
        type(of: self).change(node: node, selected: selected)
    }
    
    class func change(node: SCNNode?, selected: Bool) {
        guard let node = node else { return }
        var mask = node.categoryBitMask
        
        if selected {
            mask = Category.Selected
        } else {
            mask = 1 // 1 default...
        }
        node.categoryBitMask = mask
        
        node.childNodes.forEach { (cNode) in
            change(node: cNode, selected: selected)
        }
    }
    
    func isHightlightedNode(_ node: SCNNode) -> Bool {
        var array = node.childNodes
        array.insert(node, at: 0)
        let highlightningNodes = array.first { (child) -> Bool in
            if let material = child.geometry?.firstMaterial {
                return material.multiply.animationKeys.contains("animateContent")
            }
            return false
        }
        return highlightningNodes != nil
    }
    
    func highlightNode(_ node: SCNNode, color: UIColor = .yellow) {
        let multyAnimation = CABasicAnimation(keyPath: "contents")
        
        multyAnimation.fromValue = nil
        multyAnimation.toValue = UIColor.yellow
        multyAnimation.duration = 1.0
        multyAnimation.repeatCount = .greatestFiniteMagnitude
        
        node.enumerateChildNodes { (cNode, pointer) in
            if let material = cNode.geometry?.firstMaterial {
                material.multiply.addAnimation(multyAnimation, forKey: "animateContent")
                //material.shaderModifiers = dic
            }
        }
        
        loadGhostEffect(node: node)
        applyGhostEffect(show: true, node: node)
    }
    
    func unhighlightNode(_ node: SCNNode) {
        node.enumerateChildNodes { (cNode, pointer) in
            if let material = cNode.geometry?.firstMaterial {
                material.multiply.removeAnimation(forKey: "animateContent")
            }
        }
        
        removeGhostEffect(node: node)
        applyGhostEffect(show: false, node: node)
    }
    
    func applyTechnique() {
        if let path = Bundle.main.path(forResource: "NodeTechnique", ofType: "plist") {
            if let dict = NSDictionary(contentsOfFile: path)  {
                let dict2 = dict as! [String : AnyObject]
                let technique = SCNTechnique(dictionary:dict2)
                sceneView.technique = technique
            }
        } else { assertionFailure("No content!") }
    }
    
    func resetTechnique() {
        sceneView.technique = nil
    }
    
    func loadGhostEffect(node: SCNNode) {
        guard let url = Bundle.main.url(forResource: "character", withExtension: "shader") else { return }
        guard let fragmentModifier = try? String(contentsOf: url) else { return }
        
        let dic =  [SCNShaderModifierEntryPoint.fragment : fragmentModifier]
        
        apply(to: node, shaderModifier: dic)
    }
    
    func removeGhostEffect(node: SCNNode) {
        node.geometry?.setValue(Float(0.0), forKey: "ghostFactor")
        for child in node.childNodes {
            removeGhostEffect(node: child)
        }
    }
    
    func applyGhostEffect(show: Bool, node: SCNNode) {
        node.geometry?.setValue(Float(show ? 1.0 : 0.0), forKey: "ghostFactor")
        
        for child in node.childNodes {
            applyGhostEffect(show: show, node: child)
        }
    }
    
    func apply(to node: SCNNode, shaderModifier dic: [SCNShaderModifierEntryPoint : String]) {
        node.geometry?.shaderModifiers = dic
        for child in node.childNodes {
            apply(to: child, shaderModifier: dic)
        }
    }
}

extension ViewController {
    class func hitTestRayFromScreenPos(_ point: CGPoint, in view: ARSCNView) -> HitTestRay? {
        
        guard let frame = view.session.currentFrame else {
            return nil
        }
        
        let cameraPos = SCNVector3(frame.camera.transform.translation)
        
        // Note: z: 1.0 will unproject() the screen position to the far clipping plane.
        let positionVec = float3(x: Float(point.x), y: Float(point.y), z: 1.0)
        let screenPosOnFarClippingPlane =  view.unprojectPoint(SCNVector3(positionVec))
        let v1 = float3(screenPosOnFarClippingPlane)
        let v2 = float3(cameraPos)
        let rayDirection = simd_normalize(v1 - v2)
        let cameraPosVector = float3(cameraPos)
        return HitTestRay(origin: cameraPosVector, direction: rayDirection)
    }
    
    class func hitFeaturesTestFromOrigin(origin: float3, direction: float3, in view: ARSCNView) -> FeatureHitTestResult? {
        
        guard let features = view.session.currentFrame?.rawFeaturePoints else {
            return nil
        }
        
        let points = features.__points
        
        // Determine the point from the whole point cloud which is closest to the hit test ray.
        var closestFeaturePoint = origin
        var minDistance = Float.greatestFiniteMagnitude
        
        for i in 0...features.__count {
            let feature = points.advanced(by: Int(i))
            let featurePos = feature.pointee
            
            let originVector = origin - featurePos
            let crossProduct = simd_cross(originVector, direction)
            let featureDistanceFromResult = simd_length(crossProduct)
            
            if featureDistanceFromResult < minDistance {
                closestFeaturePoint = featurePos
                minDistance = featureDistanceFromResult
            }
        }
        
        // Compute the point along the ray that is closest to the selected feature.
        let originToFeature = closestFeaturePoint - origin
        let hitTestResult = origin + (direction * simd_dot(direction, originToFeature))
        let hitTestResultDistance = simd_length(hitTestResult - origin)
        
        return FeatureHitTestResult(position: hitTestResult,
                                    distanceToRayOrigin: hitTestResultDistance,
                                    featureHit: closestFeaturePoint,
                                    featureDistanceToHitResult: minDistance)
    }
}


