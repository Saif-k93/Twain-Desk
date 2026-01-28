#include "twain_handler.h"

#include <QApplication>
#include <QDebug>
#include <QDir>
#include <QDateTime>
#include <QStandardPaths>
#include <QDomDocument>
#include <QThread>
#include <QTimer>
#include <QWindow>


namespace PostEventType
{
const QEvent::Type TransferReady = static_cast<QEvent::Type>(QEvent::registerEventType());
const QEvent::Type CancelScan    = static_cast<QEvent::Type>(QEvent::registerEventType());
const QEvent::Type FinishScan    = static_cast<QEvent::Type>(QEvent::registerEventType());
const QEvent::Type DeviceEvent   = static_cast<QEvent::Type>(QEvent::registerEventType());
}

TwainHandler::TwainHandler(QObject *parent)
    : QObject(parent),
    m_scansLocation(QStandardPaths::writableLocation(QStandardPaths::PicturesLocation)),
    m_watcher(new ScanFolderWatcher(this)),
    m_scanFiles(QStringList()),
    m_scanMode(TwainHandler::ScanMode::Auto),
    m_scannerModel(new ScannerModel(this)),
    m_colorMode(TwainHandler::ColorMode::AutoDetect),
    m_dpi(300),
#ifdef Q_OS_WIN
    // ---- TWAIN objects ----
    m_dsm(nullptr),
    m_dsmEntry(nullptr),
    m_appId({}),
    m_dsId({}),
    m_ui({}),
    // TWAIN state
    m_currentFilePath(QString()),
    m_currentPage(NULL),
    m_dsmOpen(false),
    m_dsOpened(false),
    m_uiEnabled(false),
    m_scanning(false),
    m_cancelRequested(false),
    m_showUI(false),
    m_canceling(false),
    m_isSynchronizing(false),
    m_isSetingUp(false)
#endif

{
    createOrUpdatePdsmqConfig();
    QObject::connect(m_scannerModel, &ScannerModel::scannersChanged, this, [this] {
        emit this->hasSourcesChanged();
    });
    m_watcher->watchFolder(m_scansLocation + QString("/%1").arg(APP_NAME));
    QObject::connect(this, &TwainHandler::scansLocationChanged, this, [this] {
        m_watcher->watchFolder(scanFolder());
    });
    QObject::connect(m_watcher, &ScanFolderWatcher::fileRemoved, this, [this] (const QString &filePath) {
        emit warn(tr("File removed by user: %1").arg(filePath));
    });
    QObject::connect(m_watcher, &ScanFolderWatcher::fileAdded, this, [this] (const QString &filePath) {
        QString fileUrl = QUrl::fromLocalFile(filePath).toString();
        if (m_scanFiles.contains(fileUrl, Qt::CaseInsensitive)) return;
        if (!m_scanning && !m_isSynchronizing) emit warn(tr("File added by user: %1").arg(filePath));
        else if (m_isSynchronizing) emit warn(tr("File synchronized: %1").arg(filePath));
    });
#ifdef Q_OS_WIN
    QString dsm_path = QStringLiteral(DSM_PATH);
    m_dsm = LoadLibraryW(reinterpret_cast<LPCWSTR>(dsm_path.utf16()));
    if (!m_dsm) {
        QMetaObject::invokeMethod(this, "errorOccurred", Qt::QueuedConnection, Q_ARG(QString, tr("TWAINDSM.dll is missing. Please place TWAINDSM.dll in the same folder as the application executable")), Q_ARG(bool, true));
        return;
    }

    m_dsmEntry = reinterpret_cast<DSMENTRYPROC>(GetProcAddress(m_dsm, "DSM_Entry"));

    if (!m_dsmEntry) {
        QMetaObject::invokeMethod(this, "errorOccurred", Qt::QueuedConnection, Q_ARG(QString, tr("Unable to locate DSM_Entry in TWAINDSM.dll. The file may be missing or damaged.")), Q_ARG(bool, true));
        FreeLibrary(m_dsm);
        m_dsm = nullptr;
        return;
    }

    initAppId();
    qApp->installNativeEventFilter(this);
#endif
}

TwainHandler::~TwainHandler()
{
    qInfo() << "Cleaning up Twain library...";
    if(m_watcher) {
        m_watcher->deleteLater();
    }
    if(m_scannerModel) {
        m_scannerModel->deleteLater();
    }
#ifdef Q_OS_WIN
    qApp->removeNativeEventFilter(this);

    if (m_scanning) {
        processDeferredCancel();
    }

    if (m_dsm)
        FreeLibrary(m_dsm);
#endif
}

// ------------------------------------------------------------
// Singleton
// ------------------------------------------------------------

TwainHandler *TwainHandler::create(QQmlEngine *, QJSEngine *) { return instance(); }
TwainHandler *TwainHandler::instance() { static TwainHandler *inst = new TwainHandler; return inst; }

// ------------------------------------------------------------
// Native Event Handling
// ------------------------------------------------------------
bool TwainHandler::nativeEventFilter(const QByteArray &eventType, void *message, qintptr *r)
{
#ifdef Q_OS_WIN
    if(!message || eventType != "windows_generic_MSG" || !m_dsmOpen) return false;

    MSG *msg = static_cast<MSG *>(message);

    TW_EVENT ev{};
    ev.pEvent = msg;
    ev.TWMessage = MSG_NULL;

    if (m_dsmEntry(&m_appId, &m_dsId, DG_CONTROL, DAT_EVENT, MSG_PROCESSEVENT, &ev) == TWRC_DSEVENT) {
        if (ev.TWMessage == MSG_XFERREADY) {
            QCoreApplication::postEvent(this, new QEvent(PostEventType::TransferReady));
            return true;
        }

        if (ev.TWMessage == MSG_CLOSEDSREQ || ev.TWMessage == MSG_CLOSEDSOK) {
            QCoreApplication::postEvent(this, new QEvent(PostEventType::FinishScan));
            return true;
        }

        if (ev.TWMessage == MSG_DEVICEEVENT) {
            QCoreApplication::postEvent(this, new QEvent(PostEventType::DeviceEvent));
            return true;
        }
    }
#endif
    return false;
}

// ------------------------------------------------------------
// Utilities
// ------------------------------------------------------------
#ifdef Q_OS_WIN

HWND TwainHandler::getMainWindow()
{
    if (qApp->topLevelWindows().isEmpty())
        return nullptr;

    return reinterpret_cast<HWND>(
        qApp->topLevelWindows().first()->winId());
}

void TwainHandler::processDeferredCancel()
{
    if (!m_cancelRequested)
        return;

    m_cancelRequested = false;

    abortTransfers();
    finishScan();
}

QString TwainHandler::scanFolder()
{
    if (m_scansLocation.isEmpty()) {
        qWarning() << "Scans location not set.";
        emit warn(tr("Scans location not set."));
        return {};
    }

    QDir dir(m_scansLocation);
    QString lastFolderName = dir.dirName();
    QString savePath;

    if (lastFolderName == APP_NAME) {
        savePath = dir.absolutePath();
    } else {
        savePath = dir.filePath(APP_NAME);
    }

    QDir scanDir(savePath);

    if (!scanDir.exists()) {
        if (!scanDir.mkpath(".")) {
            qCritical() << "Failed to create scan folder:" << savePath;
            emit errorOccurred(tr("Failed to create scan folder: %1").arg(savePath));
            return {};
        } else {
            qInfo() << "Created scan folder:" << savePath;
            emit scansLocationChanged();
            emit warn(tr("Created scan folder: %1").arg(savePath));
        }
    }

    return savePath;
}

Scanner TwainHandler::twainToScanner(const TW_IDENTITY &twainId) const
{
    Scanner s;
    s.id = twainId.Id;
    s.protocolMajor = twainId.ProtocolMajor;
    s.protocolMinor = twainId.ProtocolMinor;
    s.supportedGroups = twainId.SupportedGroups;
    s.manufacturer = QString::fromLatin1(twainId.Manufacturer);
    s.productFamily = QString::fromLatin1(twainId.ProductFamily);
    s.productName = QString::fromLatin1(twainId.ProductName);
    s.versionInfo = tr("%1.%2, Info: %3")
                        .arg(twainId.Version.MajorNum)
                        .arg(twainId.Version.MinorNum)
                        .arg(QString::fromLatin1(twainId.Version.Info));
    return s;
}

TW_IDENTITY TwainHandler::scannerToTwain(const Scanner &s) const
{
    TW_IDENTITY id{};
    memset(&id, 0, sizeof(TW_IDENTITY));

    id.Id = s.id;
    id.ProtocolMajor = s.protocolMajor;
    id.ProtocolMinor = s.protocolMinor;
    id.SupportedGroups = s.supportedGroups;

    QByteArray man  = s.manufacturer.toLatin1();
    QByteArray fam  = s.productFamily.toLatin1();
    QByteArray name = s.productName.toLatin1();

    qstrncpy(id.Manufacturer,  man.constData(),  sizeof(id.Manufacturer));
    qstrncpy(id.ProductFamily, fam.constData(),  sizeof(id.ProductFamily));
    qstrncpy(id.ProductName,   name.constData(), sizeof(id.ProductName));

    return id;
}

QList<Scanner> TwainHandler::getAllScanners()
{
    QList<Scanner> scanners;

#ifdef Q_OS_WIN
    bool dsmWasAlreadyOpen = m_dsmOpen;

    // Open DSM temporarily if not already open
    if (!dsmWasAlreadyOpen) {
        TW_UINT16 rc = m_dsmEntry(&m_appId, nullptr,
                                  DG_CONTROL, DAT_PARENT,
                                  MSG_OPENDSM, nullptr);
        if (rc != TWRC_SUCCESS) {
            qWarning() << "Failed to open DSM for enumeration";
            return scanners;
        }
        m_dsmOpen = true;
    }

    // Enumerate scanners
    TW_IDENTITY src{};
    TW_UINT16 rc = m_dsmEntry(&m_appId, nullptr,
                              DG_CONTROL, DAT_IDENTITY,
                              MSG_GETFIRST, &src);

    while (rc == TWRC_SUCCESS) {
        scanners.append(twainToScanner(src));
        rc = m_dsmEntry(&m_appId, nullptr,
                        DG_CONTROL, DAT_IDENTITY,
                        MSG_GETNEXT, &src);
    }

    // Close DSM if we opened it just for enumeration
    if (!dsmWasAlreadyOpen && m_dsmOpen) {
        m_dsmEntry(&m_appId, nullptr,
                   DG_CONTROL, DAT_PARENT,
                   MSG_CLOSEDSM, nullptr);
        m_dsmOpen = false;
    }
#endif

    return scanners;
}

bool TwainHandler::isFeederLoaded()
{
    TW_CAPABILITY cap{};
    cap.Cap = CAP_FEEDERLOADED;
    cap.ConType = TWON_DONTCARE16;

    if (m_dsmEntry(&m_appId, &m_dsId,
                   DG_CONTROL, DAT_CAPABILITY,
                   MSG_GET, &cap) != TWRC_SUCCESS) {
        return false;
    }

    bool loaded = false;

    if (cap.hContainer) {
        switch (cap.ConType) {
        case TWON_ONEVALUE: {
            TW_ONEVALUE* one = static_cast<TW_ONEVALUE*>(cap.hContainer);
            loaded = (one->Item != 0);
            break;
        }
        case TWON_ENUMERATION: {
            TW_ENUMERATION* en = static_cast<TW_ENUMERATION*>(cap.hContainer);
            if (en->NumItems > 0) {
                // Use CurrentIndex to get the current value
                TW_UINT32 index = en->CurrentIndex;
                loaded = (en->ItemList[index] != 0);
            }
            break;
        }
        default:
            loaded = false;
            break;
        }
    }

    releaseContainer(cap);
    return loaded;
}

bool TwainHandler::prepareScanMode()
{
    bool feederLoaded = isFeederLoaded();
    if(scanMode() == TwainHandler::ScanMode::Auto) {
        enableFeeder(feederLoaded);
    } else if(scanMode() == TwainHandler::ScanMode::Feeder) {
        if(!feederLoaded) {
            finishScan();
            emit errorOccurred(tr("The document feeder is empty. Please load pages into the feeder and try again."));
            return false;
        }
        if(!enableFeeder(true)) {
            finishScan();
            emit errorOccurred(tr("Failed to activate the document feeder, Please try again."));
            return false;
        }
    } else if(scanMode() == TwainHandler::ScanMode::Flatbed) {
        enableFeeder(false);
    } else {
        finishScan();
        emit errorOccurred(tr("Select a scan mode !"));
        return false;
    }
    return true;
}

bool TwainHandler::prepareDpi()
{
    if (!m_dsId.Id || !m_dsOpened)
        return false;

    // Prepare horizontal DPI
    TW_ONEVALUE xVal{};
    xVal.ItemType = TWTY_FIX32;
    xVal.Item = dpi();
    TW_HANDLE hX = createOneValue(xVal);
    if (!hX) return false;

    TW_CAPABILITY capX{};
    capX.Cap = ICAP_XRESOLUTION;
    capX.ConType = TWON_ONEVALUE;
    capX.hContainer = hX;
    TW_UINT16 rcX = m_dsmEntry(&m_appId, &m_dsId, DG_CONTROL, DAT_CAPABILITY, MSG_SET, &capX);

    freeTwainHandle(hX);

    // Prepare vertical DPI
    TW_ONEVALUE yVal{};
    yVal.ItemType = TWTY_FIX32;
    yVal.Item = dpi();
    TW_HANDLE hY = createOneValue(yVal);
    if (!hY) return false;

    TW_CAPABILITY capY{};
    capY.Cap = ICAP_YRESOLUTION;
    capY.ConType = TWON_ONEVALUE;
    capY.hContainer = hY;
    TW_UINT16 rcY = m_dsmEntry(&m_appId, &m_dsId, DG_CONTROL, DAT_CAPABILITY, MSG_SET, &capY);

    freeTwainHandle(hY);

    return rcX == TWRC_SUCCESS && rcY == TWRC_SUCCESS;
}

bool TwainHandler::prepareColorMode()
{
    if (!m_dsOpened || !m_dsId.Id)
        return false;

    quint16 twainPixelType = TWPT_RGB;
    switch (m_colorMode) {
    case ColorMode::Color:         twainPixelType = TWPT_RGB;  break;
    case ColorMode::Grayscale:     twainPixelType = TWPT_GRAY; break;
    case ColorMode::BlackAndWhite: twainPixelType = TWPT_BW;   break;
    case ColorMode::AutoDetect:                                break;
    }

    TW_CAPABILITY cap{};
    cap.Cap = ICAP_PIXELTYPE;
    cap.ConType = TWON_ENUMERATION;

    TW_UINT16 rc = m_dsmEntry(&m_appId, &m_dsId, DG_CONTROL, DAT_CAPABILITY, MSG_GET, &cap);
    if (rc != TWRC_SUCCESS || !cap.hContainer) {
        return false;
    }

    TW_ENUMERATION* en = static_cast<TW_ENUMERATION*>(cap.hContainer);
    bool supported = false;

    for (quint32 i = 0; i < en->NumItems; ++i) {
        if (en->ItemList[i] == twainPixelType) {
            supported = true;
            break;
        }
    }

    if (!supported) {
        qWarning() << "Selected color mode not supported by scanner, falling back to default.";
        emit warn(tr("Selected color mode not supported by scanner, falling back to default."));
        twainPixelType = en->ItemList[en->CurrentIndex];
    }

    releaseContainer(cap);

    if (m_colorMode == ColorMode::AutoDetect) {
        return true;
    }

    TW_ONEVALUE val{};
    val.ItemType = TWTY_UINT16;
    val.Item = twainPixelType;

    TW_CAPABILITY setCap{};
    setCap.Cap = ICAP_PIXELTYPE;
    setCap.ConType = TWON_ONEVALUE;
    setCap.hContainer = createOneValue(val);

    rc = m_dsmEntry(&m_appId, &m_dsId, DG_CONTROL, DAT_CAPABILITY, MSG_SET, &setCap);
    releaseContainer(setCap);

    if (rc != TWRC_SUCCESS) {
        return false;
    }

    return true;
}

bool TwainHandler::enableFeeder(bool enable)
{
    TW_CAPABILITY cap{};
    cap.Cap = CAP_FEEDERENABLED;
    cap.ConType = TWON_ONEVALUE;

    TW_ONEVALUE one{};
    one.ItemType = TWTY_BOOL;
    one.Item = enable ? 1 : 0;

    cap.hContainer = createOneValue(one);

    TW_UINT16 rc = m_dsmEntry(&m_appId, &m_dsId,
                              DG_CONTROL, DAT_CAPABILITY,
                              MSG_SET, &cap);
    if (rc != TWRC_SUCCESS) {
        qWarning() << "Failed to enable feeder:" << twainLastError();
        return false;
    }

    releaseContainer(cap);
    return true;
}

void TwainHandler::releaseContainer(TW_CAPABILITY &cap)
{
    if (cap.hContainer) {
        freeTwainHandle(cap.hContainer);
        cap.hContainer = nullptr;
    }

}

TW_HANDLE TwainHandler::createOneValue(const TW_ONEVALUE &one)
{
    HGLOBAL hMem = GlobalAlloc(GHND | GMEM_SHARE, sizeof(TW_ONEVALUE));
    if (!hMem) return nullptr;

    void* pMem = GlobalLock(hMem);
    if (!pMem) {
        GlobalFree(hMem);
        return nullptr;
    }

    memcpy(pMem, &one, sizeof(TW_ONEVALUE));

    GlobalUnlock(hMem);
    return hMem;
}

void TwainHandler::freeTwainHandle(TW_HANDLE h)
{
    if (h) {
        HGLOBAL g = static_cast<HGLOBAL>(h);
        GlobalUnlock(g);
        GlobalFree(g);
    }
}

void TwainHandler::setScannerIndicator(const bool &state)
{
    TW_CAPABILITY cap{};
    cap.Cap = CAP_INDICATORS;
    cap.ConType = TWON_ONEVALUE;
    TW_ONEVALUE one{};
    one.ItemType = TWTY_BOOL;
    one.Item = state;
    cap.hContainer = createOneValue(one);
    m_dsmEntry(&m_appId, &m_dsId, DG_CONTROL, DAT_CAPABILITY, MSG_SET, &cap);
    releaseContainer(cap);
}

void TwainHandler::processNextTransfer()
{
    if (m_cancelRequested) {
        processDeferredCancel();
        return;
    }

    setupNextFileTransfer(); // Prepare filename
    if (m_currentFilePath.isEmpty()) {
        processDeferredCancel();
        return;
    }

    // Perform image transfer
    TW_UINT16 rc = m_dsmEntry(&m_appId, &m_dsId, DG_IMAGE, DAT_IMAGEFILEXFER, MSG_GET, nullptr);

    if (rc == TWRC_CANCEL) {
        qInfo() << "Scan canceled by user.";
        emit warn(tr("Scan canceled by user."));
        processDeferredCancel();
        return;
    }

    if (rc != TWRC_XFERDONE) {
        qCritical() << "Image transfer failed:" << m_currentFilePath;
        emit errorOccurred(tr("Image transfer failed: %1").arg(m_currentFilePath));
        processDeferredCancel();
        return;
    }

    qInfo() << "Image transferred:" << m_currentFilePath;
    emit infoAvailable(tr("Image transferred: %1").arg(m_currentFilePath));
    emit imageReady(QUrl::fromLocalFile(m_currentFilePath));
    m_currentPage++;

    // End transfer & check if more pages
    TW_PENDINGXFERS px{};
    ZeroMemory(&px, sizeof(px));
    m_dsmEntry(&m_appId, &m_dsId, DG_CONTROL, DAT_PENDINGXFERS, MSG_ENDXFER, &px);

    emit pageProgress(m_currentPage);

    if (px.Count > 0) {
        // Schedule next transfer as queued event
        QCoreApplication::postEvent(this, new QEvent(PostEventType::TransferReady));
    } else {
        finishScan();
        qInfo() << "Scan completed.";
        emit infoAvailable(tr("Scan completed."));
    }
}

void TwainHandler::handleDeviceEvent()
{
    if (!m_dsmOpen) {
        qWarning() << "DSM is not open, cannot read device events";
        return;
    }
    TW_DEVICEEVENT devEv{};

    TW_UINT16 rc = m_dsmEntry(&m_appId,
                              &m_dsId,
                              DG_CONTROL,
                              DAT_DEVICEEVENT,
                              MSG_GET,
                              &devEv);
    if (rc == TWRC_FAILURE) {
        // No event waiting → do nothing
        return;
    }

    if (rc != TWRC_SUCCESS) {
        qWarning() << "DAT_DEVICEEVENT failed rc =" << rc;
        return;
    }

    switch (devEv.Event) {
    case TWDE_CHECKAUTOMATICCAPTURE:
        qInfo() << "Automatic capture check required";
        emit deviceEvent(tr("Automatic capture check required"));
        break;

    case TWDE_CHECKBATTERY:
        qWarning() << "Battery check required";
        emit deviceEvent(tr("Battery check required"));
        break;

    case TWDE_CHECKDEVICEONLINE:
        qWarning() << "Checking whether device is online";
        emit deviceEvent(tr("Checking whether the scanner is online"));
        break;

    case TWDE_CHECKFLASH:
        qWarning() << "Flash check required";
        emit deviceEvent(tr("Flash check required"));
        break;

    case TWDE_CHECKPOWERSUPPLY:
        qWarning() << "Power supply check required";
        emit deviceEvent(tr("Power supply check required"));
        break;

    case TWDE_CHECKRESOLUTION:
        qWarning() << "Resolution check required";
        emit deviceEvent(tr("Resolution check required"));
        break;

    case TWDE_DEVICEADDED:
        qInfo() << "Scanner device added";
        emit deviceEvent(tr("Scanner device added"));
        break;

    case TWDE_DEVICEOFFLINE:
        qCritical() << "Scanner went offline";
        emit deviceEvent(tr("Scanner went offline"));
        processDeferredCancel();
        break;

    case TWDE_DEVICEREADY:
        qInfo() << "Scanner is ready";
        emit deviceEvent(tr("Scanner is ready"));
        break;

    case TWDE_DEVICEREMOVED:
        qCritical() << "Scanner was removed";
        emit deviceEvent(tr("Scanner was removed"));
        processDeferredCancel();
        break;

    case TWDE_IMAGECAPTURED:
        qInfo() << "Image captured";
        emit deviceEvent(tr("Image captured"));
        break;

    case TWDE_IMAGEDELETED:
        qInfo() << "Image deleted";
        emit deviceEvent(tr("Image deleted"));
        break;

    case TWDE_PAPERDOUBLEFEED:
        qCritical() << "Paper double feed detected";
        emit deviceEvent(tr("Paper double feed detected"));
        processDeferredCancel();
        break;

    case TWDE_PAPERJAM:
        qCritical() << "Paper jam detected";
        emit deviceEvent(tr("Paper jam detected"));
        processDeferredCancel();
        break;

    case TWDE_LAMPFAILURE:
        qCritical() << "Scanner lamp failure";
        emit deviceEvent(tr("Scanner lamp failure"));
        processDeferredCancel();
        break;

    case TWDE_POWERSAVE:
        qInfo() << "Scanner entered power save mode";
        emit deviceEvent(tr("Scanner entered power save mode"));
        break;

    case TWDE_POWERSAVENOTIFY:
        qInfo() << "Power save notification received";
        emit deviceEvent(tr("Power save notification received"));
        break;

    default:
        // Vendor-specific or unknown events
        if (devEv.Event & TWDE_CUSTOMEVENTS) {
            qInfo() << "Vendor-specific device event:" << devEv.Event;
            emit deviceEvent(tr("Vendor-specific scanner event: %1").arg(devEv.Event));
        } else {
            qWarning() << "Unknown device event:" << devEv.Event;
            emit deviceEvent(tr("Unknown scanner event"));
        }
        break;
    }
}

// ------------------------------------------------------------
// Public API
// ------------------------------------------------------------

bool TwainHandler::isReady() const
{
    return m_dsmEntry != nullptr;
}

bool TwainHandler::isScanning() const
{
    return m_scanning;
}

void TwainHandler::startScan(bool silence)
{
    if (!isReady() || m_scanning || m_isSetingUp)
        return;

    m_isSetingUp = true;

    if (m_uiEnabled || m_dsOpened) {
        if(m_scanning) {
            qWarning() << "Please wait for scanner to finish before starting new scan.";
            emit warn(tr("Please wait for scanner to finish before starting new scan."));
        } else {
            qWarning() << "Scanner was in a bad state, please try again.";
            emit warn(tr("Scanner was in a bad state, please try again."));
            finishScan();
        }
        m_isSetingUp = false;
        return;
    }

    finishScan();

    m_showUI = !silence;
    m_currentPage = 0;

    // Open DSM
    qInfo() << "Opening DSM...";
    emit infoAvailable(tr("Opening DSM..."));
    if (m_dsmEntry(&m_appId, nullptr,
                   DG_CONTROL, DAT_PARENT,
                   MSG_OPENDSM, nullptr) != TWRC_SUCCESS) {
        qCritical() << "Failed to open DSM.";
        emit errorOccurred(tr("Failed to open DSM."));
        finishScan();
        m_isSetingUp = false;
        return;
    }
    qInfo() << "DSM Opened.";
    emit infoAvailable(tr("DSM Opened."));
    m_dsmOpen = true;

    //// handled by ui
    // // Select source
    // if(m_showUI) {
    //     qInfo() << "Select a scanner.";
    //     emit infoAvailable(tr("Select a scanner."));
    // } else {
    //     qInfo() << "Selecting default scanner...";
    //     emit infoAvailable(tr("Selecting default scanner..."));
    // }
    // ZeroMemory(&m_dsId, sizeof(m_dsId));
    // TW_UINT16 selMsg = m_showUI ? MSG_USERSELECT : MSG_GETDEFAULT;

    // if (m_dsmEntry(&m_appId, nullptr,
    //                DG_CONTROL, DAT_IDENTITY,
    //                selMsg, &m_dsId) != TWRC_SUCCESS) {
    //     qCritical() << "Scanner selection failed.";
    //     emit errorOccurred(tr("Scanner selection failed."));
    //     finishScan();
    //     m_isSetingUp = false;
    //     return;
    // }
    // qInfo() << "Default scanner selected.";
    // emit infoAvailable(tr("Default scanner selected."));

    // Open source
    qInfo() << "Opening Scanner...";
    emit infoAvailable(tr("Opening Scanner..."));
    if (m_dsmEntry(&m_appId, nullptr, DG_CONTROL, DAT_IDENTITY, MSG_OPENDS, &m_dsId) != TWRC_SUCCESS) {
        qCritical() << "Failed to open scanner.";
        emit errorOccurred(tr("Failed to open the scanner. Please make sure the scanner is powered on and connected."));
        finishScan();
        m_isSetingUp = false;
        return;
    }
    qInfo() << "Scanner opened.";
    emit infoAvailable(tr("Scanner opened."));
    m_dsOpened = true;

    if(!m_showUI) {
        if(!prepareScanMode()) {
            finishScan();
            m_isSetingUp = false;
            return;
        }
        if(prepareDpi()) {
            qInfo().noquote() << QString("Scan resolution set to %1 DPI").arg(dpi());
            emit infoAvailable(tr("Scan resolution set to %1 DPI").arg(dpi()));
        } else {
            qWarning().noquote() << QString("Failed to set scan resolution to %1 DPI").arg(dpi());
            emit warn(tr("Failed to set scan resolution to %1 DPI").arg(dpi()));
        }
        if(prepareColorMode()) {
            qInfo().noquote() << QString("Color mode set to %1").arg(getColorModeText());
            emit infoAvailable(tr("Color mode set to %1").arg(getColorModeText()));
        } else {
            qWarning().noquote() << QString("Failed to set color mode to %1, falling back to default").arg(getColorModeText());
            emit warn(tr("Failed to set color mode to %1, falling back to default").arg(getColorModeText()));
        }
    }

    m_isSetingUp = false;
    m_cancelRequested = false;
    m_scanning = true;
    emit scanningChanged();
    emit scanStarted();

    enableScanner();
}

void TwainHandler::cancelScan()
{
    if (m_cancelRequested || !m_scanning)
        return;
    m_cancelRequested = true;
    m_canceling = true;
    emit isCancelingChanged();
    qInfo() << "Canceling scan...";
    emit warn(tr("Canceling scan..."));
}

QString TwainHandler::twainLastError() {
    if (!m_dsmEntry)
        return QString();

    TW_STATUS status{};
    ZeroMemory(&status, sizeof(status));
    // Query the status from the current Data Source
    TW_UINT16 rc = m_dsmEntry(&m_appId, &m_dsId, DG_CONTROL, DAT_STATUS, MSG_GET, &status);

    if (rc == TWRC_SUCCESS) {
        switch (status.ConditionCode) {
        case TWCC_SUCCESS:             return QString();
        case TWCC_BUMMER:              return tr("General failure");
        case TWCC_LOWMEMORY:           return tr("Low memory");
        case TWCC_NODS:                return tr("No Data Source open");
        case TWCC_MAXCONNECTIONS:      return tr("Max connections reached");
        case TWCC_OPERATIONERROR:      return tr("Operation error");
        case TWCC_BADCAP:              return tr("Bad capability");
        case TWCC_BADPROTOCOL:         return tr("Bad protocol/unknown triplet");
        case TWCC_BADVALUE:            return tr("Bad value (out of range)");
        case TWCC_SEQERROR:            return tr("Sequence error");
        case TWCC_BADDEST:             return tr("Bad destination");
        case TWCC_CAPUNSUPPORTED:      return tr("Capability unsupported");
        case TWCC_CAPBADOPERATION:     return tr("Capability bad operation");
        case TWCC_CAPSEQERROR:         return tr("Capability sequence error");
        case TWCC_DENIED:              return tr("Denied (file system protection)");
        case TWCC_FILEEXISTS:          return tr("File exists (conflict)");
        case TWCC_FILENOTFOUND:        return tr("File not found");
        case TWCC_NOTEMPTY:            return tr("Directory not empty");
        case TWCC_PAPERJAM:            return tr("Paper jam");
        case TWCC_PAPERDOUBLEFEED:     return tr("Paper double feed");
        case TWCC_FILEWRITEERROR:      return tr("File write error");
        case TWCC_CHECKDEVICEONLINE:   return tr("Device offline or not ready");
        default:
            return tr("Unknown TWAIN condition code: %1").arg(status.ConditionCode);
        }
    } else {
        qInfo() << "Failed to get TWAIN status";
    }
    return QString();
}

bool TwainHandler::refreshSourcesList()
{
    if (!m_scannerModel) return false;

    m_scannerModel->init(getAllScanners());
    return true;
}

bool TwainHandler::selectSource(const int &scannerId)
{
    if (!m_scannerModel)
        return false;
    const QList<Scanner> &list = m_scannerModel->scanners();
    if(list.isEmpty()) return false;

    if (m_dsOpened) {
        m_dsmEntry(&m_appId, nullptr,
                   DG_CONTROL, DAT_IDENTITY,
                   MSG_CLOSEDS, &m_dsId);
        m_dsOpened = false;
        ZeroMemory(&m_dsId, sizeof(m_dsId));
    }

    Scanner scanner;
    bool found = false;
    for (const Scanner &s : list) {
        if (s.id == static_cast<quint32>(scannerId)) {
            scanner = s;
            found = true;
            break;
        }
    }

    if (!found) {
        qWarning() << "Scanner id not found:" << scannerId;
        emit errorOccurred(tr("Failed to select a scanner, select manually from combobox bellow."));
        return false;
    }

    m_dsId = scannerToTwain(scanner);

    return true;
}

void TwainHandler::synchronizeScansLocation()
{
    if(!m_watcher || m_isSynchronizing) return;
    m_isSynchronizing = true;
    m_watcher->synchronizeScansLocation();
    m_isSynchronizing = false;
}

// ------------------------------------------------------------
// TWAIN internals
// ------------------------------------------------------------

void TwainHandler::createOrUpdatePdsmqConfig()
{
    QString appPath = QCoreApplication::applicationDirPath();
    QString exeName = QCoreApplication::applicationName() + ".exe";
    QString logFilePath = appPath + "/dsm.log";
    QString productName = "Qt TWAIN Application";
    int majorVersion = 1;
    int minorVersion = 0;
    int language = 0;
    int country = 0;
    QString xmlFilePath = appPath + "/PdsmqConfig.xml";

    QDomDocument doc;

    QFile file(xmlFilePath);
    if (file.exists()) {
        if (!file.open(QIODevice::ReadOnly)) {
            qWarning() << "Cannot open existing PdsmqConfig.xml";
            return;
        }
        if (!doc.setContent(&file)) {
            qWarning() << "Failed to parse existing XML file";
            file.close();
            return;
        }
        file.close();
    } else {
        // Create root
        QDomProcessingInstruction instr = doc.createProcessingInstruction("xml", "version=\"1.0\" encoding=\"utf-8\"");
        doc.appendChild(instr);

        QDomElement root = doc.createElement("PdsmqConfig");
        doc.appendChild(root);

        // DSM node
        QDomElement dsm = doc.createElement("DSM");
        root.appendChild(dsm);

        QDomElement logEnabled = doc.createElement("LogEnabled");
        logEnabled.appendChild(doc.createTextNode("true"));
        dsm.appendChild(logEnabled);

        QDomElement logFileNode = doc.createElement("LogFilePath");
        logFileNode.appendChild(doc.createTextNode(""));
        dsm.appendChild(logFileNode);

        QDomElement logLevel = doc.createElement("LogLevel");
        logLevel.appendChild(doc.createTextNode("3"));
        dsm.appendChild(logLevel);

        QDomElement useCallback = doc.createElement("UseCallback");
        useCallback.appendChild(doc.createTextNode("true"));
        dsm.appendChild(useCallback);

        // Applications node
        QDomElement apps = doc.createElement("Applications");
        root.appendChild(apps);

        QDomElement app = doc.createElement("Application");
        apps.appendChild(app);

        QDomElement exe = doc.createElement("ExeName");
        exe.appendChild(doc.createTextNode(""));
        app.appendChild(exe);

        QDomElement prod = doc.createElement("ProductName");
        prod.appendChild(doc.createTextNode(""));
        app.appendChild(prod);

        QDomElement major = doc.createElement("Major");
        major.appendChild(doc.createTextNode("0"));
        app.appendChild(major);

        QDomElement minor = doc.createElement("Minor");
        minor.appendChild(doc.createTextNode("0"));
        app.appendChild(minor);

        QDomElement lang = doc.createElement("Language");
        lang.appendChild(doc.createTextNode("0"));
        app.appendChild(lang);

        QDomElement countryNode = doc.createElement("Country");
        countryNode.appendChild(doc.createTextNode("0"));
        app.appendChild(countryNode);
    }

    // Update nodes with current data
    QDomNodeList logNodes = doc.elementsByTagName("LogFilePath");
    if (!logNodes.isEmpty()) {
        logNodes.at(0).firstChild().setNodeValue(logFilePath);
    }

    QDomNodeList exeNodes = doc.elementsByTagName("ExeName");
    if (!exeNodes.isEmpty()) {
        exeNodes.at(0).firstChild().setNodeValue(exeName);
    }

    QDomNodeList prodNodes = doc.elementsByTagName("ProductName");
    if (!prodNodes.isEmpty()) {
        prodNodes.at(0).firstChild().setNodeValue(productName);
    }

    QDomNodeList majorNodes = doc.elementsByTagName("Major");
    if (!majorNodes.isEmpty()) {
        majorNodes.at(0).firstChild().setNodeValue(QString::number(majorVersion));
    }

    QDomNodeList minorNodes = doc.elementsByTagName("Minor");
    if (!minorNodes.isEmpty()) {
        minorNodes.at(0).firstChild().setNodeValue(QString::number(minorVersion));
    }

    QDomNodeList langNodes = doc.elementsByTagName("Language");
    if (!langNodes.isEmpty()) {
        langNodes.at(0).firstChild().setNodeValue(QString::number(language));
    }

    QDomNodeList countryNodes = doc.elementsByTagName("Country");
    if (!countryNodes.isEmpty()) {
        countryNodes.at(0).firstChild().setNodeValue(QString::number(country));
    }

    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        qWarning() << "Cannot write PdsmqConfig.xml";
        return;
    }

    QTextStream out(&file);
    doc.save(out, 4);
    file.close();

    qDebug() << "PdsmqConfig.xml created/updated at" << xmlFilePath;
}

QString TwainHandler::getColorModeText()
{
    switch (m_colorMode) {
    case ColorMode::AutoDetect:    return tr("Auto Detect");
    case ColorMode::Color:         return tr("Color");
    case ColorMode::Grayscale:     return tr("Grayscale");
    case ColorMode::BlackAndWhite: return tr("Black and White");
    default:                       break;
    }
    return tr("Unknown");
}

void TwainHandler::initAppId()
{
    ZeroMemory(&m_appId, sizeof(m_appId));

    m_appId.ProtocolMajor = TWON_PROTOCOLMAJOR;
    m_appId.ProtocolMinor = TWON_PROTOCOLMINOR;
    m_appId.SupportedGroups = DG_CONTROL | DG_IMAGE;

    m_appId.Version.MajorNum = 1;
    m_appId.Version.Language = TWLG_ENGLISH;
    m_appId.Version.Country = TWCY_USA;

    strcpy_s(m_appId.Manufacturer, ORGANIZATION_NAME);
    strcpy_s(m_appId.ProductFamily, "Qt Apps");
    strcpy_s(m_appId.ProductName, ORGANIZATION_DOMAIN);
}

void TwainHandler::enableScanner() {
    qInfo() << "Enabling Scanner...";
    emit infoAvailable(tr("Enabling Scanner..."));

    ZeroMemory(&m_ui, sizeof(m_ui));
    m_ui.ShowUI  = m_showUI ? TRUE : FALSE;
    m_ui.ModalUI = TRUE;
    m_ui.hParent = getMainWindow();
    setScannerIndicator(m_showUI || (isFeederLoaded() && m_scanMode != TwainHandler::ScanMode::Flatbed));

    if (m_dsmEntry(&m_appId, &m_dsId, DG_CONTROL, DAT_USERINTERFACE, MSG_ENABLEDS, &m_ui) != TWRC_SUCCESS) {
        qCritical() << "Failed to enable scanner.";
        emit errorOccurred(tr("Failed to enable scanner."));
        finishScan();
        return;
    }
    qInfo() << "Scanner enabled.";
    emit infoAvailable(tr("Scanner enabled."));
    m_uiEnabled = true;
}

QString TwainHandler::nextFilePath()
{
    auto scan_folder = scanFolder();
    if(scan_folder.isEmpty()) return {};

    return scan_folder
           + QString("/scan_%1_%2.jpeg")
                 .arg(m_currentPage)
                 .arg(QDateTime::currentDateTime()
                          .toString("yyyyMMdd_hhmmss_zzz"));
}

void TwainHandler::setupNextFileTransfer()
{
    m_currentFilePath = nextFilePath();
    if (m_currentFilePath.isEmpty()) { processDeferredCancel(); return; }

    TW_SETUPFILEXFER fx{};
    fx.Format = TWFF_JFIF;
    QByteArray pathUtf8 = m_currentFilePath.toUtf8();
    strncpy_s(fx.FileName, sizeof(fx.FileName), pathUtf8.constData(), _TRUNCATE);
    fx.VRefNum = 0;

    TW_UINT16 rc = m_dsmEntry(&m_appId, &m_dsId, DG_CONTROL, DAT_SETUPFILEXFER, MSG_SET, &fx);
    if (rc != TWRC_SUCCESS) {
        qCritical() << "File transfer setup failed:" << twainLastError();
        emit errorOccurred(tr("File transfer setup failed."));
        processDeferredCancel();
    }
}

void TwainHandler::abortTransfers()
{
    if (!m_dsOpened)
        return;

    TW_PENDINGXFERS px{};
    ZeroMemory(&px, sizeof(px));
    m_dsmEntry(&m_appId, &m_dsId, DG_CONTROL, DAT_PENDINGXFERS, MSG_RESET, &px);
}

void TwainHandler::finishScan()
{
    cleanup();

    if(m_canceling) {
        qInfo() << "Scan canceled by user.";
        emit warn(tr("Scan canceled by user."));
    }
    m_canceling = false;
    emit isCancelingChanged();
    m_scanning = false;
    m_cancelRequested = false;
    emit scanningChanged();
    emit scanFinished();
}

void TwainHandler::disableScanner()
{
    if (m_uiEnabled) {
        m_dsmEntry(&m_appId, &m_dsId,
                   DG_CONTROL, DAT_USERINTERFACE,
                   MSG_DISABLEDS, &m_ui);
        m_uiEnabled = false;
    }
}

void TwainHandler::closeScanner()
{
    if (m_dsOpened) {
        m_dsmEntry(&m_appId, nullptr,
                   DG_CONTROL, DAT_IDENTITY,
                   MSG_CLOSEDS, &m_dsId);
        m_dsOpened = false;
        ZeroMemory(&m_dsId, sizeof(m_dsId));
    }
}

void TwainHandler::cleanup()
{
    disableScanner();
    closeScanner();

    if (m_dsmOpen) {
        m_dsmEntry(&m_appId, nullptr,
                   DG_CONTROL, DAT_PARENT,
                   MSG_CLOSEDSM, nullptr);
        m_dsmOpen = false;
        emit dsmClosed();
    }
}

#endif

bool TwainHandler::isCanceling() const
{
    return m_canceling;
}

QString TwainHandler::scansLocation() const
{
    QDir dir(m_scansLocation + QString("/%1").arg(APP_NAME));
    if(dir.exists())
        return m_scansLocation + QString("/%1").arg(APP_NAME);
    else
        return m_scansLocation;
}

void TwainHandler::setScansLocation(const QString &newScansLocation)
{
    if (m_scansLocation == newScansLocation)
        return;
    m_scansLocation = newScansLocation;
    emit scansLocationChanged();
}

bool TwainHandler::hasSources() const
{
    return m_scannerModel && !m_scannerModel->scanners().isEmpty();
}

QStringList TwainHandler::scanFiles() const
{
    return m_scanFiles;
}

void TwainHandler::setScanFiles(const QStringList &newScanFiles)
{
    if (m_scanFiles == newScanFiles)
        return;
    m_scanFiles = newScanFiles;
    emit scanFilesChanged();
}

TwainHandler::ScanMode TwainHandler::scanMode() const
{
    return m_scanMode;
}

void TwainHandler::setScanMode(const ScanMode &newScanMode)
{
    if (m_scanMode == newScanMode)
        return;
    m_scanMode = newScanMode;
    emit scanModeChanged();
}

bool TwainHandler::event(QEvent *event)
{   
    if (event->type() == PostEventType::TransferReady) {
        processNextTransfer();
        return true;
    }
    if (event->type() == PostEventType::CancelScan) {
        processDeferredCancel();
        return true;
    }
    if (event->type() == PostEventType::FinishScan) {
        finishScan();
        return true;
    }
    if (event->type() == PostEventType::DeviceEvent) {
        handleDeviceEvent();
        return true;
    }

    return QObject::event(event);
}

quint16 TwainHandler::dpi() const
{
    return m_dpi;
}

void TwainHandler::setDpi(quint16 newDpi)
{
    if (m_dpi == newDpi)
        return;
    m_dpi = newDpi;
    emit dpiChanged();
}

TwainHandler::ColorMode TwainHandler::colorMode() const
{
    return m_colorMode;
}

void TwainHandler::setColorMode(const ColorMode &newColorMode)
{
    if (m_colorMode == newColorMode)
        return;
    m_colorMode = newColorMode;
    emit colorModeChanged();
}
