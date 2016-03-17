function DoubleRoboticsProxy() {
    var travelDataCallback,
        collisionCallback,
        driveIntervalId,
        leftEncoderDeltaCm,
        rightEncoderDeltaCm,
        driveData = [],
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
                leftEncoderDeltaCm = 0.0;
                rightEncoderDeltaCm = 0.0;
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
        //if (!driveStartDate) {
        driveStartDate = new Date();
        leftEncoderDeltaCm = 0.0;
        rightEncoderDeltaCm = 0.0;
        //}
        //console.log("DoubleRoboticsProxy.drive | driveDirection:" + driveDirection);// + " (" + new Date().toISOString() + ")");
        if (driveIntervalId) {
            clearInterval(driveIntervalId);
        }
        driveIntervalId = setInterval(function () {
            driveCounter++;
            var deaccelerateStart = 50;
            var remainingRange = rangeInCm - Math.abs(leftEncoderDeltaCm);
            if (rangeInCm && remainingRange < deaccelerateStart) {
                driveDirection *= 0.95;
            }
            leftEncoderDeltaCm += (10.0 * driveDirection);
            rightEncoderDeltaCm += (10.0 * driveDirection);
            var elapsedTimeInMs = new Date() - driveStartDate;
            var newData = {
                speed: driveDirection,
                range: Math.abs(leftEncoderDeltaCm),
                time: new Date(),//msToTime(elapsedTimeInMs),
                start: driveStartDate
            };
            driveData.push(newData)
            //console.log("DoubleRoboticsProxy.drive | driveDirection:" + driveDirection + " | leftEncoderDeltaCm: " + leftEncoderDeltaCm + " | elapsedTimeInMs: " + elapsedTimeInMs);// + " (" + new Date().toISOString() + ")");
            var cmPerInches = 2.54;
            var travelData = {
                leftEncoderDeltaInches: leftEncoderDeltaCm / cmPerInches,
                rightEncoderDeltaInches: rightEncoderDeltaCm / cmPerInches,
                leftEncoderDeltaCm: leftEncoderDeltaCm,
                rightEncoderDeltaCm: rightEncoderDeltaCm,
                driveData: driveData,
                lastDrive: newData
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
            if (rangeInCm && Math.abs(leftEncoderDeltaCm) >= rangeInCm) {
                console.log("DoubleRoboticsProxy.stop => rangeInCm >= " + rangeInCm + " | leftEncoderDeltaCm: " + leftEncoderDeltaCm);// + " (" + new Date
                clearInterval(driveIntervalId);
            }
        }, 200);
        if (typeof success === "function") {
            setTimeout(function () {
                success({ serial: "00-00FAKE", message: "Fake Robot..." });
            }, 0);
        }
    }
    this.turnByDegrees = function (success, fail, arguments) {
        var degrees = arguments[0];
        console.log("DoubleRoboticsProxy.turnByDegrees: " + degrees);
    }
    this.stop = function (success, fail) {
        console.log("DoubleRoboticsProxy.stop()");
        clearInterval(driveIntervalId);
        //driveData.length = 0;
        //driveStartDate = null;
    }

    this.startStatusListener = function (success, fail) {
        console.log("DoubleRoboticsProxy.startStatusListener()");
    }

    this.stopStatusListener = function (success, fail) {
        console.log("DoubleRoboticsProxy.stopStatusListener()");
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
        travelDataCallback = null;
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
