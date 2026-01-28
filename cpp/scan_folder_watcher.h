#ifndef SCAN_FOLDER_WATCHER_H
#define SCAN_FOLDER_WATCHER_H

#include <QObject>
#include <QFileSystemWatcher>
#include <QDir>
#include <qqmlintegration.h>

class ScanFolderWatcher : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("ScanFolderWatcher is exposed via TwainHandler")
public:
    explicit ScanFolderWatcher(QObject *parent = nullptr);
    void watchFolder(const QString &path);
    void synchronizeScansLocation();

signals:
    void fileRemoved(const QString &filePath);
    void fileAdded(const QString &filePath);

private slots:
    void onDirectoryChanged(const QString &path);

private:
    QFileSystemWatcher m_watcher;
    QSet<QString> m_knownFiles;

};


#endif // SCAN_FOLDER_WATCHER_H
