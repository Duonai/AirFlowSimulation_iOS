//
//  Type.swift
//  wow
//
//  Created by 정우석 on 2021/07/09.
//

import Foundation

public enum Type{
    case boolData
    case giveData
    case charData
    case infoData
    case initData
    
    case provideSpaceInfo
    case provideACInfo
    case provideOccupancy
    case requestPhysicalValue
    case storeBIM
    case requestBIM
    case requestGraph
    
    func returnChar() -> Byte {
        switch self{
//        case .boolData:
//            return 0x11
//        case .giveData:
//            return 0x12
//        case .charData:
//            return 0x13
//        case .infoData:å
//            return 0x14

        case .provideSpaceInfo:
            return 0x10
        case .provideOccupancy:
            return 0x11
        case .provideACInfo:
            return 0x14
        case .requestPhysicalValue:
            return 0x12
        case .storeBIM:
            return 0x16
        case .requestBIM:
            return 0x17
        case .requestGraph:
            return 0x18
        default:
            return 0x15
        }
    }
}
