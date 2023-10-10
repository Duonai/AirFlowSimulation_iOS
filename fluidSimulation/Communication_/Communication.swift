//
//  File.swift
//  File
//
//  Created by 정우석 on 2021/10/12.
//

import Foundation

class Communication {
    //let addr = "163.152.162.106" //161.214
    //let addr = "163.152.161.214" //162.106
    //let addr = "223.195.36.220" //161.214
    //let addr = "192.168.0.236"
    //let addr = "172.31.38.200"

    var addr = "163.152.162.108"
    let port = 1235
    let client : TCPClient
    
    private var addrSet = false
    
    // Simulation info
    private var gridSizeX:Int
    private var gridSizeY:Int
    private var gridSizeZ:Int
    private var gridSize3:Int
    
    // Send data - Air controller info
    private var acType:Int = 0
    private var acDirection:Int = 0
    private var acPosition = [0, 0, 0]
    private var acVentLevel:Int = 1
    private var acVentSpeed:Int = 6
    private var acReset = false
    private var currentTemp = Float(0.0)
    private var targetTemp = Float(1.0)

    // Send data - occupancy grid
    private var occupancyGrid = [Bool]()
    private var occupancyGridTemp : [Bool]?
    private var changeOccIndex = [UInt32]()
    
    // Send data - BIM
    private var distXL:Float = Float(0.0)
    private var distXR:Float = Float(0.0)
    private var distYU:Float = Float(0.0)
    private var distYD:Float = Float(0.0)
    private var roomSizeX:Float = Float(0.0)
    private var roomSizeY:Float = Float(0.0)
    private var roomSizeZ:Float = Float(0.0)
    private var roomNum:UInt16  = 0
    
    // Send & Receive data for graph
    private var drawGraph:Bool = false
    private var targetPosition:[UInt16] = [0, 0, 0]
    private var graphInfo = [Float]()
    
    // Receive data - physical value
    private var velocity = [Float]()
    private var temperature = [Float]()
    private var tempPhysicsValue = [Float]()
    private var phyPacket : Packet?
    
    private var occupancyUpdated = false;
    var occupancySent = false;  // Is initial occupancy snet?
    var acInfoUpdated = false;
    var ACfirstInstalled = false;
    private var timeLater:Byte = 0x00;
    private var jumpSet = false;
    private var jumpDone = true;
    private var graphDone = true;
    private var loadDone = false;
    private var connectDone = false;
    
    private var lock_ac = NSLock()
    private var lock_occ = NSLock()
    private var lock_occchange = NSLock()
    private var lock_phy = NSLock()
    private var lock_load = NSLock()
    
    private var connectType:Type
    
    // methods
    convenience init(gridSize:Int){
        self.init(gridSizeX:gridSize, gridSizeY:gridSize, gridSizeZ:gridSize)
        //makeConnection()
    }
    
    init(gridSizeX:Int, gridSizeY:Int, gridSizeZ:Int){

        client = TCPClient(port: Int32(port))
        self.gridSizeX = 64
        self.gridSizeY = 64
        self.gridSizeZ = 64
        self.gridSize3 = gridSizeX * gridSizeY * gridSizeZ
        acPosition = [gridSizeX/2, gridSizeY-1, gridSizeZ/2]
        //makeConnection()
        
        connectType = Type.initData
//        print("Float: ", MemoryLayout<Float>.size)
//        print("int 16: ", MemoryLayout<Int16>.size)
//        print("int 32: ", MemoryLayout<Int32>.size)
//        print("int 64: ", MemoryLayout<Int64>.size)
//        let temp:Byte = 0x14
//        print("byte sample", temp)
    }
    
    func initialize(gridSizeX:Int, gridSizeY:Int, gridSizeZ:Int){
        self.gridSizeX = gridSizeX
        self.gridSizeY = gridSizeY
        self.gridSizeZ = gridSizeZ
        self.gridSize3 = gridSizeX * gridSizeY * gridSizeZ
        acPosition = [gridSizeX/2, gridSizeY-1, gridSizeZ/2]

        tempPhysicsValue.reserveCapacity(gridSize3*4)
        velocity.reserveCapacity(gridSize3*3)
        temperature.reserveCapacity(gridSize3)
        occupancyGrid.reserveCapacity(gridSize3)
        
        occupancyGrid = [Bool].init(repeating: false, count: gridSize3)
        tempPhysicsValue = [Float].init(repeating: 0.0, count: gridSize3 * 4)
        velocity = [Float].init(repeating: 0.0, count: gridSize3 * 3)
        temperature = [Float].init(repeating: 0.0, count: gridSize3)
        
        connectType = Type.provideSpaceInfo
    }
    
    func initializeForBIM(gridSizeX:Int, gridSizeY:Int, gridSizeZ:Int, distXL:Float, distXR:Float, distYU:Float, distYD:Float, roomSizeX:Float, roomSizeY:Float, roomSizeZ:Float, roomNum:UInt16){
        self.gridSizeX = gridSizeX
        self.gridSizeY = gridSizeY
        self.gridSizeZ = gridSizeZ
        self.gridSize3 = gridSizeX * gridSizeY * gridSizeZ
        
        self.distXL = distXL
        self.distXR = distXR
        self.distYU = distYU
        self.distYD = distYD
        
        self.roomSizeX = roomSizeX
        self.roomSizeY = roomSizeY
        self.roomSizeZ = roomSizeZ
        
        self.roomNum = roomNum
        
        occupancyGrid.reserveCapacity(gridSize3)
        occupancyGrid = [Bool].init(repeating: false, count: gridSize3)
        
        connectType = Type.storeBIM
    }
    
    func storeAddr(address: String){
        //addr = "163.152.161.221"  //add //add //add //add
        addr = "192.168.1.7"
        //addr = "163.152.161.114"
        //addr = "163.152.161.214"
        client.setAddr(address: addr)
        addrSet = true
    }
    
    func storeTimeLater(time: Int){
        jumpSet = true
        timeLater = Byte(time)
        print("store time")
    }
    
    func resetTimeLater(){
        timeLater = 0
    }
    
    func getVelocity() -> [Float]{
        return velocity
    }
    
    func getTemperature() ->[Float] {
        return temperature
    }
    
    func getDistance()->[Float] {
        var data:[Float] = []
        
        data.append(distXR)
        data.append(distXL)
        data.append(distYU)
        data.append(distYD)
        
        return data
    }
    
    func getRoomSize()->[Float] {
        var data:[Float] = []
        
        data.append(roomSizeX)
        data.append(roomSizeY)
        data.append(roomSizeZ)
        
        return data
    }
    
    func getGridSize()->[Int] {
        var data:[Int] = []
        
        data.append(gridSizeX)
        data.append(gridSizeY)
        data.append(gridSizeZ)
        
        return data
    }
    
    func getOccupancyGrid()->[Bool] {
        return occupancyGrid
    }
    
    func getGraphInfo()->[Float] {
        return graphInfo
    }
    
    func getJumpDone()->Bool {
        return jumpDone
    }
    
    func getJumpSet()->Bool {
        return jumpSet
    }
    
    func getGraphDone()->Bool {
        return graphDone
    }
    
    func getLoadDone()->Bool {
        return loadDone
    }
    
    func getConnectDone()->Bool {
        return connectDone
    }
    
    func setRequestBIMType() {
        self.connectType = Type.requestBIM
    }
    
    func setRoomNum(RoomNum:UInt16) {
        self.roomNum = RoomNum
    }

    // MARK: update ac info
    func updateACPosition(x posx:Int, y posy:Int, z posz:Int){
        if self.acPosition != [posx, posy, posz] {
            acPosition = [posx, posy, posz]
            acInfoUpdated = true
        }
    }
    
    func updateACDirection(dir:Int){
        if self.acDirection != dir {
            acDirection = dir
            acInfoUpdated = true
        }
    }
    
    func updateACVentLevel(level:Int)
    {
        if (self.acVentLevel != level) &&
            level > 0 &&
            level < 8 {
            self.acVentLevel = level
            acInfoUpdated = true
        }
    }
    
    func updateACVentSpeed(speed:Int){
        if (self.acVentSpeed != speed) &&
            speed > 0 &&
            speed < 6 {
            self.acVentSpeed = speed
            acInfoUpdated = true
        }
    }
    
    func updateACReset()
    {
        acReset = true
        acInfoUpdated = true
    }
    
    func updateACInfo(type:Int, position:[Int])
    {
        lock_ac.lock()
      
        if (acType != type){   ///
            acType = type
            acInfoUpdated = true
        }
        
        if (acPosition != position){
            acPosition = position
            acInfoUpdated = true
        }
        
        lock_ac.unlock()
    }
    
    // MARK: update occupancy grid
    func updateOccupancy(grid:[Bool]){
        if (lock_occ.try()){
            /*if(grid == [false,]){
                return
            }*/
            occupancyGridTemp = grid
            //occupancyGridTemp = grid.map{$0}
            OperationQueue().addOperation{
                if (self.occupancyGridTemp != nil) {
                    if (self.occupancySent && self.lock_occchange.try()) {
                            if(self.changeOccIndex.count != 0) {
                                self.changeOccIndex = []
                            }
                        
                            for i in 0..<self.occupancyGrid.count {
                                if(self.occupancyGridTemp![i] != self.occupancyGrid[i]){
                                    self.changeOccIndex.append(UInt32(i))
                                }
                            }
                        self.lock_occchange.unlock()
                    }
                    self.occupancyGrid = self.occupancyGridTemp!
                }
                self.occupancyGridTemp = nil
                self.lock_occ.unlock()
                
                if (self.changeOccIndex.count > 0) {
                    self.occupancyUpdated = true
                }
            } // end queue
        }
    }
    
    func updateTargetPosForGraph(X:UInt16, Y:UInt16, Z:UInt16){
        targetPosition[0] = X
        targetPosition[1] = Y
        targetPosition[2] = Z
        
        graphDone = false
        //print(graphDone)
        drawGraph = true
    }
    
    // MARK: connection
    func makeConnection() -> Result{
        if(!addrSet){
            return .failure(SocketError.unknownError)
        }
        
        OperationQueue().addOperation{
            let client_return = self.client.connect(timeout:2)
            
            switch client_return
            {
            case .success:
                OperationQueue().addOperation{
                    self.work(type:self.connectType)
                }
                self.connectDone = true
            case .failure(_):
                print("error:Connect Fail")
                self.connectDone = false
            }
        }
        
        return .success
    }

    //private methods
    private func work(type:Type){
        switch(type){
        case Type.provideSpaceInfo:
            if(sendSpaceInfo())
            {
                //print("space")
                receive()
            }
        case Type.storeBIM:
            if(sendSaveBIM())
            {
                receive()
            }
            break;
        case Type.requestBIM:
            if(sendRequestBIM())
            {
                receive()
            }
            if(sendSpaceInfo())
            {
                receive()
            }
        default:
            print("error:Start Type Error")
        }
        
        sleep(2)
        while(type != Type.storeBIM)
        {
            if (send())
            {
                receive()
            }
        }
    }
    
    private func send() -> Bool { // return for needing feedback(receive)
        if (occupancyUpdated || !occupancySent) {
            //print("Occ")
            return selectOccType()
        }
        
        else if (acInfoUpdated) {
            acInfoUpdated = false
            //print("AC")
            return sendACInfo()
        }
        
        else if (drawGraph){
            drawGraph = false
            return sendRequestGraph()
        }
        
        // always send
        //print("flow")
        //return true
        else if (ACfirstInstalled){
            return sendRequestPhysicsData()
        }
        
        return false
    }
    
    private func selectOccType() -> Bool
    {
        if (!occupancySent) {
            let rst = sendOccupancy()
            occupancySent = rst
            return  rst
        }
        occupancyUpdated = false
        return sendOccupancyIndex() // Index
    }
    
    private func sendSpaceInfo() -> Bool {
        let msg = Packet(size: MemoryLayout<Int32>.size * 3 +
                         MemoryLayout<Int32>.size + 1 )
        msg.push_byte(data: Type.provideSpaceInfo.returnChar())
        msg.push_int32(data: Int32(gridSizeX))
        msg.push_int32(data: Int32(gridSizeY))
        msg.push_int32(data: Int32(gridSizeZ))
        
        //print(Type.provideSpaceInfo.returnChar())
        return sendData(msg:msg)
    }
    
    // private send method
    private func sendACInfo() -> Bool {
        let msg = Packet(size: acPosition.count * MemoryLayout<Int32>.size +
                         //acVent.count * MemoryLayout<Float>.size +
                         MemoryLayout<Int32>.size * 4  +  // type, ventLevel, ventSpeed
                         MemoryLayout<Bool>.size +      // for reset button
                         MemoryLayout<Float>.size * 2 +
                         MemoryLayout<Int32>.size + 1 )
        msg.push_byte(data: Type.provideACInfo.returnChar())
        
        msg.push_int32(data: Int32(acType))
        msg.push_int32(data: Int32(acDirection))
        
        for i in acPosition{
            msg.push_int32(data: Int32(i))
        }
        
        msg.push_int32(data: Int32(acVentLevel))
        msg.push_int32(data: Int32(acVentSpeed))
        
        msg.push_bool(data: acReset)
        
        msg.push_single(data: currentTemp)
        msg.push_single(data: targetTemp)
        //print(Type.provideACInfo.returnChar())
        return sendData(msg:msg)
    }
    
    private func sendOccupancy() -> Bool {
        let msg = Packet(size: occupancyGrid.count + MemoryLayout<Int32>.size + 1)
        msg.push_byte(data: Type.provideOccupancy.returnChar())
        
        for i in 0..<occupancyGrid.count {
            msg.push_bool(data: occupancyGrid[i])
        }
        
        //print(Type.provideOccupancy.returnChar())
        return sendData(msg:msg)
    }
    
    private func sendOccupancyIndex() -> Bool {
        lock_occchange.lock()
        let msg = Packet(size: changeOccIndex.count * 4 + MemoryLayout<Int32>.size + 1)
        msg.push_byte(data: Type.provideOccupancy.returnChar())
        
        for i in 0..<changeOccIndex.count {
            msg.push_Uint32(data: changeOccIndex[i])
        }
        changeOccIndex = []
        lock_occchange.unlock()
        
        //print(Type.provideOccupancy.returnChar())
        return sendData(msg: msg)
    }
    
    private func sendRequestPhysicsData() -> Bool {
        let msg = Packet(size: 1 + MemoryLayout<Int32>.size + 1)
        msg.push_byte(data: Type.requestPhysicalValue.returnChar())
        msg.push_byte(data: timeLater)
        if (jumpSet){
            jumpDone = false
        }
        resetTimeLater()
        //print(Type.requestPhysicalValue.returnChar())
        
//        let today = Date()
//        let formatter = DateFormatter()
//        formatter.dateFormat = "ss\tSSSS\t"
//        let timeString = "send request: " + formatter.string(from: today)
//
//        print(timeString)
        return sendData(msg:msg)
    }
    
    private func sendData(msg:Packet) -> Bool {
        if !connectDone {
            return false
        }
        
        let server_return = client.send(data: msg.get_buffer())
        
        if (server_return.isFailure){
            print("error:Send Fail")
        }
        
        return server_return.isSuccess
    }
    
    private func sendRequestBIM() -> Bool{
        let msg = Packet(size: MemoryLayout<Int32>.size + MemoryLayout<UInt16>.size + 1)
        msg.push_byte(data: Type.requestBIM.returnChar())
        msg.push_UInt16(data: roomNum)
        
        return sendData(msg: msg)
    }
    
    private func sendSaveBIM() -> Bool {
        let msg = Packet(size: MemoryLayout<Int32>.size + MemoryLayout<UInt16>.size * (3 + 1) + MemoryLayout<Float>.size * (4 + 3) + occupancyGrid.count + 1)
        msg.push_byte(data: Type.storeBIM.returnChar())
        
        msg.push_UInt16(data: UInt16(gridSizeX))
        msg.push_UInt16(data: UInt16(gridSizeY))
        msg.push_UInt16(data: UInt16(gridSizeZ))
        
        msg.push_single(data: distXL)
        msg.push_single(data: distXR)
        msg.push_single(data: distYU)
        msg.push_single(data: distYD)
        
        msg.push_single(data: roomSizeX)
        msg.push_single(data: roomSizeY)
        msg.push_single(data: roomSizeZ)
        
        msg.push_UInt16(data: roomNum)
        
        msg.push_byte_array(data: occupancyGrid.map({(value: Bool) -> Byte in return (value ? 0x01 : 0x00) })) //range bug
        
        print(gridSizeX, gridSizeY, gridSizeZ, msg.get_total_length())
        
        return sendData(msg: msg)
    }
    
    private func sendRequestGraph() -> Bool {
        let msg = Packet(size: MemoryLayout<Int32>.size + MemoryLayout<UInt16>.size * 3 + 1)
        
        msg.push_byte(data: Type.requestGraph.returnChar())
        
        msg.push_UInt16(data: targetPosition[0])
        msg.push_UInt16(data: targetPosition[1])
        msg.push_UInt16(data: targetPosition[2])
        
        return sendData(msg:msg)
    }

    
    // private receive method
    private func receive(){
        var rcvbuf = [Byte]()
        var head = 0
        var rcvLen = 0
        var len = UInt32(0)
        var lenDone = false
        var isFirst = 0
        var src:[Byte]?
        
        while(true)
        {
            src = self.client.read(10000000, isFirst: isFirst) //  128^3 * 5byte
            
            isFirst = 1
            
            if src != nil{
                rcvLen = src!.count
                head += rcvLen
                rcvbuf += src!
                if(!lenDone && head >= 4)
                {
                    len = (UInt32(rcvbuf[0]) << 24) | (UInt32(rcvbuf[1]) << 16) | (UInt32(rcvbuf[2]) << 8) | UInt32(rcvbuf[3])
                    lenDone = true
                }
            }
            
            if(head >= Int(len) + MemoryLayout<Int32>.size){
                break
            }
        }
            
//        let today = Date()
//        let formatter = DateFormatter()
//        formatter.dateFormat = "ss\tSSSS\t"
//        let timeString = "receive data: " + formatter.string(from: today)
//
//        print(timeString)
        let rcvData = Packet(buffer: rcvbuf, size: size_t(len) + MemoryLayout<Int32>.size)
        self.process(data: rcvData)
    }
    
//    func updatePhysicsValue(data:Packet){
//        if (lock_phy.try()){
//            defer {lock_phy.unlock()}
//
//            for i in 0..<gridSize3*4 {
//                tempPhysicsValue[i] = data.pop_single()
//            }
//        }
//    }
    
    private func process(data:Packet){
        let type : Byte = data.pop_byte()[0]
        switch type{
            
        case Type.provideSpaceInfo.returnChar():
            let msg = data.get_body()
            //print(String(bytes: msg, encoding: String.Encoding.utf8)!)
            
        case Type.provideOccupancy.returnChar():
            let msg = data.get_body()
            //print(String(bytes: msg, encoding: String.Encoding.utf8)!)

        case Type.provideACInfo.returnChar():
            acReset = false
            let msg = data.get_body()
            //print(String(bytes: msg, encoding: String.Encoding.utf8)!)

        case Type.charData.returnChar():
            let msg = data.get_body()
            print(String(bytes: msg, encoding: String.Encoding.utf8)!)
            
        case Type.storeBIM.returnChar():
            let msg = data.get_body()
            print(String(bytes: msg, encoding: String.Encoding.utf8)!)
            
        case Type.requestBIM.returnChar():
            if (true)
            {
                gridSizeX = Int(data.pop_UInt16())
                gridSizeY = Int(data.pop_UInt16())
                gridSizeZ = Int(data.pop_UInt16())
                gridSize3 = gridSizeX * gridSizeY * gridSizeZ
                
                acPosition = [gridSizeX/2, gridSizeY-1, gridSizeZ/2]

                tempPhysicsValue.reserveCapacity(gridSize3*4)
                velocity.reserveCapacity(gridSize3*3)
                temperature.reserveCapacity(gridSize3)
                occupancyGrid.reserveCapacity(gridSize3)
                
                occupancyGrid = [Bool].init(repeating: false, count: gridSize3)
                tempPhysicsValue = [Float].init(repeating: 0.0, count: gridSize3 * 4)
                velocity = [Float].init(repeating: 0.0, count: gridSize3 * 3)
                temperature = [Float].init(repeating: 0.0, count: gridSize3)
                
                distXL = data.pop_single()
                distXR = data.pop_single()
                distYU = data.pop_single()
                distYD = data.pop_single()
                
                roomSizeX = data.pop_single()
                roomSizeY = data.pop_single()
                roomSizeZ = data.pop_single()
                
                occupancyGrid = data.pop_byte_array(size:gridSize3).map({(value: Byte) -> Bool in return (value == 0x01 ? true : false) })
                    
                loadDone = true
            }
            
        case Type.requestGraph.returnChar():
            let graphInfoLen = data.get_body_length() / MemoryLayout<Float>.size
            
            graphInfo = []
            
            for _ in 0..<graphInfoLen{
                graphInfo.append(data.pop_single())
            }
            
            graphDone = true
            print("Graph data success")

        case Type.requestPhysicalValue.returnChar():
            
            //let methodStart = Date()

            if (true){//lock_phy.try()) {
                //defer {lock_phy.unlock()}
                phyPacket = data
                  
                if (true) //OperationQueue().addOperation
                {
                    var direction:[[Float]] = Array(repeating: Array(repeating: Float(0.0), count: 3), count: self.gridSize3)
                    var scale:[Float] = Array(repeating: Float(0.0), count: self.gridSize3)

                    if (self.phyPacket != nil){
                        let directionCount = Double(self.gridSize3) * 1.5 / 3
                        // decoding direction
                        for i in 0..<Int(directionCount){
                            // x = ~1 ~ 1;
                            let x1 = self.phyPacket!.pop_byte()
                            let x2:UInt8 = x1[0] >> 4
                            direction[i * 2][0] = Float(x2) / 15.0 * 2.0 - 1.0
                            let x3:UInt8 = x1[0] & 0b00001111  // 0x0f
                            direction[i * 2][1] = Float(x3) / 15.0 * 2.0 - 1.0
                            
                            let x4 = self.phyPacket!.pop_byte()
                            let x5:UInt8 = x4[0] >> 4
                            direction[i * 2][2] = Float(x5) / 15.0 * 2.0 - 1.0
                            let x6:UInt8 = x4[0] & 0b00001111
                            direction[i * 2 + 1][0] = Float(x6) / 15.0 * 2.0 - 1.0
                            
                            let x7 = self.phyPacket!.pop_byte()
                            let x8:UInt8 = x7[0] >> 4
                            direction[i * 2 + 1][1] = Float(x8) / 15.0 * 2.0 - 1.0
                            let x9:UInt8 = x7[0] & 0b00001111
                            direction[i * 2 + 1][2] = Float(x9) / 15.0 * 2.0 - 1.0
                            
                            //print("\(i*2) === \(x2) : \(x3) : \(x5)")
                            //print("\(i*2+1) === \(x6) : \(x8) : \(x9)")
                        }
                        //decoding scale
                        for i in 0..<self.gridSize3{
                            //let x1 = self.phyPacket!.pop_single()
                            
                            let x1 = self.phyPacket!.pop_UInt16()
                            scale[i] = Float(x1) / 30000.0
                            
                            //let x1 = self.phyPacket!.pop_byte()
                            //scale[i] = Float(x1[0]) / 100.0
                            
                            //print("\(i) : \(x1) ---> \(scale[i])")
                        }
                        //updating velocity
                        for i in 0..<self.gridSize3{
                            for j in 0..<3{
                                self.tempPhysicsValue[i * 3 + j] = direction[i][j] * scale[i]
                            }
                            //print("\(i) - \(self.tempPhysicsValue[i * 3]) : \(self.tempPhysicsValue[i * 3 + 1]) : \(self.tempPhysicsValue[i * 3+2]) /// \(scale[i])")
                        }
                        //updating temperature
                        for i in 0..<self.gridSize3{
                            let x1 = self.phyPacket!.pop_byte()
                            self.tempPhysicsValue[self.gridSize3 * 3 + i] = Float(x1[0]) / 256
                        }
                        /*
                        for i in 0..<self.gridSize3*4 {
                            self.tempPhysicsValue[i] = self.phyPacket!.pop_single()
                        }
                        */
                        
                        let valSize = self.tempPhysicsValue.count
                        self.velocity = Array(self.tempPhysicsValue[0..<valSize - self.gridSize3])
                        self.temperature =  Array(self.tempPhysicsValue[valSize - self.gridSize3..<valSize])
                        
                        self.phyPacket = nil
                        if(jumpDone == false && jumpSet == true){
                            jumpDone = true
                            jumpSet = false
                            print("jump forward done")
                        }
                        //print("-----------------------------------updataed velocity")
                    }
                    //self.lock_phy.unlock()
                }
            }
            //print("velocity success")
//            let methodFinish = Date()
//            let executionTime = methodFinish.timeIntervalSince(methodStart)
//            print("Velocity, Temperature seperate : \(executionTime)")

//        case Type.infoData:
//            let msg = data.get_body()
//            print(String(bytes: msg, encoding: String.Encoding.utf8)!)
//
//        case .initData:
//            print("init data")

        default:
            print("Unknown type in post-process")
        }
    }
}




