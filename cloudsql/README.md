## script for Cloud SQL

### Usage

```
awk -f instance-creator.awk instances.txt
awk -f database-creator.awk databases.txt
```

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
