var channel = require('cordova/channel');

function DoubleRobotics() {
    var DOUBLEROBOTICS = 'DoubleRobotics',
        BATTERYPERCENT_CRITICAL = 0.05,
        BATTERYPERCENT_LOW = 0.20,
        EVENT_BATTERYSTATUS = 'batterystatus',
        EVENT_BATTERYLOW = 'batterylow',
        EVENT_BATTERYCRITICAL = 'batterycritical',
        EVENT_TRAVELDATA = 'traveldata',
        EVENT_COLLISION = 'collision',
        _batteryPercent = null,
        _batteryIsFullyCharged = null,
        _channels = {
            batterystatus: cordova.addWindowEventHandler(EVENT_BATTERYSTATUS),
            batterylow: cordova.addWindowEventHandler(EVENT_BATTERYLOW),
            batterycritical: cordova.addWindowEventHandler(EVENT_BATTERYCRITICAL),
            traveldata: channel.create(EVENT_TRAVELDATA),
            collision: channel.create(EVENT_COLLISION)
        };
    for (var key in _channels) {
        _channels[key].onHasSubscribersChange = onHasSubscribersChange;
    }

    function statusHandlers() {
        return _channels.batterystatus.numHandlers +
        _channels.batterylow.numHandlers +
        _channels.batterycritical.numHandlers;
    }

    function travelDataHandlers() {
        return _channels.traveldata.numHandlers;
    }

    function collisionHandlers() {
        return _channels.collision.numHandlers;
    }

    /**
     * Callback for robot status
     *
     * @param {Object} status            keys: batteryPercent, batteryIsFullyCharged, kickstandState, poleHeightPercent, serial, firmwareVersion
     */
    function _statusCallback(status) {
        if (status) {
            if (_batteryPercent !== status.batteryPercent ||
                _batteryIsFullyCharged !== status.batteryIsFullyCharged) {
                if (status.batteryPercent == null && _batteryPercent != null) {
                    return; // special case where callback is called because we stopped listening to the native side.
                }
                if (status.batteryPercent !== _batteryPercent) {
                    // BatteryPercent changed. Fire batterystatus event
                    cordova.fireWindowEvent(EVENT_BATTERYSTATUS, status);
                }
                // NOTE: the following are NOT exact checks, as we want to catch a transition from
                // above the threshold to below.
                if (_batteryPercent > BATTERYPERCENT_CRITICAL && status.batteryPercent <= BATTERYPERCENT_CRITICAL) {
                    // Fire critical battery event
                    cordova.fireWindowEvent(EVENT_BATTERYCRITICAL, status);
                }
                else if (_batteryPercent > BATTERYPERCENT_LOW && status.batteryPercent <= BATTERYPERCENT_LOW) {
                    // Fire low battery event
                    cordova.fireWindowEvent(EVENT_BATTERYLOW, status);
                }
                _batteryPercent = status.batteryPercent;
                _batteryIsFullyCharged = status.batteryIsFullyCharged;

            }
        }
    }

    /**
     * Callback for robot traveldata
     *
     * @param {Object} traveldata            keys: leftEncoderTotalInches, rightEncoderTotalInches, avgEncoderTotalInches, leftEncoderTotalCm, rightEncoderTotalCm, avgEncoderTotalCm
     */
    function _traveldataCallback(travelData) {
        _channels[EVENT_TRAVELDATA].fire(travelData);
    }

    /**
     * Callback for robot collision
     *
     * @param {Object} collisionData            keys: direction, force
     */
    function _collisionCallback(collisionData) {
      var collisionDetails = {
        type: 'wheels',
        direction: collisionData.direction,
        force: collisionData.force
      };
      _channels[EVENT_COLLISION].fire(collisionDetails);
    }

    /**
     * Error callback for DoubleRobotics start
     */
    function _error(e) {
        console.log('Error initializing DoubleRobotics: ' + e);
    };


    function onHasSubscribersChange() {
        try {
          switch (this.type) {
            case EVENT_BATTERYSTATUS:
            case EVENT_BATTERYLOW:
            case EVENT_BATTERYCRITICAL:
              // If we just registered the first handler, make sure native listener is started.
              if (this.numHandlers === 1 && statusHandlers() === 1) {
                  cordova.exec(_statusCallback, _error, DOUBLEROBOTICS, 'startStatusListener', []);
              } else if (statusHandlers() === 0) {
                  cordova.exec(null, null, DOUBLEROBOTICS, 'stopStatusListener', []);
              }
              break;
            case EVENT_TRAVELDATA:
              // If we just registered the first handler, make sure native listener is started.
              if (this.numHandlers === 1 && travelDataHandlers() === 1) {
                  cordova.exec(_traveldataCallback, _error, DOUBLEROBOTICS, 'startTravelDataListener', []);
              } else if (travelDataHandlers() === 0) {
                  cordova.exec(null, null, DOUBLEROBOTICS, 'stopTravelDataListener', []);
              }
              break;
            case EVENT_COLLISION:
              // If we just registered the first handler, make sure native listener is started.
              if (this.numHandlers === 1 && collisionHandlers() === 1) {
                  cordova.exec(_collisionCallback, _error, DOUBLEROBOTICS, 'startCollisionListener', []);
              } else if (collisionHandlers() === 0) {
                  cordova.exec(null, null, DOUBLEROBOTICS, 'stopCollisionListener', []);
              }
            default:
          }
        }
        catch (err) {
            alert('Error! => ' + err);
        }
    };

    function _addEventListener(eventname,listener) {
      if (eventname in _channels) {
        _channels[eventname].subscribe(listener);
      }
    }

    function _removeEventListener(eventname,listener) {
      if (eventname in _channels) {
        _channels[eventname].unsubscribe(listener);
      }
    }

    /* DoubleRobotics Commands: */

    /* Event Listeners: */
    this.watchTravelData = function (listener) {
      _addEventListener(EVENT_TRAVELDATA, listener);
    };
    this.clearWatchTravelData = function(listener) {
      _removeEventListener(EVENT_TRAVELDATA, listener);
    };
    this.watchCollision = function (listener) {
      _addEventListener(EVENT_COLLISION, listener);
    };
    this.clearWatchCollision = function(listener) {
      _removeEventListener(EVENT_COLLISION, listener);
    };

    /* Pole Commands: */
    this.poleDown = function (success, fail) {
        cordova.exec(success, fail, DOUBLEROBOTICS, 'pole', ['poleDown']);
    }
    this.poleStop = function (success, fail) {
        cordova.exec(success, fail, DOUBLEROBOTICS, 'pole', ['poleStop']);
    }
    this.poleUp = function (command, success, fail) {
        cordova.exec(success, fail, DOUBLEROBOTICS, 'pole', ['poleUp']);
    }

    /* Kickstand Commands: */
    this.retractKickstands = function (success, fail) {
        cordova.exec(success, fail, DOUBLEROBOTICS, 'kickstand', ['retractKickstands']);
    }
    this.deployKickstands = function (success, fail) {
        cordova.exec(success, fail, DOUBLEROBOTICS, 'kickstand', ['deployKickstands']);
    }

    /* TravelData Commands: */
    this.startTravelData = function (success, fail) {
        cordova.exec(success, fail, DOUBLEROBOTICS, 'travelData', ['startTravelData']);
    }
    this.stopTravelData = function (success, fail) {
        cordova.exec(success, fail, DOUBLEROBOTICS, 'travelData', ['stopTravelData']);
    }

    /* Drive Commands: */
    this.drive = function (driveDirection, turn, rangeInCm, success, fail) {
        if (typeof driveDirection === 'string') driveDirection = parseFloat(driveDirection);
        if (typeof turn === 'string') turn = parseFloat(turn);
        if (typeof rangeInCm === 'string') rangeInCm = parseFloat(rangeInCm);
        cordova.exec(success, fail, DOUBLEROBOTICS, 'drive', [isNaN(driveDirection) ? 1.0 : driveDirection, isNaN(turn) ? 0.0 : turn, isNaN(rangeInCm) ? 0.0 : rangeInCm]);
    }
    this.stop = function (success, fail) {
        cordova.exec(success, fail, DOUBLEROBOTICS, 'stop', []);
    }
    this.turnByDegrees = function (degrees, success, fail) {
        if (typeof degrees === 'string') degrees = parseFloat(degrees);
        cordova.exec(success, fail, DOUBLEROBOTICS, 'turnByDegrees', [isNaN(degrees) ? 180.0 : degrees]);
    }

}

module.exports = new DoubleRobotics();
