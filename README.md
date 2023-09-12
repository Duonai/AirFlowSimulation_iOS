# AirFlow Simulation on iOS
This respository contains code for running FFD graphic simulations on a mobile iOS device. LiDAR equip device required. The current screen dimensions are set to the iPad Pro 12.9 inch variant.

## Installation and Build Steps
This respository uses cocoapods. First make sure cocoapods is installed in your system.

```bash
sudo gem install cocoapods
```

Clone this repository and change the current directory to the cloned respository in your terminal:
```bash
git clone https://github.com/donghankim/AirFlowSimulation.git
cd PROJECT_LOCATION/
```

Init Pod and install all pod dependecies listed in Podfile
```bash
pod init
pod install
```

Make sure there are no errors. When opening xcode project, make sure you open the project with <b>.xcworkspace</b> extension. Do not open the project with .xcodeproj extension.

## Model Setup
The airconditioner (AC) models used for this project are of <b>.scn</b> type. Make sure you convert all ac model files into .scn type, and place it in the <b>art.scnassets</b> folder.
