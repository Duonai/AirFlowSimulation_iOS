//
//  SimulationSettingsVC.swift
//  AirSim_IEEEVR
//
//  Created by Donghan Kim on 2021/08/17.
//

import UIKit

class SettingsVC: UIViewController {
    
    @IBOutlet weak var wall_ac_button: UIButton!
    @IBOutlet weak var ceiling_ac_button: UIButton!
    @IBOutlet weak var stand_ac_button: UIButton!
    @IBOutlet weak var ac_description: UILabel!
    @IBOutlet weak var apply_button: UIButton!
    
    var ac_model:String = "ceiling"


    override func viewDidLoad() {
        super.viewDidLoad()
        
        var wall_ac_config = UIButton.Configuration.plain()
        wall_ac_config.image = UIImage(named: "lg_wall_ac.png")
        wall_ac_config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
        
        var ceiling_ac_config = UIButton.Configuration.plain()
        ceiling_ac_config.image = UIImage(named: "lg_ceiling_ac.jpeg")
        ceiling_ac_config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
        
        var stand_ac_config = UIButton.Configuration.plain()
        stand_ac_config.image = UIImage(named: "lg_stand_ac.png")
        stand_ac_config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
        
        wall_ac_button.configuration = wall_ac_config
        wall_ac_button.layer.cornerRadius = 5
        wall_ac_button.imageView?.contentMode = .scaleAspectFit
        
        ceiling_ac_button.configuration = ceiling_ac_config
        ceiling_ac_button.layer.cornerRadius = 5
        ceiling_ac_button.imageView?.contentMode = .scaleAspectFit
        
        stand_ac_button.configuration = stand_ac_config
        stand_ac_button.layer.cornerRadius = 5
        stand_ac_button.imageView?.contentMode = .scaleAspectFit
        
        updateUI()

    }
    
    func updateUI(){
        if ac_model == "wall" {
            wall_ac_button.layer.borderWidth = 2.0
            wall_ac_button.layer.borderColor = CGColor(red:0.0, green:0.0, blue:1.0, alpha: 0.5)
            ceiling_ac_button.layer.borderWidth = 0.0
            stand_ac_button.layer.borderWidth = 0.0
            ac_description.text = "Wall-mounted air conditioner.\n Installation can only be done on vertical planes."
            
        }
        if ac_model == "ceiling" {
            ceiling_ac_button.layer.borderWidth = 2.0
            ceiling_ac_button.layer.borderColor = CGColor(red:0.0, green:0.0, blue:1.0, alpha: 0.5)
            wall_ac_button.layer.borderWidth = 0.0
            stand_ac_button.layer.borderWidth = 0.0
            ac_description.text = "Ceiling-mounted air conditioner.\n Installation can only be done on horizontal planes."
        }
        //if ac_model == "stand" {
        if ac_model == "tower" {
            stand_ac_button.layer.borderWidth = 2.0
            stand_ac_button.layer.borderColor = CGColor(red:0.0, green:0.0, blue:1.0, alpha: 0.5)
            wall_ac_button.layer.borderWidth = 0.0
            ceiling_ac_button.layer.borderWidth = 0.0
            ac_description.text = "Floor standing air conditioner.\n Installation can only be done on horizontal planes."
        }
    }
    
    @IBAction func send_changes(_ sender: Any) {
        let locationData:[String: String] = ["ac_model": ac_model]
        NotificationCenter.default.post(name: Notification.Name(rawValue: "settingsChanged"), object: self, userInfo: locationData)
        self.dismiss(animated: true)
    }
    
    @IBAction func wall_ac_clicked(_ sender: Any){
        ac_model = "wall"
        updateUI()
    }
    @IBAction func ceiling_ac_clicked(_ sender: Any){
        ac_model = "ceiling"
        updateUI()
    }
    @IBAction func stand_ac_clicked(_ sender: Any){
        //ac_model = "stand"
        ac_model = "tower"
        updateUI()
    }
}
