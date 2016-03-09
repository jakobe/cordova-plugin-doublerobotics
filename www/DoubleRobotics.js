var utils = require('cordova/utils'),
    exec = require('cordova/exec'),
    cordova = require('cordova');

var BATTERYPERCENT_CRITICAL = 0.05;
var BATTERYPERCENT_LOW = 0.20;

var doubleRobotics = new DoubleRobotics();

function statusHandlers() {
    return doubleRobotics.channels.batterystatus.numHandlers +
           doubleRobotics.channels.batterylow.numHandlers +
           doubleRobotics.channels.batterycritical.numHandlers;
}

function travelDataHandlers() {
    return doubleRobotics.channels.traveldata.numHandlers;
}

function DoubleRobotics() {
    this._batteryPercent = null;
    this._batteryIsFullyCharged = null;

    this.channels = {
        batterystatus: cordova.addWindowEventHandler("batterystatus"),
        batterylow: cordova.addWindowEventHandler("batterylow"),
        batterycritical: cordova.addWindowEventHandler("batterycritical"),
        traveldata: cordova.addWindowEventHandler("traveldata")
    };
    for (var key in this.channels) {
        this.channels[key].onHasSubscribersChange = onHasSubscribersChange;
    }

    /**
    * Callback for robot status
    *
    * @param {Object} status            keys: batteryPercent, batteryIsFullyCharged, kickstandState, poleHeightPercent, serial, firmwareVersion
    */
    function _status(status) {
        if (status) {
            if (doubleRobotics._batteryPercent !== status.batteryPercent ||
                doubleRobotics._batteryIsFullyCharged !== doubleRobotics.batteryIsFullyCharged) {
                if (status.batteryPercent == null && doubleRobotics._batteryPercent != null) {
                    return; // special case where callback is called because we stopped listening to the native side.
                }
                if (status.batteryPercent !== doubleRobotics._batteryPercent) {
                    // BatteryPercent changed. Fire batterystatus event
                    cordova.fireWindowEvent("batterystatus", status);
                }
                // NOTE: the following are NOT exact checks, as we want to catch a transition from 
                // above the threshold to below.
                if (doubleRobotics._batteryPercent > BATTERYPERCENT_CRITICAL && status.batteryPercent <= BATTERYPERCENT_CRITICAL) {
                    // Fire critical battery event
                    cordova.fireWindowEvent("batterycritical", status);
                }
                else if (doubleRobotics._batteryPercent > BATTERYPERCENT_LOW && status.batteryPercent <= BATTERYPERCENT_LOW) {
                    // Fire low battery event
                    cordova.fireWindowEvent("batterylow", status);
                }
                doubleRobotics._batteryPercent = status.batteryPercent;
                doubleRobotics._batteryIsFullyCharged = status.batteryIsFullyCharged;
                
            }
        }
        //var statusString = "";
        //for (var prop in status) {
        //    statusString += ("status." + prop + " = " + status[prop] + "\n");
        //}
        //alert(statusString);
    }

    /**
* Callback for robot traveldata
*
* @param {Object} traveldata            keys: leftEncoderDeltaInches, rightEncoderDeltaInches, leftEncoderDeltaCm, rightEncoderDeltaCm
*/
    function _traveldata(traveldata) {
        if (traveldata) {
            cordova.fireWindowEvent("traveldata", traveldata);
        }
    }

    /**
    * Error callback for DoubleRobotics start
    */
    function _error(e) {
        console.log("Error initializing DoubleRobotics: " + e);
    };


    function onHasSubscribersChange() {
        try {
            // If we just registered the first handler, make sure native listener is started.
            if (this.numHandlers === 1 && statusHandlers() === 1) {
                exec(_status, _error, "DoubleRobotics", "startStatusListener", []);
            } else if (statusHandlers() === 0) {
                exec(null, null, "DoubleRobotics", "stop", []);
            }
            // If we just registered the first handler, make sure native listener is started.
            if (this.numHandlers === 1 && travelDataHandlers() === 1) {
                exec(_traveldata, _error, "DoubleRobotics", "startTravelDataListener", []);
            } else if (travelDataHandlers() === 0) {
                exec(null, null, "DoubleRobotics", "stop", []);
            }
        }
        catch (err) {
            alert("Error! => " + err);
        }
    };


    /* DoubleRobotics Commands: */

    this.DRDriveDirection = {
        Stop: 0,
        Forward: 1,
        Backward: -1
    }

    this.poleDown = function (success, fail) {
        cordova.exec(success, fail, "DoubleRobotics", "pole", ['poleDown']);
    }
    this.poleStop = function (success, fail) {
        cordova.exec(success, fail, "DoubleRobotics", "pole", ['poleStop']);
    }
    this.poleUp = function (command, success, fail) {
        cordova.exec(success, fail, "DoubleRobotics", "pole", ['poleUp']);
    }
    
    this.retractKickstands = function (success, fail) {
        cordova.exec(success, fail, "DoubleRobotics", "kickstand", ['retractKickstands']);
    }
    this.deployKickstands = function (success, fail) {
        cordova.exec(success, fail, "DoubleRobotics", "kickstand", ['deployKickstands']);
    }


   this.startTravelData = function (success, fail) {
       cordova.exec(success, fail, "DoubleRobotics", "travelData", ["startTravelData"]);
   }
   this.stopTravelData = function (success, fail) {
       cordova.exec(success, fail, "DoubleRobotics", "travelData", ["stopTravelData"]);
   }
   this.drive = function (command, success, fail) {
   	cordova.exec(success, fail, "DoubleRobotics", "drive", [command]);
   }
   this.stop = function (success, fail) {
       cordova.exec(success, fail, "DoubleRobotics", "stop", []);
   }
   this.variableDrive = function (command, driveDirection, turn, success, fail) {
       if (typeof driveDirection === "string") driveDirection = parseFloat(driveDirection);
       if (typeof turn === "string") turn = parseFloat(turn);
       cordova.exec(success, fail, "DoubleRobotics", "variableDrive", [command, isNaN(driveDirection) ? 1.0 : driveDirection, isNaN(turn) ? 0.0 : turn]);
   }
   this.variableDrive2 = function (driveDirection, turn, rangeInCm, success, fail) {
       if (typeof driveDirection === "string") driveDirection = parseFloat(driveDirection);
       if (typeof turn === "string") turn = parseFloat(turn);
       if (typeof rangeInCm === "string") rangeInCm = parseFloat(rangeInCm);
       cordova.exec(success, fail, "DoubleRobotics", "variableDrive2", [isNaN(driveDirection) ? 1.0 : driveDirection, isNaN(turn) ? 0.0 : turn, isNaN(rangeInCm) ? 0.0 : rangeInCm]);
   }
   this.turnByDegrees = function (degrees, success, fail) {
       if (typeof degrees === "string") degrees = parseFloat(degrees);
       cordova.exec(success, fail, "DoubleRobotics", "turnByDegrees", [isNaN(degrees) ? 180.0 : degrees]);
   }

}

module.exports = doubleRobotics;