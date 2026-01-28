import QtQuick
import QtQuick.Controls
import QtQuick.Controls.FluentWinUI3
import QtQuick.Controls.Material as M
import QtQuick.Controls.Material.impl as MImpl
import QtQuick.Layouts
import QtQuick.Effects
import QWindowKit

Control {
    id: control
    required property WindowAgent windowAgent
    required property Window window

    default readonly property alias content: outerItemsHolder.children

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding)

    LayoutMirroring.enabled: false // don't make title bar buttons RTL
    LayoutMirroring.childrenInherit: true
    padding: 5
    antialiasing: AppSettings.quality

    Component.onCompleted: {
        windowAgent.setTitleBar(control)
    }

    background: Rectangle {
        implicitWidth: 100
        implicitHeight: 40
        antialiasing: AppSettings.quality
        gradient: Gradient {
            GradientStop { position: 0.4; color: AppSettings.isHighContrast ? AppSettings.background : Qt.lighter(AppSettings.background, 1.4) }
            GradientStop { position: 1.0; color: AppSettings.isHighContrast ? AppSettings.background : Qt.darker(AppSettings.background, 1.4) }
        }
        layer.enabled: AppSettings.quality && !AppSettings.isHighContrast
        layer.smooth: AppSettings.quality
        layer.mipmap: AppSettings.quality
        layer.effect: MultiEffect {
            blur: AppSettings.isDark ? 0.0 : 0.2
            blurEnabled: true
            blurMax: 64
            saturation: -0.9
            shadowEnabled: true
            shadowBlur: 0.8
            shadowOpacity: 1
            shadowColor: Qt.rgba(0.0, 0.0, 0.0, 0.4)
        }
    }

    component TitleBarButton: M.Button {
        id: titleBarButtonCom
        LayoutMirroring.enabled: false
        LayoutMirroring.childrenInherit: true // this is false by default
        display: AbstractButton.IconOnly
        implicitWidth: Math.max(implicitHeight, implicitContentWidth + leftPadding + rightPadding)
        implicitHeight: Math.min(parent?.height || 26, 26)
        topPadding: 1
        bottomPadding: 1
        leftPadding: 1
        rightPadding: 1
        topInset: 0
        bottomInset: 0
        antialiasing: AppSettings.quality
        icon.color: AppSettings.isHighContrast ? palette.buttonText : Qt.lighter("blue", 1.45)
        flat: false

        background: Rectangle {
            implicitWidth: 64
            implicitHeight: M.Material.buttonHeight
            color: titleBarButtonCom.hovered ? AppSettings.isHighContrast ? palette.accent : Qt.alpha(AppSettings.hovered, AppSettings.isDark ? 0.99 : 0.8) : "transparent"
            antialiasing: AppSettings.quality
            radius: 4

            Component {
                id: rippleComp
                MImpl.Ripple {
                    parent: titleBarButtonCom.background
                    width: parent.width
                    height: parent.height
                    antialiasing: AppSettings.quality
                    clip: visible
                    clipRadius: parent.radius
                    pressed: titleBarButtonCom.pressed
                    anchor: titleBarButtonCom
                    active: enabled && (titleBarButtonCom.down || titleBarButtonCom.visualFocus)
                    color: Qt.alpha(titleBarButtonCom.icon.color, 0.15)
                }
            }

            property MImpl.Ripple ripple: AppSettings.quality ? rippleComp.createObject(titleBarButtonCom.background) : null
        }
    }

    contentItem: RowLayout {
        antialiasing: AppSettings.quality
        LayoutMirroring.enabled: false
        LayoutMirroring.childrenInherit: true

        RowLayout {
            Layout.fillHeight: true
            // Prevents the wrapped title from expanding the titlebar height
            Layout.maximumHeight: control.implicitContentHeight

            Layout.fillWidth: true
            Layout.alignment: Qt.AlignLeft
            Layout.leftMargin: 5
            spacing: 10

            Image {
                id: iconButton
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                mipmap: AppSettings.quality
                antialiasing: AppSettings.quality
                source: "qrc:/assets/app-icon_32px.png"
                fillMode: Image.PreserveAspectFit
                Component.onCompleted: control.windowAgent.setSystemButton(WindowAgent.WindowIcon, iconButton)
            }

            Text {
                id: windowTitle
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignVCenter
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignLeft
                text: control.window.title
                wrapMode: Text.Wrap
                maximumLineCount: 2
                lineHeight: 0.8
                elide: Text.ElideRight
                font.pixelSize: 16
                fontSizeMode: Text.HorizontalFit
                color: palette.text
            }
        }

        Item {
            id: fillerItem
            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.minimumWidth: outerItemsHolder.width + 5
            clip: true
            RowLayout {
                id: outerItemsHolder
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }

                LayoutMirroring.enabled: false
                LayoutMirroring.childrenInherit: true
                spacing: 0
                antialiasing: AppSettings.quality
                smooth: AppSettings.quality
                visible: (children?.length > 0 || false)
                Component.onCompleted: {
                    children.forEach((child, index, arr)=> {
                                         if(child) {
                                             windowAgent.setHitTestVisible(child, true)
                                         }
                                     })
                }

            }
        }

        RowLayout {
            id: titleBarRow
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            LayoutMirroring.enabled: false // dont make title bar buttons RTL
            LayoutMirroring.childrenInherit: true

            TitleBarButton {
                id: minButton
                icon.source: "qrc:/assets/titlebar/Minimize.png"
                onClicked: control.window.showMinimized()
                Component.onCompleted: control.windowAgent.setSystemButton(WindowAgent.Minimize, minButton)
            }

            TitleBarButton {
                id: maxButton
                icon.source: control.window.visibility === Window.Maximized ? "qrc:/assets/titlebar/Restore.png" : "qrc:/assets/titlebar/Maximize.png"
                onClicked: {
                    if (control.window.visibility === Window.Maximized) {
                        control.window.showNormal()
                    } else {
                        control.window.showMaximized()
                    }
                }
                Component.onCompleted: control.windowAgent.setSystemButton(WindowAgent.Maximize, maxButton)
            }

            TitleBarButton {
                id: closeButton
                icon.source: "qrc:/assets/titlebar/Close.png"
                icon.color: Qt.alpha("red", 0.8)
                onClicked: control.window.close()
                Component.onCompleted: control.windowAgent.setSystemButton(WindowAgent.Close, closeButton)
            }
        }
    }

}
