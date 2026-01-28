#include "scan_folder_watcher.h"

ScanFolderWatcher::ScanFolderWatcher(QObject *parent)
    : QObject(parent)
{
    QObject::connect(&m_watcher, &QFileSystemWatcher::directoryChanged,
            this, &ScanFolderWatcher::onDirectoryChanged);
}

void ScanFolderWatcher::watchFolder(const QString &path)
{
    if(!m_watcher.directories().isEmpty())
        m_watcher.removePaths(m_watcher.directories());
    m_watcher.addPath(path);

    QDir dir(path);
    const QFileInfoList files = dir.entryInfoList(
        QDir::Files | QDir::NoDotAndDotDot);

    m_knownFiles.clear();
    for (const QFileInfo &fi : files)
        m_knownFiles.insert(fi.absoluteFilePath());
}

void ScanFolderWatcher::synchronizeScansLocation()
{
    foreach (const QString &file, m_knownFiles) {
        emit fileAdded(file);
    }
}

void ScanFolderWatcher::onDirectoryChanged(const QString &path)
{
    QDir dir(path);
    const QFileInfoList files = dir.entryInfoList(
        QDir::Files | QDir::NoDotAndDotDot);

    QSet<QString> currentFiles;
    for (const QFileInfo &fi : files)
        currentFiles.insert(fi.absoluteFilePath());

    // Removed files
    for (const QString &file : std::as_const(m_knownFiles)) {
        if (!currentFiles.contains(file)) {
            emit fileRemoved(file);
        }
    }

    // Added files
    for (const QString &file : std::as_const(currentFiles)) {
        if (!m_knownFiles.contains(file)) {
            emit fileAdded(file);
        }
    }

    m_knownFiles = currentFiles;
}
