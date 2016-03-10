//
//  DoubleRoboticsPlugin.swift
//  DoubleRobotics
//
//  Created by Jakob Engelbrecht Olesen on 03/11/2015.
//
//

import Foundation

enum RobotState {
    case Unknown
    case Parked
    case Balancing
    case Driving
    case Rolling
    case Recovering
}

@objc(DoubleRobotics) // This class must be accessible from Objective-C.
class DoubleRobotics : CDVPlugin, DRDoubleDelegate  {
    
    var currentDriveDirection:Float = 0.0;
    var currentTurn:Float = 0.0;
	var currentRangeInCm:Float = 0.0;
	var currentTurnByDegrees:Float = 0.0;
	var leftEncoderDeltaInches:Float = 0.0;
	var rightEncoderDeltaInches:Float = 0.0;
    var avgEncoderDeltaInches:Float = 0.0;
	var leftEncoderDeltaCm:Float = 0.0;
	var rightEncoderDeltaCm:Float = 0.0;
    var avgEncoderDeltaCm:Float = 0.0;
	var statusCallbackId:String?;
	var travelDataCallbackId:String?;
	var rangePeak:Float = 0.0;
	var driveStartDate = NSDate();
    var collisionDetected = false;
    var collisionDirection:Float = 0.0;
    var state = RobotState.Unknown;
    var previousState = RobotState.Unknown;
    var driveData:[[String : AnyObject]] = [[String : AnyObject]]();
    var lastDrive:[String : AnyObject] = [String : AnyObject]();

    override func pluginInitialize() {
        super.pluginInitialize()
        NSLog("******** CDVDoubleRobotics instantiated... *******")
        driveData = [[String : AnyObject]]()
        lastDrive = [String : AnyObject]();
        driveStartDate = NSDate()
        collisionDirection = 0.0
        DRDouble.sharedDouble().delegate = self
    }

	func startStatusListener(command: CDVInvokedUrlCommand) {
		self.statusCallbackId = command.callbackId;
		updateStatus();
    }

	func startTravelDataListener(command: CDVInvokedUrlCommand) {
		self.travelDataCallbackId = command.callbackId;
    }
    
    func drive(command: CDVInvokedUrlCommand) {
        //driveData = [[String : AnyObject]]()
        rangePeak = 0.0
        let driveDirection = command.arguments[0] as! Float
        let turn = command.arguments[1] as! Float
        let rangeInCm = command.arguments[2] as! Float
        driveStartDate = NSDate()

        
        currentDriveDirection = driveDirection
        currentTurn = turn
        currentRangeInCm = rangeInCm
        
        if (self.state == .Balancing) {
            startTravelData()
        } else {
            NSLog("Somethings wrong...? State: \(self.state)")
        }
        
        updateState()
        
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK)
        commandDelegate!.sendPluginResult(pluginResult, callbackId:command.callbackId)
    }
    
    func stop(command: CDVInvokedUrlCommand) {
        stop()
        
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK)
        commandDelegate!.sendPluginResult(pluginResult, callbackId:command.callbackId)
    }
    
    func turnByDegrees(command: CDVInvokedUrlCommand) {
        let degrees = command.arguments[0] as! Float
        currentTurn = 0.0
        currentTurnByDegrees = degrees
        
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK)
        commandDelegate!.sendPluginResult(pluginResult, callbackId:command.callbackId)
    }
    
    func pole(command: CDVInvokedUrlCommand) {
        let poleCommand = command.arguments[0] as! String
        switch (poleCommand) {
        case "poleDown":
            DRDouble.sharedDouble().poleDown()
            break;
        case "poleStop":
            DRDouble.sharedDouble().poleStop()
            break;
        case "poleUp":
            DRDouble.sharedDouble().poleUp()
            break;
        default:
            break;
        }
        
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK)
        commandDelegate!.sendPluginResult(pluginResult, callbackId:command.callbackId)
    }
    
    func kickstand(command: CDVInvokedUrlCommand) {
        let kickstandCommand = command.arguments[0] as! String
        
        switch (kickstandCommand) {
        case "retractKickstands":
            DRDouble.sharedDouble().retractKickstands()
            break;
        case "deployKickstands":
            DRDouble.sharedDouble().deployKickstands()
            break;
        default:
            break;
        }
        
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK)
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
    
    func hasReachedCurrentRange() -> Bool {
        return currentRangeInCm > 0 && abs(avgEncoderDeltaCm) >= currentRangeInCm
    }

    func doubleDriveShouldUpdate(theDouble:DRDouble) {
        if (hasReachedCurrentRange()) {
            theDouble.drive(DRDriveDirection.Stop, turn: 0.0)
            currentRangeInCm = 0.0
            stop()
            NSLog("*** hasReachedCurrentRange ***")
        }

		var drive = currentDriveDirection;
        let turn = currentTurn;

		if (currentRangeInCm > 0) {
			let deaccelerateStart:Float = drive > 0.5 ? 90 : 50
			let deaccelerateEnd:Float = drive > 0.5 ? 40 : 20
			let deaccelerateRange = deaccelerateStart - deaccelerateEnd
			
			let remainingRange = currentRangeInCm - abs(avgEncoderDeltaCm)

			if (remainingRange < deaccelerateEnd) {
				if (currentDriveDirection != 0.0) {
					stop()
                    NSLog("*** STOP - avgEncoderDeltaCm: \(avgEncoderDeltaCm) | drive: \(drive) ***")
                    drive = 0.0
				}
			} else if (remainingRange < deaccelerateStart) {
				let remainingDeaccelerateRange = remainingRange - deaccelerateEnd
				let remainingRangeZeroTowardsOne:Float = (1-(remainingDeaccelerateRange/deaccelerateRange))
				let halfPI:Float = Float(M_PI / 2.0)
				let deacceleration:Float = (sin(halfPI * remainingRangeZeroTowardsOne + halfPI))
				drive = currentDriveDirection * deacceleration
                //NSLog("*** deAcc - drive: \(drive) ***")
			}
		}

        if (drive != 0.0 || turn != 0.0) {
            //NSLog("*** avgEncoderDeltaCm: \(avgEncoderDeltaCm) | leftEncoderDeltaCm: \(leftEncoderDeltaCm) | rightEncoderDeltaCm: \(rightEncoderDeltaCm) | drive: \(drive) ***")
            theDouble.variableDrive(drive, turn: turn)
			snapDriveData(drive)
        } else if (currentTurnByDegrees != 0.0) {
			theDouble.turnByDegrees(currentTurnByDegrees)
			currentTurnByDegrees = 0.0
		}
    }

	func doubleTravelDataDidUpdate(theDouble: DRDouble!) {
		let cmPerInches:Float = 2.54;
        let drive = currentDriveDirection;
        let collisionMinimumRangeThreshold:Float = 5.0;
        collisionDetected = false;
        
        updateState()
        
		leftEncoderDeltaInches = leftEncoderDeltaInches + theDouble.leftEncoderDeltaInches
		rightEncoderDeltaInches = rightEncoderDeltaInches + theDouble.rightEncoderDeltaInches
        avgEncoderDeltaInches = (leftEncoderDeltaInches + rightEncoderDeltaInches) / 2.0
		leftEncoderDeltaCm = leftEncoderDeltaInches * cmPerInches
		rightEncoderDeltaCm = rightEncoderDeltaInches * cmPerInches
        avgEncoderDeltaCm = (leftEncoderDeltaCm + rightEncoderDeltaCm) / 2.0
        
        if (drivingOrRolling && abs(avgEncoderDeltaCm) > collisionMinimumRangeThreshold) {
            //NSLog("*** leftEncoderDeltaInches: \(theDouble.leftEncoderDeltaInches) ***")
            if (collisionDirection == 0.0) {
                if ((drive > 0 && theDouble.leftEncoderDeltaInches < 0) ||
                    (drive < 0 && theDouble.leftEncoderDeltaInches > 0)) {
                        collisionDetected = true
                        collisionDirection = theDouble.leftEncoderDeltaInches
                }
            } else if ((collisionDirection < 0 && theDouble.leftEncoderDeltaInches > 0) ||
                collisionDirection > 0 && theDouble.leftEncoderDeltaInches < 0) {
                //Reset collision detection:
                collisionDirection = 0.0
            }
        }
        
		if (state == .Rolling) {
            NSLog("*** avgEncoderDeltaCm: \(avgEncoderDeltaCm) ***")
			if (abs(avgEncoderDeltaCm) > rangePeak) {
				rangePeak = abs(avgEncoderDeltaCm)
                //NSLog("*** rangePeak: \(rangePeak) ***")
				snapDriveData(drive)
			} else {
				//DRDouble.sharedDouble().stopTravelData()
                updateState(.Balancing)
			}
        } else if (state == .Balancing) {
            //TODO: If travelData > pushThreshold => raisePushEvent!
        }
        if (self.drivingOrRolling && (leftEncoderDeltaInches != 0.0 || rightEncoderDeltaInches != 0.0)) {
            updateTravelData()
        }
	}
    
    func updateTravelData() {
        if (self.travelDataCallbackId != nil && !self.travelDataCallbackId!.isEmpty) {
            let data: [String : AnyObject] = [
                "leftEncoderDeltaInches" : leftEncoderDeltaInches,
                "rightEncoderDeltaInches" : rightEncoderDeltaInches,
                "avgEncoderDeltaInches" : avgEncoderDeltaInches,
                "leftEncoderDeltaCm" : leftEncoderDeltaCm,
                "rightEncoderDeltaCm" : rightEncoderDeltaCm,
                "avgEncoderDeltaCm" : avgEncoderDeltaCm,
                "collisionDetected" : collisionDetected,
                "driveData" : driveData,
                "lastDrive" : lastDrive
            ]
            //NSLog("Send traveldata...")
            let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAsDictionary: data as [String : AnyObject])
            pluginResult.setKeepCallbackAsBool(true)
            commandDelegate!.sendPluginResult(pluginResult, callbackId:self.travelDataCallbackId!)
        }
    }
    
    func doubleStatusDidUpdate(theDouble: DRDouble!) {
        updateStateFromKickstandState(theDouble.kickstandState)
        updateStatus()
        NSLog("*** poleHeightPercent: \(DRDouble.sharedDouble().poleHeightPercent) ***")
        NSLog("*** kickstandState: \(DRDouble.sharedDouble().kickstandState) ***")
        NSLog("*** batteryPercent: \(DRDouble.sharedDouble().batteryPercent) ***")
        NSLog("*** batteryIsFullyCharged: \(DRDouble.sharedDouble().batteryIsFullyCharged) ***")
        NSLog("*** firmwareVersion: \(DRDouble.sharedDouble().firmwareVersion) ***")
    }
    
    func updateStatus() {
        if (self.statusCallbackId != nil && self.statusCallbackId!.isEmpty) {
            let sharedDouble = DRDouble.sharedDouble()
            let data: [String : AnyObject] = [
                "batteryPercent" : sharedDouble.batteryPercent,
                "batteryIsFullyCharged" : sharedDouble.batteryIsFullyCharged,
                "kickstandState" : UInt(sharedDouble.kickstandState),
                "poleHeightPercent" : sharedDouble.poleHeightPercent,
                //"serial" : sharedDouble.serial,
                //"firmwareVersion" : sharedDouble.firmwareVersion
            ]
            let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAsDictionary: data as [String : AnyObject])
            pluginResult.setKeepCallbackAsBool(true)
            commandDelegate!.sendPluginResult(pluginResult, callbackId:self.statusCallbackId!)
        }
    }

	func snapDriveData(speed:Float) {
		//let elapsedTime = NSDate().timeIntervalSinceDate(driveStartDate)
        lastDrive = ["speed" : speed, "range" : abs(avgEncoderDeltaCm), "time" : stringFromNSDate(NSDate()), "start": stringFromNSDate(driveStartDate)]
        //self.driveData.append(["speed" : speed, "range" : abs(avgEncoderDeltaCm), "time" : elapsedTime])
	}

	func stringFromTimeInterval(interval:NSTimeInterval) -> NSString {
		let ti = NSInteger(interval)
		let ms = Int((interval % 1) * 1000)
		let seconds = ti % 60
		let minutes = (ti / 60) % 60
		let hours = (ti / 3600)

		return NSString(format: "%0.2d:%0.2d°:%0.2d.%0.3d",hours,minutes,seconds,ms)
	}
    
    func stringFromNSDate(date:NSDate) -> NSString {
        let formatter = NSDateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        return formatter.stringFromDate(date)
    }

	func startTravelData() {
		DRDouble.sharedDouble().stopTravelData()
		leftEncoderDeltaInches = 0.0
		rightEncoderDeltaInches = 0.0
        avgEncoderDeltaCm = 0.0
		leftEncoderDeltaCm = 0.0
		rightEncoderDeltaCm = 0.0
        avgEncoderDeltaCm = 0.0
        collisionDirection = 0.0
		DRDouble.sharedDouble().startTravelData()
	}
    
    func stop() {
        currentDriveDirection = 0.0
        currentTurn = 0.0
        //currentRangeInCm = 0.0
        self.driveData.append(["stop" : "************** STOP **************"])
        snapDriveData(currentDriveDirection)
        self.driveData.append(["stop" : "************** STOP **************"])
    }
    
    func updateState(state:RobotState? = nil) {
        var newState = self.state
        if let state = state {
            if (state != .Unknown) {
                newState = state
            }
        } else {
            switch self.state {
            case .Balancing:
                if (currentDriveDirection != 0.0) {
                    newState = .Driving
                }
            case .Driving:
                if (currentDriveDirection == 0.0) {
                    newState = .Rolling
                }
            default:
                break
            }
            
        }
        if (newState != self.state) {
            self.previousState = self.state
            self.state = newState
            NSLog("*** state: \(self.previousState) => \(self.state) ***")
        }
    }
    
    func updateStateFromKickstandState(kickstandState:Int32) {
        var newState = RobotState.Unknown
        if (state == .Unknown || state == .Parked || state == .Balancing) {
            switch kickstandState {
            case 1:
                newState = .Parked
            case 2:
                newState = .Balancing
            case 3:
                newState = .Parked //Deploying kickstand
            case 4:
                newState = .Balancing //Retracting kickstand
            default:
                break;
            }
            if (newState != .Unknown) {
                updateState(newState)
            }
        }
    }
    
    var drivingOrRolling: Bool {
        get {
            return self.state == .Driving || self.state == .Rolling
        }
    }
    
}