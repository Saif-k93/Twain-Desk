import QtQuick
import QtQuick.Controls
import QtQuick.Controls.impl as Impl
import QtQuick.Controls.FluentWinUI3
import QtQuick.Layouts
import QtQuick.Effects
import TwainDesk

// do not create more than root item in this component from outside
// root item most be Item derived (visual item)
/* example:
CContainer { // bad, 2 root items
                    Item { }
                    Item { }
            }

CContainer { // bad, nonvisual item
                    Timer {
                     Item {}
                     Item {}
                    }
            }

CContainer { // good, 1 root item then can be nested
                    Item {
                     Timer {}
                     Item {}
                     Item {}
                    }
            }
*/

Page {
    id: control

    default property alias content: contentsLoader.sourceComponent
    /* access to the root item of the loader
       cuz items in loader can only be accessed though the root item
       of the loader and nested items need aliasing
    */
    readonly property Item loaderItem: contentsLoader.item
    readonly property bool pressed: tapH.pressed
    readonly property alias down: control.pressed // just an alias of pressed
    readonly property bool loaded: contentsLoader.status == Loader.Ready // content has loaded

    // When false: Content loading is deferred, showing a load button instead
    // When true: Content loads automatically (default in Quality mode)
    // Purpose: Improves performance by letting users manually load optional content
    property bool active: AppSettings.quality

    property bool asynchronous: true // load content asynchronously

    property bool showDescription: false
    property string description: ""

    // signals
    signal clicked(event: eventPoint) // a signal will emit any time this component is pressed

    // auto fit content width
    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    // auto fit content height
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding
                             + (implicitHeaderHeight > 0 ? implicitHeaderHeight + spacing : 0)
                             + (implicitFooterHeight > 0 ? implicitFooterHeight + spacing : 0))
    // changes the content from (left to right, like english) to (right to left, like arabic)
    LayoutMirroring.enabled: AppSettings.isRTL
    // also make children inherit right to left if arabic selected
    LayoutMirroring.childrenInherit: true // this is false by default
    antialiasing: AppSettings.quality
    padding: 10
    topPadding: title !== "" ? 3 : 10
    topInset: 2
    bottomInset: 2
    leftInset: 2
    rightInset: 2
    spacing: 0 // space between header and content and footer
    clip: false // do not clip this will make shadow look bad
    // to give load button a space to showup
    Binding { target: control; property: "padding"; when: !control.active; value: 0 }
    Binding { target: control; property: "topPadding"; when: !control.active; value: 0 }
    Binding { target: control; property: "topInset"; when: !control.active; value: 0 }
    Binding { target: control; property: "bottomInset"; when: !control.active; value: 0 }
    Binding { target: control; property: "leftInset"; when: !control.active; value: 0 }
    Binding { target: control; property: "rightInset"; when: !control.active; value: 0 }

    header: Label {
        LayoutMirroring.enabled: AppSettings.isRTL
        LayoutMirroring.childrenInherit: true
        leftPadding: control.leftPadding + (AppSettings.isRTL ? 10 : 0)
        rightPadding: control.rightPadding + (AppSettings.isRTL ? 0 : 10)
        topPadding: 4
        bottomPadding: 4
        antialiasing: AppSettings.quality
        wrapMode: Text.NoWrap
        elide: Text.ElideRight
        text: control.title
        visible: control.loaded && control.title !== ""
        fontSizeMode: Text.Fit
        font.pixelSize: 15
        color: AppSettings.text
        verticalAlignment: Text.AlignVCenter

        background: Impl.PaddedRectangle {
            antialiasing: AppSettings.quality
            color: AppSettings.isHighContrast ? AppSettings.background : control.hovered ? Qt.darker(AppSettings.accent, AppSettings.isLight ? 1.05 : 1.15) : AppSettings.accent
            leftPadding: 4
            rightPadding: 4
            topPadding: control.topPadding + 1
            radius: 3

            Behavior on color {
                enabled: AppSettings.quality
                ColorAnimation {
                    duration: 800
                    easing.type: Easing.OutCubic
                    alwaysRunToEnd: true
                }
            }
        }

        CItemDelegate {
            anchors {
                verticalCenter: parent.verticalCenter
                right: parent.right
            }
            implicitWidth: 20
            implicitHeight: 20
            display: AbstractButton.TextOnly
            topPadding: 1
            leftPadding: 1
            rightPadding: 1
            bottomPadding: 1
            topInset: 0
            bottomInset: 0
            leftInset: 0
            rightInset: 0
            icon.color: AppSettings.isHighContrast ? AppSettings.border : "#fa3838"
            textAlignment: Qt.AlignBottom
            text: "\u0078"
            tooltipVisible: true
            tooltipText: qsTr("Unload content.")
            tooltipDelay: 200

            onReleased: {
                control.active = false
            }
        }

        CToolTip {
            text: control.title
            visible: parent.truncated && control.title.trim() !== "" && headerHov.hovered
        }
        HoverHandler { id: headerHov }
    }

    background: Rectangle {
        implicitWidth: Math.max(30, loadBtnLoader.width + control.leftPadding + control.rightPadding)
        implicitHeight: Math.max(30, loadBtnLoader.height + control.topPadding + control.bottomPadding)
        radius: 6
        color: AppSettings.background
        antialiasing: AppSettings.quality
        border.color: AppSettings.border
        layer.enabled: AppSettings.quality
        layer.smooth: AppSettings.quality
        layer.mipmap: AppSettings.quality
        layer.effect: MultiEffect {
            blur: 0.1
            blurEnabled: true
            shadowEnabled: true
            shadowBlur: 0.3
            shadowColor: AppSettings.shadow
            shadowOpacity: 0.9
            contrast: 0.1
        }
    }

    contentItem: Loader {
        id: contentsLoader

        antialiasing: AppSettings.quality
        asynchronous: control.asynchronous
        active: control.active
        clip: false

        BusyIndicator {
            z: 100
            anchors.centerIn: parent
            // min 8 max 100
            implicitWidth: Math.max(8, Math.min(100, (Math.min(contentsLoader.width / 2, contentsLoader.height / 2))))
            implicitHeight: width // shadow the width
            antialiasing: AppSettings.quality
            visible: running
            running: contentsLoader.status === Loader.Loading
        }

        // this button will showup if content is not loaded to manually load

        Loader {
            id: loadBtnLoader
            anchors.centerIn: parent
            asynchronous: true
            active: !contentsLoader.active
            sourceComponent: CButton {
                tooltipText: control.title.trim() !== "" ? qsTr("Load The %1 Content.").arg(control.title) : qsTr("Load The Content.")
                tooltipVisible: true
                icon.source: "qrc:/assets/load-content_32px.png"
                display: AbstractButton.IconOnly

                onReleased: {
                    // contentsLoader.active = true // bad, will break Binding
                    control.active = true // good, can be turned off again
                }
            }
        }

        // a text to show description if control.showDescription is true
        Loader {
            width: parent.width
            height: parent.height
            asynchronous: true
            active: control.loaded && control.showDescription
            sourceComponent: Text {
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                antialiasing: AppSettings.quality
                wrapMode: Text.WordWrap
                text: control.description
                color: AppSettings.text
                elide: Text.ElideRight
            }
        }
    }

    TapHandler { id: tapH; onTapped: (event, button)=> control.clicked(event) }
}
