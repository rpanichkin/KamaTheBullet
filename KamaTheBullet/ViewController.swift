//
//  ViewController.swift
//  KamaTheBullet
//
//  Created by Roman Panichkin on 03/03/2018.
//  Copyright © 2018 kama. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate {
    
    @IBOutlet var sceneView: ARSCNView!
    
    var firstHit: ARHitTestResult?
    
    var surfaceDictionary: [UUID: SCNNode] = [:]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        self.sceneView.autoenablesDefaultLighting = true
        self.sceneView.debugOptions  = [.showConstraints, .showLightExtents,
                                        ARSCNDebugOptions.showFeaturePoints,
                                        ARSCNDebugOptions.showWorldOrigin]
        
        self.sceneView.automaticallyUpdatesLighting = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        
        // Run the view's session
        sceneView.session.run(configuration)
        
        sceneView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(insetCubeRecognizer)))
    }
    
    @objc func insetCubeRecognizer(gesture: UIGestureRecognizer) {
        // Take the screen space tap coordinates and pass them to the hitTest method on the ARSCNView instance
        let tapPoint = gesture.location(in: sceneView)
        let result = sceneView.hitTest(tapPoint, types: .existingPlaneUsingExtent)
        
        // If the intersection ray passes through any plane geometry they will be returned, with the planes
        // ordered by distance from the camera
        if result.count == 0 {
            AudioServicesPlayAlertSound(kSystemSoundID_Vibrate)
            return
        }
        
        if (firstHit == nil) {
            firstHit = result[0]
        } else {
            //            insertCube(hitResult: result[0])
            
            insertKama(secondHit: result[0])
            firstHit = nil
        }
    }
    
    func insertKama(secondHit: ARHitTestResult) {
        guard let firstHit = firstHit else {
            return
        }
        
        
        
        guard let firstSurface = firstHit.anchor as? ARPlaneAnchor else {
            return
        }
        guard let secondSurface = secondHit.anchor as? ARPlaneAnchor else {
            return
        }
        
        print(firstSurface.center.y)
        print(secondSurface.center.y)
        let maxY = max(firstSurface.transform.columns.3.y, secondSurface.transform.columns.3.y)
        print(maxY)
        
        let center = centerBetweenHits(firstHit, secondHit)
        
        let kamaCube = SCNBox(width: 1, height: 0.5, length: 0.1, chamferRadius: 0)
        let kamaMaterial = SCNMaterial()
        kamaMaterial.diffuse.contents = #imageLiteral(resourceName: "kama")
        let kamaFlippedMaterial = SCNMaterial()
        kamaFlippedMaterial.diffuse.contents = #imageLiteral(resourceName: "kama_flipped")
        let clearMaterial = SCNMaterial()
        clearMaterial.transparency = 0
        kamaCube.materials = [kamaMaterial, clearMaterial, kamaFlippedMaterial, clearMaterial, clearMaterial, clearMaterial]
        
        let position = SCNVector3(center.0,
                                  maxY + 0.1,
                                  center.1)
        
        //        let cube = SCNBox(width: 0.25, height: 0.1, length: 0.05, chamferRadius: 0)
        
        let kamaNode = SCNNode(geometry: kamaCube)
        kamaNode.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
        
        kamaNode.physicsBody?.mass = 2.0
        
        
        kamaNode.position = position
        
        sceneView.scene.rootNode.addChildNode(kamaNode)
    }
    
    func centerBetweenHits(_ first: ARHitTestResult, _ second: ARHitTestResult) -> (Float, Float) {
        let x1 = first.worldTransform.columns.3.x
        let x2 = second.worldTransform.columns.3.x
        
        let y1 = first.worldTransform.columns.3.z
        let y2 = second.worldTransform.columns.3.z
        
        let x3 = (x1 + x2) / 2
        let y3 = (y1 + y2) / 2
        
        return (x3, y3)
    }
    
    func insertCube(hitResult: ARHitTestResult) {
        
        
        
        
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }
    
    // MARK: - ARSCNViewDelegate
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else {
            return
        }
        
        guard let surface = surfaceDictionary[anchor.identifier] else {
            return
        }
        
        guard let boxGeometry = surface.geometry as? SCNBox else {
            return
        }
        
        boxGeometry.width = CGFloat(planeAnchor.extent.x);
        boxGeometry.length = CGFloat(planeAnchor.extent.z);
        
        surface.position = SCNVector3(planeAnchor.center.x, 0, planeAnchor.center.z)
        
        surface.physicsBody = SCNPhysicsBody(type: .kinematic, shape: SCNPhysicsShape(geometry: boxGeometry, options: nil))
        
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else {
            return
        }
        let height = 0.0001
        let surface = SCNBox(width: CGFloat(planeAnchor.extent.x),
                             height: CGFloat(height),
                             length: CGFloat(planeAnchor.extent.z),
                             chamferRadius: 0)
        let surfaceNode = SCNNode(geometry: surface)
        surfaceNode.position = SCNVector3(0, 0, 0)
        surfaceNode.physicsBody = SCNPhysicsBody(type: .kinematic, shape: SCNPhysicsShape(geometry: surface, options: nil))
        
        let voidMaterial = SCNMaterial()
        voidMaterial.diffuse.contents = UIColor.red.withAlphaComponent(0.4)
        surface.materials = [voidMaterial, voidMaterial, voidMaterial, voidMaterial, voidMaterial, voidMaterial]
        
        
        surfaceDictionary[anchor.identifier] = surfaceNode
        
        node.addChildNode(surfaceNode)
        
    }
    
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
        
        
        return node
    }
    
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
}

