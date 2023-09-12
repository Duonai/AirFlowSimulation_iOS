//
//  Packet.swift
//  AirFlowSimulation
//
//  Created by 정우석 on 2021/07/23.
//  Copyright © 2021 Apple. All rights reserved.
//

import Foundation

extension Float{
    var bytes: [UInt8]{
        withUnsafeBytes(of: self, Array.init)
    }
}

open class Packet{
    
    var buffer_length = 1440;
    let header_length = MemoryLayout<Int32>.size
    
    private var m_buffer = [Byte]()
    private var m_position = 0;
    private var m_body_length:UInt32 = 0;
    
    func get_buffer_length() -> Int{
        return buffer_length
    }
    
    func set_buffer_length(length:Int){
        buffer_length = length
    }
    
    init(size:size_t = 0){
        m_position = header_length
        m_body_length = 0
        if(size != 0){
            buffer_length = size
        }
        
        m_buffer = [Byte](repeating: 0x00, count: buffer_length)
    }
    
    init (buffer:[Byte], size:size_t = 0){
        m_position = header_length
        m_body_length = 0
        if(size != 0){
            buffer_length = size
        }
        m_buffer = buffer
        self.decode_body_length()
    }
    
    //init(buffer:Packet)
    
    func record_body_length(){
        let header = withUnsafeBytes(of: Int32(m_body_length).bigEndian, Array.init)
        m_buffer[0] = header[0]
        m_buffer[1] = header[1]
        m_buffer[2] = header[2]
        m_buffer[3] = header[3]
    }
    
    func decode_body_length(){
        var header = [Byte]()
        
        for i in 0...3{
            header.append(m_buffer[i])
        }
        
        var value : UInt32 = 0
        
        let data = NSData(bytes: header, length: 4)
        data.getBytes(&value, length: 4)
        value = UInt32(bigEndian: value)
        
        m_body_length = value
    }
    
    func get_buffer()->[Byte]{
        
        return m_buffer
    }
    
    func get_body()->[Byte]{
        var body = [Byte]()
        
        for i in header_length...Int(m_body_length) + header_length - 1{
            body.append(m_buffer[i])
        }
        return body
    }
    
    func get_position()->Int{
        return m_position
    }
    
    func get_total_length()->Int{
        return Int(m_body_length) + header_length
    }
    
    func get_body_length()->Int{
        return Int(m_body_length)
    }
    
    func read_buffer(size:size_t)->[Byte]{
        var data = [Byte](repeating: 0x00, count: size)
        for i in 0...size - 1{
            data[i] = m_buffer[m_position + i]
        }
        m_position += size
        return data
    }
    
    func write_buffer(data:[Byte], size:size_t){
        for i in 0...size - 1{
            m_buffer[m_position + i] = data[i]
        }
        m_position += size
        m_body_length += UInt32(size)
        record_body_length()
    }
    
    func pop_byte()->[Byte]{
        let data = read_buffer(size: 1)
        
        return data
    }
    
    func pop_byte_array(size:size_t)->[Byte]{
        let data = read_buffer(size: size)
        
        return data
    }
    
    func pop_bool()->Bool{
        let data = pop_byte()
        
        return data[0] != 0x00; //check
    }
    
    func pop_UInt16()->UInt16{
        let temp = read_buffer(size: MemoryLayout<Int16>.size)

        var value : UInt16 = 0

        let data = NSData(bytes: temp, length: MemoryLayout<Int16>.size)
        data.getBytes(&value, length: MemoryLayout<Int16>.size)
        value = UInt16(littleEndian: value)
        return value
    }
    
//    func pop_int32()->Int32{
//        let temp = read_buffer(size: MemoryLayout<Int32>.size)
//        
//        var value : Int32 = 0
//        
//        let data = NSData(bytes: temp, length: MemoryLayout<Int32>.size)
//        data.getBytes(&value, length: MemoryLayout<Int32>.size)
//        value = Int32(bigEndian: value)
//        
//        return value
//    }
//    
//    func pop_int64()->Int64{
//        let temp = read_buffer(size: MemoryLayout<Int64>.size)
//        
//        var value : Int64 = 0
//        
//        let data = NSData(bytes: temp, length: MemoryLayout<Int64>.size)
//        data.getBytes(&value, length: MemoryLayout<Int64>.size)
//        value = Int64(bigEndian: value)
//        
//        return value
//    }
    
    func pop_single()->Float{
//        let temp = read_buffer(size: MemoryLayout<Float>.size)
//        let preData = NSData(bytes:temp, length:4)
//        let data = Data(preData)
//        let value = Float(bitPattern: UInt32(littleEndian: data.withUnsafeBytes{$0.load(as:UInt32.self)}))
//        return value
        
        //https://newbedev.com/how-to-convert-bytes-to-a-float-value-in-swift
        let data = Data(read_buffer(size: MemoryLayout<Float>.size))
        let floatNb:Float = data.withUnsafeBytes { $0.load(as: Float.self) }
        return floatNb
    }
    
//    func pop_double
    
//    func pop_byte_array()->[Byte]{
//        let size = pop_int64()
//        let data = read_buffer(size: size_t(size))
//
//        return data
//    }
    
//    func pop_string
    
    func push_byte(data:Byte){
        let tmp = [data]
        
        write_buffer(data: tmp, size: 1)
    }
    
    func push_byte_array(data:[Byte]){ // need check
        write_buffer(data:data, size:data.count)
    }
    
    func push_bool(data:Bool){ //need check
        if (data){
            write_buffer(data: [0x01], size: 1)
        }
        else{
            write_buffer(data: [0x00], size: 1)
        }
    }
    
    func push_UInt16(data:UInt16){
        let tmp = withUnsafeBytes(of: data.littleEndian, Array.init)
        
        write_buffer(data: tmp, size: MemoryLayout<UInt16>.size)
    }
    
    func push_int32(data:Int32){
        let tmp = withUnsafeBytes(of: data.littleEndian, Array.init)
        
        write_buffer(data: tmp, size: MemoryLayout<Int32>.size)
    }
    
    func push_Uint32(data:UInt32){
        let tmp = withUnsafeBytes(of: data.littleEndian, Array.init)
        
        write_buffer(data: tmp, size: MemoryLayout<UInt32>.size)
    }
    
    func push_int64(data:Int64){
        let tmp = withUnsafeBytes(of: data.littleEndian, Array.init)
        
        write_buffer(data: tmp, size: MemoryLayout<Int64>.size)
    }
    
    func push_single(data:Float){
        let tmp = data.bytes //check!
        
        write_buffer(data: tmp, size: MemoryLayout<Float>.size)
    }
    
//    func push_double
    
    func push_byte_array(data: [Byte], size:size_t){
        push_int64(data: Int64(size))
        write_buffer(data: data, size: size)
    }
    
//    func push_string
    
}
