cmake_minimum_required(VERSION 3.16)

project(TwainDesk
    VERSION 0.1.0
    DESCRIPTION "Modern C++ wrapper library for TWAIN image acquisition API"
    HOMEPAGE_URL "https://github.com/Saif-k93"
    LANGUAGES CXX
)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC on)
set(CMAKE_AUTORCC on)
set(CMAKE_INCLUDE_CURRENT_DIR on)

########## definitions ##############
add_definitions(-DAPP_NAME="${PROJECT_NAME}")
add_definitions(-DAPP_VER="${PROJECT_VERSION}")
add_definitions(-DORGANIZATION_NAME="SaifDev")
add_definitions(-DORGANIZATION_DOMAIN="SaifDev.${PROJECT_NAME}")
####################################
if(CMAKE_SIZEOF_VOID_P EQUAL 8)
    set(SYSTEM_X64 ON)
else()
    set(SYSTEM_X64 OFF)
endif()

find_package(Qt6 REQUIRED COMPONENTS
    Quick
    Core
    Gui
    Qml
    QuickControls2
    Widgets # needed by QApplication (QApplication app(argc, argv)) in main.cpp if u use QCoreApplication or QGuiApplication remove it
    Xml
    LinguistTools
)

set(__PRIVATE_LINK_LIBRARIES
    Qt6::Quick
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::QuickControls2
    Qt6::Widgets
    Qt6::Xml
)

qt_standard_project_setup(
    REQUIRES 6.7
    I18N_SOURCE_LANGUAGE en
    I18N_TRANSLATED_LANGUAGES ar
)

include_directories(cpp)

if(SYSTEM_X64)
    set(TWAIN_DSM_SRC "${CMAKE_CURRENT_SOURCE_DIR}/bin/Twain/x64/TWAINDSM.dll")
else()
    set(TWAIN_DSM_SRC "${CMAKE_CURRENT_SOURCE_DIR}/bin/Twain/x86/TWAINDSM.dll")
endif()

set(AppIcon "${CMAKE_SOURCE_DIR}/icon.rc")

set(__CXX_SOURCES
    "main.cpp"
    "cpp/twain.h"
    "cpp/scan_folder_watcher.h"
    "cpp/scan_folder_watcher.cpp"
    "cpp/models/scanner_model.h"
    "cpp/models/scanner_model.cpp"

)

set(__CXX_MODELS
    "cpp/twain_handler.h"
    "cpp/twain_handler.cpp"
    "cpp/worker.h"
    "cpp/worker.cpp"

)

set(__QML_FILES
    "Main.qml"
    "qml/PagesView.qml"
    "qml/OptionsView.qml"
    "qml/StatusView.qml"
    "qml/AppSettings.qml"
    "qml/TitleBar.qml"

    # components
    "qml/components/CWindow.qml"
    "qml/components/CButton.qml"
    "qml/components/CItemDelegate.qml"
    "qml/components/CToolTip.qml"
    "qml/components/CComboBox.qml"
    "qml/components/CScrollBar.qml"
    "qml/components/CContainer.qml"

)

set(__JS_FILES
    "js/Helper.js"

)

################### 3rd Party Libraries  ##########################

## QWindowKit: A cross-platform frameless window framework for Qt, supporting Windows, macOS, and Linux.
set(QWINDOWKIT_BUILD_STATIC ON) # build static
set(QWINDOWKIT_BUILD_WIDGETS OFF) # turn this ON if using Qt WIDGETS
set(QWINDOWKIT_BUILD_QUICK ON)
set(QWINDOWKIT_BUILD_EXAMPLES OFF)
set(QWINDOWKIT_BUILD_DOCUMENTATIONS OFF)
set(QWINDOWKIT_INSTALL ON)
set(QWINDOWKIT_FORCE_QT_WINDOW_CONTEXT OFF)
set(QWINDOWKIT_ENABLE_WINDOWS_SYSTEM_BORDERS ON)
set(QWINDOWKIT_ENABLE_STYLE_AGENT ON)
# add_subdirectory() must be called before linking
add_subdirectory(deps/qwindowkit) # calls "deps\qwindowkit\CMakeLists.txt" to build the library
include_directories(deps/qwindowkit/src) # just to include QWindowKit headers to be used in the app
# append it to the list to be linked later or just link to it directly: target_link_libraries(${PROJECT_NAME} PRIVATE QWKCore QWKQuick)
list(APPEND __PRIVATE_LINK_LIBRARIES QWKCore QWKQuick)
#-------------------------------------------------------


#########################################################


qt_add_executable(${PROJECT_NAME}
    ${AppIcon} # app icon.rc

    # c++
    ${__CXX_SOURCES}


    # Res
    res.qrc # qt resource
)

###### TWAIN_DSM ######
set(TWAIN_DSM_BIN "$<TARGET_FILE_DIR:${PROJECT_NAME}>/TWAINDSM.dll")
add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
    "${TWAIN_DSM_SRC}"
    "${TWAIN_DSM_BIN}"
    COMMENT "Copying TWAINDSM.dll to output directory"
)
set(TWAIN_DSM "${TWAIN_DSM_BIN}")
target_compile_definitions(${PROJECT_NAME} PRIVATE DSM_PATH="${TWAIN_DSM}")
#########################

qt_policy(SET QTP0001 NEW)
qt_policy(SET QTP0004 NEW)
set_property(SOURCE js/Helper.js PROPERTY QT_QML_SKIP_QMLDIR_ENTRY FALSE)
set_source_files_properties(qml/AppSettings.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
qt_add_qml_module(${PROJECT_NAME} URI ${PROJECT_NAME} VERSION 1.0
    # qml
    QML_FILES
    ${__QML_FILES}


    #Java Script
    ${__JS_FILES}


    #c++ models
    SOURCES
    ${__CXX_MODELS}


    DEPENDENCIES
    QtCore

)

set_target_properties(${PROJECT_NAME} PROPERTIES
    #    MACOSX_BUNDLE_GUI_IDENTIFIER com.example.${PROJECT_NAME}
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
    #QT_ANDROID_PACKAGE_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/android"
)

###### translation ######
qt_add_translations(${PROJECT_NAME}
    TS_FILE_BASE ${PROJECT_NAME}
    PLURALS_TS_FILE ${PROJECT_NAME}_en.ts
    NO_GENERATE_PLURALS_TS_FILE
)
# uncomment to update translations
#add_custom_target(update_translations ALL)
#add_custom_target(release_translations ALL)
#########################

target_link_libraries(${PROJECT_NAME}
    PRIVATE
    ${__PRIVATE_LINK_LIBRARIES}

)

include(GNUInstallDirs)
install(TARGETS ${PROJECT_NAME}
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)


