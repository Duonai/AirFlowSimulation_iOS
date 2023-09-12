//
//  SimulationSettingsVC.swift
//  AirSim_IEEEVR
//
//  Created by Donghan Kim on 2021/08/17.
//

import UIKit

class SimulationSettingsVC: UIViewController {

    
    
    @IBOutlet weak var renderTypePicker: UIPickerView!
    @IBOutlet weak var apply_change_button: UIButton!
    let renderTypeOptions = ["Vectors", "Volume", "Animation", "Streamline", "SinWave"]
    
    var current_render_type:String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        renderTypePicker.delegate = self
        renderTypePicker.dataSource = self
        
        renderTypePicker.selectRow(0, inComponent: 0, animated: true)
        apply_change_button.layer.cornerRadius = 5
    }
    
    @IBAction func send_changes(_ sender: Any) {
        let locationData:[String: String] = ["renderType": current_render_type]
        NotificationCenter.default.post(name: Notification.Name(rawValue: "settingsChanged"), object: self, userInfo: locationData)
        self.dismiss(animated: true, completion: nil)
    }
    
}

extension SimulationSettingsVC: UIPickerViewDelegate, UIPickerViewDataSource {
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return "\(renderTypeOptions[row])"
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        let idx = pickerView.selectedRow(inComponent: 0)
        current_render_type = renderTypeOptions[idx]
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return 5
    }

}
