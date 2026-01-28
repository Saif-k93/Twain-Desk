#pragma once

#include <QObject>
#include <QAbstractNativeEventFilter>
#include <QUrl>
#include <qcoreevent.h>
#include <qqmlintegration.h>
#include <QQmlEngine>
#include <QJSEngine>

#include "cpp/scan_folder_watcher.h"
#include "cpp/models/scanner_model.h"

#ifdef Q_OS_WIN
#include <windows.h>
#include <twain.h>
#endif

namespace PostEventType {
extern const QEvent::Type TransferReady;
extern const QEvent::Type CancelScan;
extern const QEvent::Type FinishScan;
extern const QEvent::Type DeviceEvent;
}

class TwainHandler : public QObject, public QAbstractNativeEventFilter
{
    Q_OBJECT
    QML_NAMED_ELEMENT(Twain)
    QML_UNCREATABLE("Twain is a singleton class and can be accessed directly")
    QML_SINGLETON
    Q_PROPERTY(bool scanning READ isScanning NOTIFY scanningChanged)
    Q_PROPERTY(bool isCanceling READ isCanceling NOTIFY isCancelingChanged FINAL)
    Q_PROPERTY(QString scansLocation READ scansLocation WRITE setScansLocation NOTIFY scansLocationChanged FINAL)
    Q_PROPERTY(ScanFolderWatcher *scanWatcher MEMBER m_watcher CONSTANT)
    Q_PROPERTY(ScannerModel *scannerModel MEMBER m_scannerModel CONSTANT)
    Q_PROPERTY(bool hasSources READ hasSources NOTIFY hasSourcesChanged FINAL)
    Q_PROPERTY(QStringList scanFiles READ scanFiles WRITE setScanFiles NOTIFY scanFilesChanged FINAL)
    Q_PROPERTY(ScanMode scanMode READ scanMode WRITE setScanMode NOTIFY scanModeChanged FINAL)
    Q_PROPERTY(quint16 dpi READ dpi WRITE setDpi NOTIFY dpiChanged FINAL)
    Q_PROPERTY(ColorMode colorMode READ colorMode WRITE setColorMode NOTIFY colorModeChanged FINAL)
    // constructor most be private, have a look at worker.h to know why
    explicit TwainHandler(QObject *parent = nullptr);
    ~TwainHandler();
public:
    static TwainHandler *create(QQmlEngine *, QJSEngine *);
    static TwainHandler *instance();

    enum class ScanMode { Auto = 0, Flatbed, Feeder };
    Q_ENUM(ScanMode)

    enum ColorMode { AutoDetect = 0, Color, Grayscale, BlackAndWhite };
    Q_ENUM(ColorMode)


    virtual bool event(QEvent *event) Q_DECL_OVERRIDE;

    bool isReady() const;
    bool isScanning() const;
    bool isCanceling() const;
    QString scansLocation() const;
    void setScansLocation(const QString &newScansLocation);
    bool hasSources() const;
    QStringList scanFiles() const;
    void setScanFiles(const QStringList &newScanFiles);
    ScanMode scanMode() const;
    void setScanMode(const ScanMode &newScanMode);
    quint16 dpi() const;
    void setDpi(quint16 newDpi);
    ColorMode colorMode() const;
    void setColorMode(const ColorMode &newColorMode);


public slots:
    void startScan(bool silence = false);
    void cancelScan();
    QString twainLastError(); // reads last twain error
    bool refreshSourcesList();
    bool selectSource(const int &scannerId);
    void synchronizeScansLocation();

signals:
    void scanStarted();
    void scanFinished();
    void scanningChanged();
    void imageReady(const QUrl &url);
    void pageProgress(int current);
    void errorOccurred(const QString &message, const bool &isFinal = false);
    void infoAvailable(const QString &message);
    void warn(const QString &message);
    void deviceEvent(const QString &event);
    void isCancelingChanged();
    void scansLocationChanged();
    void hasSourcesChanged();
    void scanFilesChanged();
    void scanModeChanged();
    void dsmClosed();
    void dpiChanged();
    void colorModeChanged();

protected:
    bool nativeEventFilter(const QByteArray &eventType, void *message, qintptr *) override;

private:
    void createOrUpdatePdsmqConfig();
    QString getColorModeText();
#ifdef Q_OS_WIN
    // TWAIN helpers
    void initAppId();
    void enableScanner();
    void setupNextFileTransfer();
    void abortTransfers();
    void finishScan();
    void disableScanner();
    void closeScanner();
    void cleanup();
    QString nextFilePath();
    static HWND getMainWindow();
    QString scanFolder();
    Scanner twainToScanner(const TW_IDENTITY &twainId) const;
    TW_IDENTITY scannerToTwain(const Scanner &s) const;
    QList<Scanner> getAllScanners();
    bool isFeederLoaded();
    bool prepareScanMode();
    bool prepareDpi();
    bool prepareColorMode();
    bool enableFeeder(bool enable);
    void releaseContainer(TW_CAPABILITY &cap);
    TW_HANDLE createOneValue(const TW_ONEVALUE &one);
    void freeTwainHandle(TW_HANDLE h);
    void setScannerIndicator(const bool &state);
    void processNextTransfer();


private slots:
    void processDeferredCancel();
    void handleDeviceEvent();


private:
    // ---- TWAIN objects ----
    HMODULE          m_dsm;
    DSMENTRYPROC     m_dsmEntry;
    TW_IDENTITY      m_appId;
    TW_IDENTITY      m_dsId;
    TW_USERINTERFACE m_ui;
    // ---- TWAIN state  ----
    bool m_dsmOpen;
    bool m_dsOpened;
    bool m_uiEnabled;
    bool m_scanning;
    bool m_cancelRequested;
    bool m_showUI;
    int m_currentPage;
    QString m_currentFilePath;
    bool m_canceling;
    bool m_isSynchronizing;

#endif
    QString m_scansLocation;
    ScanFolderWatcher *m_watcher;
    ScannerModel *m_scannerModel;
    QStringList m_scanFiles;
    ScanMode m_scanMode;
    bool m_isSetingUp;
    quint16 m_dpi;
    ColorMode m_colorMode;

};
