import QtQuick
import QtQuick.Controls
import QtQuick.Controls.impl
import QtQuick.Controls.Material.impl as MImpl
import QtQuick.Controls.FluentWinUI3
import QtQuick.Controls.FluentWinUI3.impl as FIMPL
import QtQuick.Layouts
import QtQuick.Templates as T
import TwainDesk
import Qt.labs.qmlmodels
import QtQuick.Effects
import "../../js/Helper.js" as Helper


ComboBox {
    id: control

    // options
    property bool animationsActive: AppSettings.quality
    property bool showFocusFrame: true

    // toolTip array
    // this should have the index and the tooltip text to be shown for the index
    // example { 0: 'this is a test', 1: 'test 2' }
    property var toolTipMap: ({})

    // combo tooltip
    property bool tooltipVisible: false
    property string tooltipText: ""

    // icons array
    // this should have the index and the icon url to be shown for the index
    // example { 0: 'qrc:/assets/star_24px.png', 1: 'qrc:/assets/night-mode_24px.png' }
    property var iconsMap: ({})

    // msg data
    property bool showMsg: false // makes the combobox show a message
    property string msgText: "" // content of the message
    property int msgMaxWidth: Math.round(control.width * 1.5)
    property int msgType: 0 // options [CComboBox.Info, CComboBox.Warning, CComboBox.Error] // default is CComboBox.Info
    property int msgTimeout: -1 // -1 means it never disappear until user manually click it or click another area
    property int msgDelay: 80 // delay before msg show up
    property bool msgClosable: false // message will not be closable if you set this to true
    property bool showMsgBox: true

    // combo
    property int maxWidth: 150
    property int maxPopupHeight: 350
    readonly property bool isOpen: control.popup?.opened || false

    // signals
    signal msgClicked()

    enum MsgType { Info = 0, Warning, Error }

    enum PopupPos {
        Default = 0,
        Top = 1,      // 2^0
        Bottom = 2,   // 2^1
        Left = 4,     // 2^2
        Right = 8,    // 2^3
        Center = 16   // 2^4
    }
    /********************************
     it can be combined,
     this will set the popup to the right top of the combobox
              example:
     CComboBox.PopupPos.Right | CComboBox.PopupPos.Center
     *********************************/
    property int popupPos: CComboBox.PopupPos.Top

    readonly property Item __focusFrameTarget: null // disable default focus frame

    LayoutMirroring.enabled: AppSettings.isRTL
    LayoutMirroring.childrenInherit: true

    implicitHeight: 28
    implicitWidth: Math.min(maxWidth, implicitContentWidth + leftPadding + rightPadding)
    leftPadding: (!control.mirrored || !indicator || !indicator.visible ? 4 : indicator.width + spacing) || 0
    rightPadding: (control.mirrored || !indicator || !indicator.visible ? 4 : indicator.width + spacing) || 0
    antialiasing: AppSettings.quality
    smooth: AppSettings.quality
    displayText: currentText
    focus: true
    spacing: showMsg ? 5 : 0.5
    font.capitalization: AppSettings.isRTL ? Font.MixedCase : Font.Capitalize

    indicator: ColorImage {
        property url indSource: AppSettings.isDark ? "qrc:/qt-project.org/imports/QtQuick/Controls/FluentWinUI3/dark/images/combobox-indicator.png" : "qrc:/qt-project.org/imports/QtQuick/Controls/FluentWinUI3/light/images/combobox-indicator.png"
        property color fallbackColor: AppSettings.isHighContrast ? AppSettings.border : AppSettings.text
        x: control.mirrored ? 2 : control.width - width - 2
        y: (control.topPadding + (control.availableHeight - height) / 2) + (control.pressed ? vars.msgVisible ? 1 : 2 : 0)
        antialiasing: AppSettings.quality
        mipmap: AppSettings.quality
        smooth: AppSettings.quality
        source: vars.msgVisible ? "qrc:/assets/info_24px.png" : Qt.resolvedUrl(indSource)
        sourceSize: Qt.size(width, height)
        color: vars.msgVisible && !AppSettings.isHighContrast ? control.msgType === CComboBox.MsgType.Info ? AppSettings.isDark ? "lightgreen" : "#073707" : control.msgType === CComboBox.MsgType.Warning ? AppSettings.isDark ? "#fff53d" : "#737000" : control.msgType === CComboBox.MsgType.Error ? AppSettings.isDark ? "#f6a29e" : "#f5cfce" : fallbackColor : fallbackColor
        transformOrigin: Item.Center
        autoTransform: true

        states: [
            State {
                name: "default"
                when: !control.isOpen && control.indicator
                PropertyChanges {
                    target: control.indicator
                    rotation: 0
                }
            },
            State {
                name: "rotated"
                when: control.isOpen && control.indicator && !vars.msgVisible
                PropertyChanges {
                    target: control.indicator
                    rotation: 180
                }
            }
        ]
        transitions: [
            Transition {
                enabled: control.indicator && AppSettings.quality
                from: "default"
                to: "rotated"

                NumberAnimation {
                    target: control.indicator
                    property: "rotation"
                    duration: 300
                    easing.type: Easing.OutCubic
                }
            },
            Transition {
                enabled: control.indicator && AppSettings.quality
                from: "rotated"
                to: "default"

                NumberAnimation {
                    target: control.indicator
                    property: "rotation"
                    duration: 300
                    easing.type: Easing.OutCubic
                }
            }
        ]

        Behavior on y {
            enabled: AppSettings.quality
            NumberAnimation{ easing.type: Easing.OutCubic; duration: 167 }
        }
    }

    QtObject {
        id: vars

        readonly property bool msgVisible: msgRectLoader.active && msgRectLoader.item && msgRectLoader.item.visible
    }

    Component {
        id: notEditableItem
        Label {
            id: notEditableLabel
            readonly property color __pressedText: AppSettings.isLight
                                                   ? Qt.rgba(control.palette.text.r, control.palette.text.g, control.palette.text.b, 0.62)
                                                   : Qt.rgba(control.palette.text.r, control.palette.text.g, control.palette.text.b, 0.7725)

            readonly property bool __focused: hovered || control.popup.opened
            antialiasing: AppSettings.quality
            smooth: AppSettings.quality
            text: control.editable ? control.editText : control.displayText
            topPadding: control.__config.label_contentItem.topPadding || 0
            bottomPadding: control.__config.label_contentItem.bottomPadding || 0
            leftPadding: control.__config.label_contentItem.leftPadding || 0
            rightPadding: control.__config.label_contentItem.rightPadding || 0
            enabled: !control.editable

            color: control.down ? __pressedText : !control.enabled && AppSettings.isHighContrast ? AppSettings.palette.midlight : AppSettings.palette.buttonText
            horizontalAlignment: Label.AlignLeft
            verticalAlignment: AppSettings.isRTL ? Label.AlignBottom : Label.AlignVCenter
            elide: Label.ElideRight
            font.capitalization: control.font.capitalization
            fontSizeMode: Label.Fit
            wrapMode: Label.NoWrap
            opacity: enabled ? __focused ? 0.75 : 1 : AppSettings.isHighContrast ? 0.8 : 0.6

            CToolTip {
                y: -implicitHeight - bottomPadding
                visible: control.hovered && (notEditableLabel.truncated || control.tooltipVisible)
                text: control.tooltipVisible ? control.tooltipText : notEditableLabel.text
                delay: 300
            }

            readonly property Item __focusFrameControl: control
        }
    }

    Component {
        id: editableItem
        T.TextField {
            text: control.editable ? control.editText : control.displayText

            topPadding: control.__config.label_contentItem.topPadding || 0
            leftPadding: control.__config.label_contentItem.leftPadding || 0
            rightPadding: control.__config.label_contentItem.rightPadding || 0
            bottomPadding: control.__config.label_contentItem.bottomPadding || 0

            implicitWidth: (implicitBackgroundWidth + leftInset + rightInset)
                           || contentWidth + leftPadding + rightPadding
            implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                                     contentHeight + topPadding + bottomPadding)

            enabled: control.editable
            autoScroll: control.editable
            readOnly: control.down
            inputMethodHints: control.inputMethodHints
            validator: control.validator
            selectByMouse: control.selectTextByMouse
            font.capitalization: control.font.capitalization

            readonly property color __pressedText: AppSettings.isLight
                                                   ? Qt.rgba(control.palette.text.r, control.palette.text.g, control.palette.text.b, 0.62)
                                                   : Qt.rgba(control.palette.text.r, control.palette.text.g, control.palette.text.b, 0.7725)

            color: control.down ? __pressedText : control.palette.text
            selectionColor: control.palette.highlight
            selectedTextColor: control.palette.highlightedText
            horizontalAlignment: control.__config.label_text.textHAlignment
            verticalAlignment: control.__config.label_text.textVAlignment

            readonly property Item __focusFrameControl: control
        }
    }

    contentItem: control.editable ? editableItem.createObject(control) : notEditableItem.createObject(control)

    background: FIMPL.StyleImage {
        antialiasing: AppSettings.quality
        imageConfig: control.__config.background

        // blur combobox when popup is opened
        layer.enabled: control.isOpen
        layer.smooth: AppSettings.quality
        layer.mipmap: AppSettings.quality
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: 0.1 // amount of blur, from 0.0 to 1.0
        }

        Loader {
            id: msgRectLoader
            anchors {
                fill: parent
            }
            active: control.showMsg
            asynchronous: true
            visible: active
            antialiasing: AppSettings.quality
            smooth: AppSettings.quality

            sourceComponent: Rectangle {
                id: msgRect
                readonly property alias tooltip: msgTooltip
                readonly property color infoColor: AppSettings.isDark ? "#400d9a4c" : "#730d9a4c"
                readonly property color warningColor: AppSettings.isDark ? "#8e8d1a" : "#66f7f701"
                readonly property color errorColor: AppSettings.isDark ? "#80c42b1c" : "#A6c42b1c"
                property bool canShowMsgBox: false
                readonly property color __color: control.msgType === CComboBox.MsgType.Info ? infoColor : control.msgType === CComboBox.MsgType.Warning ? warningColor : control.msgType === CComboBox.MsgType.Error ? errorColor : infoColor
                antialiasing: AppSettings.quality
                smooth: AppSettings.quality
                radius: 4
                color: control.showMsgBox ? __color : "transparent"
                visible: opacity > 0
                opacity: control.showMsg && msgRect.canShowMsgBox;
                Behavior on opacity { enabled: AppSettings.quality; NumberAnimation { duration: 167; easing.type: Easing.InCubic } }

                Component.onCompleted: {
                    if(control.msgTimeout >= 0)
                        timeoutTimer.restart()
                    if(control.msgDelay >= 0) {
                        delayTimer.restart()
                    }
                }

                Timer {
                    id: timeoutTimer
                    triggeredOnStart: false
                    repeat: false
                    interval: control.msgTimeout

                    onTriggered: {
                        msgRect.canShowMsgBox = false
                    }
                }

                Timer {
                    id: delayTimer
                    triggeredOnStart: false
                    repeat: false
                    interval: control.msgDelay

                    onTriggered: {
                        msgRect.canShowMsgBox = true
                    }
                }

                ToolTip {
                    id: msgTooltip
                    implicitWidth: Math.min(control.msgMaxWidth, Math.max(implicitBackgroundWidth + leftInset + rightInset,
                                                                          contentWidth + leftPadding + rightPadding))
                    topPadding: 3
                    bottomPadding: 3
                    visible: msgRect.visible && text !== ""
                    opacity: visible ? tooltipArea.containsPress ? 0.7 : tooltipArea.containsMouse ? 0.9 : 1 : 0; Behavior on opacity { enabled: AppSettings.quality; NumberAnimation { duration: 167; easing.type: Easing.InCubic } }
                    text: control.msgText
                    font.bold: true
                    closePolicy: control.msgTimeout === -1 && !control.msgClosable ? ToolTip.NoAutoClose : ToolTip.CloseOnEscape | ToolTip.CloseOnPressOutsideParent | ToolTip.CloseOnReleaseOutsideParent
                    palette.toolTipText: AppSettings.isHighContrast ? AppSettings.palette.buttonText : control.msgType === CComboBox.MsgType.Info ? "lightgreen" : control.msgType === CComboBox.MsgType.Warning ? "yellow" : control.msgType === CComboBox.MsgType.Error ? Qt.lighter("red", 1.65) : AppSettings.text
                    timeout: 0
                    delay: 0
                    margins: 20

                    onClosed: control.showMsg = false

                    onVisibleChanged: {
                        msgRect.canShowMsgBox = visible
                    }
                    MouseArea {
                        id: tooltipArea
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftArrow
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onReleased: {
                            if(containsMouse) {
                                if(control.msgClosable) {
                                    msgRect.canShowMsgBox = false
                                }
                                control.msgClicked()
                            }
                        }
                    }

                    background: Item {
                        MultiEffect {
                            x: -msgTooltip.leftInset
                            y: -msgTooltip.topInset
                            width: source.width
                            height: source.height

                            source: Rectangle {
                                width: msgTooltip.background.width + msgTooltip.leftInset + msgTooltip.rightInset
                                implicitHeight: 30
                                height: msgTooltip.background.height + msgTooltip.topInset + msgTooltip.bottomInset
                                antialiasing: AppSettings.quality
                                smooth: AppSettings.quality
                                color: AppSettings.isHighContrast ? AppSettings.background : `#${ tooltipArea.containsMouse ? '73' : '99'}000000`
                                Behavior on opacity {
                                    enabled: AppSettings.quality
                                    NumberAnimation {
                                        duration: 167
                                    }
                                }
                                border.width: 1
                                border.color: AppSettings.isHighContrast ? AppSettings.palette.buttonText : "#17161a"
                                radius: 4
                            }
                            shadowOpacity: AppSettings.isLight ? 0.4 : 0.88
                            shadowColor: msgTooltip.palette.shadow
                            shadowEnabled: AppSettings.quality
                            shadowHorizontalOffset: 0
                            shadowVerticalOffset: 2
                            shadowBlur: 0.1
                            blur: 0.1
                            blurMax: 64
                            blurEnabled: AppSettings.quality
                            contrast: 0.9
                        }
                    }
                }
            }
        }

        Item {
            id: focusStroke
            visible: control.editable ? ((control.down && control.popup.visible) || control.activeFocus) : control.activeFocus || (popup && popup.opened)
            width: visible ? parent.width : 0
            height: 2
            y: parent.height - height
            FIMPL.FocusStroke {
                x: parent.width / 2 - width / 2
                width: parent.width
                height: parent.height
                antialiasing: AppSettings.quality
                smooth: AppSettings.quality
                radius: control.editable ? control.down && control.popup.visible ? 0 : control.__config.background.bottomOffset : control.__config.background.bottomOffset
                color: vars.msgVisible ? AppSettings.isDark ? "#ffffff" : "#D9003366" : AppSettings.isHighContrast ? AppSettings.border : control.palette.accent
                Behavior on width {
                    enabled: AppSettings.quality
                    SmoothedAnimation { velocity: 350; easing.type: Easing.InBack }
                }
            }
        }

        Rectangle {
            x: parent.width / 2 - width / 2
            y: parent.height / 2 - height / 2
            width: parent.width
            height: parent.height
            visible: control.showFocusFrame && control.visualFocus

            antialiasing: AppSettings.quality
            smooth: AppSettings.quality
            border.width: 2
            border.color: AppSettings.isHighContrast ? AppSettings.palette.highlight :  AppSettings.isDark ? Qt.rgba(0.9, 0.9, 0.9, 1.0) : Qt.rgba(0.0, 0.0, 0.0, 0.8)
            color: "transparent"
            radius: 4
        }

        Rectangle {
            x: parent.width / 2 - width / 2
            y: parent.height / 2 - height / 2
            width: parent.width
            height: parent.height
            visible: AppSettings.isHighContrast
            antialiasing: AppSettings.quality
            smooth: AppSettings.quality
            border.width: 1
            border.color: control.enabled ? AppSettings.palette.buttonText : AppSettings.palette.midlight
            color: "transparent"
            radius: 4
        }

        MImpl.Ripple {
            x: parent.width / 2 - width / 2
            y: parent.height / 2 - height / 2
            width: parent.width
            height: parent.height - focusStroke.height
            antialiasing: AppSettings.quality
            smooth: AppSettings.quality
            clip: visible
            clipRadius: 4
            anchor: control
            pressed: control.down && !control.popup?.opened
            visible: AppSettings.quality
            color: Qt.alpha(AppSettings.highlighted, 0.1)
            active: false
        }

        HoverHandler {cursorShape: Qt.PointingHandCursor}
    }

    delegate: Loader {
        id: delegateItem
        required property var model
        required property int index
        asynchronous: true
        active: true
        width: ListView.view.width
        height: 30

        sourceComponent: CItemDelegate {
            id: __delegateItem
            property bool isCurrentItem: control.currentIndex === delegateItem.index
            property bool isHighlighted: control.highlightedIndex === delegateItem.index
            text: delegateItem.model[control.textRole]
            hoverEnabled: !delegateItem.ListView.view.moving
            highlighted: isCurrentItem
            font.bold: isCurrentItem
            font.capitalization: control.font.capitalization
            tooltipVisible: Object.keys(control.toolTipMap).length > 0 && control.toolTipMap[delegateItem.index] !== undefined
            tooltipText: control.toolTipMap[delegateItem.index] || text
            icon.source: Object.keys(control.iconsMap).length > 0 && control.iconsMap[delegateItem.index] !== undefined ? control.iconsMap[delegateItem.index] : ""
            icon.width: 16
            icon.height: 16
            spacing: 3
            onReleased: {
                control.currentIndex = delegateItem.index
                control.activated(delegateItem.index)
                control.popup?.close()
                control.forceActiveFocus()
            }
        }
    }

    popup: Popup {
        id: popupItem
        topPadding:  control.__config.popup_contentItem.topPadding || 0
        leftPadding: control.__config.popup_contentItem.leftPadding || 0
        rightPadding: control.__config.popup_contentItem.rightPadding || 0
        bottomPadding: control.__config.popup_contentItem.bottomPadding || 0

        x: {
            // Helper function to check if a flag is set
            function hasFlag(flag) {
                return (control.popupPos & flag) === flag;
            }

            const center = (control.width - width) / 2
            const left = -(control.width + control.leftPadding + control.rightPadding)
            const right = control.width

            // Check for combined positions
            if (hasFlag(CComboBox.PopupPos.Left)) return left;
            if (hasFlag(CComboBox.PopupPos.Right)) return right;

            // Default to center if neither left nor right is specified
            return center;
        }

        y: {
            // Helper function to check if a flag is set
            function hasFlag(flag) {
                return (control.popupPos & flag) === flag;
            }

            const bottom = (control.height)
            const top = -height
            const center = -(height / 2) + (control.height / 2)

            // Check for combined positions
            if (hasFlag(CComboBox.PopupPos.Bottom)) return bottom;
            if (hasFlag(CComboBox.PopupPos.Top)) return top;
            if (hasFlag(CComboBox.PopupPos.Center)) return center;

            return 0;
        }

        implicitWidth: Math.max(40, (control.width + control.leftPadding + control.rightPadding) + (Object.keys(control.iconsMap).length > 0 ? 15 : 0))
        implicitHeight: Math.min(itemsList.contentHeight + topPadding + bottomPadding, control.maxPopupHeight)

        onOpened: {
            itemsList.positionViewAtIndex(control.currentIndex, ListView.Contain)
        }

        Component {
            id: qualityBackgroundCom
            FIMPL.StyleImage {
                implicitWidth: 320
                implicitHeight: 72
                imageConfig: popupItem.__config.background
                drawShadowWithinBounds: AppSettings.isHighContrast
                antialiasing: true
                smooth: true

                Rectangle {
                    implicitWidth: parent.width
                    implicitHeight: parent.height
                    visible: AppSettings.isHighContrast
                    antialiasing: true
                    smooth: true
                    radius: 4
                    color: AppSettings.background
                    border.color: AppSettings.border
                    border.width: 2
                }
            }
        }

        Component {
            id: performanceBackgroundCom
            Rectangle {
                implicitWidth: 320
                implicitHeight: 72
                antialiasing: false
                smooth: false
                radius: 4
                color: AppSettings.accent
                border.width: 1
                border.color: AppSettings.border

                Rectangle {
                    implicitWidth: parent.width
                    implicitHeight: parent.height
                    visible: AppSettings.isHighContrast
                    radius: 4
                    antialiasing: false
                    smooth: false
                    color: AppSettings.background
                    border.color: AppSettings.border
                    border.width: 2
                }

            }
        }

        background: AppSettings.quality ? qualityBackgroundCom.createObject(control) : performanceBackgroundCom.createObject(control)

        contentItem: ListView {
            id: itemsList
            implicitHeight: contentHeight
            clip: true
            highlightMoveDuration: control.animationsActive ? 167 : 1
            highlightResizeDuration: control.animationsActive ? 167 : 1
            highlightFollowsCurrentItem: true
            keyNavigationEnabled: true
            focus: true
            spacing: 0
            interactive: Window.window
                         ? contentHeight + popupItem.topPadding + popupItem.bottomPadding > popupItem.height
                         : false
            highlight: PaddedRectangle {
                z: AppSettings.isHighContrast ? 0 : 2
                radius: 5
                leftPadding: 2
                rightPadding: 2
                antialiasing: AppSettings.quality
                opacity: control.pressed ? 0.5 : 1
                smooth: AppSettings.quality
                color: AppSettings.isHighContrast ? AppSettings.highlighted : AppSettings.isDark ? Qt.rgba(0.0, 0.0, 0.0, 0.2) : Qt.rgba(0.0, 0.0, 0.0, 0.07)
                border.width: control.visualFocus ? 1 : control.pressed ? 0.5 : 0.0
                border.color: AppSettings.isHighContrast ? AppSettings.border : AppSettings.isDark ? "white" : Qt.rgba(0.0, 0.0, 0.0, 0.75)
                visible: control.highlightedIndex !== control.currentIndex
            }

            model: control.delegateModel
            currentIndex: control.highlightedIndex
            ScrollBar.vertical: CScrollBar { transform: Translate { x: AppSettings.isRTL ? -3 : 3 }}
        }

        Component {
            id: enterAnimation
            Transition {
                NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; easing.type: Easing.Linear; duration: 83 }
                NumberAnimation { property: "scale"; from: 1.2; to: 1; easing.type: Easing.OutCubic; duration: 167 }
            }
        }
        Component {
            id: exitAnimation
            Transition {
                NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; easing.type: Easing.Linear; duration: 83 }
                NumberAnimation { property: "scale"; from: 1; to: 1.2; easing.type: Easing.OutCubic; duration: 167 }
            }
        }

        enter: AppSettings.quality ? enterAnimation.createObject(popupItem) : null
        exit: AppSettings.quality ? exitAnimation.createObject(popupItem) : null
    }

}














