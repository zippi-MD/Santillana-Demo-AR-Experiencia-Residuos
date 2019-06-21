//
//  ARSceneViewController.swift
//  Santillana-Demo-AR-Experiencia-Residuos
//
//  Created by Alejandro Mendoza on 6/10/19.
//  Copyright © 2019 Alejandro Mendoza. All rights reserved.
//

import UIKit
import ARKit

class ARSceneViewController: UIViewController {
    
    //MARK: Constans
    let contants = ARSceneViewConstans.share

    
    //MARK: Outlets
    @IBOutlet weak var arSceneView: ARSCNView!
    
    //MARK: picker variables and data
    var pickerController: HorizontalPickerViewController!
    
    var message: MessageLabelViewController!
    var alert: AlertMessageViewController!
    var actionButton: ActionButtonViewController!
    var segmentedControl: UISegmentedControl!
    
    //MARK: Detecting Plane Variable
    var showedAlertMessageForDetectingPlane = false
    
    //MARK: Retrieving Information
    var trash: TrashInformation!
    
    //MARK: Showing Trash
    var timeSelected: TimeInformation!
    
    //MARK: Control flow variables
    var actualState: AppState!{
        willSet {
            switch newValue! {
            case .detectingPlanes:
                self.detectingPlanesSetupUI()
            case .retriveInfo:
                self.retriveInfoSetupUI()
            case .displayTrash:
                self.displayTrashSetupUI()
            case .changingSelectedTime:
                self.changeSelectedTimeSetupUI()
            }
        }
    }
    
    var debugPlanes = [SCNNode]()
    var trashNodes = [SCNNode]()
    var tvNode: TVNode?
    var timeInformation: TimeInformation?
    var trashInformation: TrashInformation?
    
    //MARK: life cycle of view controller
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupAR()
        setupUIElements()
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        addUIElementsToView()
        actualState = .detectingPlanes
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let tvNode = self.tvNode else { return }
        let point = touch.location(in: self.arSceneView)
        guard let hit = self.arSceneView.hitTest(point, options: nil).first else { return }
        let node = hit.node
        
        if node.name == "Play" {
            tvNode.playOrPause()
        }
        
        if node.name == "Recargar" {
            tvNode.reset()
        }
    }
    
    //MARK: Actions
    
    func setTrashInformation(){
        if let tvNode = self.tvNode {
            tvNode.removeFromParentNode()
        }
        for trashNode in trashNodes {
            trashNode.removeFromParentNode()
        }
        trashNodes = [SCNNode]()
        
        let totalTrash = calculateTotalTrash(days: timeSelected.timeInDays, trashPerDay: trash.quantity)
        
        let planePercentage = areaDistribution(Planes: debugPlanes)
        
        var trashPerPlane = [Float]()
        
        for percentage in planePercentage {
            trashPerPlane.append(totalTrash * percentage)
        }
        
        var modelsPerPlane = garbageBagsInThePlane(TrashPlanes: trashPerPlane, timeLapse: timeSelected.timeLapse)
        
        let models = ModelNode.share
        let sceneRoot = self.arSceneView.scene.rootNode
        
        for (index, modelsForPlane) in modelsPerPlane.enumerated() {
            let actualPlane = debugPlanes[index]
            for model in TrashModels.allCases{
                let range = Int(modelsForPlane[model] ?? 0)
                if range > 0 {
                    for _ in 0...range {
                        if let node = models.getModelNodeFor(model) {
                            node.position = actualPlane.position
                            node.position.y += 0.3
                            trashNodes.append(node)
                            sceneRoot.addChildNode(node)
                        }
                    }
                }
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {[unowned self] in
            let max = trashPerPlane.index(of: trashPerPlane.max() ?? 0)
            let index = Int(max?.magnitude ?? 0)
            let plane = self.debugPlanes[index]
            self.tvNode = TVNode()
            guard let tvNode = self.tvNode else { return }
            tvNode.position = plane.position
            tvNode.position.y += 0.3
            sceneRoot.addChildNode(tvNode)
        }
    }
    
    func stopPlaneDetection() {
        let config = ARWorldTrackingConfiguration()
        
        self.arSceneView.session.run(config)
        
//        for child in debugPlanes{
//            child.opacity = 0.0
//        }
        self.actualState = .retriveInfo
        
    }
    
    //MARK: Preferences
    
    //MARK: methods
    
    func setupUIElements(){
        setupMassPicker()
        setupMessage()
        setupActionButton()
    }
    
    func addUIElementsToView(){
        addChild(pickerController)
        view.addSubview(pickerController.view)
        pickerController.didMove(toParent: self)
        pickerController.view.isHidden = true
        
        addChild(message)
        view.addSubview(message.view)
        message.didMove(toParent: self)
        message.view.isHidden = true
        
        addChild(actionButton)
        view.addSubview(actionButton.view)
        actionButton.didMove(toParent: self)
        actionButton.view.isHidden = true
    }
    
    func setupMassPicker(){
        let pickerUnit = Mass.kilo
        trash = TrashInformation(quantity: 0, unit: pickerUnit)
        pickerController = HorizontalPickerViewController(values: pickerMassValues[pickerUnit]!, unit: pickerUnit)
        pickerController.delegate = self
    }
    
    func setupTimePicker(){
        let pickerUnit = Time.day
        timeSelected = TimeInformation(timeSelected: 1, timeLapse: pickerUnit)
        pickerController = HorizontalPickerViewController(values: pickerTimeValues[pickerUnit]!, unit: pickerUnit)
        pickerController.delegate = self
    }
    
    func setupSegmentedControl(){
        var items = [String]()
        
        for timeUnit in Time.allCases {
            items.append(getSuffixesFor(timeUnit).1)
        }
        
        segmentedControl = UISegmentedControl(items: items)
        
        segmentedControl.layer.cornerRadius = 10
        segmentedControl.backgroundColor = UIColor.black.withAlphaComponent(6)
        segmentedControl.tintColor = UIColor.white
        
        segmentedControl.selectedSegmentIndex = 0
        
        let pickerCenter = pickerController.view.center
        segmentedControl.center = CGPoint(x: pickerCenter.x, y: pickerCenter.y + pickerController.view.frame.height/2 + segmentedControl.frame.height)
        
        segmentedControl.addTarget(self, action: #selector(indexChanged(_:)), for: .valueChanged)

    }
    
    func addSegmentedControlToView(){
        view.addSubview(segmentedControl)
    }
    
    @objc func indexChanged(_ sender: UISegmentedControl){
        var time: Time = .day
        
        switch sender.selectedSegmentIndex {
        case 0:
            time = .day
        case 1:
            time = .month
        case 2:
            time = .year
        default:
            assert(true, "Missing case for segmented controller")
        }
        pickerController.values = pickerTimeValues[time]
        pickerController.updateUnitTo(time)
    }
    
    func addTimerPickerToView(){
        addChild(pickerController)
        view.addSubview(pickerController.view)
        pickerController.didMove(toParent: self)
    }
    
    func setupMessage(){
        message = MessageLabelViewController(message: " ")
    }
    
    func showAlertMessage(message: String){
        alert = AlertMessageViewController(message: message)
        addChild(alert)
        view.addSubview(alert.view)
        alert.didMove(toParent: self)
    }
    
    func messageForGeneratedTrashIn(value: Int, timeUnit: Time) -> String{
        let suffixes = getSuffixesFor(timeUnit)
        
        let timeSuffix = value == 1 ? suffixes.0 : suffixes.1
        
        return contants.showTrashMessage + "\(value)" + " \(timeSuffix)"
    }
    
    func setupActionButton(){
        actionButton = ActionButtonViewController(text: " ")
        let tap = UITapGestureRecognizer(target: self, action: #selector(actionButtonWasPressed))
        actionButton.view.addGestureRecognizer(tap)
    }
    
    func showActionButtonWithMessage(_ message: String){
        actionButton.buttonText = message
        actionButton.view.isHidden = false
    }
    
    func setupAR(){
        arSceneView.delegate = self
        
        #if DEBUG
        arSceneView.debugOptions = [.showFeaturePoints]
        #endif
        
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = .horizontal
        
        arSceneView.session.run(config)
        
        let scene = SCNScene()
        
        arSceneView.scene = scene
    }
    
    //MARk: Observer methods for state of game
    func detectingPlanesSetupUI(){
        message.message = contants.startScanningMessage
        message.view.isHidden = false
    }
    
    func retriveInfoSetupUI(){
        actionButton.view.isHidden = true
        alert.view.isHidden = true
        
        message.message = contants.retrieveInformationAskTrashData
        pickerController.view.isHidden = false
        
        actionButton.buttonText = contants.endRetrievingInformation
        actionButton.view.isHidden = false
        
    }
    
    func displayTrashSetupUI(){
        
        pickerController.view.isHidden = true
        segmentedControl.isHidden = true
        
        message.message = messageForGeneratedTrashIn(value: timeSelected.timeSelected, timeUnit: timeSelected.timeLapse)
        
        showAlertMessage(message: contants.showTrashAlertMessage)
        alert.view.isHidden = false
        
        actionButton.buttonText = contants.showTrashChangeSelectedTime
        actionButton.view.isHidden = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.actionButton.view.isHidden = false
        }
        
        setTrashInformation()
        
    }
    
    func changeSelectedTimeSetupUI(){
        pickerController.view.isHidden = false
        segmentedControl.isHidden = false
        
        actionButton.buttonText = contants.showTrashViewNewSelectedTime
        actionButton.view.isHidden = false
    }
    
    
    @objc func actionButtonWasPressed(){
        guard let state = actualState else { return }
        switch state {
        case .detectingPlanes:
            stopPlaneDetection()
            actualState = .retriveInfo
            
        case .retriveInfo:
            pickerController.view.isHidden = true
            setupTimePicker()
            addTimerPickerToView()
            setupSegmentedControl()
            addSegmentedControlToView()
            actualState = .displayTrash
            
        case .displayTrash:
            actualState = .changingSelectedTime
            
        case .changingSelectedTime:
            actualState = .displayTrash
            
        default:
            assert(true, "Missing Case")
            
        }
    }
}
