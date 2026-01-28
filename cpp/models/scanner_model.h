#ifndef SCANNER_MODEL_H
#define SCANNER_MODEL_H

#include <QAbstractListModel>
#include <qqmlintegration.h>
#include <QList>

struct Scanner
{
    Scanner() = default;
    quint32   id = -1;
    QString   productName;
    QString   manufacturer;
    QString   productFamily;
    quint16   protocolMajor = 0;
    quint16   protocolMinor = 0;
    quint32   supportedGroups = 0;
    QString   versionInfo;
    inline bool isValid() const { return id > -1; }
    inline bool operator==(const Scanner &other) const { return id == other.id; }
};

class ScannerModel : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("ScannerModel is exposed via TwainHandler")
public:
    explicit ScannerModel(QObject *parent = nullptr);
    ~ScannerModel();

    enum RoleNames {
        idRole = Qt::UserRole + 1,
        productNameRole,
        manufacturerRole,
        productFamilyRole,
        protocolMajorRole,
        protocolMinorRole,
        supportedGroupsRole,
        versionInfoRole
    };

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    virtual QHash<int, QByteArray> roleNames() const Q_DECL_OVERRIDE;

    Q_INVOKABLE QVariant getData(const int &row, const QString &roleName) const;
    void init(const QList<Scanner> &scanners);
    bool addScanner(const Scanner &scanner);
    bool removeScanner(const Scanner &scanner);
    QList<Scanner> scanners() const;

signals:
    void scannersChanged();


private:
    QList<Scanner> *m_scanners;

};

#endif // SCANNER_MODEL_H
