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

    var currentDrive:Float = 0.0;
    var currentTurn:Float = 0.0;
    var currentDirection:DRDriveDirection = .Stop;
    var currentSpeed:Float = 0.0;
    var currentSpeedInCmPerSecond:Float = 0.0;
    var currentSpeedInCmPerSecondPer100Ms:Float = 0.0;
    var currentRangeInCm:Float = 0.0;
    var currentTurnByDegrees:Float = 0.0;
    var lastAvgEncoderDeltaInches:Float = 0.0;
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
    var state = RobotState.Unknown;
    var previousState = RobotState.Unknown;
    var driveData:[[String : AnyObject]] = [[String : AnyObject]]();

    override func pluginInitialize() {
        super.pluginInitialize()
        NSLog("******** CDVDoubleRobotics instantiated... *******")
        driveStartDate = NSDate()
        driveData = [[String : AnyObject]]();
        collisionDirection = 0.0
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

    func drive(command: CDVInvokedUrlCommand) {
        rangePeak = 0.0
        let driveDirection = command.arguments[0] as! Float
        let turn = command.arguments[1] as! Float
        let rangeInCm = command.arguments[2] as! Float

        currentDrive = driveDirection
        currentTurn = turn
        currentRangeInCm = rangeInCm
        currentDirection = driveDirection > 0 ? .Forward : .Backward

        if (self.state == .Balancing || self.state == .Rolling) {
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
        NSLog("*** stop() ***")
        stop()
        driveCallbackId = nil
        currentRangeInCm = 0.0
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

        currentSpeed = calculateSpeed();

        if (currentSpeed == 0.0 && currentDrive != 0.0) {
            stop()
            NSLog("*** STOP - avgEncoderTotalCm: \(avgEncoderTotalCm) | currentSpeed: \(currentSpeed) ***")
        } else if (currentSpeed != 0.0 || currentTurn != 0.0) {
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

    var travelDataCounter:Float = 0.0;
    var travelDataStartTime = NSDate();
    var travelDataEndTime = NSDate();
    var travelDataEnded = false;
    var detectCollision = false;
    var deaccelerationCount = 0;

    func doubleTravelDataDidUpdate(theDouble: DRDouble!) {
        let cmPerInches:Float = 2.54;
        //Allow 250 ms between speed samples:
        let speedMeasureIntervalInSeconds:Float = 0.15;

        updateState()

        let leftEncoderDeltaInches = theDouble.leftEncoderDeltaInches
        let rightEncoderDeltaInches = theDouble.rightEncoderDeltaInches
        let avgEncoderDeltaInches = (leftEncoderDeltaInches + rightEncoderDeltaInches) / 2.0

        leftEncoderTotalInches = leftEncoderTotalInches + leftEncoderDeltaInches
        rightEncoderTotalInches = rightEncoderTotalInches + rightEncoderDeltaInches
        avgEncoderTotalInches = (leftEncoderTotalInches + rightEncoderTotalInches) / 2.0
        leftEncoderTotalCm = leftEncoderTotalInches * cmPerInches
        rightEncoderTotalCm = rightEncoderTotalInches * cmPerInches
        avgEncoderTotalCm = avgEncoderTotalInches * cmPerInches

        if (self.drivingOrRolling) {
          let speedInCmPerSecondPer100Ms:Float = ((avgEncoderDeltaInches * cmPerInches) / 100) * 1000
          if (state == .Rolling) {
            if (detectCollision == true) {
              if ((speedInCmPerSecondPer100Ms > 0 && speedInCmPerSecondPer100Ms < 10 && speedInCmPerSecondPer100Ms < currentSpeedInCmPerSecondPer100Ms) ||
                  (speedInCmPerSecondPer100Ms < 0 && speedInCmPerSecondPer100Ms > -10 && speedInCmPerSecondPer100Ms > currentSpeedInCmPerSecondPer100Ms)) {
                deaccelerationCount += 1
                if (deaccelerationCount >= 3) {
                  detectCollision = false
                }
              }
            }
          }
          currentSpeedInCmPerSecondPer100Ms = speedInCmPerSecondPer100Ms
          if ((currentDirection == .Forward && avgEncoderTotalInches < 0) ||
              (currentDirection == .Backward && avgEncoderTotalInches > 0)) {
                detectCollision = false
          } else if ((avgEncoderTotalInches > 0 && currentSpeedInCmPerSecondPer100Ms > 10) ||
              (avgEncoderTotalInches < 0 && currentSpeedInCmPerSecondPer100Ms < -10)) {
            detectCollision = true
          }
        } else {
          currentSpeedInCmPerSecondPer100Ms = 0.0
          detectCollision = false
          deaccelerationCount = 0
        }

        detectCollision(avgEncoderTotalInches, wheelDirection:avgEncoderDeltaInches)
        lastAvgEncoderDeltaInches = avgEncoderDeltaInches


        if (self.drivingOrRolling) {// && abs(avgEncoderTotalCm) > 5.0) {

          if (avgEncoderTotalCm < 100) {
            travelDataCounter = 0.0;
            travelDataEnded = false;
          }
          if (avgEncoderTotalCm > 100 && avgEncoderTotalCm < 200) {
            if (travelDataCounter == 0) {
              travelDataStartTime = NSDate()
            }
            travelDataCounter += 1.0;
          } else if (avgEncoderTotalCm > 200 && !travelDataEnded) {
            travelDataEndTime = NSDate()
            let elapsedTravelDataTimeInMs = Float(travelDataEndTime.timeIntervalSinceDate(travelDataStartTime)) * 1000
            let averageTravelDataTimeInMs = elapsedTravelDataTimeInMs / travelDataCounter

            NSLog(" XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX")
            NSLog(" XXX range: \(avgEncoderTotalCm) cm - travelDataCounter: \(travelDataCounter) - elapsed: \(elapsedTravelDataTimeInMs) ms - averageTravelDataTime: \(averageTravelDataTimeInMs) ms")
            NSLog(" XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX")
            travelDataEnded = true
          }
          var startTime = driveStartDate
          let currentTime = NSDate()
          let currentRange = abs(avgEncoderTotalCm)
          var rangeInCm = currentRange
          var new = [
              "avgEncoderTotalCm" : currentRange,
              "time" : currentTime
          ]
          if let last = driveData.last {
            let startRange:Float = last["avgEncoderTotalCm"] as! Float
            rangeInCm = currentRange - startRange
            startTime = last["time"] as! NSDate
          }
          let elapsedTimeInSeconds = Float(currentTime.timeIntervalSinceDate(startTime))

          if (elapsedTimeInSeconds > speedMeasureIntervalInSeconds) {
            let speedInCmPerSecond:Float = rangeInCm / elapsedTimeInSeconds
            new["speed"] = speedInCmPerSecond
            driveData.append(new)
            currentSpeedInCmPerSecond = speedInCmPerSecond
            //NSLog(" *** range: \(abs(avgEncoderTotalCm)) - elapsed: \(elapsedTimeInSeconds) - current speed: \(speedInCmPerSecond) cm/s")
            // if (driveData.count > 3) {
            //     driveData.removeAtIndex(0)
            //     var totalItems:Float = 0.0
            //     var totalSpeed:Float = 0.0
            //     for item in driveData {
            //         totalItems++;
            //         totalSpeed += item["speed"] as! Float
            //     }
            //     let avgSpeed = totalSpeed / totalItems
            //     NSLog(" *** range: \(abs(avgEncoderTotalCm)) - avg speed: \(avgSpeed) cm/s - new speed: \(new["speed"] as! Float) cm/s")
            // } else {
            //   NSLog(" *** range: \(abs(avgEncoderTotalCm)) - avg speed: 0.000 cm/s - new speed: \(new["speed"] as! Float) cm/s")
            // }
            //NSLog(" *** range: \(abs(avgEncoderTotalCm)) - delta: \(avgEncoderDeltaInches) - speed: \(new["speed"] as! Float) cm/s - collisionDirection: \(collisionDirection)")
          }
          //if (currentSpeedInCmPerSecond < 15 || collisionDirection != 0.0) {
          //NSLog(" *** elapsed: \(elapsedTimeInSeconds * 1000)")
          NSLog(" *** range: \(avgEncoderTotalCm) cm - delta: \(avgEncoderDeltaInches) inch - drive: \(currentSpeed) - speed: \(currentSpeedInCmPerSecondPer100Ms) cm/s - detect: \(detectCollision) - deacc.count: \(deaccelerationCount)")
          //}

        }


        if (state == .Rolling) {
            //NSLog("*** avgEncoderTotalCm: \(avgEncoderTotalCm) ***")
            // if (abs(avgEncoderTotalCm) > rangePeak) {
            //     rangePeak = abs(avgEncoderTotalCm)
            //     //NSLog("*** rangePeak: \(rangePeak) ***")
            //} else if (collisionDirection == 0.0) {
            if (((avgEncoderTotalInches > 0 && avgEncoderDeltaInches < 0) ||
                (avgEncoderTotalInches < 0 && avgEncoderDeltaInches > 0))
                && collisionDirection == 0.0) {
                //DRDouble.sharedDouble().stopTravelData()
                updateState(.Balancing)
                currentDirection = .Stop
                if (currentRangeInCm > 0) {
                   NSLog("About to sendDriveRangeSuccess... state: \(state)")
                   sendDriveRangeSuccess()
                }
            }
        }
        if (self.drivingOrRolling && (leftEncoderTotalInches != 0.0 || rightEncoderTotalInches != 0.0)) {
            //NSLog("***  doubleTravelDataDidUpdate - avgEncoderTotalCm: \(avgEncoderTotalCm) ***")
            updateTravelData()
        }
    }

    func detectCollision(driveDirection:Float, wheelDirection:Float) {
      let collisionMinimumRangeThreshold:Float = 5.0;
      let collisionMinimumSpeedThreshold:Float = 10;
      if (self.drivingOrRolling) { // && abs(avgEncoderTotalCm) > collisionMinimumRangeThreshold) {
      //if (self.drivingOrRolling) {
          //NSLog("*** avgEncoderTotalInches: \(avgEncoderTotalInches) ***")
          if (collisionDirection == 0.0) {
              //if (currentSpeedInCmPerSecond > collisionMinimumSpeedThreshold ) {
              if (detectCollision) {
                let directionChange = detectDirectionChange(driveDirection, wheelDirection: wheelDirection)
                if (!directionChange.isEmpty) {
                    NSLog("Collision detected - direction: \(directionChange) - speed: \(currentSpeedInCmPerSecond)")
                    updateCollision(directionChange, force: wheelDirection);
                    collisionDirection = wheelDirection
                    detectCollision = false
                }
              }
          } else if ((collisionDirection < 0 && wheelDirection > 0) ||
                     (collisionDirection > 0 && wheelDirection < 0)) {
                  //Reset collision detection:
                  NSLog("Resetting collision direction...")
                  collisionDirection = 0.0
          }
      } else if (state == .Balancing) {
          //TODO: If travelData > pushThreshold => raisePushEvent!
      }
    }

    func detectDirectionChange(driveDirection:Float, wheelDirection:Float) -> String {
      var direction = ""
      if (driveDirection > 0 && wheelDirection < 0) {
        direction = "back"
      } else if (driveDirection < 0 && wheelDirection > 0) {
        direction = "forward"
      }
      return direction
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
          "speed" : currentSpeed,
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
        // NSLog("*** batteryPercent: \(DRDouble.sharedDouble().batteryPercent) ***")
        // NSLog("*** batteryIsFullyCharged: \(DRDouble.sharedDouble().batteryIsFullyCharged) ***")
        // NSLog("*** firmwareVersion: \(DRDouble.sharedDouble().firmwareVersion) ***")
    }

    func updateStatus() {
        if (self.statusCallbackId != nil && !self.statusCallbackId!.isEmpty) {
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
        lastAvgEncoderDeltaInches = 0.0
        leftEncoderTotalInches = 0.0
        rightEncoderTotalInches = 0.0
        avgEncoderTotalCm = 0.0
        leftEncoderTotalCm = 0.0
        rightEncoderTotalCm = 0.0
        avgEncoderTotalCm = 0.0
        collisionDirection = 0.0
        driveStartDate = NSDate()
        driveData = [[String : AnyObject]]()
        currentSpeedInCmPerSecond = 0.0
        currentSpeedInCmPerSecondPer100Ms = 0.0
        detectCollision = false
        deaccelerationCount = 0
        DRDouble.sharedDouble().startTravelData()
    }

    func stop() {
        currentDrive = 0.0
        currentTurn = 0.0
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
              case .Balancing, .Rolling:
                if (currentDrive != 0.0) {
                    newState = .Driving
                }
            case .Driving:
                if (currentDrive == 0.0) {
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
