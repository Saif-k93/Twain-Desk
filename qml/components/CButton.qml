import QtQuick
import QtQuick.Controls
import QtQuick.Controls.impl
import QtQuick.Controls.FluentWinUI3
import QtQuick.Controls.FluentWinUI3.impl
import QtQuick.Controls.Material.impl as MImpl
import QtQuick.Effects
import TwainDesk

Button {
    id: control

    property MImpl.Ripple ripple: AppSettings.quality ? rippleComp.createObject(control) : null
    property bool loading: false
    property string tooltipText: ""
    property bool tooltipVisible: false

    // changes the content from (left to right, like english) to (right to left, like arabic)
    LayoutMirroring.enabled: AppSettings.isRTL
    // also make children inherit right to left if arabic selected
    LayoutMirroring.childrenInherit: true // this is false by default

    implicitWidth: implicitContentWidth + leftPadding + rightPadding
    implicitHeight: Math.min(28, (implicitContentHeight)) +  + topPadding + bottomPadding
    highlighted: false
    hoverEnabled: enabled
    antialiasing: AppSettings.quality
    topPadding: display === AbstractButton.IconOnly ? 2 : 6
    bottomPadding: display === AbstractButton.IconOnly ? 2 : 6
    leftPadding: display === AbstractButton.IconOnly ? 2 : 6
    rightPadding: display === AbstractButton.IconOnly ? 2 : 6
    topInset: 0
    bottomInset: 0

    Binding {
        when: control.background !== null && control.hovered
        target: control.background
        property: "opacity"
        value: 0.75
        restoreMode: Binding.RestoreBindingOrValue
    }

    CToolTip {
        id: tooltip
        delay: 300
        text: control.tooltipText
        visible: control.hovered && (control.truncated || control.tooltipVisible)
    }

    property ProgressBar progressBar: ProgressBar {
        parent: control.background
        y: parent.height - height
        x: (parent.width - width) / 2
        implicitWidth: parent.width / 1.1
        implicitHeight: 2
        antialiasing: AppSettings.quality
        indeterminate: true
        visible: control.loading
    }

    layer.enabled: AppSettings.quality && control.enabled
    layer.smooth: AppSettings.quality
    layer.mipmap: AppSettings.quality
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowBlur: 0.1
        shadowOpacity: 0.7
        shadowColor: AppSettings.shadow
        shadowVerticalOffset: AppSettings.isDark ? 2 : 0
    }

    contentItem: IconLabel {
        id: iconLabel
        spacing: control.spacing
        mirrored: control.mirrored
        display: control.display
        alignment: control.__config.label.textVAlignment | control.__config.label.textHAlignment
        icon: control.icon
        text: control.text
        font: control.font
        color: control.icon.color
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

    Component {
        id: rippleComp
        MImpl.Ripple {
                parent: control
                x: parent.width / 2 - width / 2
                y: parent.height / 2 - height / 2
                implicitWidth: parent.width
                implicitHeight: parent.height
                color: Qt.alpha(parent.palette.highlight, 0.3)
                pressed: parent.down
                clip: visible
                clipRadius: 5
                anchor: parent
                antialiasing: AppSettings.quality
                active: enabled && (parent.down || visualFocus)
            }
    }

    HoverHandler { cursorShape: Qt.PointingHandCursor }
}
