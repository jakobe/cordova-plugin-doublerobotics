function stop() {
    console.log("DoubleRoboticsProxy.stop()");
}

module.exports = {
    stop: function (success, error) {
        stop();
        setTimeout(function () {
            success();
        }, 0);
    }
};

require("cordova/exec/proxy").add("DoubleRobotics", module.exports);