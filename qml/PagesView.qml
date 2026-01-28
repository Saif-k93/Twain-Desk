pragma FunctionSignatureBehavior: Enforced

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.FluentWinUI3
import QtQuick.Controls.FluentWinUI3.impl
import QtQuick.Layouts
import QtQuick.Effects
import TwainDesk
import "../js/Helper.js" as Helper

CContainer {
    id: control

    bottomPadding: 3
    title: qsTr("Scanned Files")
    showDescription: pagesModel.count <= 0
    description: qsTr("No scanned files yet. Start scanning to add documents here.")

    readonly property bool hasPages: pagesModel.count > 0

    function append(path: string): bool {
        if(path === "") return false

        pagesModel.append({path: path})
        return true
    }

    function remove(filePath: string): bool {
        if(filePath === "") return false
        var __removed = false
        for (let i = pagesModel.count - 1; i >= 0; --i) {
            const __target = String(pagesModel.get(i).path).toLowerCase().replace("file:///", "")
            const __file = String(filePath).toLowerCase().replace("file:///", "")
            if (__target === __file) {
                pagesModel.remove(i)
                __removed = true;
                break
            }
        }
        return __removed;
    }

    function clear(): void {
        pagesModel.clear()
        Twain.scanFiles = []
    }

    function getPages(): list<string> {
        var pagesList = []
        for(let i = 0; i < pagesModel.count; ++i) {
            const __path = pagesModel.get(i).path
            if(__path) {
                pagesList.push(__path)
            }
        }
        return pagesList;
    }

    resources: [
        ListModel {
            id: pagesModel
            onCountChanged: {
                if(count > 0)
                    Twain.scanFiles = getPages()
                else
                    Twain.scanFiles = []
            }
        },

        QtObject {
            id: __private
            function validateAddedFile(filePath: string): void {
                var found = false;
                for (let i = pagesModel.count - 1; i >= 0; --i) {
                    if (String(pagesModel.get(i).path).toLowerCase().replace("file:///", "") === String(filePath).toLowerCase()) {
                        found = true;
                        break
                    }
                }
                if(!found) {
                    console.log(String("File Added By User: %1").arg(filePath))
                    pagesModel.append({path: String("file:///").concat(filePath)})
                }
            }

        },

        Connections {
            target: Twain.scanWatcher

            function onFileRemoved(filePath): void {
                console.log(String("File Removed By User: %1").arg(filePath))
                control.remove(filePath)
            }

            function onFileAdded(filePath): void {
                Helper.createTimer(control, 500, ()=> __private.validateAddedFile(filePath))
            }
        }

    ]

    ColumnLayout {
        // changes the content from (left to right, like english) to (right to left, like arabic)
        LayoutMirroring.enabled: AppSettings.isRTL
        // also make children inherit right to left if arabic selected
        LayoutMirroring.childrenInherit: true // this is false by default
        spacing: -4

        ListView {
            id: myList
            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: ListView.Horizontal
            clip: true
            boundsBehavior: ListView.StopAtBounds
            boundsMovement: ListView.FollowBoundsBehavior
            ScrollBar.horizontal: hScrollBarl
            spacing: 0
            antialiasing: AppSettings.quality
            cacheBuffer: 1000

            model: pagesModel

            delegate: Rectangle {
                id: __delegate
                required property int index
                required property string path
                width: Math.min(ListView.view.width, ListView.view.height)
                height: width
                radius: mask.radius
                color: "transparent"
                antialiasing: AppSettings.quality

                layer.enabled: AppSettings.quality
                layer.smooth: AppSettings.quality
                layer.mipmap: AppSettings.quality
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowBlur: 0.3
                    shadowColor: AppSettings.shadow
                    shadowOpacity: 0.7
                }

                TableView.onPooled: {

                }

                TableView.onReused: {

                }

                Image {
                    id: pageImage
                    anchors {
                        fill: parent
                        margins: 5
                    }

                    mipmap: AppSettings.quality
                    antialiasing: AppSettings.quality
                    autoTransform: true
                    asynchronous: true
                    source: __delegate.path
                    fillMode: Image.Stretch
                    opacity: hovH.hovered ? 0.88 : 1
                    Component.onCompleted: {
                        sourceSize = Qt.binding(()=> Qt.size(width, height))
                    }

                    CToolTip {
                        text: __delegate.path.replace("file:///", "")
                        visible: hovH.hovered && !myList.moving
                        delay: 500
                    }

                    BusyIndicator {
                        anchors.centerIn: parent
                        implicitWidth: Math.min(pageImage.width / 2, pageImage.height / 2)
                        implicitHeight: width
                        antialiasing: AppSettings.quality
                        visible: running
                        running: pageImage.status === Image.Loading
                    }

                    Rectangle {
                        id: mask
                        radius: 6
                        width: pageImage.width
                        height: pageImage.height
                        antialiasing: AppSettings.quality
                        layer.enabled: AppSettings.quality
                        visible: false
                    }

                    layer.enabled: AppSettings.quality
                    layer.smooth: AppSettings.quality
                    layer.mipmap: AppSettings.quality
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSpreadAtMin: 1.0
                        maskThresholdMin: 0.5
                        maskSource: mask
                    }

                    ContextMenu.menu: Menu {
                        implicitWidth: removeImageBtn.implicitWidth + leftPadding + rightPadding
                        modal: false

                        MenuItem {
                            id: removeImageBtn
                            implicitWidth: implicitContentWidth + leftPadding + rightPadding
                            leftPadding: 6
                            rightPadding: 6
                            text: qsTr("Remove (from app only)")
                            icon.color: "red"
                            onReleased: {
                                pagesModel.remove(__delegate.index)
                            }
                        }
                    }

                    HoverHandler { id: hovH; cursorShape: Qt.PointingHandCursor}
                    TapHandler {
                        id: tapH
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onTapped: (eventPoint, button)=> {
                                      if(button === Qt.LeftButton) {
                                          const popup = Qt.createQmlObject(
                                              `
                                              import QtQuick
                                              import QtQuick.Window
                                              import QtQuick.Controls
                                              import QtQuick.Controls.FluentWinUI3

                                              Window {
                                              id: imageView
                                              property url source: ""
                                              width: 1080
                                              height: 900
                                              visible: true
                                              flags: Qt.Window
                                              | Qt.WindowTitleHint
                                              | Qt.WindowMaximizeButtonHint
                                              | Qt.WindowCloseButtonHint
                                              | Qt.CustomizeWindowHint
                                              color: AppSettings.background
                                              minimumWidth: 200
                                              minimumHeight: 200
                                              modality: Qt.ApplicationModal

                                              onClosing: {
                                              destroy()
                                              }

                                              Component.onCompleted: {
                                              x = Screen.width / 2 - width / 2
                                              y = Screen.height / 2 - height / 2
                                              }

                                              Image {
                                              id: image
                                              anchors {
                                              fill: parent
                                              }
                                              sourceSize: Qt.size(width, height)
                                              asynchronous: true
                                              mipmap: AppSettings.quality
                                              antialiasing: AppSettings.quality
                                              fillMode: Image.Stretch
                                              source: imageView.source

                                              BusyIndicator {
                                              anchors.centerIn: parent
                                              implicitWidth: 150
                                              implicitHeight: 150
                                              padding: 5
                                              visible: running
                                              running: image.status === Image.Loading
                                              }
                                              }
                                              }
                                              `, control, "myDynamicSnippet")
                                          if(popup) {
                                              popup.source = __delegate.path
                                              popup.title = __delegate.path.replace("file:///", "")
                                          }
                                      } else if(button === Qt.RightButton) {

                                      }
                                  }
                    }
                }
            }
        }

        CScrollBar { id: hScrollBarl; Layout.fillWidth: true;  }
    }
}

