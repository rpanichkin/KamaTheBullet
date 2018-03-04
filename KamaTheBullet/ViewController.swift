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
import AVFoundation

class ViewController: UIViewController, ARSCNViewDelegate, SCNNodeRendererDelegate {
    @IBOutlet weak var wastedLabel: UILabel!
    
    var timer: Timer?
    private static var myContext = 0
    
    var player: AVAudioPlayer?
    
    @IBOutlet var sceneView: ARSCNView!
    
    var firstHit: ARHitTestResult?
    
    var surfaceDictionary: [UUID: SCNNode] = [:]
    
    var kamaExists = false
    
    var kamaOnScene: SCNNode?
    var kamaItitialPosition: SCNVector3?
    
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
    
    @IBAction func eraseButtonAction(_ sender: Any) {
        if !kamaExists {
            return
        }
        
        kamaOnScene?.removeFromParentNode()
        kamaOnScene = nil
        kamaExists = false
        
        wastedLabel.alpha = 0
        
        timer?.invalidate()
        timer = nil
    }
    
    
    @objc func insetCubeRecognizer(gesture: UIGestureRecognizer) {
        
                // Take the screen space tap coordinates and pass them to the hitTest method on the ARSCNView instance
        let tapPoint = gesture.location(in: sceneView)
        let result = sceneView.hitTest(tapPoint, types: .existingPlaneUsingExtent)
        
        if kamaExists {
            let hits = sceneView.hitTest(tapPoint, options: nil)
            if let node = hits.first?.node {

                if node == kamaOnScene {
                    handleKamaTap()
                }

                return
            }

            return
        }

        
        // If the intersection ray passes through any plane geometry they will be returned, with the planes
        // ordered by distance from the camera
        if result.count == 0 {
            AudioServicesPlayAlertSound(kSystemSoundID_Vibrate)
            return
        }
        
        if (firstHit == nil) {
            firstHit = result[0]
        } else {
            insertKama(secondHit: result[0])
            firstHit = nil
            
            kamaExists = true
        }
    }
    
    func handleKamaTap() {
        let phrases = [
        "shaa", "diavol", "sport", "protivnik"
        ]
        
        let count = UInt32(phrases.count)
        guard count > 0 else { return  }
        
        let idx = Int(arc4random_uniform(count))
        
        let phrase = phrases[idx]
        
        Thread.detachNewThreadSelector(#selector(playSound(assetName:)), toTarget: self, with: phrase)
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
        
        let maxY = max(firstSurface.transform.columns.3.y, secondSurface.transform.columns.3.y)
        
        let center = centerBetweenHits(firstHit, secondHit)
        
        let width = max(CGFloat(distanceBetweenHit(firstHit, secondHit)), 0.3)
        let kamaCube = SCNBox(width: width,
                              height: 0.5 * width,
                              length: 0.1 * width,
                              chamferRadius: 0)
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
        
        let kamaNode = SCNNode(geometry: kamaCube)
        kamaNode.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
        
        kamaNode.physicsBody?.mass = 2.0
        
        
        kamaNode.position = position
        
        kamaNode.runAction(SCNAction.rotateBy(x: 0,
                                              y: CGFloat(angleForTouchPoints(firstHit, secondHit) - Float(Double.pi / 2)),
                                              z: 0,
                                              duration: 0))
        
        kamaNode.rendererDelegate = self
        
        sceneView.scene.rootNode.addChildNode(kamaNode)
        
        kamaOnScene = kamaNode
        
        perform(#selector(startCheckingKamaPosition), with: nil, afterDelay: 0.5)
        
        Thread.detachNewThreadSelector(#selector(playSound(assetName:)), toTarget: self, with: "salam")
    }
    
    func angleForTouchPoints(_ first: ARHitTestResult, _ second: ARHitTestResult) -> Float {
        let x1 = first.worldTransform.columns.3.x
        let x2 = second.worldTransform.columns.3.x
        
        let y1 = first.worldTransform.columns.3.z
        let y2 = second.worldTransform.columns.3.z
        
        let deltaX = x2 - x1
        let deltaY = y2 - y1
        
        return atan2(deltaX, deltaY)
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
    
    func distanceBetweenHit(_ first: ARHitTestResult, _ second: ARHitTestResult) -> Float {
        let x1 = first.worldTransform.columns.3.x
        let x2 = second.worldTransform.columns.3.x
        
        let y1 = first.worldTransform.columns.3.z
        let y2 = second.worldTransform.columns.3.z
        
        return sqrt(pow((x2 - x1), 2) + pow((y2 - y1), 2))
    }
    
    @objc func playSound(assetName: String) {
        if player?.isPlaying ?? false {
            return
        }
        
        guard let url = Bundle.main.url(forResource: assetName, withExtension: "mp3") else {
            return
        }
        
        do {
            player = try AVAudioPlayer(contentsOf: url)
            guard let player = player else { return }
            
            player.prepareToPlay()
            player.play()
            
        } catch let error as NSError {
            print(error.description)
        }
    }
    
    @objc func startCheckingKamaPosition() {
        kamaItitialPosition = kamaOnScene?.presentation.position
        if timer == nil {
            timer = Timer.scheduledTimer(timeInterval: 0.1,
                                         target: self,
                                         selector: #selector(checkKama),
                                         userInfo: nil,
                                         repeats: true)
        }
    }
    
    @objc func checkKama() {
        guard let currentKama = kamaOnScene?.presentation, let initialPosition = kamaItitialPosition else {
            fatalError("no Kama to check")
        }
        
        if initialPosition.x.rounded(toPlaces: 2) != currentKama.position.x.rounded(toPlaces: 2)
            || initialPosition.y.rounded(toPlaces: 2) != currentKama.position.y.rounded(toPlaces: 2)
            || initialPosition.z.rounded(toPlaces: 2) != currentKama.position.z.rounded(toPlaces: 2) {
            kamaFalls()
            timer?.invalidate()
            timer = nil
        }
        
    }
    
    func kamaFalls() {
        wastedLabel.alpha = 1
        
        perform(#selector(removeWastedLabel), with: nil, afterDelay: 2)
    }
    
    @objc func removeWastedLabel()  {
        UIView.animate(withDuration: 2) {
            self.wastedLabel.alpha = 0
        }
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


extension Float {
    /// Rounds the double to decimal places value
    func rounded(toPlaces places:Int) -> Float {
        let divisor = pow(10.0, Float(places))
        return (self * divisor).rounded() / divisor
    }
}
