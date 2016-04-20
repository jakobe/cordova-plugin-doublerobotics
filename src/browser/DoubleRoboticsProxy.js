function DoubleRoboticsProxy() {
    var travelDataCallback,
        collisionCallback,
        driveIntervalId,
        batteryStatusIntervalId,
        leftEncoderTotalCm,
        rightEncoderTotalCm,
        avgEncoderTotalCm,
        driveStartDate;

    this.pole = function (success, fail, arguments) {
        var poleCommand = arguments[0];
        console.log("DoubleRoboticsProxy." + poleCommand);
        if (typeof success === "function")
            success();
    }

    this.kickstand = function (success, fail, arguments) {
        var kickstandCommand = arguments[0];
        console.log("DoubleRoboticsProxy." + kickstandCommand);
        if (typeof success === "function")
            success();
    }

    this.travelData = function (success, fail, arguments) {
        var travelDataCommand = arguments[0];
        console.log("DoubleRoboticsProxy." + travelDataCommand);
        switch (travelDataCommand) {
            case "startTravelData":
                driveStartDate = new Date();
                leftEncoderTotalCm = 0.0;
                rightEncoderTotalCm = 0.0;
                console.log("TravelData started");
                break;
        }
        if (typeof success === "function")
            success();

    }
    this.drive = function (success, fail, arguments) {
        var driveDirection = arguments[0];
        var turn = arguments[1];
        var rangeInCm = arguments[2];
        var driveCounter = 0;

        if (typeof driveDirection === "string") driveDirection = parseFloat(driveDirection);
        var currentDrive = driveDirection,
            currentSpeed = 0;
        //if (!driveStartDate) {
        driveStartDate = new Date();
        leftEncoderTotalCm = 0.0;
        rightEncoderTotalCm = 0.0;
        avgEncoderTotalCm = 0.0;
        //}
        //console.log("DoubleRoboticsProxy.drive | driveDirection:" + driveDirection);// + " (" + new Date().toISOString() + ")");
        if (driveIntervalId) {
            clearInterval(driveIntervalId);
        }
        driveIntervalId = setInterval(function () {
            driveCounter++;
            var accelerateEnd = 50;
            var deaccelerateStart = 50;
            var range = Math.abs(avgEncoderTotalCm);
            var remainingRange = rangeInCm - range;
            if (range < accelerateEnd) {
              currentSpeed += (10.0 * driveDirection);
            }
            if (rangeInCm > 0) {
              if (remainingRange < deaccelerateStart) {
                currentDrive *= 0.95;
                currentSpeed -= (7.5 * driveDirection);
              }
            }
            leftEncoderTotalCm += (10.0 * currentDrive);
            rightEncoderTotalCm += (10.0 * currentDrive);
            avgEncoderTotalCm = (leftEncoderTotalCm + rightEncoderTotalCm) / 2;
            range = Math.abs(avgEncoderTotalCm);
            if (currentSpeed < 0 || (range >= rangeInCm)) {
              currentSpeed = 0.0;
            }
            var elapsedTimeInMs = new Date() - driveStartDate;
            //console.log("DoubleRoboticsProxy.drive | driveCounter: " + driveCounter + " | currentDrive:" + currentDrive + " | currentSpeed: " + currentSpeed + " | range: " + range + " | elapsedTimeInMs: " + elapsedTimeInMs);// + " (" + new Date().toISOString() + ")");
            var cmPerInches = 2.54;
            var travelData = {
                leftEncoderTotalInches: leftEncoderTotalCm / cmPerInches,
                rightEncoderTotalInches: rightEncoderTotalCm / cmPerInches,
                avgEncoderTotalInches: avgEncoderTotalCm / cmPerInches,
                leftEncoderTotalCm: leftEncoderTotalCm,
                rightEncoderTotalCm: rightEncoderTotalCm,
                avgEncoderTotalCm: avgEncoderTotalCm,
                speed: currentSpeed,
                range: range,
                time: new Date(),//msToTime(elapsedTimeInMs),
                start: driveStartDate
            };
            if (driveCounter === 10) {
              if (collisionCallback && typeof collisionCallback === "function") {
                collisionCallback({
                  direction: 'back',
                  force: 20
                });
              }
            }
            if (travelDataCallback && typeof travelDataCallback === "function")
                travelDataCallback(travelData);
            if (rangeInCm && range >= rangeInCm) {
                console.log("DoubleRoboticsProxy.stop => rangeInCm >= " + rangeInCm + " | range: " + range);// + " (" + new Date
                clearInterval(driveIntervalId);
                if (rangeInCm && rangeInCm > 0) {
                  if (typeof success === "function") {
                    success(travelData);
                  }
                }

            }
        }, 200);
        if (!rangeInCm || rangeInCm === 0) {
          if (typeof success === "function") {
              setTimeout(function () {
                  success();
              }, 0);
          }
        }
    }
    this.turnByDegrees = function (success, fail, arguments) {
        var degrees = arguments[0];
        console.log("DoubleRoboticsProxy.turnByDegrees: " + degrees);
    }
    this.stop = function (success, fail) {
        console.log("DoubleRoboticsProxy.stop()");
        clearInterval(driveIntervalId);
        //driveStartDate = null;
    }

    this.startStatusListener = function (success, fail) {
        console.log("DoubleRoboticsProxy.startStatusListener()");
        var batteryPercent = 100;
        var status = {
          "batteryPercent" : batteryPercent / 100.0,
          "batteryIsFullyCharged" : true,
          "kickstandState" : 0,
          "poleHeightPercent" : 0,
          "serial" : '00-00FAKE',
          "firmwareVersion" : '1004'
         };
        if (typeof success === "function") {
            setTimeout(function () {
                console.log("DoubleRoboticsProxy.batteryStatus: " + status.batteryPercent);
                success(status);
            }, 0);
            batteryStatusIntervalId = setInterval(function() {
              batteryPercent -= 1;
              status.batteryPercent = batteryPercent / 100.0;
              status.batteryIsFullyCharged = (batteryPercent === 100);
              console.log("DoubleRoboticsProxy.batteryStatus: " + status.batteryPercent);
              if (status.batteryPercent >= 0) {
                success(status);
              }
              if (status.batteryPercent <= 0) {
                clearInterval(batteryStatusIntervalId);
              }
            }, 10000);
        }
    }

    this.stopStatusListener = function (success, fail) {
        console.log("DoubleRoboticsProxy.stopStatusListener()");
        clearInterval(batteryStatusIntervalId);
    }

    this.startTravelDataListener = function (success, fail) {
        console.log("DoubleRoboticsProxy.startTravelDataListener()");
        travelDataCallback = success;
    }

    this.stopTravelDataListener = function (success, fail) {
        console.log("DoubleRoboticsProxy.stopTravelDataListener()");
        travelDataCallback = null;
    }

    this.startCollisionListener = function (success, fail) {
        console.log("DoubleRoboticsProxy.startCollisionListener()");
        collisionCallback = success;
    }

    this.stopCollisionListener = function (success, fail) {
        console.log("DoubleRoboticsProxy.stopCollisionListener()");
        collisionCallback = null;
    }

    function msToTime(duration) {
        var milliseconds = parseInt((duration % 1000)),
            seconds = parseInt((duration / 1000) % 60),
            minutes = parseInt((duration / (1000 * 60)) % 60),
            hours = parseInt((duration / (1000 * 60 * 60)) % 24);

        hours = (hours < 10) ? "0" + hours : hours;
        minutes = (minutes < 10) ? "0" + minutes : minutes;
        seconds = (seconds < 10) ? "0" + seconds : seconds;
        milliseconds = (milliseconds < 100) ? "0" + milliseconds : milliseconds;

        return hours + ":" + minutes + ":" + seconds + "." + milliseconds;
    }
}

var proxy = new DoubleRoboticsProxy();

module.exports = proxy;

require("cordova/exec/proxy").add("DoubleRobotics", module.exports);
