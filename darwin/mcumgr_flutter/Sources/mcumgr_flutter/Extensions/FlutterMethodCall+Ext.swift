//
//  FlutterMethodCall+Ext.swift
//  mcumgr_flutter
//
//  Created by Nick Kibysh on 27/02/2024.
//

#if os(iOS)
import Flutter
#elseif os(macOS)
import FlutterMacOS
#endif

extension FlutterMethodCall {
    var debugDetails: [String:Any] {
        var details: [String:Any] = ["method": method]
        
        if let arguments {
            details["argumentsType"] = String(describing: arguments)
        }
        
        if let str = arguments as? String {
            details["argumentsValue"] = str
        } else if let data = arguments as? FlutterStandardTypedData {
            details["argumentsDataLength"] = data.data.count
        } else {
            details["argumentsDebugDescription"] = arguments.debugDescription
        }
        
        return details
    }
}
