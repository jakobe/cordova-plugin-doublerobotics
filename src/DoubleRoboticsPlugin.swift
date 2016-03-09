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
	var currentRangeInCm:Float = 0.0;
	var currentTurnByDegrees:Float = 0.0;
	var currentVariableDriveDirection:Float = 0.0;
	var leftEncoderDeltaInches:Float = 0.0;
	var rightEncoderDeltaInches:Float = 0.0;
	var leftEncoderDeltaCm:Float = 0.0;
	var rightEncoderDeltaCm:Float = 0.0;
	var statusCallbackId:String?;
	var travelDataCallbackId:String?;
	var driveCounter = 0;
	var driveData = [[String : AnyObject]]();
	var lastDrive = [String : AnyObject]();
	var rangePeak:Float = 0.0;
	var driveStartDate = NSDate();

    override func pluginInitialize() {
        super.pluginInitialize()
        NSLog("******** CDVDoubleRobotics instantiated... *******")
        DRDouble.sharedDouble().delegate = self
		lastDrive = [String : AnyObject]();
    }

	func startStatusListener(command: CDVInvokedUrlCommand) {
		self.statusCallbackId = command.callbackId;
		updateStatus();
    }

	func startTravelDataListener(command: CDVInvokedUrlCommand) {
		self.travelDataCallbackId = command.callbackId;
    }
    
	func updateStatus() {	
		if (self.statusCallbackId != nil) {
			let sharedDouble = DRDouble.sharedDouble()
			let data: [String : AnyObject] = [
				"batteryPercent" : sharedDouble.batteryPercent,
				"batteryIsFullyCharged" : sharedDouble.batteryIsFullyCharged,
				"kickstandState" : UInt(sharedDouble.kickstandState),
				"poleHeightPercent" : sharedDouble.poleHeightPercent,
				"serial" : sharedDouble.serial,
				"firmwareVersion" : sharedDouble.firmwareVersion
			]
			let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAsDictionary: data as [String : AnyObject])
			pluginResult.setKeepCallbackAsBool(true)
			commandDelegate!.sendPluginResult(pluginResult, callbackId:self.statusCallbackId!)
		}
    }

	func updateTravelData() {	
		if (self.travelDataCallbackId != nil) {
			let data: [String : AnyObject] = [
				"leftEncoderDeltaInches" : leftEncoderDeltaInches,
				"rightEncoderDeltaInches" : rightEncoderDeltaInches,
				"leftEncoderDeltaCm" : leftEncoderDeltaCm,
				"rightEncoderDeltaCm" : rightEncoderDeltaCm,
				"driveData" : driveData,
				"lastDrive": lastDrive
			]
			let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAsDictionary: data as [String : AnyObject])
			pluginResult.setKeepCallbackAsBool(true)
			commandDelegate!.sendPluginResult(pluginResult, callbackId:self.travelDataCallbackId!)
		}
    }

    func doubleDriveShouldUpdate(theDouble:DRDouble) {
		/*
		var stopTresholdInCm:Float = 0.0//currentVariableDriveDirection > 0.5 ? 30.0 : 10.0
		if (currentVariableDriveDirection >= 0.9) {
			stopTresholdInCm = 60.0
		} else if (currentVariableDriveDirection >= 0.8) {
			stopTresholdInCm = 50.0
		} else if (currentVariableDriveDirection >= 0.7) {
			stopTresholdInCm = 40.0
		} else if (currentVariableDriveDirection >= 0.6) {
			stopTresholdInCm = 30.0
		} else if (currentVariableDriveDirection >= 0.5) {
			stopTresholdInCm = 20.0
		} else if (currentVariableDriveDirection >= 0.3) {
			stopTresholdInCm = 10.0
		} else if (currentVariableDriveDirection >= 0.2) {
			stopTresholdInCm = 5.0
		}
		if (currentRangeInCm > 0) {
			if ((abs(leftEncoderDeltaCm) >= (currentRangeInCm-stopTresholdInCm)) || (abs(rightEncoderDeltaCm) >= (currentRangeInCm-stopTresholdInCm))) {
				theDouble.drive(DRDriveDirection.Stop, turn: 0.0)
				currentRangeInCm = 0.0
				currentDriveDirection = DRDriveDirection.Stop
				currentTurn = 0.0
				currentVariableDriveDirection = 0.0	
				driveData.append(["stop" : "************** STOP **************"])
			}
		}
		*/

		if (currentRangeInCm > 0) {
			if ((abs(leftEncoderDeltaCm) >= (currentRangeInCm)) || (abs(rightEncoderDeltaCm) >= (currentRangeInCm))) {
				theDouble.drive(DRDriveDirection.Stop, turn: 0.0)
				currentRangeInCm = 0.0
				currentDriveDirection = DRDriveDirection.Stop
				currentTurn = 0.0
				currentVariableDriveDirection = 0.0
				driveData.append(["stop" : "************** STOP **************"])
				snapDriveData(currentVariableDriveDirection)
				driveData.append(["stop" : "************** STOP **************"])
			}
		}


        let drive = currentDriveDirection;
		var variableDrive = currentVariableDriveDirection;
        let turn = currentTurn;

		if (currentRangeInCm > 0) {
			let deaccelerateStart:Float = variableDrive > 0.5 ? 90 : 50
			let deaccelerateEnd:Float = variableDrive > 0.5 ? 40 : 20
			let deaccelerateRange = deaccelerateStart - deaccelerateEnd
			
			let remainingRange = currentRangeInCm - abs(leftEncoderDeltaCm)

			if (remainingRange < deaccelerateEnd) {
				if (currentVariableDriveDirection > 0) {
					currentVariableDriveDirection = 0.0
					 variableDrive = 0.0
					driveData.append(["stop" : "************** STOP **************"])
					snapDriveData(currentVariableDriveDirection)
					driveData.append(["stop" : "************** STOP **************"])			
				}
			} else if (remainingRange < deaccelerateStart) {
				let remainingDeaccelerateRange = remainingRange - deaccelerateEnd
				let remainingRangeZeroTowardsOne:Float = (1-(remainingDeaccelerateRange/deaccelerateRange))
				let halfPI:Float = Float(M_PI / 2.0)
				let deacceleration:Float = (sin(halfPI * remainingRangeZeroTowardsOne + halfPI))
				variableDrive = currentVariableDriveDirection * deacceleration
			}
		}

        if (variableDrive != 0.0 || turn != 0.0) {
            theDouble.variableDrive(variableDrive, turn: turn)
			snapDriveData(variableDrive)
		} else if (drive != DRDriveDirection.Stop || turn != 0.0) {
            theDouble.drive(drive, turn: turn)
        } else if (currentTurnByDegrees != 0.0) {
			theDouble.turnByDegrees(currentTurnByDegrees)
			currentTurnByDegrees = 0.0
		}


		/*
		driveCounter++;
		if (driveCounter > 70) {
			currentDriveDirection = DRDriveDirection.Stop
			currentTurn = 0.0
			currentVariableDriveDirection = 0.0	
		}
		*/
    }
    
    func doubleStatusDidUpdate(theDouble: DRDouble!) {
		updateStatus()
        NSLog("*** poleHeightPercent: \(DRDouble.sharedDouble().poleHeightPercent) ***")
        NSLog("*** kickstandState: \(DRDouble.sharedDouble().kickstandState) ***")
        NSLog("*** batteryPercent: \(DRDouble.sharedDouble().batteryPercent) ***")
        NSLog("*** batteryIsFullyCharged: \(DRDouble.sharedDouble().batteryIsFullyCharged) ***")
        NSLog("*** firmwareVersion: \(DRDouble.sharedDouble().firmwareVersion) ***")
    }

	func doubleTravelDataDidUpdate(theDouble: DRDouble!) {
		let cmPerInches:Float = 2.54;
		leftEncoderDeltaInches = leftEncoderDeltaInches + DRDouble.sharedDouble().leftEncoderDeltaInches;
		rightEncoderDeltaInches = rightEncoderDeltaInches + DRDouble.sharedDouble().rightEncoderDeltaInches;
		leftEncoderDeltaCm = leftEncoderDeltaInches * cmPerInches;
		rightEncoderDeltaCm = rightEncoderDeltaInches * cmPerInches;
		if (currentVariableDriveDirection == 0.0) {
			if (abs(leftEncoderDeltaCm) > rangePeak) {
				rangePeak = abs(leftEncoderDeltaCm)
				snapDriveData(currentVariableDriveDirection)
			} else {
				DRDouble.sharedDouble().stopTravelData()
			}
		}
		updateTravelData();
	}

	func snapDriveData(speed:Float) {
		let elapsedTime = stringFromTimeInterval(NSDate().timeIntervalSinceDate(driveStartDate))
		driveData.append(["speed" : speed, "range" : abs(leftEncoderDeltaCm), "time" : elapsedTime])
	}

	func stringFromTimeInterval(interval:NSTimeInterval) -> NSString {

		var ti = NSInteger(interval)

		var ms = Int((interval % 1) * 1000)

		var seconds = ti % 60
		var minutes = (ti / 60) % 60
		var hours = (ti / 3600)

		return NSString(format: "%0.2d:%0.2d:%0.2d.%0.3d",hours,minutes,seconds,ms)
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
			startTravelData()
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

	func startTravelData() {
		DRDouble.sharedDouble().stopTravelData()
		leftEncoderDeltaInches = 0.0
		rightEncoderDeltaInches = 0.0
		leftEncoderDeltaCm = 0.0
		rightEncoderDeltaCm = 0.0
		DRDouble.sharedDouble().startTravelData()
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

	func variableDrive2(command: CDVInvokedUrlCommand) {
		//driveData = [[String : AnyObject]]()
		rangePeak = 0.0
		let driveDirection = command.arguments[0] as! Float
		let turn = command.arguments[1] as! Float
		let rangeInCm = command.arguments[2] as! Float
		driveCounter = 0
		driveStartDate = NSDate()
        
        currentVariableDriveDirection = driveDirection
        currentTurn = turn
		currentRangeInCm = rangeInCm
		if (rangeInCm > 0) {
			startTravelData()		
		}

		/*let data = [
				"serial" : DRDouble.sharedDouble().serial,
				"leftEncoderDeltaInches" : leftEncoderDeltaInches,
				"rightEncoderDeltaInches" : rightEncoderDeltaInches,
				"leftEncoderDeltaCm" : leftEncoderDeltaCm,
				"rightEncoderDeltaCm" : rightEncoderDeltaCm
		]*/
        
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK)//, messageAsDictionary: data as [NSObject : AnyObject])
        commandDelegate!.sendPluginResult(pluginResult, callbackId:command.callbackId)
    }

	func stop(command: CDVInvokedUrlCommand) {
        currentVariableDriveDirection = 0.0
        currentTurn = 0.0
        currentDriveDirection = DRDriveDirection.Stop
		let elapsedTime = stringFromTimeInterval(NSDate().timeIntervalSinceDate(driveStartDate))
		//DRDouble.sharedDouble().stopTravelData()
		driveData.append(["stop" : "************** STOP **************"])
		snapDriveData(currentVariableDriveDirection)
		driveData.append(["stop" : "************** STOP **************"])
        
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK)
        commandDelegate!.sendPluginResult(pluginResult, callbackId:command.callbackId)
    }

	func turnByDegrees(command: CDVInvokedUrlCommand) {
		let degrees = command.arguments[0] as! Float
        currentDriveDirection = DRDriveDirection.Stop
        currentTurn = 0.0
		currentTurnByDegrees = degrees
               
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK)
        commandDelegate!.sendPluginResult(pluginResult, callbackId:command.callbackId)
    }
    
}