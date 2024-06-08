## script for Cloud SQL

### Usage

```
awk -v project_id=$PROJECT_ID -f instance-creator.awk instances.txt
awk -v project_id=$PROJECT_ID -f database-creator.awk databases.txt
```

### 注意

 * 変更には非対応
 * インスタンス作成後にはデータベース接続情報のアプリケーションへの反映が必要
    * 例えば App Engine に環境変数で渡す場合にはアプリケーションの再デプロイを行う必要がある

### databases.txt format

 * 1 database : desribed as multilines separated by blank line
 * job flag : YAML-like tagged ( separator is `: ` not `:` )

### example

 * instances.txt
```
name: sql-instance
version: POSTGRES_12
tier: db-f1-micro
region: us-central1
```

see [gcloud sql instances create  \|  Google Cloud CLI Documentation](https://cloud.google.com/sdk/gcloud/reference/sql/instances/create)

 * databases.txt
```
name: database
instance: instance-name
charset: UTF8
collation: ja-JP-x-icu
```

see [gcloud sql databases create  \|  Google Cloud CLI Documentation](https://cloud.google.com/sdk/gcloud/reference/sql/databases/create)

eg)

 * [PostgreSQL: Documentation: 16: 24\.2\. Collation Support](https://www.postgresql.org/docs/current/collation.html)

try

```
$ psql -c "select collname, collcollate, collctype from pg_collation where collname LIKE 'ja%' postgres"
```
