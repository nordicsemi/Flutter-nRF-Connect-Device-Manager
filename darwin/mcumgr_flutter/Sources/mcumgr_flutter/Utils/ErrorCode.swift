//
//  ErrorCode.swift
//  mcumgr_flutter
//
//  Created by Mykola Kibysh on 11/12/2020.
//

import Foundation
#if os(iOS)
import Flutter
#elseif os(macOS)
import FlutterMacOS
#endif

public enum ErrorCode: String {
    case platformError = "Error"
    case wrongArguments = "WrongArguments"
    case updateManagerExists = "UpdateManagerExists"
    case updateManagerDoesNotExist = "UpdateManagerDoesNotExist"
    case flutterTypeError = "FlutterTypeError"
    case updateError = "UpdateError"
}
