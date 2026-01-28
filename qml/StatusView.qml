pragma FunctionSignatureBehavior: Enforced

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.FluentWinUI3
import QtQuick.Controls.FluentWinUI3.impl
import QtQuick.Layouts
import QtQuick.Effects
import TwainDesk
import "../js/Helper.js" as Helper
import "components"

CContainer {
    id: control

    title: qsTr("Status View")
    showDescription: loaderItem?.statusModel?.count <= 0 || false
    description: qsTr("Displays current scan status and active notifications.")
    leftPadding: 5
    rightPadding: 5

    function append(status): void {
        /*
          CAN'T DO: statusModel.append(status)

          WHY? Because statusModel is INSIDE a dynamically loaded component.

          Loader creates an isolated scope. Anything inside it is only accessible
          through the loader's root item (loader.item).

          SOLUTION:
          1. First, we need an alias to the root item:
             readonly property Item loaderItem: contentsLoader.item

          2. Inside the loaded component, we need to expose statusModel:
             property alias statusModel: statusModel

          3. Now we can access it through the chain:
             loaderItem → statusModel → append()
        */

        // Safe access using optional chaining (?.)
        loaderItem?.statusModel?.append(status)

        /*
          ANALOGY:
          Loader is like a locked box. You can't reach inside directly.
          loaderItem is getting the whole box first.
          Then you can ask the box for what's inside (statusModel).
        */
    }


    RowLayout {
        property alias statusModel: statusModel
        // changes the content from (left to right, like english) to (right to left, like arabic)
        LayoutMirroring.enabled: AppSettings.isRTL
        // also make children inherit right to left if arabic selected
        LayoutMirroring.childrenInherit: true // this is false by default
        spacing: 0
        antialiasing: AppSettings.quality

        ListView {
            id: statusList
            LayoutMirroring.enabled: AppSettings.isRTL
            // also make children inherit right to left if arabic selected
            LayoutMirroring.childrenInherit: true // this is false by default
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            boundsBehavior: ListView.StopAtBounds
            boundsMovement: ListView.FollowBoundsBehavior
            verticalLayoutDirection: ListView.BottomToTop
            ScrollBar.vertical: vScrollBar


            function requestClear(position: point): void {
                if(statusModel.count < 1) return

                if(clearStatusLoader.active) {
                    clearStatusLoader.item?.popup(position)
                } else {
                    clearStatusLoader.active = true
                    clearStatusLoader.item?.popup(position)
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                preventStealing: true
                onReleased: (event)=> {
                                if(event.button === Qt.RightButton) {
                                    statusList.requestClear(Qt.point(event.x, event.y))
                                }
                                event.accepted = true;
                            }
            }

            Timer {
                id: scrollTimer
                interval: 100
                repeat: false
                triggeredOnStart: false
                running: false
                onTriggered: {
                    statusList.currentIndex = statusList.count -1
                    statusList.positionViewAtEnd()
                }
            }

            ListModel {
                id: statusModel

                onCountChanged: {
                    scrollTimer.restart()
                }
            }

            Loader {
                id: clearStatusLoader
                active: false
                sourceComponent: Menu {
                    implicitWidth: clearStatusBtn.implicitWidth + leftPadding + rightPadding
                    modal: false

                    MenuItem {
                        id: clearStatusBtn
                        implicitWidth: implicitContentWidth + leftPadding + rightPadding
                        leftPadding: 6
                        rightPadding: 6
                        text: qsTr("Clear All Status")
                        icon.color: "red"
                        onReleased: {
                            statusModel.clear()
                        }
                    }
                }
            }

            model: statusModel

            delegate: CItemDelegate {
                id: __delegate
                required property var status
                required property int index

                width: ListView.view.width
                implicitHeight: 24
                topPadding: 1
                bottomPadding: 1
                spacing: 6
                text: `<b><font pointSize='8'>${status.time}</font></b>:
                ${status.title.toString() !== "" ? `<b>${status.title}</b> : ` : ""}${status.text}`
                icon.width: 16
                icon.height: 16
                icon.source: status.icon
                icon.color: status.color
                display: AbstractButton.TextBesideIcon
                highlighted: ListView.isCurrentItem
                hoverEnabled: enabled
                tooltipText: status.text
                font.pixelSize: 12
            }
        }

        CScrollBar { id: vScrollBar; Layout.fillHeight: true }
    }
}

