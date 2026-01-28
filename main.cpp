#include <QApplication>
#include <QCoreApplication>
#include <QStringLiteral>
#include <QQmlApplicationEngine>
#include <QJSEngine>
#include <QQmlEngine>
#include <QQmlContext>
#include <QSurfaceFormat>
#include <QIcon>
#include <QQuickItem>
#include <QTranslator>
#include <QColorSpace>
#include <QQuickStyle>


#include <QWKQuick/qwkquickglobal.h>
#include "cpp/twain_handler.h"
#include "cpp/worker.h"

#ifdef Q_OS_WIN
// Indicates to hybrid graphics systems to prefer the discrete part by default.
extern "C" {
Q_DECL_EXPORT unsigned long NvOptimusEnablement = 0x00000001;
Q_DECL_EXPORT int AmdPowerXpressRequestHighPerformance = 1;
}
#endif

#if QT_VERSION < QT_VERSION_CHECK(6, 10, 0)
class TranslateHelper : public QObject
{
    Q_OBJECT
public:
    explicit TranslateHelper(QTranslator *translator,
                             QQmlApplicationEngine *engine,
                             TwainHandler *twainHandler, QObject *parent): QObject(parent),
        m_translator(translator),
        m_engine(engine),
        m_twainHandler(twainHandler) {}

public Q_SLOTS:
    inline void handleLangChanged()
    {
        QObject *sender = QObject::sender();
        if(!m_twainHandler || !sender) return;

        QString newLang = sender->property("lang").toString();
        if (!newLang.isEmpty()) {
            QCoreApplication::removeTranslator(m_translator);
            bool success = m_translator->load(QString("%1_%2").arg(APP_NAME, newLang), ":/i18n");
            if (success) {
                QCoreApplication::installTranslator(m_translator);
                QLocale::setDefault(QLocale(newLang));
                m_engine->retranslate();
                qInfo() << "Language changed to:" << newLang;
                if(m_twainHandler) {
                    Q_EMIT m_twainHandler->infoAvailable(QObject::tr("Language changed to: %1").arg(newLang == "ar" ? QObject::tr("Arabic") : QObject::tr("English")));
                }
            } else {
                qWarning() << "Failed to load translation for:" << newLang;
            }
        }
    }
private:
    QTranslator *m_translator;
    QQmlApplicationEngine *m_engine;
    TwainHandler *m_twainHandler;
};
#endif


int main(int argc, char *argv[])
{
    /*
    * Singleton instance lifecycle is managed by QML engine.
    * The engine owns the Worker instance and will delete it
    * automatically when the engine is destroyed.
    *
    * See Worker.h for implementation details.
    */
    Worker *worker = Worker::instance();

    // Determine if Quality rendering mode was selected
    bool isQuality = (worker->renderingMode() == 0); // 0 Quality, 1 Performance

// debug only
#ifdef QT_DEBUG
    qputenv("QT_WIN_DEBUG_CONSOLE", "new"); // options [attach, new]
    qputenv("QSG_INFO", "1");
#endif
    // options: [Windows(vulkan, opengl, d3d11, d3d12), macOS(metal), linux(vulkan, opengl)]
    qputenv("QSG_RHI_BACKEND", "d3d11");

    // - 'threaded': Rendering happens in a dedicated thread (default on most platforms)
    // - 'basic': Rendering happens on the main thread (GUI thread)
    qputenv("QSG_RENDER_LOOP", "threaded"); // options [threaded, basic]

    if(!isQuality) {
        // ⚠ Avoid disabling the redirection surface when using vulkan (QSG_RHI_BACKEND = vulkan)
        //    as it can cause transparency issues, broken effects, or crashes
        qputenv("QT_QPA_DISABLE_REDIRECTION_SURFACE", "1"); // options [1: true, 0: false]
    }

    QSurfaceFormat fmt;
    fmt.setSwapInterval(isQuality ? 1 : 0); // any value higher than 0 will turn the vertical syncing on
    fmt.setSwapBehavior(isQuality ? QSurfaceFormat::TripleBuffer : QSurfaceFormat::DoubleBuffer);

    // These are REQUESTS, not guarantees
    // What you get depends on:
    // 1. GPU capabilities
    // 2. Display capabilities
    // 3. Driver support
    // 4. Operating system
    int channelBit{isQuality ? 16 : 0};
    fmt.setAlphaBufferSize(channelBit);
    fmt.setRedBufferSize(channelBit);
    fmt.setGreenBufferSize(channelBit);
    fmt.setBlueBufferSize(channelBit);
    //////////////////////////////////
    fmt.setSamples(isQuality ? 8 : -1); // options [-1, 1, 2, 4, 8] // default -1 (disabled)
    fmt.setColorSpace(isQuality ? QColorSpace::AdobeRgb : QColorSpace::SRgb);
    fmt.setDepthBufferSize(isQuality ? 32 : 0);
    fmt.setStencilBufferSize(isQuality ? 8 : 0);
    QSurfaceFormat::setDefaultFormat(fmt);

#if QT_VERSION >= QT_VERSION_CHECK(5, 14, 0)
    QApplication::setHighDpiScaleFactorRoundingPolicy(isQuality ? Qt::HighDpiScaleFactorRoundingPolicy::Round : Qt::HighDpiScaleFactorRoundingPolicy::PassThrough);
#endif

    QApplication app(argc, argv);
    app.setApplicationName(APP_NAME);
    app.setApplicationDisplayName(worker->camelToSpaced(APP_NAME));
    app.setApplicationVersion(APP_VER);
    app.setOrganizationName(ORGANIZATION_NAME);
    app.setOrganizationDomain(ORGANIZATION_DOMAIN);
    app.setWindowIcon(QIcon(":/assets/app-icon_32px.png"));
    QQmlApplicationEngine engine;
    worker->setEngine(&engine);
    engine.rootContext()->setContextProperty("qtversion", QVariant::fromValue(qVersion()));

    QWK::registerTypes(&engine);

    // The engine owns the TwainHandler instance and will delete it automatically when the engine is destroyed.
    TwainHandler *twainHandler = engine.singletonInstance<TwainHandler*>(APP_NAME, "Twain");

    QJSValue appSettings = engine.singletonInstance<QJSValue>(APP_NAME, "AppSettings");
    if (appSettings.isObject()) {
        appSettings.setProperty("renderMode", QJSValue(qMax(worker->renderingMode(), 0)));
    }

#if QT_VERSION >= QT_VERSION_CHECK(6, 10, 0)
    QJSValue val(true);
    appSettings.setProperty("highContrastSupported", val);
#else
    QJSValue val(false);
    appSettings.setProperty("highContrastSupported", val);
    qWarning()  << "Your Qt version is below 6.10 — High Contrast support is limited";
#endif


    ///////////////////////// installing language ///////////////////////////////////
    QTranslator translator;
    QString lang = appSettings.property("lang").toString();
    bool translated{false};
    if(!lang.isEmpty()) {
        bool loaded = translator.load(QString("%1_%2").arg(APP_NAME, lang), ":/i18n");
        if (loaded) {
            translated = app.installTranslator(&translator);
            QLocale::setDefault(QLocale(lang));
        }
    }
    // Only report translation failure for non-English languages
    // (English uses the source strings directly)
    if(!translated && lang != "en") {
        qWarning().noquote() << QString("Falied to install translation. %1").arg(lang);
        QMetaObject::invokeMethod(&app, [&twainHandler, lang] {
            if(twainHandler) {
                Q_EMIT twainHandler->errorOccurred(QObject::tr("Falied to install %1 translation").arg(lang == "ar" ? QObject::tr("Arabic") : QObject::tr("English")));
            }
        }, Qt::QueuedConnection);
    }
    //// connecting signal langChanged to reinstall the translation
    QQuickItem *appSettingsItem = qobject_cast<QQuickItem*>(appSettings.toQObject()); // AppSettings.qml
    if (appSettingsItem) {
        const QMetaObject *metaObject = appSettingsItem->metaObject();
        int langChangedSignalIndex = metaObject->indexOfSignal("langChanged()");
        QMetaMethod langChangedSignal(metaObject->method(langChangedSignalIndex));
        if (langChangedSignal.isValid()) {
#if QT_VERSION < QT_VERSION_CHECK(6, 10, 0)
            // translateHelper is only created once and it will be deleted when app goes out of scope
            // in this case when the application quits
            TranslateHelper *translateHelper = new TranslateHelper(&translator, &engine, twainHandler, &app);
            QMetaObject::connect(appSettingsItem,
                                 langChangedSignalIndex,
                                 translateHelper,
                                 translateHelper->metaObject()->indexOfSlot("handleLangChanged()"));
#else
            QMetaObject::connect(appSettingsItem, langChangedSignal, &app, [&translator, &app, &appSettingsItem, &engine, &twainHandler] {
                QString newLang = appSettingsItem->property("lang").toString();
                if (!newLang.isEmpty()) {
                    app.removeTranslator(&translator);
                    bool success = translator.load(QString("%1_%2").arg(APP_NAME, newLang), ":/i18n");
                    if (success) {
                        app.installTranslator(&translator);
                        QLocale::setDefault(QLocale(newLang));
                        engine.retranslate();
                        qInfo() << "Language changed to:" << newLang;
                        if(twainHandler) {
                            Q_EMIT twainHandler->infoAvailable(QObject::tr("Language changed to: %1").arg(newLang == "ar" ? QObject::tr("Arabic") : QObject::tr("English")));
                        }
                    } else {
                        qWarning() << "Failed to load translation for:" << newLang;
                    }
                }
            });
#endif
        }
    }

    ////////////////////////////////////////////////////////////
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.loadFromModule(APP_NAME, "Main");

    return app.exec();
}

/*
 * ESSENTIAL: Include MOC-generated code for QObject classes in main.cpp
 *
 * Why needed:
 * - Qt's Meta-Object Compiler (MOC) processes Q_OBJECT classes
 * - Generates signal/slot implementations in main.moc
 * - Must be included manually in main.cpp
 *
 * Standard practice for separate files:
 * - .h files: MOC generates moc_header.cpp
 * - .cpp files: #include "moc_header.cpp" auto-added by build system
 * - main.cpp: Special case, need manual #include "main.moc"
 *
 * Without this:
 * - Signals won't emit, slots won't trigger for TranslateHelper class
 *
 * Must be at END of file, after all QObject class definitions.
 */

#include "main.moc"
