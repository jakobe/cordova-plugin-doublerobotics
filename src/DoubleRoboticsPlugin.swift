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
	var currentTurnByDegrees:Float = 0.0;
	var currentVariableDriveDirection:Float = 0.0;
	var leftEncoderDeltaInches:Float = 0.0;
	var rightEncoderDeltaInches:Float = 0.0;
	var leftEncoderDeltaCm:Float = 0.0;
	var rightEncoderDeltaCm:Float = 0.0;

    override func pluginInitialize() {
        super.pluginInitialize()
        NSLog("******** CDVDoubleRobotics instantiated... *******")
        DRDouble.sharedDouble().delegate = self
    }
    
    func doubleDriveShouldUpdate(theDouble:DRDouble) {
        //NSLog("doubleDriveShouldUpdate... from plugin")
        let drive = currentDriveDirection;
		let variableDrive = currentVariableDriveDirection;
        let turn = currentTurn;
        if (variableDrive != 0.0 || turn != 0.0) {
            theDouble.variableDrive(variableDrive, turn: turn)
		} else if (drive != DRDriveDirection.Stop || turn != 0.0) {
            theDouble.drive(drive, turn: turn)
        } else if (currentTurnByDegrees != 0.0) {
			theDouble.turnByDegrees(currentTurnByDegrees)
			currentTurnByDegrees = 0.0
		}
        currentDriveDirection = DRDriveDirection.Stop
        currentTurn = 0.0
		currentVariableDriveDirection = 0.0
    }
    
    func doubleStatusDidUpdate(theDouble: DRDouble!) {
        NSLog("*** poleHeightPercent: \(DRDouble.sharedDouble().poleHeightPercent) ***")
        NSLog("*** kickstandState: \(DRDouble.sharedDouble().kickstandState) ***")
        NSLog("*** batteryPercent: \(DRDouble.sharedDouble().batteryPercent) ***")
        NSLog("*** batteryIsFullyCharged: \(DRDouble.sharedDouble().batteryIsFullyCharged) ***")
        NSLog("*** firmwareVersion: \(DRDouble.sharedDouble().firmwareVersion) ***")
    }

	func doubleTravelDataDidUpdate(theDouble: DRDouble!) {
		leftEncoderDeltaInches = leftEncoderDeltaInches + DRDouble.sharedDouble().leftEncoderDeltaInches;
		rightEncoderDeltaInches = rightEncoderDeltaInches + DRDouble.sharedDouble().rightEncoderDeltaInches;
		leftEncoderDeltaCm = leftEncoderDeltaInches * 2.54;
		rightEncoderDeltaCm = rightEncoderDeltaInches * 2.54;
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

	func travelData(command: CDVInvokedUrlCommand) {
		let travelDataCommand = command.arguments[0] as! String
		var message = "Unknown command."
		switch (travelDataCommand) {
        case "startTravelData":
			leftEncoderDeltaInches = 0.0
			rightEncoderDeltaInches = 0.0
			leftEncoderDeltaCm = 0.0
			rightEncoderDeltaCm = 0.0
			DRDouble.sharedDouble().startTravelData()
			message = "Travel data started."
            break;
        case "stopTravelData":
			DRDouble.sharedDouble().stopTravelData()
			message = "Travel data stopped."
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
        case "turnByDegrees":
            currentDriveDirection = DRDriveDirection.Stop
            currentTurn = 0.0
			currentTurnByDegrees = 180;
            message = "turnByDegrees"
            break;
        default:
            break;
        }
        
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAsString: message)
        commandDelegate!.sendPluginResult(pluginResult, callbackId:command.callbackId)
    }
    
	func variableDrive(command: CDVInvokedUrlCommand) {
        let driveCommand = command.arguments[0] as! String
		let driveDirection = command.arguments[1] as! Float
		let turn = command.arguments[2] as! Float
        var message = "Unknown command."
		//var data: NSDictionary?
        
        switch (driveCommand) {
        case "drive":
            currentVariableDriveDirection = driveDirection
            currentTurn = turn
            //message = "VariableDriveForward - driveDirection: \(driveDirection) | leftEncoderDeltaInches: \(leftEncoderDeltaInches) | rightEncoderDeltaInches: \(rightEncoderDeltaInches) | batteryPercent: \(DRDouble.sharedDouble().batteryPercent) | firmwareVersion: \(DRDouble.sharedDouble().firmwareVersion) | serial: \(DRDouble.sharedDouble().serial)"
			//message = "leftEncoderDeltaInches: \(leftEncoderDeltaInches) | rightEncoderDeltaInches: \(rightEncoderDeltaInches)"
			message = "leftEncoderDeltaInches: \(leftEncoderDeltaInches) | rightEncoderDeltaInches: \(rightEncoderDeltaInches)"
            break;
        case "turnByDegrees":
            currentDriveDirection = DRDriveDirection.Stop
            currentTurn = 0.0
			currentTurnByDegrees = turn
            message = "turnByDegrees: \(currentTurnByDegrees)"
            break;
        default:
            break;
        }

		let data = [
				"serial" : DRDouble.sharedDouble().serial,
				"message" : message,
				"leftEncoderDeltaInches" : leftEncoderDeltaInches,
				"rightEncoderDeltaInches" : rightEncoderDeltaInches,
				"leftEncoderDeltaCm" : leftEncoderDeltaCm,
				"rightEncoderDeltaCm" : rightEncoderDeltaCm
		]
        
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAsDictionary: data as [NSObject : AnyObject])
        commandDelegate!.sendPluginResult(pluginResult, callbackId:command.callbackId)
    }
    
}