var utils = require('cordova/utils'),
    exec = require('cordova/exec'),
    cordova = require('cordova');

function DoubleRobotics() {
    this.pole = function(command, success, fail) {
        cordova.exec(success, fail, "DoubleRobotics", "pole", [command]);
    }
   this.kickstand = function(command, success, fail) {
   	cordova.exec(success, fail, "DoubleRobotics", "kickstand", [command]);
   }
   this.drive = function(command, success, fail) {
   	cordova.exec(success, fail, "DoubleRobotics", "drive", [command]);
   }
    
}

module.exports = new DoubleRobotics();