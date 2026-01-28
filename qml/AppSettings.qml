/* Makes this QML type a singleton - only one instance exists globally
 you still have to do:
 set_source_files_properties(qml/AppSettings.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
 in cmake before qt_add_qml_module
 */
pragma Singleton

/* The default value of ComponentBehavior is Unbound
 read https://doc.qt.io/qt-6/qtqml-documents-structure.html */
pragma ComponentBehavior: Bound

/* Type annotation requirement for function parameters:
 Enforced (requires explicit types):
   function calculate(x: int, y: real): real { return x * y }
   ^ Type annotations mandatory

 Ignored (types optional, default to 'var'):
   function calculate(x, y) { return x * y }
   ^ Types can be omitted, parameters are 'var'
*/
pragma FunctionSignatureBehavior: Enforced

import QtQuick
import QtCore

Item {
    id: root

    enum Theme { System = 0, Light = 1, Dark = 2 }
    enum RenderMode { Quality = 0, Performance = 1 }
    enum Language { EN = 0, AR = 1 }

    Settings { id: globalSettings }

    function colorProvider(colorName: string): color {
        return (paletteLoader.item?.[colorName] || "transparent") // incase paletteLoader.item not ready yet
    }

    /* SystemPalette doesn't have link and some other colors so we use Palette as helper for the other colors
     but Palette doesn't dynamically change colors so what we can do is
     we put it inside a Loader then listen to onPaletteChanged inside SystemPalette
     onPaletteChanged will trigger whenever user changes the Contrast theme on the System
     then we destroy and recreate the palette so it can reload the new Contrast theme colors
     **** note that SystemPalette can dynamically change colors so we doing all that just for colors used by Palette
    */
    Loader {
        id: paletteLoader
        active: true
        asynchronous: false
        sourceComponent: Palette { }
    }
    SystemPalette {
        id: appPalette
        // 1. Create a custom colors propertites for SystemPalette
        property color link: root.colorProvider("link")
        property color linkVisited: root.colorProvider("linkVisited")
        property color toolTipBase: root.colorProvider("toolTipBase")

        // 2. When system colors change (user changes theme/contrast)
        onPaletteChanged: {
            // 3. Force reload the Palette object
            paletteLoader.active = false  // Destroy the old Palette
            paletteLoader.active = true   // Create new Palette with updated colors
            // Instead of using paletteLoader.item directly, we copy colors to appPalette.
            // This ensures consistent access through a single object reference.

            // 4. Update our custom 'link' color
            appPalette.link = root.colorProvider("link")
            appPalette.linkVisited = root.colorProvider("linkVisited")
            appPalette.toolTipBase = root.colorProvider("toolTipBase")
        }
    }

    property int renderMode: 0
    property bool highContrastSupported: false // dont not change its controlled from main.cpp
    property int language: 0

    readonly property string lang: language === AppSettings.Language.AR ? "ar" : "en" // 2 letters for QTranslator
    readonly property bool quality: renderMode === 0
    readonly property bool isRTL:language === AppSettings.Language.AR
    readonly property int theme: Application.styleHints.colorScheme
    readonly property bool isDark: theme === Qt.Dark
    readonly property bool isLight: theme === Qt.Light
    readonly property bool isHighContrast: highContrastSupported ? Application.styleHints.accessibility.contrastPreference === Qt.HighContrast : (!isDark && !isLight)
    readonly property int alternateTheme: isDark ? 1 : isLight ? 2 : 0
    readonly property alias palette: appPalette
    // color
    readonly property color light: "#f9f9f9"
    readonly property color dark: "#202020"
    // let Qt palette deal with HighContrast colors dont hard code it
    readonly property color background: isHighContrast ? appPalette.window : isDark ? dark : light
    readonly property color highlighted: isHighContrast ? appPalette.highlight : isDark ? Qt.lighter("green", 1.3) : Qt.lighter("blue", 1.35)
    readonly property color accent: isHighContrast ? appPalette.accent : isDark ? "#282828" : "#f6f6f6"
    readonly property color text: isHighContrast ? appPalette.text : isDark ? Qt.rgba(1.0, 1.0, 1.0, 0.88) : Qt.rgba(0.0, 0.0, 0.0, 0.88)
    readonly property color hovered: isHighContrast ? appPalette.shadow : isDark ? "#2d2d2d" : "#eaeaea"
    readonly property color border: isHighContrast ? appPalette.buttonText : isDark ? Qt.rgba(0.0, 0.0, 0.0, 0.3) : Qt.rgba(0.0, 0.0, 0.0, 0.15)
    readonly property color shadow: isHighContrast ? appPalette.shadow : Qt.rgba(0.0, 0.0, 0.0, 0.88)
    readonly property color link: isHighContrast ? appPalette.link : isDark ? Qt.lighter("green", 1.4) : Qt.lighter("blue", 1.4)
    readonly property color midlight: isHighContrast ? appPalette.midlight : isDark ? Qt.rgba(1.0, 1.0, 1.0, 0.8) : Qt.rgba(0.0, 0.0, 0.0, 0.15)

    function setTheme(theme: int): bool {
        if(theme < 0 || theme > 2) return false
        Application.styleHints.colorScheme = theme
        globalSettings.setValue("UI/theme", theme)
        return true
    }

    function setLanguage(language: int): bool {
        if(language < 0 || language > 1) return false
        root.language = language
        globalSettings.setValue("UI/language", language)
        return true
    }

    Component.onCompleted: {
        setTheme(globalSettings.value("UI/theme", AppSettings.Theme.System))
        setLanguage(globalSettings.value("UI/language", AppSettings.Language.EN))
    }

}
