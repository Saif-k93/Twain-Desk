import QtQuick
import QtQuick.Controls
import QtQuick.Controls.impl
import QtQuick.Controls.Material.impl as MIpml
import QtQuick.Controls.FluentWinUI3
import QtQuick.Controls.FluentWinUI3.impl as FImpl
import QtQuick.Effects
import TwainDesk

ItemDelegate {
    id: control

    property string tooltipText: ""
    property bool tooltipVisible: false
    property int tooltipDelay: 500
    property int textAlignment: display === IconLabel.IconOnly || display === IconLabel.TextUnderIcon ? Qt.AlignCenter : Qt.AlignLeft
    readonly property bool truncated: __private.truncated
    // changes the content from (left to right, like english) to (right to left, like arabic)
    LayoutMirroring.enabled: AppSettings.isRTL
    // also make children inherit right to left if arabic selected
    LayoutMirroring.childrenInherit: true // this is false by default
    antialiasing: AppSettings.quality
    hoverEnabled: enabled

    CToolTip {
        id: tooltip
        delay: control.tooltipDelay
        text: control.tooltipText
        visible: hovered && (control.truncated || control.tooltipVisible)
    }

    QtObject {
        id: __private
        property bool truncated: false
        Component.onCompleted: {
            if(iconLabel) {
                iconLabel.children.forEach((child, index, arr)=> {
                                               if(child && child instanceof Text) {
                                                   __private.truncated = Qt.binding(()=> child.truncated)
                                                   return
                                               }
                                           })
            }
        }
    }

    background: Item {
        implicitWidth: 160
        implicitHeight: 40
        antialiasing: AppSettings.quality
        property Item backgroundImage: FImpl.StyleImage {
            parent: control.background
            visible: !AppSettings.isHighContrast
            imageConfig: control.__config.background
            implicitWidth: parent.width - control.__horizontalOffset * 2
            implicitHeight: parent.height - control.__verticalOffset * 2
            x: control.__horizontalOffset
            y: control.__verticalOffset
        }

        property MIpml.Ripple ripple: MIpml.Ripple {
            parent: control.background.backgroundImage
            visible: AppSettings.quality
            implicitWidth: parent.width
            implicitHeight: parent.height
            x: (parent.width - width) / 2
            y: (parent.height - height) / 2
            clip: visible
            clipRadius: 4
            anchor: control
            antialiasing: AppSettings.quality
            pressed: control.pressed
            active: enabled && (control.down || control.visualFocus)
            color: Qt.alpha(AppSettings.highlighted, 0.1)
        }

        property Rectangle selector: Rectangle {
            parent: control.background.backgroundImage
            anchors.left: parent.left
            y: (parent.height - height) / 2
            width: 3
            height: (control.highlighted || control.activeFocus)
                    ? control.down ? 10 : 16
            : 0
            radius: width * 0.5
            color: control.palette.accent
            visible: (control.highlighted || control.activeFocus) && !AppSettings.isHighContrast
            Behavior on height {
                NumberAnimation {
                    duration: 187
                    easing.type: Easing.OutCubic
                }
            }
        }

        Rectangle {
            visible: AppSettings.isHighContrast
            implicitWidth: parent.width - control.__horizontalOffset * 2
            implicitHeight: parent.height - control.__verticalOffset * 2
            x: control.__horizontalOffset
            y: control.__verticalOffset
            color: control.hovered || control.highlighted ? control.palette.accent : AppSettings.background
            radius: 4
        }
    }

    contentItem: IconLabel {
        id: iconLabel
        antialiasing: AppSettings.quality
        spacing: control.spacing
        mirrored: control.mirrored
        display: control.display
        alignment: control.textAlignment
        icon: control.icon
        text: control.text
        font: control.font
        color: AppSettings.isHighContrast && (control.hovered || control.highlighted) ? control.palette.highlightedText : control.icon.color
    }

    HoverHandler { cursorShape: Qt.PointingHandCursor }

}
