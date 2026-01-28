#include "worker.h"

#include <QJSValue>
#include <qquickitem.h>
#include <qtmetamacros.h>
#include <QRegularExpression>


#ifdef Q_OS_WIN
#include <dwmapi.h>
#include <VersionHelpers.h>
#pragma comment(lib, "dwmapi.lib")

#endif

Worker::Worker(QObject *parent)
    : QObject{parent}
{
    QCoreApplication::setOrganizationName(ORGANIZATION_NAME);
    QCoreApplication::setOrganizationDomain(ORGANIZATION_DOMAIN);
    QCoreApplication::setApplicationName(APP_NAME);
    m_globalSettings = new QSettings(ORGANIZATION_NAME, APP_NAME);
}

Worker::~Worker()
{
    qInfo() << "Cleaning up Worker instance...";
    if(m_globalSettings)
        m_globalSettings->deleteLater();
}

Worker *Worker::create(QQmlEngine *, QJSEngine *) { return instance(); }
Worker *Worker::instance() { static Worker *inst = new Worker; return inst; }

void Worker::setEngine(QQmlApplicationEngine *engine)
{
    m_engine = nullptr;
    m_engine = engine;
}

int Worker::renderingMode()
{
    // Determine rendering mode
    bool ok{false};
    int savedRenderMode = m_globalSettings->value("Options/renderMode", 0).toInt(&ok);
    if(!ok) return -1;
    return savedRenderMode;
}

QString Worker::camelToSpaced(const QString &camelStr)
{
    if (camelStr.isEmpty()) return camelStr;

    QRegularExpression re("([a-z])([A-Z])");
    QString result = camelStr;
    result = result.replace(re, "\\1 \\2");

    return result;
}

void Worker::clearCache()
{
    if(m_engine) {
        m_engine->clearComponentCache();
        m_engine->collectGarbage();
    }
}

void Worker::setGlobalSettings(QString key, const QVariant &val)
{
    m_globalSettings->setValue(QAnyStringView(key), val);
}

QVariant Worker::getGlobalSettings(QString key, const QVariant &defaultVal)
{
    return m_globalSettings->value(QAnyStringView(key), defaultVal);
}

void Worker::clearGlobalSettings()
{
    m_globalSettings->clear();
    m_globalSettings->sync();
}

bool Worker::setWindowRound(QQuickWindow *window, CornerPreference::Preference pref)
{
#ifdef Q_OS_WIN
    if (!window) {
        qWarning() << "setWindowRound: Null window provided";
        return false;
    }

    if(!isWindows11OrGreater()) {
        qWarning() << "setWindowRound: Requires Windows 11 or later";
        return false;
    }

    HWND hwnd = reinterpret_cast<HWND>(window->winId());
    if (!hwnd)  {
        qWarning() << "setWindowRound: Invalid window handle";
        return false;
    }
    DWM_WINDOW_CORNER_PREFERENCE dwmPref = DWMWCP_DEFAULT;
    switch (pref) {
    case CornerPreference::Default:    dwmPref = DWMWCP_DEFAULT; break;
    case CornerPreference::DoNotRound: dwmPref = DWMWCP_DONOTROUND; break;
    case CornerPreference::Round:      dwmPref = DWMWCP_ROUND; break;
    case CornerPreference::RoundSmall: dwmPref = DWMWCP_ROUNDSMALL; break;
    default:
        qWarning() << "setWindowRound: Unknown corner preference value";
        return false;
    }
    HRESULT hr = DwmSetWindowAttribute(hwnd, DWMWA_WINDOW_CORNER_PREFERENCE, &dwmPref, sizeof(dwmPref));
    if (SUCCEEDED(hr)) {
        return true;
    }
    qWarning().noquote() << QString("setWindowRound failed: 0x%1")
                                .arg(hr, 8, 16, QChar('0')).toUpper();
    return false;
#else
    return false;
#endif
}

bool Worker::isWindows11OrGreater()
{
#ifdef Q_OS_WIN
    // Get OS version
    HMODULE hMod = ::GetModuleHandleW(L"ntdll.dll");
    if (!hMod) return false;

    using RtlGetVersionPtr = LONG(WINAPI *)(OSVERSIONINFOEXW*);
    auto pRtlGetVersion = reinterpret_cast<RtlGetVersionPtr>(::GetProcAddress(hMod, "RtlGetVersion"));
    if (!pRtlGetVersion) return false;
    OSVERSIONINFOEXW rovi{};
    rovi.dwOSVersionInfoSize = sizeof(rovi);
    pRtlGetVersion(&rovi);
    return (rovi.dwMajorVersion == 10 && rovi.dwBuildNumber >= 22000);
#else
    return false;
#endif
}

