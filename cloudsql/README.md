## script for Cloud SQL

### Usage

```
awk -f instance-creator.awk instances.txt
awk -f database-creator.awk databases.txt
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

 * databases.txt
```
name: database
instance: instance-name
charset: UTF8
```
