//
//  DoubleRoboticsPlugin.swift
//  DoubleRobotics
//
//  Created by Jakob Engelbrecht Olesen on 03/11/2015.
//
//

import Foundation

@objc(DoubleRobotics) // This class must be accessible from Objective-C.
class DoubleRobotics : CDVPlugin, DRDoubleDelegate  {
    
    var currentDriveDirection = DRDriveDirection.Stop;
    var currentTurn:Float = 0.0;

    override func pluginInitialize() {
        super.pluginInitialize()
        NSLog("******** CDVDoubleRobotics instantiated... *******")
        DRDouble.sharedDouble().delegate = self
    }
    
    func doubleDriveShouldUpdate(theDouble:DRDouble) {
        //NSLog("doubleDriveShouldUpdate... from plugin")
        let drive = currentDriveDirection;
        let turn = currentTurn;
        if (drive != DRDriveDirection.Stop || turn != 0.0) {
            theDouble.drive(drive, turn: turn)
        }
        currentDriveDirection = DRDriveDirection.Stop
        currentTurn = 0.0
    }
    
    func doubleStatusDidUpdate(theDouble: DRDouble!) {
        NSLog("*** poleHeightPercent: \(DRDouble.sharedDouble().poleHeightPercent) ***")
        NSLog("*** kickstandState: \(DRDouble.sharedDouble().kickstandState) ***")
        NSLog("*** batteryPercent: \(DRDouble.sharedDouble().batteryPercent) ***")
        NSLog("*** batteryIsFullyCharged: \(DRDouble.sharedDouble().batteryIsFullyCharged) ***")
        NSLog("*** firmwareVersion: \(DRDouble.sharedDouble().firmwareVersion) ***")
    }
    
    func pole(command: CDVInvokedUrlCommand) {
        let poleCommand = command.arguments[0] as! String
        var message = "Unknown command.";

        switch (poleCommand) {
        case "poleDown":
            DRDouble.sharedDouble().poleDown()
            message = "Pole Down!"
            NSLog(message)
            break;
        case "poleStop":
            DRDouble.sharedDouble().poleStop()
            DRDouble.sharedDouble().turnByDegrees(180)
            message = "Pole Stop!"
            break;
        case "poleUp":
            DRDouble.sharedDouble().poleUp()
            message = "Pole Up!"
            break;
        default:
            break;
        }
        
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAsString: message)
        commandDelegate!.sendPluginResult(pluginResult, callbackId:command.callbackId)
    }
    
    func kickstand(command: CDVInvokedUrlCommand) {
        let kickstandCommand = command.arguments[0] as! String
        var message = "Unknown command.";
        
        switch (kickstandCommand) {
        case "retractKickstands":
            DRDouble.sharedDouble().retractKickstands()
            message = "Retract kickstands"
            break;
        case "deployKickstands":
            DRDouble.sharedDouble().deployKickstands()
            message = "Deploy kickstands"
            break;
        default:
            break;
        }
        
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAsString: message)
        commandDelegate!.sendPluginResult(pluginResult, callbackId:command.callbackId)
    }
    
    func drive(command: CDVInvokedUrlCommand) {
        let driveCommand = command.arguments[0] as! String
        var message = "Unknown command.";
        
        switch (driveCommand) {
        case "driveForward":
            currentDriveDirection = DRDriveDirection.Forward
            currentTurn = 0.0
            message = "DriveForward"
            break;
        case "driveBackward":
            currentDriveDirection = DRDriveDirection.Backward
            currentTurn = 0.0
            message = "DriveBackward"
            break;
        case "turnLeft":
            currentDriveDirection = DRDriveDirection.Stop
            currentTurn = -1.0
            message = "turnLeft"
            break;
        case "turnRight":
            currentDriveDirection = DRDriveDirection.Stop
            currentTurn = 1.0
            message = "turnRight"
            break;
        default:
            break;
        }
        
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAsString: message)
        commandDelegate!.sendPluginResult(pluginResult, callbackId:command.callbackId)
    }
    
    
}