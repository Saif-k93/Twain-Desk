#include "scanner_model.h"

ScannerModel::ScannerModel(QObject *parent)
    : QAbstractListModel(parent),
    m_scanners(new QList<Scanner>)
{

}

ScannerModel::~ScannerModel()
{
    if(m_scanners) {
        m_scanners->clear();
        delete m_scanners;
        m_scanners = nullptr;
    }
}

int ScannerModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid())
        return 0;

    return m_scanners->size();
}

QVariant ScannerModel::data(const QModelIndex &index, int role) const
{
    if (!m_scanners || !index.isValid() || index.row() < 0 || index.row() >= m_scanners->size())
        return QVariant();

    const auto &scanner = m_scanners->at(index.row());
    switch (role) {
    case idRole:              return QVariant::fromValue(scanner.id);
    case productNameRole:     return QVariant::fromValue(scanner.productName);
    case manufacturerRole:    return QVariant::fromValue(scanner.manufacturer);
    case productFamilyRole:   return QVariant::fromValue(scanner.productFamily);
    case protocolMajorRole:   return QVariant::fromValue(scanner.protocolMajor);
    case protocolMinorRole:   return QVariant::fromValue(scanner.protocolMinor);
    case supportedGroupsRole: return QVariant::fromValue(scanner.supportedGroups);
    case versionInfoRole:     return QVariant::fromValue(scanner.versionInfo);
    default: break;
    }

    return QVariant();
}

void ScannerModel::init(const QList<Scanner> &scanners)
{
    beginResetModel();
    if(m_scanners) {
        m_scanners->clear();
        delete m_scanners;
        m_scanners = nullptr;
    }
    m_scanners = new QList<Scanner>(scanners);
    endResetModel();
    emit scannersChanged();
}

bool ScannerModel::addScanner(const Scanner &scanner)
{
    if(!scanner.isValid() || m_scanners->contains(scanner)) return false;

    beginInsertRows(QModelIndex(), rowCount(), rowCount());
    m_scanners->append(scanner);
    endInsertRows();
    emit scannersChanged();
    return true;
}

bool ScannerModel::removeScanner(const Scanner &scanner)
{
    if (!scanner.isValid()) return false;
    auto index = m_scanners->indexOf(scanner);
    if(index == -1) return false;

    beginRemoveRows(QModelIndex(), index, index);
    m_scanners->removeAt(index);
    endRemoveRows();
    emit scannersChanged();
    return true;
}

QList<Scanner> ScannerModel::scanners() const
{
    return *m_scanners;
}


QHash<int, QByteArray> ScannerModel::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles[idRole]              = "id";
    roles[productNameRole]     = "productName";
    roles[manufacturerRole]    = "manufacturer";
    roles[productFamilyRole]   = "productFamily";
    roles[protocolMajorRole]   = "protocolMajor";
    roles[protocolMinorRole]   = "protocolMinor";
    roles[supportedGroupsRole] = "supportedGroups";
    roles[versionInfoRole]     = "versionInfo";
    return roles;
}

QVariant ScannerModel::getData(const int &row, const QString &roleName) const
{
    auto role = roleName.trimmed();
    if(!m_scanners || row < 0 || row >= m_scanners->size() || role.isEmpty())
        return QVariant();

    const auto &scanner = m_scanners->at(row);
    if(role == "id") return QVariant::fromValue(scanner.id);
    if(role == "productName") return QVariant::fromValue(scanner.productName);
    if(role == "manufacturer") return QVariant::fromValue(scanner.manufacturer);
    if(role == "productFamily") return QVariant::fromValue(scanner.productFamily);
    if(role == "protocolMajor") return QVariant::fromValue(scanner.protocolMajor);
    if(role == "protocolMinor") return QVariant::fromValue(scanner.protocolMinor);
    if(role == "supportedGroups") return QVariant::fromValue(scanner.supportedGroups);
    if(role == "versionInfo") return QVariant::fromValue(scanner.versionInfo);
    return QVariant();

}
