## script for BigQuery

### ■ Usage

### 1. Create Dataset
```
awk -v project_id=<..> -f dataset-creator.awk datasets.txt
```

Dataset については変更・削除に対応していない（作成のみ）


### 2. Create Table ( and update schema optionally )
```
awk -v project_id=<..> -f table-creator.awk tables.txt [<schema>.json [<schema>.json] ...]
```

\<schema\>.json は tables.txt 内のテーブル名 ( `name: `  )に一致する名前のファイルが該当 table に対して適用される。

schema ファイルの内容が実際の table の schema 定義に対して以下の操作に該当すれば適用される。[^1]

 * カラム追加（新規作成時はすべてこれに該当）
 * REQUIRED → NULLABLE への変更（制限の緩和）

CI/CD 上でくり返し実行した際に上記操作に合致している限りは「変更」として適用できる。

※ 上記に該当しない場合はエラーになるのでエラーを取り除く必要がある。

[^1]: 実体は `bq update` なのでその制限に従う see https://docs.cloud.google.com/bigquery/docs/reference/bq-cli-reference#bq_update

### ■ datasets.txt format

 * 1 dataset : desribed as multilines separated by blank line
 * job flag : YAML-like tagged ( separator is `: ` not `:` )
 * required keys
    * `name`
    * `location`
 * optional ...
     https://cloud.google.com/bigquery/docs/datasets#create-dataset

#### example

```
name: foobar_dataset
location: us-central1
default_table_expiration: 3600
```


### ■ tables.txt format

 * 1 table : desribed as multilines separated by blank line
 * job flag : YAML-like tagged ( separator is `: ` not `:` )
 * required keys
    * `name`
    * `dataset`
 * optional ...
    https://cloud.google.com/bigquery/docs/tables#creating_an_empty_table_with_a_schema_definition

#### example

```
name: foobar_table
dataset: foobar_dataset
expiration: 3600
```

### schema.json

see [Specifying a schema  \|  BigQuery  \|  Google Cloud](https://cloud.google.com/bigquery/docs/schemas)
