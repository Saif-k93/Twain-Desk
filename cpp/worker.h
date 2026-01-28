#ifndef WORKER_H
#define WORKER_H

#include <QObject>
#include <QQuickWindow>
#include <QQmlEngine>
#include <QJSEngine>
#include <QSettings>
#include <qqmlapplicationengine.h>

namespace CornerPreference {
Q_NAMESPACE
QML_ELEMENT

enum Preference
{
    Default    = 0, // Let the system decide whether or not to round window corners
    DoNotRound = 1, // Never round window corners
    Round      = 2, // Round the corners if appropriate
    RoundSmall = 3 //  Round the corners if appropriate, with a small radius
};
Q_ENUM_NS(Preference)
}

class Worker : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("")
    QML_SINGLETON
    /*
     * CRITICAL: Constructor MUST be private for proper QML singleton behavior.
     *
     * Why private? To prevent QML engine from creating a separate instance.
     *
     see https://doc.qt.io/qt-6/qqmlintegration-h.html#QML_SINGLETON

     * The QML_SINGLETON macro tells Qt:
     * 1. This is a singleton class
     * 2. Use the default constructor if accessible and has the default parameters or
     *  static create() method if declared and constructor is not default or not accessible ( to get the instance )
     *  if not 1 and 2 QML_SINGLETON will do nothing
     *   ** We don't want instances to be created through the default constructor. **
     *
     * HOW IT WORKS:
     * - With private constructor: QML cannot instantiate Worker directly
     * - QML is forced to call Worker::create() for the instance
     * - create() ensures only one instance exists by calling instance() method
     * - Both QML and C++ code access the SAME instance
     *
     * WHAT HAPPENS IF CONSTRUCTOR IS PUBLIC AND DEFAULT(THE BUG):
     * 1. QML ignores create() and makes its own instance through the default constructor
     * 2. Your C++ code calls instance() and creates another instance
     * 3. Now you have TWO "singletons" → Memory leak + inconsistent state
     * 4. QML deletes only its instance on engine destruction
     * 5. Your C++ instance leaks memory
     *
     * RESULT: Private constructor = 1 instance. Public constructor = 2+ instances (bug).
     *
     * Ownership transfer behavior:
     *
     * The first caller (C++ or QML) creates the singleton.
     * When QML engine receives the instance, it automatically
     * takes ownership for cleanup.
     *
     * To prevent engine ownership:
     * Use QJSEngine::setObjectOwnership(instance, QJSEngine::CppOwnership)
     */
    explicit Worker(QObject *parent = nullptr);
    ~Worker();
public:
    // most match Qt create method in https://doc.qt.io/qt-6/qqmlintegration-h.html#QML_SINGLETON
    static Worker *create(QQmlEngine *, QJSEngine *);

    static Worker *instance();

    void setEngine(QQmlApplicationEngine *engine);

    int renderingMode();

    Q_INVOKABLE QString camelToSpaced(const QString &camelStr);
    Q_INVOKABLE void clearCache();



signals:



public slots:
    void setGlobalSettings(QString key, const QVariant &val);
    QVariant getGlobalSettings(QString key, const QVariant &defaultVal = QVariant());
    void clearGlobalSettings();
    bool isWindows11OrGreater();

    /**
 * Sets window corner rounding preference for Windows 11+ rounded corners.
 *
 * Windows 11 introduced system-wide rounded corners. This function allows
 * overriding the default behavior per window.
 *
 * @param window Target QWindow to modify
 * @param pref Corner rounding preference (default: ROUND - Windows 11 style)
 *
 * Note: Only effective on Windows 11 and later. On older Windows versions
 * or other platforms, this function does nothing.
 *
 * DWM corner preference mapping:
 * - DEFAULT:    Use system default (DWMWCP_DEFAULT)
 * - DONOTROUND: Force square corners (DWMWCP_DONOTROUND)
 * - ROUND:      Standard Windows 11 rounded corners (DWMWCP_ROUND)
 * - ROUNDSMALL: Smaller radius rounded corners (DWMWCP_ROUNDSMALL)
 */
    bool setWindowRound(QQuickWindow* window, CornerPreference::Preference pref = CornerPreference::Round);




    // private methods
private:





    // private members
private:
    QSettings *m_globalSettings;
    QQmlApplicationEngine *m_engine = nullptr;
};

#endif // WORKER_H
