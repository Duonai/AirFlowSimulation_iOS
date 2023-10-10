import UIKit
import QuartzCore
import SceneKit
import ARKit
import AVFoundation
import simd
import Charts
import MBProgressHUD

class MainViewController: UIViewController, ARSCNViewDelegate, UITextFieldDelegate {
    let mainStoryBoard:UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
    var simulationSettingView: SettingsVC!
    
    @IBOutlet var sceneView: ARSCNView!
    private var session: ARSession!
    private var current_view:String = "simulation"
    private var viewPortSize:CGSize!
    private var pointCloudRenderer: PCRenderer!
    private var simulationRenderer: SimulationRenderer!
    private var modelAC: AirConditioner!
    var mtl_library: MTLLibrary!
    var scan_started = false
    
    // reconstruction stack
    @IBOutlet weak var reconstruction_stack: UIStackView!
    @IBOutlet weak var start_button: UIButton!
    @IBOutlet weak var scan_control_button: UIButton!
    @IBOutlet weak var save_image_button: UIButton!
    @IBOutlet weak var load_image_button: UIButton!
    @IBOutlet weak var edit_grid_button: UIButton!
    
    // flow  Stack
    @IBOutlet weak var flow_stack: UIStackView!
    @IBOutlet weak var vector_vis_button: UIButton!
    @IBOutlet weak var particle_vis_button: UIButton!
    @IBOutlet weak var particle2_vis_button: UIButton!
    @IBOutlet weak var occlusion_button: UIButton!
        
    // temperature stack
    @IBOutlet weak var temperature_stack: UIStackView!
    @IBOutlet weak var volume_vis_button: UIButton!
    @IBOutlet weak var isosurface_vis_button: UIButton!
    @IBOutlet weak var pinpont_button: UIButton!
    @IBOutlet weak var surface_button: UIButton!
    
    // clear and pointcloud button
    @IBOutlet weak var rgb_button: UIButton!
    @IBOutlet weak var pointcloud_button: UIButton!
    
    // ac selector
    @IBOutlet weak var sim_setting_button: UIButton!
    
    // ac fan speed
    @IBOutlet weak var ac_speed_stack: UIStackView!
//    @IBOutlet weak var low_button: UIButton!
//    @IBOutlet weak var medium_button: UIButton!
//    @IBOutlet weak var high_button: UIButton!
    @IBOutlet weak var fan_speed_label: UILabel!
    @IBOutlet weak var nowSpeed_label: UILabel!
    @IBOutlet weak var speedUp_button: UIButton!
    @IBOutlet weak var speedDown_button: UIButton!
    
    // ac angle
    @IBOutlet weak var ac_angle_stack: UIStackView!
    @IBOutlet weak var angle_label: UILabel!
//    @IBOutlet weak var level1_button: UIButton!
//    @IBOutlet weak var level2_button: UIButton!
//    @IBOutlet weak var level3_button: UIButton!
//    @IBOutlet weak var swing_button: UIButton!
    @IBOutlet weak var nowAngle_label: UILabel!
    @IBOutlet weak var angleUP_button: UIButton!
    @IBOutlet weak var angleDown_button: UIButton!
    
    // server buttons
    @IBOutlet weak var server_stack: UIStackView!
    @IBOutlet weak var reset_server_button: UIButton!
    @IBOutlet weak var jump_forward_text: UITextField!
    
    // ac control pad
    @IBOutlet weak var left_rotate: UIButton!
    @IBOutlet weak var right_rotate: UIButton!
    @IBOutlet weak var up_button: UIButton!
    @IBOutlet weak var left_button: UIButton!
    @IBOutlet weak var down_button: UIButton!
    @IBOutlet weak var right_button: UIButton!
    @IBOutlet weak var controlpad_label: UILabel!
    @IBOutlet weak var location_lock_button: UIButton!
    
    // number of points - slider UI
    @IBOutlet weak var center_control_stack: UIStackView!
    @IBOutlet weak var plane_slider_label: UILabel!
    @IBOutlet weak var plane_slider: UISlider!
    
    // graph viewer
    @IBOutlet weak var graphViewer: LineChartView!
    @IBOutlet weak var graphXLabel: UILabel!
    @IBOutlet weak var graphYLabel: UILabel!
    @IBOutlet weak var graphToggleButton: UIButton!
    
    @IBOutlet weak var hide_ui_button: UIButton!
    var hide_all_ui: Bool = false
    var showGraph: Bool = false
    
    // simulation grid variables
    var gridSize:Int = 64 //128
    var gridSizeX:Int = 0
    var gridSizeY:Int = 0
    var gridSizeZ:Int = 0
    
    //image detection
    var imageSaveMode:Bool = false
    var imageLoadMode:Bool = false
    var imageDetectMode:Bool = false
    var imageDetected:Bool = false
    var imagePos:simd_float3 = simd_float3(0,0,0)
    var imageBox:SCNNode!
    
    //corner detection
    var cornerDetectMode:Bool = false
    var vertical_plane_arr:[String:plane_geom] = [:]
    var horizontal_plane_arr:[String:plane_geom] = [:]
    var corners_arr:[SCNVector3] = []
    
    var plane_max_y = ("", Float(0.0))
    var dist_tolerance:Float = 0.08
    
    //rotation
    var rotationValue:Float = 0.0
    var rotAxisX:simd_float3 = simd_float3(Float(cos(-0.0)), 0, Float(-sin(-0.0)))
    var rotAxisZ:simd_float3 = simd_float3(Float(sin(-0.0)), 0, Float(cos(-0.0)))
        
    // server-client communication
    var comms: Communication!
    var madeConnection:Bool = false
    var commsLink: Timer?
    var paramLink: Timer?
    var loadLink: Timer?
    var saveLink: Timer?
    var jumpLink: Timer?
    var connectLink: Timer?
    var mutex_lock = NSLock()
    var occLoad:Bool = false
    var graphDontMove: Bool = false
    var progressHUD: MBProgressHUD!
    var angleChange:Bool = true
    var graphInfo: [Float] = []
    
    var connectionCount:Int = 0
    
    var ACfirstInstalled:Bool = false //add
    
    override func viewDidLoad() {
        super.viewDidLoad()
        simulationSettingView = mainStoryBoard.instantiateViewController(withIdentifier: "SettingsVC") as? SettingsVC
        
        // init all necessary objects
        mtl_library = sceneView.device!.makeDefaultLibrary()
        viewPortSize = sceneView.bounds.size
        comms = Communication(gridSize: self.gridSize)
        
        pointCloudRenderer = PCRenderer(session: sceneView.session, metalDevice: sceneView.device!, mtl_library: mtl_library, sceneView: sceneView, gridSize: self.gridSize)
        pointCloudRenderer.drawRectResized(size: viewPortSize)
        pointCloudRenderer.sessionPaused.toggle()
        simulationRenderer = SimulationRenderer(scnview: sceneView, gridSize: self.gridSize, mtl_library: mtl_library, comms: comms)
        simulationRenderer.setupRenderSystem()
        modelAC = AirConditioner()
        NotificationCenter.default.addObserver(self, selector: #selector(updateSettings(_:)), name: Notification.Name(rawValue: "settingsChanged"), object: nil)
        
        // UI modifications
        start_button.layer.cornerRadius = 5
        scan_control_button.layer.cornerRadius = 5
        sim_setting_button.layer.cornerRadius = 5
        reset_server_button.layer.cornerRadius = 5
        edit_grid_button.layer.cornerRadius = 5
//        level1_button.layer.cornerRadius = 5
//        level2_button.layer.cornerRadius = 5
//        level3_button.layer.cornerRadius = 5
//        swing_button.layer.cornerRadius = 5
//        low_button.layer.cornerRadius = 5
//        medium_button.layer.cornerRadius = 5
//        high_button.layer.cornerRadius = 5
        nowSpeed_label.layer.cornerRadius = 5
        nowSpeed_label.layer.masksToBounds = true
        speedUp_button.layer.cornerRadius = 5
        speedDown_button.layer.cornerRadius = 5
        nowAngle_label.layer.cornerRadius = 5
        nowAngle_label.layer.masksToBounds = true
        angleUP_button.layer.cornerRadius = 5
        angleDown_button.layer.cornerRadius = 5
        rgb_button.layer.cornerRadius = 5
        pointcloud_button.layer.cornerRadius = 5
        volume_vis_button.layer.cornerRadius = 5
        vector_vis_button.layer.cornerRadius = 5
        particle_vis_button.layer.cornerRadius = 5
        particle2_vis_button.layer.cornerRadius = 5
        isosurface_vis_button.layer.cornerRadius = 5
        occlusion_button.layer.cornerRadius = 5
        pinpont_button.layer.cornerRadius = 5
        surface_button.layer.cornerRadius = 5
        save_image_button.layer.cornerRadius = 5
        load_image_button.layer.cornerRadius = 5
        plane_slider_label.layer.cornerRadius = 5
        graphToggleButton.layer.cornerRadius = 5
        hide_ui_button.layer.cornerRadius = 5
        graphToggleButton.backgroundColor = UIColor.systemGray
        graphYLabel.transform = CGAffineTransform(rotationAngle: -CGFloat.pi / 2)
        
        plane_slider.isHidden = true
        plane_slider_label.isHidden = true
    
        jump_forward_text.delegate = self
        
        initGraphViewer()
        graphViewer.isHidden = true
        graphXLabel.isHidden = true
        graphYLabel.isHidden = true
        
        pinpont_button.isHidden = true
                
        // for occupancy grid removal
        let pan = UIPanGestureRecognizer(target: self, action: #selector(MainViewController.handlePan(sender:)))
        sceneView.addGestureRecognizer(pan)
                
        // start ARSession
        sceneView.scene = SCNScene()
        initARSession()
        sceneView.delegate = self
        sceneView.showsStatistics = false
        sceneView.autoenablesDefaultLighting = true
        sceneView.allowsCameraControl = false
        sceneView.isMultipleTouchEnabled = true
        UIApplication.shared.isIdleTimerDisabled = true
        
        pointCloudRenderer.viewPaused = true
        updateUI()
        
    }
    
    func initARSession(){
        let ARConfig = ARWorldTrackingConfiguration()
        ARConfig.frameSemantics = .sceneDepth
        ARConfig.worldAlignment = .gravity
        ARConfig.planeDetection = [.horizontal, .vertical]
        ARConfig.isAutoFocusEnabled = false
        
        guard let trackedImages = ARReferenceImage.referenceImages(inGroupNamed: "Photos", bundle: Bundle.main) else {
            print("No images available")
            return
        }
        ARConfig.detectionImages = trackedImages
        ARConfig.maximumNumberOfTrackedImages = 1
        
        sceneView.session.run(ARConfig)
    }
        
    @IBAction func pausePointCloud(_ sender: Any){
        pointCloudRenderer.sessionPaused.toggle()
        
        if pointCloudRenderer.sessionPaused {
            scan_control_button.setTitle("Resume Scan", for: .normal)
        }
        else {
            scan_control_button.setTitle("Pause Scan", for: .normal)
        }
    }
    
    // Called when the line feed button is pressed
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        let userInput = textField.text!
        let strInt = Int(userInput)
        textField.resignFirstResponder()
        textField.text = userInput + " minutes"
    
        progressHUD = MBProgressHUD.showAdded(to: sceneView, animated: true)
        progressHUD.mode = MBProgressHUDMode.indeterminate
        progressHUD.label.text = "Loading..."
        
        jumpLink = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(checkJumpDone), userInfo: nil, repeats: true)
        
        comms.storeTimeLater(time: strInt!)
        return true
    }
    
    @objc func checkJumpDone() {
        if !comms.getJumpSet(){
            progressHUD.hide(animated: true)
            jumpLink?.invalidate()
        }
    }
            
    // MARK: - UI Code
    
    @IBAction func hide_ui_pressed(_ sender: Any){
        hide_all_ui.toggle()
    
        if hide_all_ui {
            reconstruction_stack.isHidden = true
            center_control_stack.isHidden = true
            flow_stack.isHidden = true
            temperature_stack.isHidden = true
            server_stack.isHidden = true
            ac_speed_stack.isHidden = true
            ac_angle_stack.isHidden = true
            center_control_stack.isHidden = true
            
            // ac control
            left_rotate.isHidden = true
            right_rotate.isHidden = true
            up_button.isHidden = true
            right_button.isHidden = true
            left_button.isHidden = true
            down_button.isHidden = true
            location_lock_button.isHidden = true
            controlpad_label.isHidden = true
            
            // individual buttons
            sim_setting_button.isHidden = true
            rgb_button.isHidden = true
            pointcloud_button.isHidden = true
            
            hide_ui_button.setTitle("Show UI", for: .normal)
        }
        else {
            reconstruction_stack.isHidden = false
            center_control_stack.isHidden = false
            flow_stack.isHidden = false
            temperature_stack.isHidden = false
            server_stack.isHidden = false
            ac_speed_stack.isHidden = false
            ac_angle_stack.isHidden = false
            center_control_stack.isHidden = false
            
            // ac control
            left_rotate.isHidden = false
            right_rotate.isHidden = false
            up_button.isHidden = false
            right_button.isHidden = false
            left_button.isHidden = false
            down_button.isHidden = false
            location_lock_button.isHidden = false
            controlpad_label.isHidden = false
            plane_slider.isHidden = true
            plane_slider_label.isHidden = true
            
            // individual buttons
            sim_setting_button.isHidden = false
            rgb_button.isHidden = false
            pointcloud_button.isHidden = false
            pinpont_button.isHidden = true
            hide_ui_button.setTitle("Hide UI", for: .normal)
        }
    }
        
    func updateUI(){
        // ui buttons that dont change in color
        sim_setting_button.backgroundColor = UIColor.systemGray
        reset_server_button.backgroundColor = UIColor.systemGray
        start_button.backgroundColor = UIColor.systemGray
        scan_control_button.backgroundColor = UIColor.systemGray
        save_image_button.backgroundColor = UIColor.systemGray
        load_image_button.backgroundColor = UIColor.systemGray
        edit_grid_button.backgroundColor = UIColor.systemGray
        hide_ui_button.backgroundColor = UIColor.systemGray
        speedUp_button.backgroundColor = UIColor.systemGray
        speedDown_button.backgroundColor = UIColor.systemGray
        angleUP_button.backgroundColor = UIColor.systemGray
        angleDown_button.backgroundColor = UIColor.systemGray
        
        if simulationRenderer.currentVisualization == "pointcloud" {
            edit_grid_button.backgroundColor = UIColor.systemGray
            rgb_button.backgroundColor = UIColor.systemGray
            pointcloud_button.backgroundColor = UIColor.systemBlue
            volume_vis_button.backgroundColor = UIColor.systemGray
            vector_vis_button.backgroundColor = UIColor.systemGray
            particle_vis_button.backgroundColor = UIColor.systemGray
            particle2_vis_button.backgroundColor = UIColor.systemGray
            isosurface_vis_button.backgroundColor = UIColor.systemGray
            pinpont_button.backgroundColor = UIColor.systemGray
            surface_button.backgroundColor = UIColor.systemGray
            graphViewer.isHidden = true
            graphYLabel.isHidden = true
            graphXLabel.isHidden = true
            graphToggleButton.isHidden = true
            showGraph = false
            
            simulationRenderer.resetVisualization()
            pointCloudRenderer.viewPaused = false
            sceneView.scene = SCNScene()
            sceneView.scene.background.contents = UIColor.black
            
            // maintain ac model
            for node_ in modelAC.acNodeArr {
                sceneView.scene.rootNode.addChildNode(node_)
            }
            hideAC()
        }
        else if simulationRenderer.currentVisualization == "RGB" {
            pointCloudRenderer.viewPaused = true
            simulationRenderer.resetVisualization()
            sceneView.scene = SCNScene()
            
            // re-add ac mode
            for node_ in modelAC.acNodeArr {
                sceneView.scene.rootNode.addChildNode(node_)
            }
            showAC()
        }
        else {
            pointCloudRenderer.viewPaused = true
        }
        if ACfirstInstalled{
            if modelAC.currentAngle == 1 && angleChange{
                //            level1_button.backgroundColor = UIColor.systemBlue
                //            level2_button.backgroundColor = UIColor.systemGray
                //            level3_button.backgroundColor = UIColor.systemGray
                //            swing_button.backgroundColor = UIColor.systemGray
                modelAC.blade_timer?.invalidate()
                
                if modelAC.currentACModel == "ceiling" {
                    let new_angle = -45.0 - modelAC.current_ceiling_angle
                    modelAC.blade_x1.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: new_angle), axis: simd_float3(1,0,0)))
                    modelAC.blade_x2.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: new_angle), axis: simd_float3(1,0,0)))
                    modelAC.blade_z1.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: new_angle), axis: simd_float3(1,0,0)))
                    modelAC.blade_z2.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: new_angle), axis: simd_float3(1,0,0)))
                    modelAC.current_ceiling_angle = -45.0
                    nowAngle_label.text = "Power"
                }
                else if modelAC.currentACModel == "stand" {
                    let new_angle = -30.0 - modelAC.current_ceiling_angle
                    modelAC.stdblade1.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: new_angle), axis: simd_float3(0,0,1)))
                    modelAC.stdblade2.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: new_angle), axis: simd_float3(0,0,1)))
                    modelAC.stdblade3.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: new_angle), axis: simd_float3(0,0,1)))
                    modelAC.stdblade4.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: new_angle), axis: simd_float3(0,0,1)))
                    modelAC.current_ceiling_angle = -30.0
                    nowAngle_label.text = "Up"
                }
                else if modelAC.currentACModel == "tower" {
                    let new_angle = -30.0 - modelAC.current_ceiling_angle
                    nowAngle_label.text = "WideCare"
                }
                else if modelAC.currentACModel == "wall" {
                    let new_angle = 30.0 - modelAC.current_ceiling_angle
                    modelAC.wallblade.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: new_angle), axis: simd_float3(1,0,0)))
                    modelAC.current_ceiling_angle = 30.0
                    nowAngle_label.text = "Up"
                }

            }
            
            else if modelAC.currentAngle == 2 && angleChange{
                //            level1_button.backgroundColor = UIColor.systemGray
                //            level2_button.backgroundColor = UIColor.systemBlue
                //            level3_button.backgroundColor = UIColor.systemGray
                //            swing_button.backgroundColor = UIColor.systemGray
                modelAC.blade_timer?.invalidate()
                
                if modelAC.currentACModel == "ceiling" {
                    let new_angle = -45.0 - modelAC.current_ceiling_angle
                    modelAC.blade_x1.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: new_angle), axis: simd_float3(1,0,0)))
                    modelAC.blade_x2.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: new_angle), axis: simd_float3(1,0,0)))
                    modelAC.blade_z1.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: new_angle), axis: simd_float3(1,0,0)))
                    modelAC.blade_z2.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: new_angle), axis: simd_float3(1,0,0)))
                    modelAC.current_ceiling_angle = -45.0
                    nowAngle_label.text = "Forest"
                }
                else if modelAC.currentACModel == "stand" {
                    let new_angle = -modelAC.current_ceiling_angle
                    modelAC.stdblade1.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: new_angle), axis: simd_float3(0,0,1)))
                    modelAC.stdblade2.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: new_angle), axis: simd_float3(0,0,1)))
                    modelAC.stdblade3.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: new_angle), axis: simd_float3(0,0,1)))
                    modelAC.stdblade4.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: new_angle), axis: simd_float3(0,0,1)))
                    modelAC.current_ceiling_angle = 0.0
                    nowAngle_label.text = "Mid"
                }
                else if modelAC.currentACModel == "tower" {
                    let new_angle = -modelAC.current_ceiling_angle
                    nowAngle_label.text = "SpaceDiv"
                }
                else if modelAC.currentACModel == "wall" {
                    let new_angle = 55.0 - modelAC.current_ceiling_angle
                    modelAC.wallblade.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: new_angle), axis: simd_float3(1,0,0)))
                    modelAC.current_ceiling_angle = 55.0
                    nowAngle_label.text = "Mid"
                }
            }
            
            else if modelAC.currentAngle == 3 && angleChange{
                //            level1_button.backgroundColor = UIColor.systemGray
                //            level2_button.backgroundColor = UIColor.systemGray
                //            level3_button.backgroundColor = UIColor.systemBlue
                //            swing_button.backgroundColor = UIColor.systemGray
                modelAC.blade_timer?.invalidate()
                
                if modelAC.currentACModel == "ceiling" {
                    let new_angle = -45.0 - modelAC.current_ceiling_angle
                    modelAC.blade_x1.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: new_angle), axis: simd_float3(1,0,0)))
                    modelAC.blade_x2.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: new_angle), axis: simd_float3(1,0,0)))
                    modelAC.blade_z1.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: new_angle), axis: simd_float3(1,0,0)))
                    modelAC.blade_z2.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: new_angle), axis: simd_float3(1,0,0)))
                    modelAC.current_ceiling_angle = -45.0
                    nowAngle_label.text = "Auto"
                }
                else if modelAC.currentACModel == "stand" {
                    let new_angle = 30.0 - modelAC.current_ceiling_angle
                    modelAC.stdblade1.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: new_angle), axis: simd_float3(0,0,1)))
                    modelAC.stdblade2.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: new_angle), axis: simd_float3(0,0,1)))
                    modelAC.stdblade3.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: new_angle), axis: simd_float3(0,0,1)))
                    modelAC.stdblade4.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: new_angle), axis: simd_float3(0,0,1)))
                    modelAC.current_ceiling_angle = 30.0
                }
                else if modelAC.currentACModel == "tower" {
                    let new_angle = 30.0 - modelAC.current_ceiling_angle
                    nowAngle_label.text = "4X"
                }
                else if modelAC.currentACModel == "wall" {
                    let new_angle = 80.0 - modelAC.current_ceiling_angle
                    modelAC.wallblade.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: new_angle), axis: simd_float3(1,0,0)))
                    modelAC.current_ceiling_angle = 80.0
                    nowAngle_label.text = "Down"
                }
            }
            
            else if modelAC.currentAngle == 4 && angleChange{
                if modelAC.currentACModel == "ceiling" {
                    nowAngle_label.text = "AirGuide"
                }
                else if modelAC.currentACModel == "stand" || modelAC.currentACModel == "wall" {
                    modelAC.start_blade_swing()
                    nowAngle_label.text = "Swing"
                }
                else if modelAC.currentACModel == "tower" {
                    nowAngle_label.text = "Left"
                }
            }
            
            else if modelAC.currentAngle == 5 && angleChange{
                if modelAC.currentACModel == "ceiling" {
                    nowAngle_label.text = "HighCeiling"
                }
                else if modelAC.currentACModel == "tower" {
                    nowAngle_label.text = "Right"
                }
            }
            
            else if modelAC.currentAngle == 6 && angleChange{
                if modelAC.currentACModel == "tower" {
                    nowAngle_label.text = "Div_Left"
                }
            }
            
            else if modelAC.currentAngle == 7 && angleChange{
                if modelAC.currentACModel == "tower" {
                    nowAngle_label.text = "Div_Right"
                }
            }
            
            if modelAC.currentSpeed == 1 {
                nowSpeed_label.text = "1"
            }
            else if modelAC.currentSpeed == 2 {
                nowSpeed_label.text = "2"
            }
            else if modelAC.currentSpeed == 3 {
                nowSpeed_label.text = "3"
            }
            else if modelAC.currentSpeed == 4 {
                nowSpeed_label.text = "4"
            }
            else if modelAC.currentSpeed == 5 {
                nowSpeed_label.text = "5"
            }
        }
        if simulationRenderer.currentVisualization == "RGB" {
            edit_grid_button.backgroundColor = UIColor.systemGray
            rgb_button.backgroundColor = UIColor.systemBlue
            pointcloud_button.backgroundColor = UIColor.systemGray
            volume_vis_button.backgroundColor = UIColor.systemGray
            vector_vis_button.backgroundColor = UIColor.systemGray
            particle_vis_button.backgroundColor = UIColor.systemGray
            particle2_vis_button.backgroundColor = UIColor.systemGray
            isosurface_vis_button.backgroundColor = UIColor.systemGray
            pinpont_button.backgroundColor = UIColor.systemGray
            surface_button.backgroundColor = UIColor.systemGray
            graphViewer.isHidden = true
            graphYLabel.isHidden = true
            graphXLabel.isHidden = true
            graphToggleButton.isHidden = true
            showGraph = false
            
        }
        
        else if simulationRenderer.currentVisualization == "Volume" {
            edit_grid_button.backgroundColor = UIColor.systemGray
            rgb_button.backgroundColor = UIColor.systemGray
            pointcloud_button.backgroundColor = UIColor.systemGray
            volume_vis_button.backgroundColor = UIColor.systemBlue
            vector_vis_button.backgroundColor = UIColor.systemGray
            particle_vis_button.backgroundColor = UIColor.systemGray
            particle2_vis_button.backgroundColor = UIColor.systemGray
            isosurface_vis_button.backgroundColor = UIColor.systemGray
            pinpont_button.backgroundColor = UIColor.systemGray
            surface_button.backgroundColor = UIColor.systemGray
            graphViewer.isHidden = true
            graphYLabel.isHidden = true
            graphXLabel.isHidden = true
            graphToggleButton.isHidden = true
            showGraph = false
            
        }
        
        else if simulationRenderer.currentVisualization == "Vector" {
            edit_grid_button.backgroundColor = UIColor.systemGray
            rgb_button.backgroundColor = UIColor.systemGray
            pointcloud_button.backgroundColor = UIColor.systemGray
            volume_vis_button.backgroundColor = UIColor.systemGray
            vector_vis_button.backgroundColor = UIColor.systemBlue
            particle_vis_button.backgroundColor = UIColor.systemGray
            particle2_vis_button.backgroundColor = UIColor.systemGray
            isosurface_vis_button.backgroundColor = UIColor.systemGray
            pinpont_button.backgroundColor = UIColor.systemGray
            surface_button.backgroundColor = UIColor.systemGray
            graphViewer.isHidden = true
            graphYLabel.isHidden = true
            graphXLabel.isHidden = true
            graphToggleButton.isHidden = true
            showGraph = false
        }
        
        else if simulationRenderer.currentVisualization == "Particle" {
            edit_grid_button.backgroundColor = UIColor.systemGray
            rgb_button.backgroundColor = UIColor.systemGray
            pointcloud_button.backgroundColor = UIColor.systemGray
            volume_vis_button.backgroundColor = UIColor.systemGray
            vector_vis_button.backgroundColor = UIColor.systemGray
            particle_vis_button.backgroundColor = UIColor.systemBlue
            particle2_vis_button.backgroundColor = UIColor.systemGray
            isosurface_vis_button.backgroundColor = UIColor.systemGray
            pinpont_button.backgroundColor = UIColor.systemGray
            surface_button.backgroundColor = UIColor.systemGray
            graphViewer.isHidden = true
            graphYLabel.isHidden = true
            graphXLabel.isHidden = true
            graphToggleButton.isHidden = true
            showGraph = false
        }
        else if simulationRenderer.currentVisualization == "Dense Particle" {
            edit_grid_button.backgroundColor = UIColor.systemGray
            rgb_button.backgroundColor = UIColor.systemGray
            pointcloud_button.backgroundColor = UIColor.systemGray
            volume_vis_button.backgroundColor = UIColor.systemGray
            vector_vis_button.backgroundColor = UIColor.systemGray
            particle_vis_button.backgroundColor = UIColor.systemGray
            particle2_vis_button.backgroundColor = UIColor.systemBlue
            isosurface_vis_button.backgroundColor = UIColor.systemGray
            pinpont_button.backgroundColor = UIColor.systemGray
            surface_button.backgroundColor = UIColor.systemGray
            graphViewer.isHidden = true
            graphYLabel.isHidden = true
            graphXLabel.isHidden = true
            graphToggleButton.isHidden = true
            showGraph = false
        }
        
        else if simulationRenderer.currentVisualization == "Isosurface" {
            edit_grid_button.backgroundColor = UIColor.systemGray
            rgb_button.backgroundColor = UIColor.systemGray
            pointcloud_button.backgroundColor = UIColor.systemGray
            volume_vis_button.backgroundColor = UIColor.systemGray
            vector_vis_button.backgroundColor = UIColor.systemGray
            particle_vis_button.backgroundColor = UIColor.systemGray
            particle2_vis_button.backgroundColor = UIColor.systemGray
            isosurface_vis_button.backgroundColor = UIColor.systemBlue
            pinpont_button.backgroundColor = UIColor.systemGray
            surface_button.backgroundColor = UIColor.systemGray
            graphViewer.isHidden = true
            graphYLabel.isHidden = true
            graphXLabel.isHidden = true
            graphToggleButton.isHidden = true
            showGraph = false
        }
        
        else if simulationRenderer.currentVisualization == "Flow and Volume" {
            edit_grid_button.backgroundColor = UIColor.systemGray
            rgb_button.backgroundColor = UIColor.systemGray
            pointcloud_button.backgroundColor = UIColor.systemGray
            volume_vis_button.backgroundColor = UIColor.systemBlue
            vector_vis_button.backgroundColor = UIColor.systemBlue
            particle_vis_button.backgroundColor = UIColor.systemGray
            particle2_vis_button.backgroundColor = UIColor.systemGray
            isosurface_vis_button.backgroundColor = UIColor.systemGray
            pinpont_button.backgroundColor = UIColor.systemGray
            surface_button.backgroundColor = UIColor.systemGray
            graphViewer.isHidden = true
            graphYLabel.isHidden = true
            graphXLabel.isHidden = true
            graphToggleButton.isHidden = true
            showGraph = false
        }
        else if simulationRenderer.currentVisualization == "Surface" {
            edit_grid_button.backgroundColor = UIColor.systemGray
            rgb_button.backgroundColor = UIColor.systemGray
            pointcloud_button.backgroundColor = UIColor.systemGray
            volume_vis_button.backgroundColor = UIColor.systemGray
            vector_vis_button.backgroundColor = UIColor.systemGray
            particle_vis_button.backgroundColor = UIColor.systemGray
            particle2_vis_button.backgroundColor = UIColor.systemGray
            isosurface_vis_button.backgroundColor = UIColor.systemGray
            pinpont_button.backgroundColor = UIColor.systemGray
            surface_button.backgroundColor = UIColor.systemBlue
            graphViewer.isHidden = true
            graphYLabel.isHidden = true
            graphXLabel.isHidden = true
            graphToggleButton.isHidden = true
            showGraph = false
        }
        else if simulationRenderer.currentVisualization == "OccupancyGrid" {
            edit_grid_button.backgroundColor = UIColor.systemBlue
            rgb_button.backgroundColor = UIColor.systemGray
            pointcloud_button.backgroundColor = UIColor.systemGray
            volume_vis_button.backgroundColor = UIColor.systemGray
            vector_vis_button.backgroundColor = UIColor.systemGray
            particle_vis_button.backgroundColor = UIColor.systemGray
            particle2_vis_button.backgroundColor = UIColor.systemGray
            isosurface_vis_button.backgroundColor = UIColor.systemGray
            pinpont_button.backgroundColor = UIColor.systemGray
            surface_button.backgroundColor = UIColor.systemGray
            graphViewer.isHidden = true
            graphYLabel.isHidden = true
            graphXLabel.isHidden = true
            graphToggleButton.isHidden = true
            showGraph = false
            
        }
        else if simulationRenderer.currentVisualization == "Pinpoint" {
            edit_grid_button.backgroundColor = UIColor.systemGray
            rgb_button.backgroundColor = UIColor.systemGray
            pointcloud_button.backgroundColor = UIColor.systemGray
            volume_vis_button.backgroundColor = UIColor.systemGray
            vector_vis_button.backgroundColor = UIColor.systemGray
            particle_vis_button.backgroundColor = UIColor.systemGray
            particle2_vis_button.backgroundColor = UIColor.systemGray
            isosurface_vis_button.backgroundColor = UIColor.systemGray
            pinpont_button.backgroundColor = UIColor.systemBlue
            surface_button.backgroundColor = UIColor.systemGray
            graphToggleButton.isHidden = false
            showGraph = false
        
        }
        
        if simulationRenderer.complete_occlude {
            occlusion_button.backgroundColor = UIColor.systemBlue
        } else { occlusion_button.backgroundColor = UIColor.systemGray }
    }
    
    // MARK: - IBAction Outlets
    
    @IBAction func left_rotate_pressed(_ sender: Any){
        if (modelAC.currentACModel == "tower" && modelAC.acNodeArr.count != 0)
        {
            modelAC.acOrientation += 1
            if (modelAC.acOrientation > 7)
            {
                modelAC.acOrientation = 0
            }
            comms.updateACDirection(dir: modelAC.acOrientation)
            comms.updateACReset()
        }
        modelAC.left_rotate_pressed()
    }
    
    @IBAction func right_rotate_pressed(_ sender: Any){
        if (modelAC.currentACModel == "tower" && modelAC.acNodeArr.count != 0)
        {
            modelAC.acOrientation -= 1
            if (modelAC.acOrientation < 0)
            {
                modelAC.acOrientation = 7
            }
            comms.updateACDirection(dir: modelAC.acOrientation)
            comms.updateACReset()
        }
        modelAC.right_rotate_pressed()
    }
    
    @IBAction func up_pressed(_ sender: Any){
        modelAC.up_pressed()
    }
    
    @IBAction func up_released(_ sender: Any){
        modelAC.up_dir_timer?.invalidate()
    }
    
    @IBAction func left_pressed(_ sender: Any){
        modelAC.left_pressed()
    }
    
    @IBAction func left_released(_ sender: Any){
        modelAC.left_dir_timer?.invalidate()
    }
    
    @IBAction func down_pressed(_ sender: Any){
        modelAC.down_pressed()
    }
    
    @IBAction func down_released(_ sender: Any){
        modelAC.down_dir_timer?.invalidate()
    }
    
    @IBAction func right_pressed(_ sender: Any){
        modelAC.right_pressed()
    }
    
    @IBAction func right_released(_ sender: Any){
        modelAC.right_dir_timer?.invalidate()
    }
    
    // update ac location
    @IBAction func ac_location_pressed(_ sender: Any) {
        if modelAC.acNodeArr.count != 0 {
            let rotACPosition = simd_float3(Float(cos(rotationValue)) * modelAC.currentPosition.x + Float(sin(rotationValue)) * modelAC.currentPosition.z,
                modelAC.currentPosition.y,
                -Float(sin(rotationValue)) * modelAC.currentPosition.x + Float(cos(rotationValue)) * modelAC.currentPosition.z)
           
            var i = Int(Float(gridSizeX)*(rotACPosition.x - pointCloudRenderer.boundary_points[1])/pointCloudRenderer.gridLengthX)
            var j = Int(Float(gridSizeY)*(rotACPosition.y - pointCloudRenderer.pc_min_y)/pointCloudRenderer.gridLengthY)
            var k = Int(Float(gridSizeZ)*(rotACPosition.z - pointCloudRenderer.boundary_points[3])/pointCloudRenderer.gridLengthZ)
            
            if i >= gridSizeX {
                i = gridSizeX-1
            }
            else if i < 0 {
                i = 0
            }
            if j >= gridSizeY {
                j = gridSizeY-1
            }
            else if j < 0 {
                j = 0
            }
            if k >= gridSizeZ {
                k = gridSizeZ-1
            }
            else if k < 0 {
                k = 0
            }
            // modelAC.currentPosition = simd_float3(node.position.x, node.position.y, node.position.z)
            
            if modelAC.currentACModel == "stand" {
                j += 16
                
                if modelAC.acOrientation == 4 { //"plus_x" {
                    i += 1
                }
                else if modelAC.acOrientation == 0 { //"minus_x" {
                    i -= 1
                }
                else if modelAC.acOrientation == 2 { //"plus_z" {
                    k += 1
                }
                else if modelAC.acOrientation == 6 {//"minus_z" {
                    k -= 1
                }
            }
            comms.updateACPosition(x:i, y: j, z: k)
        }
    }
        
    @IBAction func reset_server_simulation_pressed(_ sender: Any){
//        reset_server_button.setTitle("Reset Simulation", for: .normal)
        comms.updateACReset()
    }
    
    @IBAction func angleUp_selected(_ sender: Any){
        modelAC.currentAngle += 1
        if modelAC.currentACModel == "ceiling" && modelAC.currentAngle > 5 {
            modelAC.currentAngle = 1
        }
        else if modelAC.currentACModel == "wall" || modelAC.currentACModel == "stand" && modelAC.currentAngle > 4 {
            modelAC.currentAngle = 1
        }
        else if modelAC.currentACModel == "tower" && modelAC.currentAngle > 7 {
            modelAC.currentAngle = 1
        }
        comms.updateACVentLevel(level: modelAC.currentAngle)
        simulationRenderer.acAngle = modelAC.currentAngle
        angleChange = true
        updateUI()
    }
    
    @IBAction func angleDown_selected(_ sender: Any){
        modelAC.currentAngle -= 1
        if modelAC.currentACModel == "ceiling" && modelAC.currentAngle < 1 {
            modelAC.currentAngle = 5
        }
        else if modelAC.currentACModel == "wall" || modelAC.currentACModel == "stand" && modelAC.currentAngle < 1 {
            modelAC.currentAngle = 4
        }
        else if modelAC.currentACModel == "tower" && modelAC.currentAngle < 1 {
            modelAC.currentAngle = 7
        }
        comms.updateACVentLevel(level: modelAC.currentAngle)
        simulationRenderer.acAngle = modelAC.currentAngle
        angleChange = true
        updateUI()
    }
    
    @IBAction func speedUp_selected(_ sender: Any){
        modelAC.currentSpeed += 1
        if modelAC.currentACModel == "tower" && modelAC.currentSpeed > 5 {
            modelAC.currentSpeed = 1
        }
        else if modelAC.currentACModel != "tower" && modelAC.currentSpeed > 3 {
            modelAC.currentSpeed = 1
        }
        comms.updateACVentSpeed(speed: modelAC.currentSpeed)
        updateUI()
    }
    
    @IBAction func speedDown_selected(_ sender: Any){
        modelAC.currentSpeed -= 1
        if modelAC.currentACModel == "tower" && modelAC.currentSpeed < 1 {
            modelAC.currentSpeed = 5
        }
        else if modelAC.currentACModel != "tower" && modelAC.currentSpeed < 1 {
            modelAC.currentSpeed = 3
        }
        comms.updateACVentSpeed(speed: modelAC.currentSpeed)
        updateUI()
    }
        
    @IBAction func session_control(_ sender: Any) {
        if scan_started {
            calculate_grid()
//            imageSaveMode = false
//            imageLoadMode = false
            imageDetectMode = false
            cornerDetectMode = false
//            let today = Date()
////            let hour = (Calendar.current.component(.hour, from: today))
////            let min = (Calendar.current.component(.minute, from: today))
////            let second = (Calendar.current.component(.second, from: today))
//            let formatter = DateFormatter()
//            formatter.dateFormat = "HH\tmm\tss\tSSSS\t"
//            scanEnd = formatter.string(from: today) + "scan_end\n"
//            print(scanEnd)
//            //scanBegin = "\(hour)\t\(min)\t\(second)\tscan_begin\n"
        }
        else {
            scan_started = true
            cornerDetectMode = true
            pointCloudRenderer.sessionPaused.toggle()
            start_button.setTitle("Create Grid", for: .normal)
//            let today = Date()
////            let hour = (Calendar.current.component(.hour, from: today))
////            let min = (Calendar.current.component(.minute, from: today))
////            let second = (Calendar.current.component(.second, from: today))
//            let formatter = DateFormatter()
//            formatter.dateFormat = "HH\tmm\tss\tSSSS\t"
//            scanBegin = formatter.string(from: today) + "scan_begin\n"
//            print(scanBegin)
//            //scanBegin = "\(hour)\t\(min)\t\(second)\tscan_begin\n"
        }
    }
        
    @objc func data_move_for_load() {
        if (comms.getLoadDone()) {
            madeConnection = true
            
            pointCloudRenderer.gridSizeX = comms.getGridSize()[0]
            pointCloudRenderer.gridSizeY = comms.getGridSize()[1]
            pointCloudRenderer.gridSizeZ = comms.getGridSize()[2]
            pointCloudRenderer.gridLengthX = comms.getRoomSize()[0]
            pointCloudRenderer.gridLengthY = comms.getRoomSize()[1]
            pointCloudRenderer.gridLengthZ = comms.getRoomSize()[2]
            
            pointCloudRenderer.boolGrid = comms.getOccupancyGrid()
            pointCloudRenderer.loadGrid(px:comms.getDistance()[0], mx:comms.getDistance()[1],
                                        py:comms.getDistance()[2], my:comms.getDistance()[3])
            
            
            if(!occLoad)
            {
                commsLink = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(updateOccupancyGrid), userInfo: nil, repeats: true)
                occLoad = true
            }
             
            simulationRenderer.gridArray = pointCloudRenderer.gridArray
            simulationRenderer.boundary_points = pointCloudRenderer.boundary_points
            simulationRenderer.pc_max_y = pointCloudRenderer.pc_max_y
            simulationRenderer.pc_min_y = pointCloudRenderer.pc_min_y
            simulationRenderer.gridSizeX = pointCloudRenderer.gridSizeX
            simulationRenderer.gridSizeY = pointCloudRenderer.gridSizeY
            simulationRenderer.gridSizeZ = pointCloudRenderer.gridSizeZ
            
            gridSizeX = pointCloudRenderer.gridSizeX
            gridSizeY = pointCloudRenderer.gridSizeY
            gridSizeZ = pointCloudRenderer.gridSizeZ
            
            simulationRenderer.calc_room_dimensions()
            loadLink?.invalidate()
            imageBox.removeFromParentNode()
            
            let alert = UIAlertController(title: "", message: "Occupancy grid has been loaded.", preferredStyle: UIAlertController.Style.alert)
            self.present(alert, animated: true, completion: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                alert.dismiss(animated: true, completion: nil)
            }
        }
        
        connectionCount += 1
        
        if connectionCount >= 5 {
            print("server off")
            
            let alert = UIAlertController(title: "", message: "Server is not available", preferredStyle: UIAlertController.Style.alert)
            self.present(alert, animated: true, completion: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                alert.dismiss(animated: true, completion: nil)
            }
            
            loadLink?.invalidate()
            connectionCount = 0
        }
    }
    
    @objc func data_move_for_save() {
        if (comms.getConnectDone()) {
            madeConnection = true
            
            commsLink = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(updateOccupancyGrid), userInfo: nil, repeats: true)
            
            //print(connectionCount)
            saveLink?.invalidate()
            
            let alert = UIAlertController(title: "", message: "Occupancy grid has been saved.", preferredStyle: UIAlertController.Style.alert)
            self.present(alert, animated: true, completion: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                alert.dismiss(animated: true, completion: nil)
            }
            
            imageSaveMode = false
            imageDetectMode = false
            imageBox.removeFromParentNode()
        }
        connectionCount += 1
        
        if connectionCount >= 3 {
            print("server off")
            
            let alert = UIAlertController(title: "", message: "Server is not available", preferredStyle: UIAlertController.Style.alert)
            self.present(alert, animated: true, completion: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                alert.dismiss(animated: true, completion: nil)
            }
            
            saveLink?.invalidate()
            connectionCount = 0
        }
    }
            
    func calculate_grid() {
        if imageLoadMode && imageDetected {
            comms.setRequestBIMType()
            comms.storeAddr(address: "")
            comms.setRoomNum(RoomNum: 2)
            if !madeConnection {
                comms.makeConnection()
                
                loadLink = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(data_move_for_load), userInfo: nil, repeats: true)
            }
        }
        else if imageSaveMode && imageDetected {
            pointCloudRenderer.sessionPaused = true
            
            if (!pointCloudRenderer.checkSideline()) {
                let alert = UIAlertController(title: "", message: "Scan Error alert, Please scan room again", preferredStyle: UIAlertController.Style.alert)
                self.present(alert, animated: true, completion: nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    alert.dismiss(animated: true, completion: nil)
                }
            }

            simulationRenderer.gridArray = pointCloudRenderer.gridArray
            simulationRenderer.boundary_points = pointCloudRenderer.boundary_points
            simulationRenderer.pc_max_y = pointCloudRenderer.pc_max_y
            simulationRenderer.pc_min_y = pointCloudRenderer.pc_min_y
        
            simulationRenderer.gridSizeX = pointCloudRenderer.gridSizeX
            simulationRenderer.gridSizeY = pointCloudRenderer.gridSizeY
            simulationRenderer.gridSizeZ = pointCloudRenderer.gridSizeZ
            
            gridSizeX = pointCloudRenderer.gridSizeX
            gridSizeY = pointCloudRenderer.gridSizeY
            gridSizeZ = pointCloudRenderer.gridSizeZ
            
            simulationRenderer.calc_room_dimensions()
            
            gridSizeX = pointCloudRenderer.gridSizeX
            gridSizeY = pointCloudRenderer.gridSizeY
            gridSizeZ = pointCloudRenderer.gridSizeZ
            
            comms.initializeForBIM(gridSizeX: pointCloudRenderer.gridSizeX, gridSizeY: pointCloudRenderer.gridSizeY, gridSizeZ: pointCloudRenderer.gridSizeZ,
                                   distXL: pointCloudRenderer.mxLen, distXR: pointCloudRenderer.pxLen,
                                   distYU: pointCloudRenderer.pyLen, distYD: pointCloudRenderer.myLen,
                                   roomSizeX: pointCloudRenderer.gridLengthX, roomSizeY: pointCloudRenderer.gridLengthY, roomSizeZ: pointCloudRenderer.gridLengthZ, roomNum: 2)
            updateOccupancyGrid()
            comms.storeAddr(address: "")
            if !madeConnection {
                comms.makeConnection()
                
                saveLink = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(data_move_for_save), userInfo: nil, repeats: true)
            }
        }
        else {
            //pointCloudRenderer.sessionPaused = true
            calcCornerRot()
            if (!pointCloudRenderer.checkSideline()) {
                let alert = UIAlertController(title: "", message: "Scan Error alert, Please scan room again", preferredStyle: UIAlertController.Style.alert)
                self.present(alert, animated: true, completion: nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    alert.dismiss(animated: true, completion: nil)
                }
            }
            simulationRenderer.gridArray = pointCloudRenderer.gridArray
            simulationRenderer.boundary_points = pointCloudRenderer.boundary_points
            simulationRenderer.pc_max_y = pointCloudRenderer.pc_max_y
            simulationRenderer.pc_min_y = pointCloudRenderer.pc_min_y
        
            simulationRenderer.gridSizeX = pointCloudRenderer.gridSizeX
            simulationRenderer.gridSizeY = pointCloudRenderer.gridSizeY
            simulationRenderer.gridSizeZ = pointCloudRenderer.gridSizeZ
            
            gridSizeX = pointCloudRenderer.gridSizeX
            gridSizeY = pointCloudRenderer.gridSizeY
            gridSizeZ = pointCloudRenderer.gridSizeZ
            
            simulationRenderer.calc_room_dimensions()
            //pointCloudRenderer.sessionPaused = false
            
            let alert = UIAlertController(title: "", message: "Occupancy grid has been created.", preferredStyle: UIAlertController.Style.alert)
            self.present(alert, animated: true, completion: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                alert.dismiss(animated: true, completion: nil)
            }
        }
        
        if paramLink == nil {
            paramLink = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(updateGridParameters), userInfo: nil, repeats: true)
        }
    }

    
    @IBAction func plane_distance_changed(_ sender: Any){
        if simulationRenderer.currentVisualization == "Volume" {
            simulationRenderer.nearNum = plane_slider.value*3.0
        }
        else if simulationRenderer.currentVisualization == "Flow and Volume" {
            simulationRenderer.nearNum = plane_slider.value*4
        }
        else if simulationRenderer.currentVisualization == "Dense Particle" {
            simulationRenderer.particleDistance = (plane_slider.value*5) + 0.5
        }
        else if simulationRenderer.currentVisualization == "Pinpoint" {
            let curr_pos = simulationRenderer.graph.graphRootNode.position
            let dt = plane_slider.value*5
            var new_pos = SCNVector3(simulationRenderer.graph.currentRay.origin + dt*simulationRenderer.graph.currentRay.direction)
            
            let rotPos = simd_float3(Float(cos(rotationValue)) * new_pos.x + Float(sin(rotationValue)) * new_pos.z,
                                     new_pos.y,
                                            -Float(sin(rotationValue)) * new_pos.x + Float(cos(rotationValue)) * new_pos.z)
            
            if rotPos.x >= pointCloudRenderer.boundary_points[0] {
                new_pos = curr_pos
                simulationRenderer.graph.graphRootNode.geometry?.firstMaterial?.diffuse.contents = UIColor.red
            }
            else if rotPos.y >= pointCloudRenderer.pc_max_y {
                new_pos = curr_pos
                simulationRenderer.graph.graphRootNode.geometry?.firstMaterial?.diffuse.contents = UIColor.red
            }
            else if rotPos.z >= pointCloudRenderer.boundary_points[2] {
                new_pos = curr_pos
                simulationRenderer.graph.graphRootNode.geometry?.firstMaterial?.diffuse.contents = UIColor.red
            }
            else if rotPos.x <= pointCloudRenderer.boundary_points[1] {
                new_pos = curr_pos
                simulationRenderer.graph.graphRootNode.geometry?.firstMaterial?.diffuse.contents = UIColor.red
            }
            else if rotPos.y <= pointCloudRenderer.pc_min_y {
                new_pos = curr_pos
                simulationRenderer.graph.graphRootNode.geometry?.firstMaterial?.diffuse.contents = UIColor.red
            }
            else if rotPos.z <= pointCloudRenderer.boundary_points[3] {
                new_pos = curr_pos
                simulationRenderer.graph.graphRootNode.geometry?.firstMaterial?.diffuse.contents = UIColor.red
            }
            else {
                simulationRenderer.graph.graphRootNode.geometry?.firstMaterial?.diffuse.contents = UIColor.green
            }
            simulationRenderer.graph.graphRootNode.position = new_pos
            
            // update graphInfo from server
            let i = Int(Float(gridSizeX)*(rotPos.x - pointCloudRenderer.boundary_points[1])/pointCloudRenderer.gridLengthX)
            let j = Int(Float(gridSizeY)*(rotPos.y - pointCloudRenderer.pc_min_y)/pointCloudRenderer.gridLengthY)
            let k = Int(Float(gridSizeZ)*(rotPos.z - pointCloudRenderer.boundary_points[3])/pointCloudRenderer.gridLengthZ)
            
            if i > -1 && i < gridSizeX && j > -1 && j < gridSizeY && k > -1 && k < gridSizeZ{
                comms.updateTargetPosForGraph(X: UInt16(i), Y: UInt16(j), Z: UInt16(k))
                
                var bob:Bool = false
                for i in 0...1000{
                    bob = self.comms.getGraphDone()
                    if (i / 10) == 1{
                        print(" ")
                    }
                    if bob{
                        break
                    }
                }
                
                graphInfo = comms.getGraphInfo()
            }
        }
    }
    
    func initGraphViewer(){
        graphViewer.layer.borderColor = UIColor.black.cgColor
        graphViewer.layer.borderWidth = 1.5
        graphViewer.isUserInteractionEnabled = true
        graphViewer.backgroundColor = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        graphViewer.minOffset = 50
        graphViewer.extraLeftOffset = 40
        graphViewer.legend.enabled = false
    
        graphViewer.rightAxis.enabled = false
        graphViewer.leftAxis.labelFont = .boldSystemFont(ofSize: 12)
        graphViewer.leftAxis.labelTextColor = .black
        graphViewer.leftAxis.axisLineColor = .black
        graphViewer.leftAxis.axisLineWidth = 1.5
        
        graphViewer.xAxis.labelPosition = .bottom
        graphViewer.xAxis.labelFont = .boldSystemFont(ofSize: 12)
        graphViewer.xAxis.labelTextColor = .black
        graphViewer.xAxis.axisLineColor = .black
        graphViewer.xAxis.axisLineWidth = 1.5
        graphViewer.xAxis.axisMinimum = 0.0
        graphViewer.xAxis.axisMaximum = 180.0
        
        
        let dataset = LineChartDataSet(entries: [
            ChartDataEntry(x: 0, y: 33.0),
            ChartDataEntry(x: 20, y: 31.83),
            ChartDataEntry(x: 40, y: 31.79),
            ChartDataEntry(x: 60, y: 30.65),
            ChartDataEntry(x: 80, y: 29.90),
            ChartDataEntry(x: 100, y: 29.20),
            ChartDataEntry(x: 120, y: 28.81),
            ChartDataEntry(x: 140, y: 28.20),
            ChartDataEntry(x: 160, y: 27.65),
            ChartDataEntry(x: 180, y: 27.10)
        ])
        
        dataset.mode = .cubicBezier
        dataset.setCircleColor(.black)
        dataset.lineWidth = 1.5
        dataset.valueFont = .boldSystemFont(ofSize: 12)
        dataset.valueTextColor = .black
        dataset.setColor(.black)
        
        let data = LineChartData(dataSet: dataset)
        graphViewer.data = data

    }
    
    @IBAction func open_sim_settings(_ sender: Any) {
        present(simulationSettingView, animated: true, completion: {})
//        let today = Date()
////            let hour = (Calendar.current.component(.hour, from: today))
////            let min = (Calendar.current.component(.minute, from: today))
////            let second = (Calendar.current.component(.second, from: today))
//        let formatter = DateFormatter()
//        formatter.dateFormat = "HH\tmm\tss\tSSSS\t"
//        ACBegin = formatter.string(from: today) + "AC_begin\n"
//        print(ACBegin)
//        //scanBegin = "\(hour)\t\(min)\t\(second)\tscan_begin\n"
    }
    
    
    @IBAction func graphTogglePressed(_ sender: Any){
        showGraph.toggle()
        
        if showGraph {
            graphDontMove = true
            
            
            if graphInfo.count == 0 {
                graphInfo = Array(repeating: 0.0, count: 10)
            }
            
            var data: [ChartDataEntry] = []
            for i in 0..<graphInfo.count {
                data.append(ChartDataEntry(x: Double(i)*20.0, y: Double(graphInfo[i])))
            }
            
            let dataset = LineChartDataSet(entries: data)
            dataset.mode = .cubicBezier
            dataset.setCircleColor(.black)
            dataset.lineWidth = 1.5
            dataset.valueFont = .boldSystemFont(ofSize: 12)
            dataset.valueTextColor = .black
            dataset.setColor(.black)
            let dataObj = LineChartData(dataSet: dataset)
            
            graphViewer.data = dataObj
            graphViewer.animate(yAxisDuration: 2.0)
            
            graphToggleButton.setTitle("Hide Graph", for: .normal)
            graphViewer.animate(yAxisDuration: 2.0)
            graphViewer.isHidden = false
            graphYLabel.isHidden = false
            graphXLabel.isHidden = false
        
        }
        else {
            graphDontMove = false
            graphToggleButton.setTitle("Show Graph", for: .normal)
            graphViewer.isHidden = true
            graphYLabel.isHidden = true
            graphXLabel.isHidden = true
        }
    }
    
// MARK: - Handle Screen Touch Interface
    
    @objc func handlePan(sender: UIPanGestureRecognizer){
        if simulationRenderer.currentVisualization == "OccupancyGrid" {
            let touchLocation = sender.location(in: sceneView)
            if let removePos = simulationRenderer.updateOccupancyGridVisualizationMetal(location: touchLocation) {
                pointCloudRenderer.eraseGrid(removePos)
                simulationRenderer.gridArray = pointCloudRenderer.gridArray
                simulationRenderer.boolGrid = pointCloudRenderer.boolGrid
            }
        }
    }
    
// MARK: - AC Installtion (using scenekit)
    
    //ac model change
    @objc func updateSettings(_ notification: Notification){
        if let dict = notification.userInfo as NSDictionary? {
            if !ACfirstInstalled && dict["ac_model"] as? String == "ceiling" {
                return
            }
            // reset current modelAC node
            for node_ in modelAC.acNodeArr {
                node_.removeFromParentNode()
            }
            simulationRenderer.acInstalled = false
            modelAC.acNodeArr = []
                        
            if let model = dict["ac_model"] as? String{
                modelAC.currentACModel = model
                if model == "ceiling" {
                    modelAC.current_ceiling_angle = 0.0
                }
                else if model == "stand" {
                    modelAC.current_ceiling_angle = 0.0
                }
                else if model == "tower" {
                    modelAC.current_ceiling_angle = 0.0
                }
                else if model == "wall" {
                    modelAC.current_ceiling_angle = 0.0
                }
            }
            simulationRenderer.currentVisualization = "RGB"
            angleChange = false //add
            updateUI()
            angleChange = true //add
        }
    }
    

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touch = touches.first!; let location = touch.location(in: sceneView)
        
        if simulationRenderer.currentVisualization == "OccupancyGrid" {
            return
        }
        
        else if simulationRenderer.currentVisualization == "Pinpoint" {
            if graphDontMove {
                return
            }
            if let position = simulationRenderer.graph.screenToWorld(screenPoint: location) {
                simulationRenderer.graph.graphRootNode.position = position
                plane_slider.value = 0.2
                simulationRenderer.graph.updatePointLocation(dt: 1.0)
                simulationRenderer.graph.graphRootNode.geometry?.firstMaterial?.diffuse.contents = UIColor.green
                
                // update graphInfo from server
                let rotPos = simd_float3(Float(cos(rotationValue)) * position.x + Float(sin(rotationValue)) * position.z,
                                                position.y,
                                                -Float(sin(rotationValue)) * position.x + Float(cos(rotationValue)) * position.z)
                
                let i = Int(Float(gridSizeX)*(rotPos.x - pointCloudRenderer.boundary_points[1])/pointCloudRenderer.gridLengthX)
                let j = Int(Float(gridSizeY)*(rotPos.y - pointCloudRenderer.pc_min_y)/pointCloudRenderer.gridLengthY)
                let k = Int(Float(gridSizeZ)*(rotPos.z - pointCloudRenderer.boundary_points[3])/pointCloudRenderer.gridLengthZ)
                comms.updateTargetPosForGraph(X: UInt16(i), Y: UInt16(j), Z: UInt16(k))
                
                var bob:Bool = false
                for i in 0...1000{
                    bob = self.comms.getGraphDone()
                    if (i / 10) == 1{
                        print(" ")
                    }
                    if bob{
                        break
                    }
                }
                
                graphInfo = comms.getGraphInfo()
            }
        }
        
        // for ac installation
        else if pointCloudRenderer.gridCreated {
            if simulationRenderer.acInstalled == false && simulationRenderer.currentVisualization != "pointcloud" {
                var ray_query: ARRaycastQuery?
                if modelAC.currentACModel == "wall" {
                    ray_query = sceneView.raycastQuery(from: location, allowing: .estimatedPlane, alignment: .vertical)
                } else {
                    ray_query = sceneView.raycastQuery(from: location, allowing: .estimatedPlane, alignment: .horizontal)
                }
                
                guard let query = ray_query else { return }
                let results = sceneView.session.raycast(query)
                if results.count == 0 {
                    if modelAC.currentACModel == "wall" {
                        let ac = UIAlertController(title: "Error", message: "You can only install wall-mounted air conditioners on vertical planes.", preferredStyle: .alert)
                        ac.addAction(UIAlertAction(title: "OK", style: .default))
                        present(ac, animated: true)
                        return
                    }
                    else if modelAC.currentACModel == "ceiling" {
                        let ac = UIAlertController(title: "Error", message: "You can only install ceiling-mounted air conditioners on horizontal planes.", preferredStyle: .alert)
                        ac.addAction(UIAlertAction(title: "OK", style: .default))
                        present(ac, animated: true)
                        return
                    }
                    else if modelAC.currentACModel == "stand" {
                        let ac = UIAlertController(title: "Error", message: "You can only install floor standing air conditioners on horizontal planes.", preferredStyle: .alert)
                        ac.addAction(UIAlertAction(title: "OK", style: .default))
                        present(ac, animated: true)
                        return
                    }
                    else if modelAC.currentACModel == "tower" {
                        let ac = UIAlertController(title: "Error", message: "You can only install floor standing air conditioners on horizontal planes.", preferredStyle: .alert)
                        ac.addAction(UIAlertAction(title: "OK", style: .default))
                        present(ac, animated: true)
                        return
                    }
                }
                
                guard let hitTestResult = results.last else { return }
                guard let currentFrame = sceneView.session.currentFrame else {
                    print("Could not get current frame AR Session...")
                    return
                }
        
                let columns = hitTestResult.worldTransform.columns.3
                modelAC.currentPosition = simd_float3(columns.x, columns.y, columns.z)
                
                let rotAC = simd_float3(Float(cos(rotationValue)) * modelAC.currentPosition.x + Float(sin(rotationValue)) * modelAC.currentPosition.z,
                                                modelAC.currentPosition.y,
                                                -Float(sin(rotationValue)) * modelAC.currentPosition.x + Float(cos(rotationValue)) * modelAC.currentPosition.z)
        
                var ind_x = Int(Float(gridSizeX)*(rotAC.x - pointCloudRenderer.boundary_points[1])/pointCloudRenderer.gridLengthX)
                var ind_y = Int(Float(gridSizeY)*(rotAC.y - pointCloudRenderer.pc_min_y)/pointCloudRenderer.gridLengthY)
                var ind_z = Int(Float(gridSizeZ)*(rotAC.z - pointCloudRenderer.boundary_points[3])/pointCloudRenderer.gridLengthZ)
                
                if ind_x >= gridSizeX {
                    ind_x = gridSizeX - 1
                }
                if ind_x < 0 {
                    ind_x = 0
                }
                if ind_y >= gridSizeY {
                    ind_y = gridSizeY - 1
                }
                if ind_y < 0 {
                    ind_y = 0
                }
                if ind_z >= gridSizeZ {
                    ind_z = gridSizeZ - 1
                }
                if ind_z < 0 {
                    ind_z = 0
                }
                let idx = pointCloudRenderer.convert3DIndex(x: ind_x, y: ind_y, z: ind_z)
                var position = pointCloudRenderer.gridArray[idx].position
                
                position = simd_float3(Float(cos(-rotationValue)) * position.x + Float(sin(-rotationValue)) * position.z,
                                                      position.y,
                                        -Float(sin(-rotationValue)) * position.x + Float(cos(-rotationValue)) * position.z)
                modelAC.currentPosition = simd_float3(position.x, columns.y, position.z)
                
                if modelAC.currentACModel == "ceiling" {
                    if ACfirstInstalled {
                        modelAC.loadCeilingModels()
                    }
                    modelAC.ceiling_ac.position = SCNVector3(position.x, columns.y, position.z)
                    modelAC.ceiling_ac.simdLocalRotate(by: simd_quatf(angle: -rotationValue, axis: simd_float3(0,1,0)))
                    
                    // reset blade orientation
                    modelAC.blade_x1.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: -modelAC.current_ceiling_angle), axis: simd_float3(1,0,0)))
                    modelAC.blade_x2.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: -modelAC.current_ceiling_angle), axis: simd_float3(1,0,0)))
                    modelAC.blade_z1.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: -modelAC.current_ceiling_angle), axis: simd_float3(1,0,0)))
                    modelAC.blade_z2.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: -modelAC.current_ceiling_angle), axis: simd_float3(1,0,0)))
                    
                    modelAC.blade_x1.simdLocalRotate(by: simd_quatf(angle: -rotationValue, axis: simd_float3(0,1,0)))
                    modelAC.blade_x2.simdLocalRotate(by: simd_quatf(angle: -rotationValue, axis: simd_float3(0,1,0)))
                    modelAC.blade_z1.simdLocalRotate(by: simd_quatf(angle: -rotationValue, axis: simd_float3(0,1,0)))
                    modelAC.blade_z2.simdLocalRotate(by: simd_quatf(angle: -rotationValue, axis: simd_float3(0,1,0)))
                    
                    modelAC.blade_x1.position = SCNVector3(position.x - 0.36 * rotAxisZ.x, columns.y - 0.0095, position.z - 0.36 * rotAxisZ.z)
                    modelAC.blade_x2.position = SCNVector3(position.x + 0.36 * rotAxisZ.x, columns.y - 0.0095, position.z + 0.36 * rotAxisZ.z)
                    modelAC.blade_z1.position = SCNVector3(position.x + 0.36 * rotAxisX.x, columns.y - 0.0095, position.z + 0.36 * rotAxisX.z)
                    modelAC.blade_z2.position = SCNVector3(position.x - 0.36 * rotAxisX.x, columns.y - 0.0095, position.z - 0.36 * rotAxisX.z)
                    
                    // reset blade orientation
                    modelAC.blade_x1.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: modelAC.current_ceiling_angle), axis: simd_float3(1,0,0)))
                    modelAC.blade_x2.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: modelAC.current_ceiling_angle), axis: simd_float3(1,0,0)))
                    modelAC.blade_z1.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: modelAC.current_ceiling_angle), axis: simd_float3(1,0,0)))
                    modelAC.blade_z2.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: modelAC.current_ceiling_angle), axis: simd_float3(1,0,0)))
                    
                    modelAC.ceiling_ac.scale = SCNVector3(0.032, 0.032, 0.032)
                    modelAC.blade_x1.scale = SCNVector3(0.032, 0.032, 0.032)
                    modelAC.blade_x2.scale = SCNVector3(0.032, 0.032, 0.032)
                    modelAC.blade_z1.scale = SCNVector3(0.032, 0.032, 0.032)
                    modelAC.blade_z2.scale = SCNVector3(0.032, 0.032, 0.032)
                                    
                    sceneView.scene.rootNode.addChildNode(modelAC.ceiling_ac)
                    sceneView.scene.rootNode.addChildNode(modelAC.blade_x1)
                    sceneView.scene.rootNode.addChildNode(modelAC.blade_x2)
                    sceneView.scene.rootNode.addChildNode(modelAC.blade_z1)
                    sceneView.scene.rootNode.addChildNode(modelAC.blade_z2)
                                     
                    modelAC.acNodeArr.append(modelAC.ceiling_ac)
                    modelAC.acNodeArr.append(modelAC.blade_x1)
                    modelAC.acNodeArr.append(modelAC.blade_x2)
                    modelAC.acNodeArr.append(modelAC.blade_z1)
                    modelAC.acNodeArr.append(modelAC.blade_z2)
                    
                    modelAC.currentPosition = simd_float3(position.x, columns.y, position.z)

                }
                else if modelAC.currentACModel == "wall" {
                    if ACfirstInstalled {
                        modelAC.loadWallModels()
                    }
                    let camera = currentFrame.camera
                    let view_matrix = camera.viewMatrix(for: UIInterfaceOrientation.landscapeRight).transpose.inverse
                    let at = normalize(simd_float3(view_matrix[0,2], view_matrix[1,2], view_matrix[2,2]))*(-1)
                    
                    let x_pos = rotAxisX; let x_neg = -rotAxisX
                    let z_pos = rotAxisZ; let z_neg = -rotAxisZ
                    let x_pos_angle = acos(simd_dot(at, x_pos)); let x_neg_angle = acos(simd_dot(at, x_neg))
                    let z_pos_angle = acos(simd_dot(at, z_pos)); let z_neg_angle = acos(simd_dot(at, z_neg))
                    var rot_vector:SCNVector4 = SCNVector4(0,0,0,0)
                    
                    // (1,0,0)
                    if (x_pos_angle < x_neg_angle) && (x_pos_angle < z_pos_angle) && (x_pos_angle < z_neg_angle) {
                        rot_vector = SCNVector4(0.0,1.0,0.0,(-1*Float.pi)/2 - rotationValue)
                        modelAC.wallblade.position = SCNVector3(columns.x + 0.016*rotAxisX.x - 0.005*rotAxisZ.x,
                                                                columns.y-0.172,
                                                                columns.z + 0.016*rotAxisX.z - 0.005*rotAxisZ.z)
                        modelAC.acOrientation = 4 //"plus_x"
                    }
                    // (-1,0,0)
                    else if (x_neg_angle < x_pos_angle) && (x_neg_angle < z_pos_angle) && (x_neg_angle < z_neg_angle) {
                        rot_vector = SCNVector4(0.0,1.0,0.0,Float.pi/2 - rotationValue)
                        modelAC.wallblade.position = SCNVector3(columns.x - 0.016*rotAxisX.x + 0.005*rotAxisZ.x,
                                                                columns.y-0.172,
                                                                columns.z - 0.016*rotAxisX.z + 0.005*rotAxisZ.z)
                        modelAC.acOrientation = 0 //"minus_x"
                    }
                    // (0,0,1)
                    else if (z_pos_angle < z_neg_angle) && (z_pos_angle < x_pos_angle) && (z_pos_angle < x_neg_angle) {
                        rot_vector = SCNVector4(0.0,1.0,0.0,-1*Float.pi - rotationValue)
                        modelAC.wallblade.position = SCNVector3(columns.x + 0.005*rotAxisX.x + 0.016*rotAxisZ.x,
                                                                columns.y-0.172,
                                                                columns.z + 0.005*rotAxisX.z + 0.016*rotAxisZ.z)
                        modelAC.acOrientation = 2 //"plus_z"
                    }
                    // (0,0,-1)
                    else if (z_neg_angle < z_pos_angle) && (z_neg_angle < x_neg_angle) && (z_neg_angle < x_pos_angle) {
                        rot_vector = SCNVector4(0.0,1.0,0.0, -rotationValue)
                        modelAC.wallblade.position = SCNVector3(columns.x - 0.005*rotAxisX.x - 0.016*rotAxisZ.x,
                                                                columns.y-0.172,
                                                                columns.z - 0.005*rotAxisX.z - 0.016*rotAxisZ.z)
                        modelAC.acOrientation = 6 //"minus_z"
                    }
                    
                    modelAC.wall_ac.position = SCNVector3(columns.x, columns.y, columns.z)
                    modelAC.wall_ac.scale = SCNVector3(0.002, 0.002, 0.002)
                    modelAC.wall_ac.rotation = rot_vector
                    modelAC.wallblade.scale = SCNVector3(0.002, 0.002, 0.002)
                    modelAC.wallblade.rotation = rot_vector
                    
                    sceneView.scene.rootNode.addChildNode(modelAC.wall_ac)
                    sceneView.scene.rootNode.addChildNode(modelAC.wallblade)
                    
                    modelAC.acNodeArr.append(modelAC.wall_ac)
                    modelAC.acNodeArr.append(modelAC.wallblade)
                }
                
                else if modelAC.currentACModel == "stand" {  //add //add //add //add //add
                    if ACfirstInstalled {
                        modelAC.loadStandModels()
                    }
                    let camera = currentFrame.camera
                    let view_matrix = camera.viewMatrix(for: UIInterfaceOrientation.landscapeRight).transpose.inverse
                    let at = normalize(simd_float3(view_matrix[0,2], view_matrix[1,2], view_matrix[2,2]))*(-1)

                    let x_pos = rotAxisX; let x_neg = -rotAxisX
                    let z_pos = rotAxisZ; let z_neg = -rotAxisZ
                    let x_pos_angle = acos(simd_dot(at, x_pos)); let x_neg_angle = acos(simd_dot(at, x_neg))
                    let z_pos_angle = acos(simd_dot(at, z_pos)); let z_neg_angle = acos(simd_dot(at, z_neg))
                    var rot_vector:SCNVector4 = SCNVector4(0,0,0,0)

                    // (1,0,0)
                    if (x_pos_angle < x_neg_angle) && (x_pos_angle < z_pos_angle) && (x_pos_angle < z_neg_angle) {
                        rot_vector = SCNVector4(0.0,1.0,0.0, -rotationValue)
                        modelAC.acOrientation = 4 //"plus_x"

                        modelAC.stdblade1.position = SCNVector3(columns.x-0.031*rotAxisX.x, columns.y + 1.6807, columns.z+0.005*rotAxisZ.z)
                        modelAC.stdblade2.position = SCNVector3(columns.x-0.031*rotAxisX.x, columns.y + 1.6107, columns.z+0.005*rotAxisZ.z)
                        modelAC.stdblade3.position = SCNVector3(columns.x-0.031*rotAxisX.x, columns.y + 1.5407, columns.z+0.005*rotAxisZ.z)
                        modelAC.stdblade4.position = SCNVector3(columns.x-0.031*rotAxisX.x, columns.y + 1.4707, columns.z+0.005*rotAxisZ.z)
                    }
                    // (-1,0,0)
                    else if (x_neg_angle < x_pos_angle) && (x_neg_angle < z_pos_angle) && (x_neg_angle < z_neg_angle) {
                        rot_vector = SCNVector4(0.0,1.0,0.0,Float.pi - rotationValue)
                        modelAC.acOrientation = 0 //"minus_x"

                        modelAC.stdblade1.position = SCNVector3(columns.x+0.031*rotAxisX.x, columns.y + 1.6807, columns.z-0.005*rotAxisZ.z)
                        modelAC.stdblade2.position = SCNVector3(columns.x+0.031*rotAxisX.x, columns.y + 1.6107, columns.z-0.005*rotAxisZ.z)
                        modelAC.stdblade3.position = SCNVector3(columns.x+0.031*rotAxisX.x, columns.y + 1.5407, columns.z-0.005*rotAxisZ.z)
                        modelAC.stdblade4.position = SCNVector3(columns.x+0.031*rotAxisX.x, columns.y + 1.4707, columns.z-0.005*rotAxisZ.z)
                    }
                    // (0,0,1)
                    else if (z_pos_angle < z_neg_angle) && (z_pos_angle < x_pos_angle) && (z_pos_angle < x_neg_angle) {
                        rot_vector = SCNVector4(0.0,1.0,0.0,-1*Float.pi/2 - rotationValue)
                        modelAC.acOrientation = 2 //"plus_z"

                        modelAC.stdblade1.position = SCNVector3(columns.x-0.005*rotAxisX.x, columns.y + 1.6807, columns.z-0.031*rotAxisZ.z)
                        modelAC.stdblade2.position = SCNVector3(columns.x-0.005*rotAxisX.x, columns.y + 1.6107, columns.z-0.031*rotAxisZ.z)
                        modelAC.stdblade3.position = SCNVector3(columns.x-0.005*rotAxisX.x, columns.y + 1.5407, columns.z-0.031*rotAxisZ.z)
                        modelAC.stdblade4.position = SCNVector3(columns.x-0.005*rotAxisX.x, columns.y + 1.4707, columns.z-0.031*rotAxisZ.z)
                    }
                    // (0,0,-1)
                    else if (z_neg_angle < z_pos_angle) && (z_neg_angle < x_neg_angle) && (z_neg_angle < x_pos_angle) {
                        rot_vector = SCNVector4(0.0,1.0,0.0, Float.pi/2-rotationValue)
                        modelAC.acOrientation = 6 //"minus_z"

                        modelAC.stdblade1.position = SCNVector3(columns.x+0.005*rotAxisX.x, columns.y + 1.6807, columns.z+0.031*rotAxisZ.z)
                        modelAC.stdblade2.position = SCNVector3(columns.x+0.005*rotAxisX.x, columns.y + 1.6107, columns.z+0.031*rotAxisZ.z)
                        modelAC.stdblade3.position = SCNVector3(columns.x+0.005*rotAxisX.x, columns.y + 1.5407, columns.z+0.031*rotAxisZ.z)
                        modelAC.stdblade4.position = SCNVector3(columns.x+0.005*rotAxisX.x, columns.y + 1.4707, columns.z+0.031*rotAxisZ.z)
                    }
                    
                    modelAC.stand_ac.position = SCNVector3(columns.x, columns.y, columns.z)
                    modelAC.stand_ac.scale = SCNVector3(0.01, 0.01, 0.01)
                    modelAC.stand_ac.rotation = rot_vector
                   // modelAC.stand_ac.simdLocalRotate(by: simd_quatf(angle: -rotationValue, axis: simd_float3(0,1,0)))

                    modelAC.stdblade1.scale = SCNVector3(0.01, 0.01, 0.01)
                    modelAC.stdblade2.scale = SCNVector3(0.01, 0.01, 0.01)
                    modelAC.stdblade3.scale = SCNVector3(0.01, 0.01, 0.01)
                    modelAC.stdblade4.scale = SCNVector3(0.01, 0.01, 0.01)

                    modelAC.stdblade1.rotation = rot_vector
                    modelAC.stdblade2.rotation = rot_vector
                    modelAC.stdblade3.rotation = rot_vector
                    modelAC.stdblade4.rotation = rot_vector

//                    modelAC.stdblade1.simdLocalRotate(by: simd_quatf(angle: -rotationValue, axis: simd_float3(0,1,0)))
//                    modelAC.stdblade2.simdLocalRotate(by: simd_quatf(angle: -rotationValue, axis: simd_float3(0,1,0)))
//                    modelAC.stdblade3.simdLocalRotate(by: simd_quatf(angle: -rotationValue, axis: simd_float3(0,1,0)))
//                    modelAC.stdblade4.simdLocalRotate(by: simd_quatf(angle: -rotationValue, axis: simd_float3(0,1,0)))

                    sceneView.scene.rootNode.addChildNode(modelAC.stand_ac)
                    sceneView.scene.rootNode.addChildNode(modelAC.stdblade1)
                    sceneView.scene.rootNode.addChildNode(modelAC.stdblade2)
                    sceneView.scene.rootNode.addChildNode(modelAC.stdblade3)
                    sceneView.scene.rootNode.addChildNode(modelAC.stdblade4)

                    modelAC.acNodeArr.append(modelAC.stand_ac)
                    modelAC.acNodeArr.append(modelAC.stdblade1)
                    modelAC.acNodeArr.append(modelAC.stdblade2)
                    modelAC.acNodeArr.append(modelAC.stdblade3)
                    modelAC.acNodeArr.append(modelAC.stdblade4)
                }
                
                else if modelAC.currentACModel == "tower" {  //add //add //add //add //add
                    if ACfirstInstalled {
                        modelAC.loadTowerModels()
                    }
                    let x_pos = rotAxisX; let x_neg = -rotAxisX
                    let z_pos = rotAxisZ; let z_neg = -rotAxisZ
                    
                    var rot_vector:SCNVector4 = SCNVector4(0,0,0,0)

                    rot_vector = SCNVector4(0.0,1.0,0.0,Float.pi - rotationValue)
                    
                    modelAC.acOrientation = 0 //"minus_x"

//                    modelAC.stdblade1.position = SCNVector3(columns.x+0.031*rotAxisX.x, columns.y + 1.6807, columns.z-0.005*rotAxisZ.z)
//                    modelAC.stdblade2.position = SCNVector3(columns.x+0.031*rotAxisX.x, columns.y + 1.6107, columns.z-0.005*rotAxisZ.z)
//                    modelAC.stdblade3.position = SCNVector3(columns.x+0.031*rotAxisX.x, columns.y + 1.5407, columns.z-0.005*rotAxisZ.z)
//                    modelAC.stdblade4.position = SCNVector3(columns.x+0.031*rotAxisX.x, columns.y + 1.4707, columns.z-0.005*rotAxisZ.z)
                    
//                    let rotACPose = simd_float3(Float(cos(rotationValue)) * columns.x + Float(sin(rotationValue)) * columns.z,
//                                                columns.y,
//                                                    -Float(sin(rotationValue)) * columns.x + Float(cos(rotationValue)) * columns.z)
//
//                    let a = Int(Float(gridSizeX)*(rotACPose.x - pointCloudRenderer.boundary_points[1])/pointCloudRenderer.gridLengthX)
//                    let b = Int(Float(gridSizeY)*(rotACPose.y - pointCloudRenderer.pc_min_y)/pointCloudRenderer.gridLengthY)
//                    let c = Int(Float(gridSizeZ)*(rotACPose.z - pointCloudRenderer.boundary_points[3])/pointCloudRenderer.gridLengthZ)
//
//                    let idx = pointCloudRenderer.convert3DIndex(x: a, y: b, z: c)
//                    let pose = pointCloudRenderer.gridArray[idx].position
                    //branch check
                    modelAC.currentPosition = simd_float3(position.x, position.y, position.z)
                    //modelAC.currentPosition =  simd_float3(pose.x, pose.y, pose.z)
                    modelAC.tower_ac.position = SCNVector3(position.x-0.05*rotAxisZ.x, position.y-0.05, position.z-0.05*rotAxisZ.z)
                    //modelAC.tower_ac.position = SCNVector3(pose.x, pose.y, pose.z-0.05)
                    modelAC.tower_ac.scale = SCNVector3(0.0385, 0.0385, 0.0385)
                    modelAC.tower_ac.rotation = rot_vector
                   // modelAC.tower_ac.simdLocalRotate(by: simd_quatf(angle: -rotationValue, axis: simd_float3(0,1,0)))

//                    modelAC.stdblade1.scale = SCNVector3(0.01, 0.01, 0.01)
//                    modelAC.stdblade2.scale = SCNVector3(0.01, 0.01, 0.01)
//                    modelAC.stdblade3.scale = SCNVector3(0.01, 0.01, 0.01)
//                    modelAC.stdblade4.scale = SCNVector3(0.01, 0.01, 0.01)
//
//                    modelAC.stdblade1.rotation = rot_vector
//                    modelAC.stdblade2.rotation = rot_vector
//                    modelAC.stdblade3.rotation = rot_vector
//                    modelAC.stdblade4.rotation = rot_vector

                    sceneView.scene.rootNode.addChildNode(modelAC.tower_ac)
//                    sceneView.scene.rootNode.addChildNode(modelAC.stdblade1)
//                    sceneView.scene.rootNode.addChildNode(modelAC.stdblade2)
//                    sceneView.scene.rootNode.addChildNode(modelAC.stdblade3)
//                    sceneView.scene.rootNode.addChildNode(modelAC.stdblade4)

                    modelAC.acNodeArr.append(modelAC.tower_ac)
//                    modelAC.acNodeArr.append(modelAC.stdblade1)
//                    modelAC.acNodeArr.append(modelAC.stdblade2)
//                    modelAC.acNodeArr.append(modelAC.stdblade3)
//                    modelAC.acNodeArr.append(modelAC.stdblade4)
                    
                    //add //add //add //add //add //add //add //add //add //add //add
                }
                
                let x = modelAC.currentPosition.x; let y = modelAC.currentPosition.y; let z = modelAC.currentPosition.z;
                
                let rotACPosition = simd_float3(Float(cos(rotationValue)) * x + Float(sin(rotationValue)) * z,
                                                y,
                                                -Float(sin(rotationValue)) * x + Float(cos(rotationValue)) * z)
                            
                var i = Int(Float(gridSizeX)*(rotACPosition.x - pointCloudRenderer.boundary_points[1])/pointCloudRenderer.gridLengthX)
                var j = Int(Float(gridSizeY)*(rotACPosition.y - pointCloudRenderer.pc_min_y)/pointCloudRenderer.gridLengthY)
                var k = Int(Float(gridSizeZ)*(rotACPosition.z - pointCloudRenderer.boundary_points[3])/pointCloudRenderer.gridLengthZ)
                
                if i >= gridSizeX {
                    i = gridSizeX-1
                }
                else if i < 0 {
                    i = 0
                }
                if j >= gridSizeY {
                    j = gridSizeY-1
                }
                else if j < 0 {
                    j = 0
                }
                if k >= gridSizeZ {
                    k = gridSizeZ-1
                }
                else if k < 0 {
                    k = 0
                }
                
                if modelAC.currentACModel == "stand" {
                    j += 16
                    
                    if modelAC.acOrientation == 4 { //"plus_x" {
                        i += 1
                    }
                    if modelAC.acOrientation == 0 { //"minus_x" {
                        i -= 1
                    }
                    if modelAC.acOrientation == 2 { //"plus_z" {
                        k += 1
                    }
                    if modelAC.acOrientation == 6 { //"minus_z" {
                        k -= 1
                    }
                }
                
                if modelAC.currentACModel == "wall" {  //add //add //add
                    for x_occ in -7 ... 7 {
                        for y_occ in -3 ... 3 {
                            for z_occ in -7 ... 7 {
                                if i + x_occ < pointCloudRenderer.gridSizeX && i + x_occ >= 0
                                    && j + y_occ < pointCloudRenderer.gridSizeY && j + y_occ >= 0
                                    && k + z_occ < pointCloudRenderer.gridSizeZ && k + z_occ >= 0 {
                                    let index = pointCloudRenderer.convert3DIndex(x: i + x_occ, y: j + y_occ, z: k + z_occ)
                                    pointCloudRenderer.gridArray[index].occ = false
                                    pointCloudRenderer.gridArray[index].fixed = true
                                    pointCloudRenderer.boolGrid[index] = false
                                }
                            }
                        }
                    }
                }
                
                if modelAC.currentACModel == "ceiling" {  //add //add
                    for x_occ in -7 ... 7 {
                        for y_occ in -1 ... 1 {
                            for z_occ in -7 ... 7 {
                                if i + x_occ < pointCloudRenderer.gridSizeX && i + x_occ >= 0
                                    && j + y_occ < pointCloudRenderer.gridSizeY && j + y_occ >= 0
                                    && k + z_occ < pointCloudRenderer.gridSizeZ && k + z_occ >= 0 {
                                    let index = pointCloudRenderer.convert3DIndex(x: i + x_occ, y: j + y_occ, z: k + z_occ)
                                    pointCloudRenderer.gridArray[index].occ = false
                                    pointCloudRenderer.gridArray[index].fixed = true
                                    pointCloudRenderer.boolGrid[index] = false
                                }
                            }
                        }
                    }
                }
                
                // update all ac info
                comms.storeAddr(address: "")
                if !imageLoadMode && !imageSaveMode && !ACfirstInstalled{ //add //add //add
                    comms.initialize(gridSizeX: pointCloudRenderer.gridSizeX, gridSizeY: pointCloudRenderer.gridSizeY, gridSizeZ: pointCloudRenderer.gridSizeZ)
                } //add //add //add //add //add //add //add
                
                comms.acInfoUpdated = true
                comms.ACfirstInstalled = true
                ACfirstInstalled = true
                
                modelAC.currentAngle = 4
                comms.updateACVentLevel(level: modelAC.currentAngle)
                simulationRenderer.acAngle = modelAC.currentAngle
                
                modelAC.currentSpeed = 1
                comms.updateACVentSpeed(speed: modelAC.currentSpeed)
                
                comms.updateACDirection(dir: modelAC.acOrientation)
                
                comms.updateACInfo(type: modelAC.get_model_id(model_name: modelAC.currentACModel), position: [i, j, k])
                
                comms.updateACReset()
                
                if !madeConnection {
                    comms.makeConnection()
                    
                    connectLink = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(checkConnection), userInfo: nil, repeats: true)
                }
                updateUI()
                simulationRenderer.acInstalled = true
                simulationRenderer.modelAC = modelAC
                simulationRenderer.resetVisualization()
                
            }
        }
        else if cornerDetectMode && corners_arr.count < 4{
            let touch = touches.first!; let location = touch.location(in: sceneView)
            
            // for ac installation
            if current_view == "simulation" {
                var ray_query: ARRaycastQuery?
                if modelAC.currentACModel == "wall" {
                    ray_query = sceneView.raycastQuery(from: location, allowing: .estimatedPlane, alignment: .vertical)
                } else {
                    ray_query = sceneView.raycastQuery(from: location, allowing: .estimatedPlane, alignment: .horizontal)
                }
                
                guard let query = ray_query else { return }
                let results = sceneView.session.raycast(query)
                
                guard let hitTestResult = results.last else { return }
        
                let columns = hitTestResult.worldTransform.columns.3
                let cornerPosition = simd_float3(columns.x, columns.y, columns.z)
                
                corners_arr.append(SCNVector3(cornerPosition.x, cornerPosition.y, cornerPosition.z))
                draw_edge_points(new_corner: SCNVector3(cornerPosition.x, cornerPosition.y, cornerPosition.z))
                pointCloudRenderer.cornerArray = corners_arr
                
                if corners_arr.count >= 4{
                    calcCornerRot()
                    cornerDetectMode = false
                }
            }
        }
    }
    
    @objc func checkConnection() { //check
        if (comms.getConnectDone()) {
            madeConnection = true
            
            commsLink = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(updateOccupancyGrid), userInfo: nil, repeats: true)
            
            //print(connectionCount)
            connectLink?.invalidate()
        }
        connectionCount += 1
        
        if connectionCount >= 3 {
            print("server off")
            
            let alert = UIAlertController(title: "", message: "Server is not available", preferredStyle: UIAlertController.Style.alert)
            self.present(alert, animated: true, completion: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                alert.dismiss(animated: true, completion: nil)
            }
            
            connectLink?.invalidate()
            connectionCount = 0
        }
    }
    
    func calcACOrientation(ori: simd_float3) {
        let x_pos = simd_float3(1,0,0); let x_neg = simd_float3(-1,0,0)
        let z_pos = simd_float3(0,0,1); let z_neg = simd_float3(0,0,-1)
        let x_pos_angle = acos(simd_dot(ori, x_pos)); let x_neg_angle = acos(simd_dot(ori, x_neg))
        let z_pos_angle = acos(simd_dot(ori, z_pos)); let z_neg_angle = acos(simd_dot(ori, z_neg))
        
        // (1,0,0)
        if (x_pos_angle < x_neg_angle) && (x_pos_angle < z_pos_angle) && (x_pos_angle < z_neg_angle) {
            modelAC.acOrientation = 4 //"plus_x"
        }
        // (-1,0,0)
        else if (x_neg_angle < x_pos_angle) && (x_neg_angle < z_pos_angle) && (x_neg_angle < z_neg_angle) {
            modelAC.acOrientation = 0 //"minus_x"
        }
        // (0,0,1)
        else if (z_pos_angle < z_neg_angle) && (z_pos_angle < x_pos_angle) && (z_pos_angle < x_neg_angle) {
            modelAC.acOrientation = 2 //"plus_z"
        }
        // (0,0,-1)
        else if (z_neg_angle < z_pos_angle) && (z_neg_angle < x_neg_angle) && (z_neg_angle < x_pos_angle) {
            modelAC.acOrientation = 6 //"minus_z"
        }
    }
    
    func hideAC(){
        sceneView.scene.rootNode.enumerateChildNodes{ (node, stop) in
            if node.name == "ACNode" {
                node.isHidden = true
            }
        }
    }
    
    func showAC(){
        sceneView.scene.rootNode.enumerateChildNodes{ (node, stop) in
            if node.name == "ACNode" {
                node.isHidden = false
            }
        }
    }
        
    @objc func updateOccupancyGrid(){
        comms.updateOccupancy(grid: pointCloudRenderer.boolGrid)
    }
    
    @objc func updateGridParameters(){
        mutex_lock.lock()
        simulationRenderer.boolGrid = pointCloudRenderer.boolGrid
        mutex_lock.unlock()
    }
    

            
    // MARK: - Visualization Control
    
    @IBAction func rgb_vis_selected(_ sender: Any){
        simulationRenderer.currentVisualization = "RGB"
        plane_slider.isHidden = true
        plane_slider_label.isHidden = true
        updateUI()

        simulationRenderer.resetVisualization()
    }
    
    @IBAction func pointcloud_vis_selected(_ sender: Any){
        simulationRenderer.currentVisualization = "pointcloud"
        updateUI()
        
    }
    
    @IBAction func edit_grid_pressed(_ sender: Any){
        simulationRenderer.currentVisualization = "OccupancyGrid"
        updateUI()
        
        simulationRenderer.resetVisualization()
        simulationRenderer.calculateOccupancyGridVisualizationMetal()
        
//        let today = Date()
////            let hour = (Calendar.current.component(.hour, from: today))
////            let min = (Calendar.current.component(.minute, from: today))
////            let second = (Calendar.current.component(.second, from: today))
//        let formatter = DateFormatter()
//        formatter.dateFormat = "HH\tmm\tss\tSSSS\t"
//        editBegin = formatter.string(from: today) + "edit_begin\n"
//        print(editBegin)
//        //scanBegin = "\(hour)\t\(min)\t\(second)\tscan_begin\n"
//        editFlag = true
    }
        
    @IBAction func volume_vis_selected(_ sender: Any) {
        if(simulationRenderer.acInstalled == false){
            let ac = UIAlertController(title: "Error", message: "You need to set the AC location before you start the simulation.", preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "OK", style: .default))
            present(ac, animated: true)
            return
        }
        
        if simulationRenderer.currentVisualization == "Vector" {
            simulationRenderer.currentVisualization = "Flow and Volume"
            flow_volume_selected()
        }
        else {
            simulationRenderer.currentVisualization = "Volume"
            plane_slider.isHidden = false
            plane_slider_label.isHidden = false
            updateUI()

            simulationRenderer.resetVisualization()
            simulationRenderer.startVisualization()
        }
    }
    
    @IBAction func surface_vis_selected(_ sender: Any) {
        if(simulationRenderer.acInstalled == false){
            let ac = UIAlertController(title: "Error", message: "You need to set the AC location before you start the simulation.", preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "OK", style: .default))
            present(ac, animated: true)
            return
        }
        
        simulationRenderer.currentVisualization = "Surface"
       
        updateUI()

        simulationRenderer.resetVisualization()
        simulationRenderer.get_server_data()
        simulationRenderer.startSurface()
        simulationRenderer.StartLines()
        simulationRenderer.startVisualization()
    }
    
    @IBAction func vector_vis_selected(_ sender: Any) {
        if(simulationRenderer.acInstalled == false){
            let ac = UIAlertController(title: "Error", message: "You need to set the AC location before you start the simulation.", preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "OK", style: .default))
            present(ac, animated: true)
            return
        }
    
        if simulationRenderer.currentVisualization == "Volume" {
            simulationRenderer.currentVisualization = "Flow and Volume"
            flow_volume_selected()
        }
        else {
            simulationRenderer.currentVisualization = "Vector"
            plane_slider.isHidden = true
            plane_slider_label.isHidden = true
            updateUI()
            
            simulationRenderer.resetVisualization()
            simulationRenderer.get_server_data()
            simulationRenderer.startArrowAnimation()
            simulationRenderer.startVisualization()
        }
    }
    
    func flow_volume_selected(){
        plane_slider.isHidden = false
        plane_slider_label.isHidden = false
        
        simulationRenderer.resetVisualization()
        simulationRenderer.get_server_data()
        simulationRenderer.startArrowAnimation()
        simulationRenderer.startVisualization()
        updateUI()
    }
    
    @IBAction func particle_vis_selected(_ sender: Any){
        if(simulationRenderer.acInstalled == false){
            let ac = UIAlertController(title: "Error", message: "You need to set the AC location before you start the simulation.", preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "OK", style: .default))
            present(ac, animated: true)
            return
        }
        
        simulationRenderer.currentVisualization = "Particle"
        plane_slider.isHidden = true
        plane_slider_label.isHidden = true
        updateUI()

        simulationRenderer.resetVisualization()
        simulationRenderer.get_server_data()
        simulationRenderer.startParticleVane()
        simulationRenderer.startVisualization()
    }
    
    @IBAction func particle2_vis_selected(_ sender: Any){
        if(simulationRenderer.acInstalled == false){
            let ac = UIAlertController(title: "Error", message: "You need to set the AC location before you start the simulation.", preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "OK", style: .default))
            present(ac, animated: true)
            return
        }
        
        simulationRenderer.currentVisualization = "Dense Particle"
        plane_slider.isHidden = false
        plane_slider_label.isHidden = false
        updateUI()

        simulationRenderer.resetVisualization()
        simulationRenderer.get_server_data()
        simulationRenderer.startParticle()
        simulationRenderer.startVisualization()
    }
    
    @IBAction func pinpoint_selected(_ sender: Any){
        if(simulationRenderer.acInstalled == false){
            let ac = UIAlertController(title: "Error", message: "You need to set the AC location before you start the simulation.", preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "OK", style: .default))
            present(ac, animated: true)
            return
        }
        
        plane_slider.isHidden = false
        plane_slider_label.isHidden = false
        graphToggleButton.setTitle("Show Graph", for: .normal)
        
        simulationRenderer.currentVisualization = "Pinpoint"
        simulationRenderer.resetVisualization()
        simulationRenderer.get_server_data()
        simulationRenderer.graph.initTargetLocation()
        simulationRenderer.startVisualization()
        updateUI()
    }
    
    
    @IBAction func occlusion_vis_selected(_ sender: Any){
        simulationRenderer.complete_occlude.toggle()
        updateUI()
    }
        
    // MARK: - Temp Buttons
    
    @IBAction func saveButtonPressed(_ sender: Any){
        print("save button pressed")
        imageLoadMode = false
        //cornerDetectMode = false
        
        imageSaveMode = true
        imageDetectMode = true
    }
    
    @IBAction func loadButtonPressed(_ sender: Any){
        print("load button pressed")
        imageSaveMode = false
        //cornerDetectMode = false
        
        imageLoadMode = true
        imageDetectMode = true
    }
    
    //MARK: - functions for corner and image detection
    
    func close_location(p1: SCNVector3) -> Bool {
        for points_ in corners_arr {
            let distance = sqrt(pow(p1.x - points_.x, 2) + pow(p1.y - points_.y, 2) + pow(p1.z - points_.z, 2))
            if distance < 0.2 {
                return true
            }
        }
        return false
    }

    func find_corners(hPlane: plane_geom, idh: String){ //additional
        for (id1, vPlane) in vertical_plane_arr {
            var matA = simd_float3x3(); var vecD = simd_float3();
            if abs(vPlane.max_y - hPlane.max_y) < dist_tolerance {
                for (id2, vPlane2) in vertical_plane_arr {
                    if id1 == id2 {
                        continue
                    }
                    else if abs(vPlane2.max_y - hPlane.max_y) < dist_tolerance {
                        matA[0] = simd_float3(hPlane.plane_normal.x, hPlane.plane_normal.y, hPlane.plane_normal.z)
                        matA[1] = simd_float3(vPlane.plane_normal.x, vPlane.plane_normal.y, vPlane.plane_normal.z)
                        matA[2] = simd_float3(vPlane2.plane_normal.x, vPlane2.plane_normal.y, vPlane2.plane_normal.z)
                        vecD.x = hPlane.d; vecD.y = vPlane.d; vecD.z = vPlane2.d

                        let simd_point = simd_mul(matA.transpose.inverse, vecD)
                        let edge_point = SCNVector3(simd_point.x, simd_point.y, simd_point.z)
                        
                        let planeAngle = acos(SCNVector3DotProduct(left: vPlane.plane_normal, right: vPlane2.plane_normal) /
                        (SCNVector3Length(vector: vPlane.plane_normal) * SCNVector3Length(vector: vPlane2.plane_normal)))
                        
                        if same_location(p1: vPlane.top_left, p2: vPlane2.top_right){
                            if close_location(p1: edge_point) || planeAngle < 0.7 || !inSight(p1: edge_point) {
                                continue
                            } else if !vPlane.leftEdge && !vPlane2.rightEdge{
//                                print(edge_point, planeAngle)
//                                print(id1)
//                                print(id2)
//                                print(idh)
//                                print("")
                                corners_arr.append(edge_point)
                                draw_edge_points(new_corner: edge_point)
                                vertical_plane_arr[id1]?.leftEdge = true
                                vertical_plane_arr[id2]?.rightEdge = true
                            }
                        }
                        if same_location(p1: vPlane.top_right, p2: vPlane2.top_left){
                            if close_location(p1: edge_point) || planeAngle < 0.7 || !inSight(p1: edge_point) {
                                continue
                            } else if !vPlane.rightEdge && !vPlane2.leftEdge{
//                                print(edge_point, planeAngle)
//                                print(id1)
//                                print(id2)
//                                print(idh)
//                                print("")
                                corners_arr.append(edge_point)
                                draw_edge_points(new_corner: edge_point)
                                vertical_plane_arr[id1]?.rightEdge = true
                                vertical_plane_arr[id2]?.leftEdge = true
                            }
                        }
                    }
                }
            }
        }
    }

    func inSight(p1: SCNVector3) -> Bool{
        let sphereGeom = SCNSphere(radius: 0.03)
        sphereGeom.firstMaterial?.diffuse.contents = UIColor.green
        let tempNode = SCNNode(geometry: sphereGeom)
        tempNode.position = p1
        
        return sceneView.isNode(tempNode, insideFrustumOf: sceneView.pointOfView!)
    }

    func calcCornerRot() {
        if corners_arr.count >= 2 && cornerDetectMode{
            let arrCount = corners_arr.count
            let c1:simd_float3 = simd_float3(corners_arr[0].x, corners_arr[0].y, corners_arr[0].z)
            let c2:simd_float3 = simd_float3(corners_arr[arrCount-1].x, corners_arr[arrCount-1].y, corners_arr[arrCount-1].z)
            
            var rotc = acos((c2.x-c1.x)/simd_length(c2-c1))
            let rots = acos((c2.z-c1.z)/simd_length(c2-c1))

            if rotc >= 1.570796 && rots > 1.570796 {
                rotc = 3.141592 - rotc
            }
            else if rotc >= 1.570796 && rots < 1.570796 {
                rotc = rotc - 3.141592
            }
            else if rotc <= 1.570796 && rots > 1.570796 {
                rotc = -rotc
            }
            
//            let rotmat = simd_float3x3(simd_float3(Float(cos(rotc)), 0, Float(sin(rotc))),
//                                       simd_float3(0,1,0),
//                                       simd_float3(-Float(sin(rotc)), 0, Float(cos(rotc))))
//
//            print(rotc)
//            print(rots)
//
//            print(simd_transpose(rotmat)*c1)
//            print(simd_float3(Float(cos(rotc)) * c1.x + Float(sin(rotc)) * c1.z,
//                              0,
//                              -Float(sin(rotc)) * c1.x + Float(cos(rotc)) * c1.z))
//
//            print(simd_transpose(rotmat)*c2)
//            print(simd_float3(Float(cos(rotc)) * c2.x + Float(sin(rotc)) * c2.z,
//                              0,
//                              -Float(sin(rotc)) * c2.x + Float(cos(rotc)) * c2.z))
            
            rotationValue = rotc
            rotAxisX = simd_float3(Float(cos(-rotationValue)), 0, Float(-sin(-rotationValue)))
            rotAxisZ = simd_float3(Float(sin(-rotationValue)), 0, Float(cos(-rotationValue)))

            pointCloudRenderer.cornerArray = corners_arr
            pointCloudRenderer.rotationValue = rotationValue

            simulationRenderer.rotationValue = rotationValue
            simulationRenderer.rotAxisX = simd_float3(Float(cos(-rotationValue)), 0, Float(-sin(-rotationValue)))
            simulationRenderer.rotAxisZ = simd_float3(Float(sin(-rotationValue)), 0, Float(cos(-rotationValue)))

            modelAC.rotAxisX = simd_float3(Float(cos(-rotationValue)), 0, Float(-sin(-rotationValue)))
            modelAC.rotAxisZ = simd_float3(Float(sin(-rotationValue)), 0, Float(cos(-rotationValue)))
            
//            for (_, plane) in horizontal_plane_arr {
//                sceneView.session.remove(anchor: plane.planeAnchor)
//                plane.planeNode.removeFromParentNode()
//            }
//
//            for (_, plane) in vertical_plane_arr {
//                sceneView.session.remove(anchor: plane.planeAnchor)
//                plane.planeNode.removeFromParentNode()
//            }
            cornerDetectMode = false
            print(rotc)
        }
    }
    
    func startCornerDetection() {
//        for (_, plane) in horizontal_plane_arr {
//            plane.planeNode.geometry?.materials.first?.diffuse.contents = UIColor.red
//        }
//
//        for (_, plane) in vertical_plane_arr {
//            plane.planeNode.geometry?.materials.first?.diffuse.contents = UIColor.blue
//        }
    }

    func draw_edge_points(new_corner: SCNVector3){
        let sphereGeom = SCNSphere(radius: 0.03)
        sphereGeom.firstMaterial?.diffuse.contents = UIColor.green
        let sphereNode = SCNNode(geometry: sphereGeom)
        sphereNode.name = "edgePoint"
        sphereNode.position = new_corner
        sceneView.scene.rootNode.addChildNode(sphereNode)
    }

    func same_location(p1: SCNVector3, p2: SCNVector3) -> Bool {
        if sqrt(pow(p1.x-p2.x, 2) + pow(p1.y - p2.y, 2) + pow(p1.z - p2.z, 2)) < 0.13 { //additional
            return true
        } else {
            return false
        }
    }
        
    // MARK: - rendering

    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        if let imageAnchor = anchor as? ARImageAnchor {
           // if imageAnchor.referenceImage.name == "LGmarker"{
            if imageAnchor.referenceImage.name == "minions"{ //수정 필요
            //if imageAnchor.referenceImage.name == "Aruco"{
                imageDetected = true
                //let box = SCNBox(width: 0.19, height: 0.19, length: 0.03, chamferRadius: 0)
                let box = SCNBox(width: 0.263, height: 0.1479, length: 0.03, chamferRadius: 0)
                //let box = SCNBox(width: 0.33, height: 0.33, length: 0.03, chamferRadius: 0)
                //let box = SCNBox(width: 0.18, height: 0.182, length: 0.03, chamferRadius: 0)
                box.materials.first?.diffuse.contents = UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
                imageBox = SCNNode(geometry: box)
                imageBox.position = node.position
                sceneView.scene.rootNode.addChildNode(imageBox)
                print("add image")
            }
        }
        if let planeAnchor = anchor as? ARPlaneAnchor {
            let plane_width = CGFloat(planeAnchor.extent.x)
            let plane_height = CGFloat(planeAnchor.extent.z)
            let plane = SCNPlane(width: plane_width, height: plane_height)
            
            if cornerDetectMode { ///additional 2
                if planeAnchor.alignment == .horizontal {
                    plane.materials.first?.diffuse.contents = UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
                } else {
                    plane.materials.first?.diffuse.contents = UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
                }
            }
            else {
                plane.materials.first?.diffuse.contents = UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
            }

            let plane_node = SCNNode(geometry: plane)
            let x = CGFloat(planeAnchor.center.x); let y = CGFloat(planeAnchor.center.y); let z = CGFloat(planeAnchor.center.z);
            plane_node.position = SCNVector3(x,y,z)
            plane_node.eulerAngles.x = -Float.pi/2
            plane_node.name = planeAnchor.identifier.uuidString
            node.addChildNode(plane_node)

            let (min, max) = plane_node.boundingBox
            let bottomLeft = SCNVector3(min.x, min.y, 0)
            let topRight = SCNVector3(max.x, max.y, 0)
            let topLeft = SCNVector3(min.x, max.y, 0)
            let bottomRight = SCNVector3(max.x, min.y, 0)
            
            let worldBottomLeft = plane_node.convertPosition(bottomLeft, to: nil)
            let worldTopRight = plane_node.convertPosition(topRight, to: nil)
            let worldTopLeft = plane_node.convertPosition(topLeft, to: nil)
            let worldBottomRight = plane_node.convertPosition(bottomRight, to: nil)
            
            let maxBottom = Float.maximum(worldBottomLeft.y, worldBottomRight.y)
            let maxTop = Float.maximum(worldTopLeft.y, worldTopRight.y)
            let max_y = Float.maximum(maxBottom, maxTop)
            
            let BV = worldBottomLeft - worldTopLeft
            let TV = worldTopRight - worldTopLeft
            var scn_pN = SCNVector3CrossProduct(left: BV, right: TV)
            scn_pN = SCNVector3Normalize(vector: scn_pN) //normal vector of plane
            let pN_d = (worldBottomLeft.x*scn_pN.x + worldBottomLeft.y*scn_pN.y + worldBottomLeft.z*scn_pN.z)
            
            let new_plane_geom = plane_geom(planeNode: plane_node, planeAnchor: planeAnchor, plane_normal: scn_pN, d:pN_d, max_y: max_y, bottom_left: worldBottomLeft, top_left: worldTopLeft, bottom_right: worldBottomRight, top_right: worldTopRight)
            
            if planeAnchor.alignment == .horizontal {
                node.renderingOrder = -1
                // change opacity here
                node.opacity = 0.6
                horizontal_plane_arr[planeAnchor.identifier.uuidString] = new_plane_geom
            }
            else if planeAnchor.alignment == .vertical {
                // change opacity here
                node.opacity = 0.6
                vertical_plane_arr[planeAnchor.identifier.uuidString] = new_plane_geom
            }
        }
    }
        
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        if let imageAnchor = anchor as? ARImageAnchor {
            //if imageAnchor.referenceImage.name == "LGmarker" && imageDetectMode{
            if imageAnchor.isTracked == false {
                sceneView?.session.remove(anchor: anchor)
                print("remove image")
                imageBox.removeFromParentNode()
                return
            }
            if imageAnchor.referenceImage.name == "minions" && imageDetectMode{
            //if imageAnchor.referenceImage.name == "Aruco" && imageDetectMode{
                imagePos = simd_float3(node.position.x, node.position.y, node.position.z)
                
                imageBox.geometry?.materials.first?.diffuse.contents = UIColor.blue
                imageBox.position = node.position
                
                pointCloudRenderer.imagePos = imagePos
                
                //add //add //add
                if node.eulerAngles.x >= 0 {
                    rotationValue = -node.eulerAngles.y
                }
                else {
                    rotationValue = Float.pi+node.eulerAngles.y
                }
                imageBox.rotation = SCNVector4(0.0,1.0,0.0, -1*rotationValue)
                
                rotAxisX = simd_float3(Float(cos(-rotationValue)), 0, Float(-sin(-rotationValue)))
                rotAxisZ = simd_float3(Float(sin(-rotationValue)), 0, Float(cos(-rotationValue)))
                
                pointCloudRenderer.rotationValue = rotationValue
                
                simulationRenderer.rotationValue = rotationValue
                simulationRenderer.rotAxisX = simd_float3(Float(cos(-rotationValue)), 0, Float(-sin(-rotationValue)))
                simulationRenderer.rotAxisZ = simd_float3(Float(sin(-rotationValue)), 0, Float(cos(-rotationValue)))
                
                modelAC.rotAxisX = simd_float3(Float(cos(-rotationValue)), 0, Float(-sin(-rotationValue)))
                modelAC.rotAxisZ = simd_float3(Float(sin(-rotationValue)), 0, Float(cos(-rotationValue)))
            }
        }
        
        //if pause_plane_detection { return }
        if let planeAnchor = anchor as? ARPlaneAnchor {
            guard let plane_node = node.childNodes.first,
                  let plane = plane_node.geometry as? SCNPlane
            else { return }

            let updated_width = CGFloat(planeAnchor.extent.x)
            let updated_height = CGFloat(planeAnchor.extent.z)
            plane.width = updated_width
            plane.height = updated_height

            let new_centerx = CGFloat(planeAnchor.center.x)
            let new_centery = CGFloat(planeAnchor.center.y)
            let new_centerz = CGFloat(planeAnchor.center.z)
            plane_node.position = SCNVector3(new_centerx, new_centery, new_centerz)

            let (min, max) = plane_node.boundingBox
            let bottomLeft = SCNVector3(min.x, min.y, 0)
            let topRight = SCNVector3(max.x, max.y, 0)
            let topLeft = SCNVector3(min.x, max.y, 0)
            let bottomRight = SCNVector3(max.x, min.y, 0)
            
            let worldBottomLeft = plane_node.convertPosition(bottomLeft, to: nil)
            let worldTopRight = plane_node.convertPosition(topRight, to: nil)
            let worldTopLeft = plane_node.convertPosition(topLeft, to: nil)
            let worldBottomRight = plane_node.convertPosition(bottomRight, to: nil)
            
            let maxBottom = Float.maximum(worldBottomLeft.y, worldBottomRight.y)
            let maxTop = Float.maximum(worldTopLeft.y, worldTopRight.y)
            let max_y = Float.maximum(maxBottom, maxTop)
            
            let BV = worldBottomLeft - worldTopLeft
            let TV = worldTopRight - worldTopLeft
            var scn_pN = SCNVector3CrossProduct(left: BV, right: TV)
            scn_pN = SCNVector3Normalize(vector: scn_pN)
            let pN_d = (worldBottomLeft.x*scn_pN.x + worldBottomLeft.y*scn_pN.y + worldBottomLeft.z*scn_pN.z)

            var updated_geom = plane_geom()
            updated_geom.planeNode = plane_node
            updated_geom.planeAnchor = planeAnchor
            updated_geom.plane_normal = scn_pN
            updated_geom.d = pN_d
            updated_geom.max_y = max_y
            updated_geom.bottom_left = worldBottomLeft
            updated_geom.top_left = worldTopLeft
            updated_geom.bottom_right = worldBottomRight
            updated_geom.top_right = worldTopRight
            
            // update exisiting plane geometry -> might not need this...
            if planeAnchor.alignment == .horizontal {
                for (id_, _) in horizontal_plane_arr {
                    if anchor.identifier.uuidString == id_ {
                        horizontal_plane_arr[planeAnchor.identifier.uuidString] = updated_geom
                    }
                    // update plane with max y value
                    let max_bottom_side = Float.maximum(updated_geom.bottom_left.y, updated_geom.bottom_right.y)
                    let max_top_side = Float.maximum(updated_geom.top_left.y, updated_geom.top_right.y)
                    let max_y = Float.maximum(max_bottom_side, max_top_side)
                    if(max_y > plane_max_y.1){
                        plane_max_y.0 = planeAnchor.identifier.uuidString
                        plane_max_y.1 = max_y
                    }
                }
            }

            else if planeAnchor.alignment == .vertical {
                for (id_, _) in vertical_plane_arr {
                    if planeAnchor.identifier.uuidString == id_ && (vertical_plane_arr[planeAnchor.identifier.uuidString]?.rightEdge == false || vertical_plane_arr[planeAnchor.identifier.uuidString]?.leftEdge == false) {
                        vertical_plane_arr[planeAnchor.identifier.uuidString] = updated_geom
                    }
                }
            }
            
            if cornerDetectMode {
                if let currentFrame = sceneView.session.currentFrame {
                    let camera = currentFrame.camera
                    let view_matrix = camera.viewMatrix(for: UIInterfaceOrientation.landscapeRight).transpose.inverse
                    let eye = simd_float3(view_matrix[0,3], view_matrix[1,3], view_matrix[2,3])
                    
                    for (idh, horizontal_) in horizontal_plane_arr {
                        if horizontal_.max_y > eye.y && (abs(horizontal_.max_y - plane_max_y.1) < 0.04 || abs(horizontal_.max_y - plane_max_y.1) > 0.4) {
                             //find_corners(hPlane: horizontal_, idh: idh)
                        } else {
                            continue
                        }
                    }
                } else { print("could not get current frame") }
            }
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) { //additional
        guard let planeAnchor = anchor as? ARPlaneAnchor
        else { return }
        
        if planeAnchor.alignment == .vertical{
            if let removeGeom = vertical_plane_arr[planeAnchor.identifier.uuidString] {
                var geoArr:[String:plane_geom] = [:]
                
                for (ids, planeGeo) in vertical_plane_arr {
                    if ids != planeAnchor.identifier.uuidString {
                        let planeAngle_norm = acos(SCNVector3DotProduct(left: removeGeom.plane_normal, right: planeGeo.plane_normal)/(SCNVector3Length(vector: removeGeom.plane_normal) * SCNVector3Length(vector: planeGeo.plane_normal)))
                        
                        if planeAngle_norm < 0.7 {
                            let centerVec = removeGeom.planeNode.position - planeGeo.planeNode.position
                            
                            let planeAngle_op = acos(SCNVector3DotProduct(left: removeGeom.plane_normal, right: centerVec) / (SCNVector3Length(vector: removeGeom.plane_normal) * SCNVector3Length(vector: centerVec)))
                            
                            if planeAngle_op - Float.pi/2 < 0.7 {
                                geoArr[ids] = planeGeo
                            }
                        }
                    }
                }
                
                for (ids, _) in geoArr {
                    if ids != planeAnchor.identifier.uuidString {
                        if vertical_plane_arr[planeAnchor.identifier.uuidString]?.leftEdge == true {
                            vertical_plane_arr[ids]?.leftEdge = true
                        }
                        if vertical_plane_arr[planeAnchor.identifier.uuidString]?.rightEdge == true {
                            vertical_plane_arr[ids]?.rightEdge = true
                        }
                    }
                }
                vertical_plane_arr.removeValue(forKey: planeAnchor.identifier.uuidString)
            }
        }
    }
    
    
    func continuousUILabelUpdate(){
        DispatchQueue.main.async {
            if self.simulationRenderer.currentVisualization == "RGB" {
                return
            }
            else if self.simulationRenderer.currentVisualization == "Volume" {
                self.plane_slider_label.text = "Distance: \(String(format: "%.2f", self.simulationRenderer.nearNum))m"
            }
            else if self.simulationRenderer.currentVisualization == "Flow and Volume" {
                self.plane_slider_label.text = "Distance: \(String(format: "%.2f", self.simulationRenderer.nearNum))m"
            }
            else if self.simulationRenderer.currentVisualization == "Dense Particle" {
                self.plane_slider_label.text = "Distance: \(String(format: "%.2f", self.simulationRenderer.particleDistance))m"
            }
            else if self.simulationRenderer.currentVisualization == "Pinpoint" {
                self.plane_slider_label.text = "Distance: \(String(format: "%.2f", self.simulationRenderer.cameraToPoint))m"
            }
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, willRenderScene scene: SCNScene, atTime time: TimeInterval) {
        pointCloudRenderer.draw()
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
        guard let commandEncoder = sceneView.currentRenderCommandEncoder else { return }
        
        if simulationRenderer.currentVisualization == "OccupancyGrid" {
            simulationRenderer.renderOccupancyGrid(commandEncoder: commandEncoder)
        }
        
        else if current_view == "simulation" && simulationRenderer.acInstalled {
            if simulationRenderer.currentVisualization == "Vector" {
                simulationRenderer.renderArrows(commandEncoder: commandEncoder)
            }
            else if simulationRenderer.currentVisualization == "Volume" {
                simulationRenderer.renderVolume(commandEncoder: commandEncoder)
            }
            else if simulationRenderer.currentVisualization == "Particle" {
                simulationRenderer.renderParticles(commandEncoder: commandEncoder)
            }
            else if simulationRenderer.currentVisualization == "Dense Particle" {
                simulationRenderer.renderDenseParticles(commandEncoder: commandEncoder)
            }
            else if simulationRenderer.currentVisualization == "Flow and Volume" {
                simulationRenderer.renderArrows(commandEncoder: commandEncoder)
                simulationRenderer.renderVolume(commandEncoder: commandEncoder)
            }
            else if simulationRenderer.currentVisualization == "Surface" {
                simulationRenderer.renderLine(commandEncoder: commandEncoder)
                simulationRenderer.renderSurface(commandEncoder: commandEncoder)
            }
        }
        continuousUILabelUpdate()
    }
     
        
    // MARK: - Defaults
    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var shouldAutorotate: Bool {
        return false
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .allButUpsideDown
        } else {
            return .all
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }
}

//MARK: - SCNExtension
public extension SCNVector3
{
    enum Axis {
        case x, y, z
        
        func getAxisVector() -> simd_float3 {
            switch self {
            case .x:
                return simd_float3(1,0,0)
            case .y:
                return simd_float3(0,1,0)
            case .z:
                return simd_float3(0,0,1)
            }
        }
    }

    func rotatedVector(aroundAxis: Axis, angle: Float) -> SCNVector3 {
        /// create quaternion with angle in radians and your axis
        let q = simd_quatf(angle: angle, axis: aroundAxis.getAxisVector())
        
        /// use ACT method of quaternion
        let simdVector = q.act(simd_float3(self))
        
        return SCNVector3(simdVector)
    }
    /**
    * Negates the vector described by SCNVector3 and returns
    * the result as a new SCNVector3.
    */
    func negate() -> SCNVector3 {
        return self * -1
    }

    /**
    * Negates the vector described by SCNVector3
    */
    mutating func negated() -> SCNVector3 {
        self = negate()
        return self
    }

    /**
    * Returns the length (magnitude) of the vector described by the SCNVector3
    */
    func length() -> Float {
        return sqrtf(x*x + y*y + z*z)
    }

    /**
    * Normalizes the vector described by the SCNVector3 to length 1.0 and returns
    * the result as a new SCNVector3.
    */
    func normalized() -> SCNVector3 {
        return self / length()
    }

    /**
    * Normalizes the vector described by the SCNVector3 to length 1.0.
    */
    mutating func normalize() -> SCNVector3 {
        self = normalized()
        return self
    }

    /**
    * Calculates the distance between two SCNVector3. Pythagoras!
    */
    func distance(vector: SCNVector3) -> Float {
        return (self - vector).length()
    }

    /**
    * Calculates the dot product between two SCNVector3.
    */
    func dot(vector: SCNVector3) -> Float {
        return x * vector.x + y * vector.y + z * vector.z
    }

    /**
    * Calculates the cross product between two SCNVector3.
    */
    func cross(vector: SCNVector3) -> SCNVector3 {
        return SCNVector3Make(y * vector.z - z * vector.y, z * vector.x - x * vector.z, x * vector.y - y * vector.x)
    }
}

public extension SCNGeometry {
    class func cylinderLine(from: SCNVector3,
                              to: SCNVector3,
                        segments: Int) -> SCNNode {

        let x1 = from.x
        let x2 = to.x

        let y1 = from.y
        let y2 = to.y

        let z1 = from.z
        let z2 = to.z

        let distance =  sqrtf( (x2-x1) * (x2-x1) +
                               (y2-y1) * (y2-y1) +
                               (z2-z1) * (z2-z1) )

        let cylinder = SCNCylinder(radius: 0.0022,
                                   height: CGFloat(1))
        
        cylinder.radialSegmentCount = segments

        cylinder.firstMaterial?.diffuse.contents = UIColor(red: 0.8, green: 0.8, blue: 1, alpha: 0.8)

        let lineNode = SCNNode(geometry: cylinder)

        lineNode.position = SCNVector3(x: (from.x + to.x) / 2,
                                       y: (from.y + to.y) / 2,
                                       z: (from.z + to.z) / 2)
        
        lineNode.scale = SCNVector3(1,distance,1)

        lineNode.eulerAngles = SCNVector3(Float.pi / 2,
                                          acos((to.z-from.z)/distance),
                                          atan2((to.y-from.y),(to.x-from.x)))

        return lineNode
    }
}

/**
* Adds two SCNVector3 vectors and returns the result as a new SCNVector3.
*/
public func + (left: SCNVector3, right: SCNVector3) -> SCNVector3 {
    return SCNVector3Make(left.x + right.x, left.y + right.y, left.z + right.z)
}

/**
* Increments a SCNVector3 with the value of another.
*/
public func += ( left: inout SCNVector3, right: SCNVector3) {
    left = left + right
}

/**
* Subtracts two SCNVector3 vectors and returns the result as a new SCNVector3.
*/
public func - (left: SCNVector3, right: SCNVector3) -> SCNVector3 {
    return SCNVector3Make(left.x - right.x, left.y - right.y, left.z - right.z)
}

/**
* Decrements a SCNVector3 with the value of another.
*/
public func -= ( left: inout SCNVector3, right: SCNVector3) {
    left = left - right
}

/**
* Multiplies two SCNVector3 vectors and returns the result as a new SCNVector3.
*/
public func * (left: SCNVector3, right: SCNVector3) -> SCNVector3 {
    return SCNVector3Make(left.x * right.x, left.y * right.y, left.z * right.z)
}

/**
* Multiplies a SCNVector3 with another.
*/
public func *= ( left: inout SCNVector3, right: SCNVector3) {
    left = left * right
}

/**
* Multiplies the x, y and z fields of a SCNVector3 with the same scalar value and
* returns the result as a new SCNVector3.
*/
public func * (vector: SCNVector3, scalar: Float) -> SCNVector3 {
    return SCNVector3Make(vector.x * scalar, vector.y * scalar, vector.z * scalar)
}

/**
* Multiplies the x and y fields of a SCNVector3 with the same scalar value.
*/
public func *= ( vector: inout SCNVector3, scalar: Float) {
    vector = vector * scalar
}

/**
* Divides two SCNVector3 vectors abd returns the result as a new SCNVector3
*/
public func / (left: SCNVector3, right: SCNVector3) -> SCNVector3 {
    return SCNVector3Make(left.x / right.x, left.y / right.y, left.z / right.z)
}

/**
* Divides a SCNVector3 by another.
*/
public func /= ( left: inout SCNVector3, right: SCNVector3) {
    left = left / right
}

/**
* Divides the x, y and z fields of a SCNVector3 by the same scalar value and
* returns the result as a new SCNVector3.
*/
public func / (vector: SCNVector3, scalar: Float) -> SCNVector3 {
    return SCNVector3Make(vector.x / scalar, vector.y / scalar, vector.z / scalar)
}

/**
* Divides the x, y and z of a SCNVector3 by the same scalar value.
*/
public func /= ( vector: inout SCNVector3, scalar: Float) {
    vector = vector / scalar
}

/**
* Negate a vector
*/
public func SCNVector3Negate(vector: SCNVector3) -> SCNVector3 {
    return vector * -1
}

/**
* Returns the length (magnitude) of the vector described by the SCNVector3
*/
public func SCNVector3Length(vector: SCNVector3) -> Float
{
    return sqrtf(vector.x*vector.x + vector.y*vector.y + vector.z*vector.z)
}

/**
* Returns the distance between two SCNVector3 vectors
*/
public func SCNVector3Distance(vectorStart: SCNVector3, vectorEnd: SCNVector3) -> Float {
    return SCNVector3Length(vector: vectorEnd - vectorStart)
}

/**
* Returns the distance between two SCNVector3 vectors
*/
public func SCNVector3Normalize(vector: SCNVector3) -> SCNVector3 {
    return vector / SCNVector3Length(vector: vector)
}

/**
* Calculates the dot product between two SCNVector3 vectors
*/
public func SCNVector3DotProduct(left: SCNVector3, right: SCNVector3) -> Float {
    return left.x * right.x + left.y * right.y + left.z * right.z
}

/**
* Calculates the cross product between two SCNVector3 vectors
*/
public func SCNVector3CrossProduct(left: SCNVector3, right: SCNVector3) -> SCNVector3 {
    return SCNVector3Make(left.y * right.z - left.z * right.y, left.z * right.x - left.x * right.z, left.x * right.y - left.y * right.x)
}

/**
* Calculates the SCNVector from lerping between two SCNVector3 vectors
*/
public func SCNVector3Lerp(vectorStart: SCNVector3, vectorEnd: SCNVector3, t: Float) -> SCNVector3 {
    return SCNVector3Make(vectorStart.x + ((vectorEnd.x - vectorStart.x) * t), vectorStart.y + ((vectorEnd.y - vectorStart.y) * t), vectorStart.z + ((vectorEnd.z - vectorStart.z) * t))
}

/**
* Project the vector, vectorToProject, onto the vector, projectionVector.
*/
public func SCNVector3Project(vectorToProject: SCNVector3, projectionVector: SCNVector3) -> SCNVector3 {
    let scale: Float = SCNVector3DotProduct(left: projectionVector, right: vectorToProject) / SCNVector3DotProduct(left: projectionVector, right: projectionVector)
    let v: SCNVector3 = projectionVector * scale
    return v
}
