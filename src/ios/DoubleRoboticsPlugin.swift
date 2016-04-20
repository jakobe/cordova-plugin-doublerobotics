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
    case Starting
    case Driving
    case Rolling
    case Stopping
    case Recovering
}

@objc(DoubleRobotics) // This class must be accessible from Objective-C.
class DoubleRobotics : CDVPlugin, DRDoubleDelegate  {

    var currentDrive:Float = 0.0;
    var currentTurn:Float = 0.0;
    var driveDirection:DRDriveDirection = .Stop;
    var currentDirection:DRDriveDirection = .Stop;
    var currentSpeed:Float = 0.0;
    var currentSpeedInCmPerSecond:Float = 0.0;
    var currentRangeInCm:Float = 0.0;
    var currentTurnByDegrees:Float = 0.0;
    var leftEncoderTotalInches:Float = 0.0;
    var rightEncoderTotalInches:Float = 0.0;
    var avgEncoderTotalInches:Float = 0.0;
    var leftEncoderTotalCm:Float = 0.0;
    var rightEncoderTotalCm:Float = 0.0;
    var avgEncoderTotalCm:Float = 0.0;
    var statusCallbackId:String?;
    var travelDataCallbackId:String?;
    var collisionCallbackId:String?;
    var driveCallbackId:String?;
    var rangePeak:Float = 0.0;
    var driveStartDate = NSDate();
    var collisionDirection:Float = 0.0;
    var rangeSinceCollision:Float = 0.0;
    var state = RobotState.Unknown;
    var previousState = RobotState.Unknown;

    override func pluginInitialize() {
        super.pluginInitialize()
        NSLog("******** CDVDoubleRobotics instantiated... *******")
        driveStartDate = NSDate()
        collisionDirection = 0.0
        rangeSinceCollision = 0.0
        //stopTravelData if last session exited without stopping:
        DRDouble.sharedDouble().stopTravelData()
        DRDouble.sharedDouble().delegate = self
    }

    func startStatusListener(command: CDVInvokedUrlCommand) {
        self.statusCallbackId = command.callbackId;
        NSLog("startStatusListener... statusCallbackId: \(self.statusCallbackId)")
        updateStatus();
    }

    func stopStatusListener(command: CDVInvokedUrlCommand) {
        self.statusCallbackId = nil;
    }

    func startTravelDataListener(command: CDVInvokedUrlCommand) {
        self.travelDataCallbackId = command.callbackId;
        NSLog("startTravelDataListener... travelDataCallbackId: \(self.travelDataCallbackId)")
    }

    func stopTravelDataListener(command: CDVInvokedUrlCommand) {
        self.travelDataCallbackId = nil;
    }

    func startCollisionListener(command: CDVInvokedUrlCommand) {
        self.collisionCallbackId = command.callbackId;
         NSLog("startCollisionListener... collisionCallbackId: \(self.collisionCallbackId)")
    }

    func stopCollisionListener(command: CDVInvokedUrlCommand) {
        self.collisionCallbackId = nil;
    }

    var nextDriveDirection:DRDriveDirection = .Stop

    func sendNotConnectedError(command: CDVInvokedUrlCommand) {
        let message = "Robot not connected. Make sure bluetooth and robot is turned on and connected."
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAsString: message)
        commandDelegate!.sendPluginResult(pluginResult, callbackId:command.callbackId)
    }

    func drive(command: CDVInvokedUrlCommand) {
        if (self.state == .Unknown) {
            return sendNotConnectedError(command)
        }
        rangePeak = 0.0
        let drive = command.arguments[0] as! Float
        let turn = command.arguments[1] as! Float
        let rangeInCm = command.arguments[2] as! Float

        currentDrive = drive
        currentSpeed = drive
        currentTurn = turn
        currentRangeInCm = rangeInCm

        if (drive != 0.0) {
            NSLog("-------------")
            NSLog("--- DRIVE --- ... drive: \(drive) - rangeInCm: \(rangeInCm) - state: \(self.state)")
            NSLog("-------------")
        }

        nextDriveDirection = drive > 0 ? .Forward : .Backward
        if (driveDirection == .Stop) {
          driveDirection = nextDriveDirection
          nextDriveDirection = .Stop
        }

        if (self.state == .Balancing || self.state == .Starting || self.state == .Rolling || self.state == .Stopping) {
            startTravelData()
        }

        updateState()

        if (rangeInCm > 0) {
          driveCallbackId = command.callbackId;
        } else {
          let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK)
          commandDelegate!.sendPluginResult(pluginResult, callbackId:command.callbackId)
        }
    }

    func stop(command: CDVInvokedUrlCommand) {
        if (self.state == .Unknown) {
            return sendNotConnectedError(command)
        }
        NSLog("*** stop() ***")
        stop()
        driveCallbackId = nil
        currentRangeInCm = 0.0
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK)
        commandDelegate!.sendPluginResult(pluginResult, callbackId:command.callbackId)
    }

    func turnByDegrees(command: CDVInvokedUrlCommand) {
        if (self.state == .Unknown) {
            return sendNotConnectedError(command)
        }
        let degrees = command.arguments[0] as! Float
        currentTurn = 0.0
        currentTurnByDegrees = degrees

        let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK)
        commandDelegate!.sendPluginResult(pluginResult, callbackId:command.callbackId)
    }

    func pole(command: CDVInvokedUrlCommand) {
        if (self.state == .Unknown) {
            return sendNotConnectedError(command)
        }
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
        if (self.state == .Unknown) {
            return sendNotConnectedError(command)
        }
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
        NSLog("Traveldata command: " + message)

        let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAsString: message)
        commandDelegate!.sendPluginResult(pluginResult, callbackId:command.callbackId)
    }

    // func hasReachedCurrentRange() -> Bool {
    //     return currentRangeInCm > 0 && abs(avgEncoderTotalCm) >= currentRangeInCm
    // }

    func doubleDriveShouldUpdate(theDouble:DRDouble) {
        // if (hasReachedCurrentRange()) {
        //     theDouble.drive(DRDriveDirection.Stop, turn: 0.0)
        //     currentRangeInCm = 0.0
        //     stop()
        //     NSLog("*** hasReachedCurrentRange ***")
        // }
        if (currentSpeed != 0.0 || currentTurn != 0.0) {
            //NSLog("*** avgEncoderTotalCm: \(avgEncoderTotalCm) | leftEncoderTotalCm: \(leftEncoderTotalCm) | rightEncoderTotalCm: \(rightEncoderTotalCm) | drive: \(drive) ***")
            theDouble.variableDrive(currentSpeed, turn: currentTurn)
        } else if (currentTurnByDegrees != 0.0) {
            theDouble.turnByDegrees(currentTurnByDegrees)
            currentTurnByDegrees = 0.0
        }

    }

    func calculateSpeed() -> Float {
      var speed = currentDrive;

      if (currentRangeInCm > 0) {
          let deaccelerateStart:Float = speed > 0.5 ? 90 : 50
          let deaccelerateEnd:Float = speed > 0.5 ? 40 : 20
          let deaccelerateRange = deaccelerateStart - deaccelerateEnd

          let remainingRange = currentRangeInCm - abs(avgEncoderTotalCm)

          if (remainingRange < deaccelerateEnd) {
              if (currentDrive != 0.0) {
                  speed = 0.0
              }
          } else if (remainingRange < deaccelerateStart) {
              let remainingDeaccelerateRange = remainingRange - deaccelerateEnd
              let remainingRangeZeroTowardsOne:Float = (1-(remainingDeaccelerateRange/deaccelerateRange))
              let halfPI:Float = Float(M_PI / 2.0)
              let deacceleration:Float = (sin(halfPI * remainingRangeZeroTowardsOne + halfPI))
              speed = currentDrive * deacceleration
          }
      }
      return speed
    }

    var detectCollision = false;
    var deaccelerationCount = 0;

    func doubleTravelDataDidUpdate(theDouble: DRDouble!) {
        let cmPerInches:Float = 2.54;

        let leftEncoderDeltaInches = theDouble.leftEncoderDeltaInches
        let rightEncoderDeltaInches = theDouble.rightEncoderDeltaInches
        let avgEncoderDeltaInches = (leftEncoderDeltaInches + rightEncoderDeltaInches) / 2.0

        leftEncoderTotalInches += leftEncoderDeltaInches
        rightEncoderTotalInches += rightEncoderDeltaInches
        avgEncoderTotalInches = (leftEncoderTotalInches + rightEncoderTotalInches) / 2.0

        leftEncoderTotalCm = leftEncoderTotalInches * cmPerInches
        rightEncoderTotalCm = rightEncoderTotalInches * cmPerInches
        avgEncoderTotalCm = avgEncoderTotalInches * cmPerInches

        currentSpeed = calculateSpeed()

        if (self.isMoving) {
          if (currentSpeed == 0.0 && self.state == .Driving) {
              currentDrive = 0.0
              NSLog("*** STOP SPEEDER - range: \(avgEncoderTotalCm) | currentSpeed: \(currentSpeed) ***")
          }
          currentDirection = avgEncoderDeltaInches > 0 ? .Forward : .Backward
          let previousSpeedInCmPerSecond = currentSpeedInCmPerSecond
          currentSpeedInCmPerSecond = ((avgEncoderDeltaInches * cmPerInches) / 100) * 1000
          updateState()
          detectDeacceleration(currentSpeedInCmPerSecond, previousSpeedInCmPerSecond:previousSpeedInCmPerSecond)
        }

        detectCollision(avgEncoderDeltaInches)

        if (self.isMoving) {
          NSLog("*** range: \(avgEncoderTotalCm) cm - ∆: \(avgEncoderDeltaInches) inch - drive: \(currentSpeed) - speed: \(currentSpeedInCmPerSecond) cm/s - detect: \(detectCollision) - deacc.count: \(deaccelerationCount) - dir: \(directionToArrow(driveDirection))\(directionToArrow(currentDirection)) next: \(directionToArrow(nextDriveDirection))")
        }

        if (self.drivingOrRolling && (leftEncoderTotalInches != 0.0 || rightEncoderTotalInches != 0.0)) {
            //NSLog("***  doubleTravelDataDidUpdate - avgEncoderTotalCm: \(avgEncoderTotalCm) ***")
            updateTravelData()
        }
    }

    func detectDeacceleration(currentSpeedInCmPerSecond:Float, previousSpeedInCmPerSecond:Float) {
      if (state == .Rolling && currentDirection == driveDirection) {
        if (abs(currentSpeedInCmPerSecond) > 0 && abs(currentSpeedInCmPerSecond) < 10 && abs(currentSpeedInCmPerSecond) < abs(previousSpeedInCmPerSecond)) {
          deaccelerationCount += 1
          if (deaccelerationCount >= 3) {
            updateState(.Stopping)
          }
        }
      }
      if (self.drivingOrRolling && currentDirection != driveDirection && driveDirection != nextDriveDirection && nextDriveDirection != .Stop) {
        NSLog("Switching drive direction...")
        driveDirection = nextDriveDirection
        nextDriveDirection = .Stop
      }
    }

    func detectCollision(wheelDirection:Float) {
      if (self.drivingOrRolling) {
          if (collisionDirection == 0.0) {
            detectCollision = true
            if (currentDirection != driveDirection) {
              let collisionDirectionAsString = directionToString(currentDirection)
              NSLog("Collision detected - direction: \(collisionDirectionAsString) - speed: \(currentSpeedInCmPerSecond)")
              updateCollision(collisionDirectionAsString, force: wheelDirection);
              collisionDirection = wheelDirection
              rangeSinceCollision = 0.0
              detectCollision = false
            }
          } else if ((collisionDirection < 0 && wheelDirection > 0) ||
                     (collisionDirection > 0 && wheelDirection < 0)) {
            rangeSinceCollision += wheelDirection
            NSLog("--- Now moving opposite after collision - rangeSinceCollision: \(rangeSinceCollision) ")
            if (abs(rangeSinceCollision) > 0.5) {
                //Reset collision detection:
                NSLog("Resetting collision direction...")
                collisionDirection = 0.0
                rangeSinceCollision = 0.0
                detectCollision = true
            }
          }
      } else if (state == .Balancing) {
          //TODO: If travelData > pushThreshold => raisePushEvent!
      } else {
        detectCollision = false
      }
    }

    func directionToString(direction:DRDriveDirection) -> String {
      var directionAsString = ""
      if (direction == .Forward) {
        directionAsString = "forward"
      } else if (direction == .Backward) {
        directionAsString = "back"
      }
      return directionAsString
    }

    func directionToArrow(direction:DRDriveDirection) -> String {
      var directionAsString = "-"
      if (direction == .Forward) {
        directionAsString = ">"
      } else if (direction == .Backward) {
        directionAsString = "<"
      }
      return directionAsString
    }

    func sendDriveRangeSuccess() {
      if (self.driveCallbackId != nil && !self.driveCallbackId!.isEmpty) {
        let data = getTravelData()
        NSLog("Do sendDriveRangeSuccess...")
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAsDictionary: data as [String : AnyObject])
        commandDelegate!.sendPluginResult(pluginResult, callbackId:self.driveCallbackId!)
        driveCallbackId = nil
      }
    }

    func updateTravelData() {
        if (self.travelDataCallbackId != nil && !self.travelDataCallbackId!.isEmpty) {
            let data = getTravelData()
            //NSLog("Send traveldata...")
            let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAsDictionary: data as [String : AnyObject])
            pluginResult.setKeepCallbackAsBool(true)
            commandDelegate!.sendPluginResult(pluginResult, callbackId:self.travelDataCallbackId!)
        }
    }

    func getTravelData() -> [String : AnyObject] {
      let data: [String : AnyObject] = [
          "leftEncoderTotalInches" : leftEncoderTotalInches,
          "rightEncoderTotalInches" : rightEncoderTotalInches,
          "avgEncoderTotalInches" : avgEncoderTotalInches,
          "leftEncoderTotalCm" : leftEncoderTotalCm,
          "rightEncoderTotalCm" : rightEncoderTotalCm,
          "avgEncoderTotalCm" : avgEncoderTotalCm,
          "speed" : currentSpeedInCmPerSecond,
          "range" : abs(avgEncoderTotalCm),
          "time" : stringFromNSDate(NSDate()),
          "start": stringFromNSDate(driveStartDate)
      ]
      return data
    }

    func doubleStatusDidUpdate(theDouble: DRDouble!) {
        updateStateFromKickstandState(theDouble.kickstandState)
        updateStatus()
        // NSLog("*** poleHeightPercent: \(DRDouble.sharedDouble().poleHeightPercent) ***")
        // NSLog("*** kickstandState: \(DRDouble.sharedDouble().kickstandState) ***")
        NSLog("*** batteryPercent: \(DRDouble.sharedDouble().batteryPercent) ***")
        // NSLog("*** batteryIsFullyCharged: \(DRDouble.sharedDouble().batteryIsFullyCharged) ***")
        // NSLog("*** firmwareVersion: \(DRDouble.sharedDouble().firmwareVersion) ***")
    }

    func updateStatus() {
        if (self.statusCallbackId != nil && !self.statusCallbackId!.isEmpty) {
            var data: [String : AnyObject] = [:]
            let sharedDouble = DRDouble.sharedDouble()
            if (sharedDouble.serial != nil) {
                data = [
                    "batteryPercent" : sharedDouble.batteryPercent,
                    "batteryIsFullyCharged" : sharedDouble.batteryIsFullyCharged,
                    "kickstandState" : UInt(sharedDouble.kickstandState),
                    "poleHeightPercent" : sharedDouble.poleHeightPercent,
                    "serial" : sharedDouble.serial,
                    "firmwareVersion" : sharedDouble.firmwareVersion
                ]
            }

            let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAsDictionary: data as [String : AnyObject])
            pluginResult.setKeepCallbackAsBool(true)
            commandDelegate!.sendPluginResult(pluginResult, callbackId:self.statusCallbackId!)
        }
    }

    func updateCollision(direction:NSString, force:Float) {
        if (self.collisionCallbackId != nil && !self.collisionCallbackId!.isEmpty) {
            NSLog("*** Collision: \(direction) ***")
            let data: [String : AnyObject] = [
                "direction" : collisionDirection,
                "force" : force
            ]
            let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAsDictionary: data as [String : AnyObject])
            pluginResult.setKeepCallbackAsBool(true)
            commandDelegate!.sendPluginResult(pluginResult, callbackId:self.collisionCallbackId!)
        }
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
        leftEncoderTotalInches = 0.0
        rightEncoderTotalInches = 0.0
        avgEncoderTotalCm = 0.0
        leftEncoderTotalCm = 0.0
        rightEncoderTotalCm = 0.0
        avgEncoderTotalCm = 0.0
        driveStartDate = NSDate()
        currentSpeedInCmPerSecond = 0.0
        collisionDirection = 0.0
        rangeSinceCollision = 0.0
        detectCollision = false
        deaccelerationCount = 0
        DRDouble.sharedDouble().startTravelData()
    }

    func stop() {
        currentDrive = 0.0
        currentTurn = 0.0
        currentSpeed = 0.0
        //currentRangeInCm = 0.0
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
                if (currentDrive != 0.0) {
                    newState = .Starting
                }
            case .Starting:
                if (currentDrive == 0.0) {
                  if (currentDirection == driveDirection && abs(currentSpeedInCmPerSecond) > 5) {
                    newState = .Rolling
                  } else if (abs(currentSpeedInCmPerSecond) < 0.1) {
                    newState = .Balancing
                  }
                } else if (currentDirection == driveDirection && abs(currentSpeedInCmPerSecond) > 10) {
                    newState = .Driving
                }
            case .Driving:
                if (currentDrive == 0.0) {
                    newState = .Rolling
                }
            case .Rolling:
                if (currentDrive != 0.0 && currentDirection == driveDirection) {
                    newState = .Driving
                }
            case .Stopping:
                if (currentDrive != 0.0) {
                    newState = .Starting
                    NSLog("Switching drive direction...")
                    driveDirection = nextDriveDirection
                    nextDriveDirection = .Stop
                } else if (currentDirection != driveDirection) {
                    NSLog("Stopping => Balancing: Set speed to 0...")
                    newState = .Balancing
                    DRDouble.sharedDouble().stopTravelData()
                    driveDirection = .Stop
                    currentDirection = .Stop
                    nextDriveDirection = .Stop
                    currentSpeedInCmPerSecond = 0.0
                    detectCollision = false
                    deaccelerationCount = 0
                    updateTravelData()
                    if (currentRangeInCm > 0) {
                       NSLog("About to sendDriveRangeSuccess... state: \(newState)")
                       sendDriveRangeSuccess()
                    }
                }
            default:
                break
            }
        }
        if (newState != self.state) {
            self.previousState = self.state
            self.state = newState
            NSLog("*** state: \(self.previousState) => \(self.state) ***")
            // if (self.state == .Balancing) {
            //   NSLog("Resetting collision direction...")
            //   collisionDirection = 0.0
            // }
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

    var isMoving: Bool {
        get {
            return self.state == .Starting || self.state == .Stopping || self.drivingOrRolling
        }
    }

}
