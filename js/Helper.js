
function createTimer(parent, interval, job, autoStart = true) {
    var timer = Qt.createQmlObject(
                `import QtQuick; Timer {running: false; repeat: false}`,
                parent, "myDynamicSnippet")
    timer.interval = interval
    var binded = false
    timer.triggered.connect(() => {
                                job()
                                if (timer && !timer.repeat) {
                                    timer.destroy()
                                } else {
                                    if (!binded) {
                                        timer.runningChanged.connect(running => {
                                                if (!running) {
                                                    timer.destroy()
                                                }
                                            })
                                        binded = true
                                    }
                                }
                            })
    timer.Component.onDestruction.connect(() => {
                                              timer = null
                                          })
    if (autoStart) {
        timer.start()
    }
    return timer
}

function randomColor() {
    return Qt.rgba(Math.random(), Math.random(), Math.random(), 1)
}


