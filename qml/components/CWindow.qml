pragma FunctionSignatureBehavior: Enforced

import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import QtQuick.Controls.FluentWinUI3
import TwainDesk
import QWindowKit
import "../../js/Helper.js" as Helper

Window {
    id: root

    /*
     * CWindow - Custom Window Component with Automatic Title Bar Management
     * =====================================================================
     *
     * OVERVIEW:
     * This component solves a fundamental problem:
     * When you add a title bar to a window, any child content added
     * typically starts at y=0, potentially covering the title bar. This component
     * automatically manages title bar space so user content always appears BELOW
     * the title bar without manual positioning.
     *
     * ARCHITECTURE:
     * ┌───────────────────────────────────────────────┐
     * │              Window.contentItem               │
     * │  ┌─────────────────────────────────────────┐  │
     * │  │        Title Bar (fixed at top)         │  │ ← Always visible
     * │  └─────────────────────────────────────────┘  │
     * │  ┌─────────────────────────────────────────┐  │
     * │  │           Control Component             │  │
     * │  │     topPadding = titleBar.height        │  │ ← Reserved space
     * │  │  ┌─────────────────────────────────┐    │  │
     * │  │  │      User Content Area          │    │  │
     * │  │  └─────────────────────────────────┘    │  │
       │  └─────────────────────────────────────────┘  │
     * └───────────────────────────────────────────────┘
     *
     * HOW IT WORKS:
     * 1. Title Bar Placement:
     *    - The titleBar is parented directly to Window.contentItem
     *    - This ensures it's visible
     *    - It's anchored to the top of the window (y=0)
     *
     * 2. Content Area Management:
     *    - A Control component fills the window with dynamic topPadding
     *    - topPadding = titleBar.height + optional user padding
     *    - This reserves space so user content starts BELOW the title bar
     *
     * 3. Custom Content Collection:
     *    - We override Qt's default parenting behavior using
     *      default property that collects ALL child items, example
                           CWindow { Item {}; Timer {} } // item and timer now added to the default property
     *
     * WHY THIS APPROACH:
     * Standard Qt Window behavior:
     *   Window {
     *       TitleBar { height: 50; anchors.top: parent.top }
     *       Rectangle { anchors.fill: parent }  // ❌ Covers the title bar!
     *   }
     *
     * With CWindow:
     *   CWindow {
     *       Rectangle { anchors.fill: parent }  // ✅ Automatically below title bar
     *   }
     *
     * CONTENT HANDLING:
     * - Visual items (Rectangles, Text, Buttons, etc.) become children of the
     *   content area and are positioned below the title bar
     * - Non-visual items (Timers, QtObjects, Bindings) are properly managed
     *   in the component's data structure
     *
     * USAGE:
     *   CWindow {
     *       // Title bar is automatically created and managed
     *       // Content area automatically starts below title bar
     *
     *      // becomes itemsHolder.child
     *       Rectangle {
     *           anchors.fill: parent  // Fills CONTENT area, not entire window
     *           color: "lightblue"
     *       }
     *
     *       // added to itemsHolder.resources
     *       Timer {  // Non-visual items work seamlessly
     *           interval: 1000
     *           running: true
     *           onTriggered: console.log("Timer!")
     *       }
     *   }
     *
     * PADDING CONTROL:
     * - Use 'padding' property to set all sides equally
     * - Or use individual: topPadding, bottomPadding, leftPadding, rightPadding
     * - Note: topPadding automatically includes title bar height
     *
     * KEY FEATURES:
     * 1. Title bar always visible and never covered by content
     * 2. Automatic space reservation for title bar
     * 3. Support for both visual and non-visual child items
     * 4. No manual positioning required by users
     * 5. We can use multiple items and resource and not only creating one visual item to be the root of the nested items
     *
     * TECHNICAL NOTE:
     * QML only allows ONE default property per component. We use
     * 'alias contents: itemsHolder.data' to collect parent all children to itemsHolder.data, then
     * Qt will handle the rest. This gives us full
     * control over the parenting hierarchy while maintaining compatibility
     * with all QML item types.
     */
    /*************
    **this will add visual items to itemsHolder.children
    ** and nonevisual items to itemsHolder.resources
     don't do it manually let qt do it for u, itemsHolder.data handles that by default.
     read https://doc.qt.io/qt-6/qml-qtquick-item.html#data-prop
     ************/
    default readonly property alias contents: itemsHolder.data
    /*******************************************************/

    // alias
    readonly property alias itemsHolder: itemsHolder
    readonly property alias windowAgent: windowAgent

    // options
    property bool preventClosing: false
    property string preventClosingReason: ""
    property int cornerPreference: CornerPreference.Default // window corner round
    property real topPadding: 1
    property real bottomPadding: 1
    property real leftPadding: 1
    property real rightPadding: 1
    property real padding: 0 // any value greater than 0 will override (top, bottom, left, right) padding

    // can be accesed from outside example CWindow { preventClosingDialog.modal: false  }
    // can also be overridden example CWindow { preventClosingDialog: Dialog {  }  }
    property Dialog preventClosingDialog: Dialog { // to warn user why he can't close this window
        parent: root.contentItem
        anchors.centerIn: parent
        title: root.preventClosingReason
        palette.window: AppSettings.background
        modal: true
        dim: true
        closePolicy: Dialog.NoAutoClose
        visible: false
        standardButtons: Dialog.Ok
        popupType: Popup.Item
    }

    // we can add items to titleBar from outside example
    /*
      CWindow {
           titleBar.content: RowLayout {
           height: parent.height
           Repeater {
           model: 5
             Rectangle {
                 Layout.fillHeight: true
                 Layout.preferredWidth: height
                 color: Helper.randomColor()
                 }
               }
            }
        } // this will show 5 Rectangles between titlebar -> left(window title), right(minimize button)
      */
    property TitleBar titleBar: TitleBar {
        parent: root.contentItem
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        window: root // required
        windowAgent: root.windowAgent // required
    }

    width: 300
    height: 300
    color: AppSettings.background
    flags: Qt.Window
    visible: false // We hide it first, so we can move the window to our desired position silently.

    onCornerPreferenceChanged: __private.setCornerPreference() // call private method to set window corner preference

    Component.onCompleted: {
        windowAgent.setup(root)
        windowAgent.setWindowAttribute("dark-mode", AppSettings.isDark)
        root.visible = true
        AppSettings.themeChanged?.connect(()=> {
                                              windowAgent.setWindowAttribute("dark-mode", AppSettings.isDark)
                                          })
    }

    // @disable-check M16
    onClosing: (close)=> { // prevent closing this window if root.preventClosing is true
                   if(root.preventClosing) {
                       close.accepted = false; // this reject the close event
                       if(preventClosingReason.trim() !== "") {
                           preventClosingDialog.open()
                       }
                       return;
                   }
                   close.accepted = true;
               }

    // we put methods and prop inside QtObject Object to make them private
    // this prevent -> CWindow { id: root; Button { onReleased: root.setCornerPreference() } }
    QtObject {
        id: __private

        function setCornerPreference(): void {
            // timer to delay the call in case window is not ready yet
            Helper.createTimer(root, 0, ()=> {
                                   if(!Worker.setWindowRound(root, root.cornerPreference)) {
                                       console.log("Failed to set window corner preference")
                                   }
                               })
        }
    }

    WindowAgent {
        id: windowAgent

    }

    // control item to fill the CWindow
    Control {
        id: control
        implicitWidth: root.width
        implicitHeight: root.height
        topPadding: (root.titleBar?.height || 0) + (root.padding > 0 ? root.padding : root.topPadding)
        leftPadding: root.padding > 0 ? root.padding : root.leftPadding
        rightPadding: root.padding > 0 ? root.padding : root.rightPadding
        bottomPadding: root.padding > 0 ? root.padding : root.bottomPadding
        antialiasing: AppSettings.quality
        // changes the content from (left to right, like english) to (right to left, like arabic)
        LayoutMirroring.enabled: AppSettings.isRTL
        // also make children inherit right to left if arabic selected
        LayoutMirroring.childrenInherit: true // this is false by default

        // we have to create contentItem: Item { }
        // to be able to use multiple items inside the CWindow LIKE
        /* CWindow {
                 Item { }
                 Rectangle { }
                 Timer { }
                 Text { }
         } */
        // then add contents items to be children of the control.contentItem first child (itemsHolder) by default
        contentItem: Item { id: itemsHolder }
    }

}
