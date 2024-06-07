## script for BigQuery

### ■ Usage

 1. Create Dataset
```
awk -v project_id=<..> -f dataset-creator.awk datasets.txt
```

 2. Create Table ( and update schema optionally )
```
awk -v project_id=<..> -f table-creator.awk tables.txt [schema.json [schema.json] ...]
```

※ Dataset と Table について、変更や削除には対応していない（作成のみ）

### ■ datasets.txt format

 * 1 dataset : desribed as multilines separated by blank line
 * job flag : YAML-like tagged ( separator is `: ` not `:` )
 * required keys
    * `name`
    * `location`
 * optional ...  
    `https://cloud.google.com/bigquery/docs/datasets?hl=ja#create-dataset`

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
    `https://cloud.google.com/bigquery/docs/tables?hl=ja#creating_an_empty_table_with_a_schema_definition`

#### example

```
name: foobar_table
dataset: foobar_dataset
expiration: 3600
```

### schema.json

see [Specifying a schema  \|  BigQuery  \|  Google Cloud](https://cloud.google.com/bigquery/docs/schemas)
