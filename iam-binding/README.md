## script for Google Cloud IAM & Admin

### Usage

```
awk -v project_id=<..> -v project_number=<..> -f add-iam-binding.awk bindings.txt
```

### bindings.txt format

 * 1 binding : described as multilines separated by blank line
 * member and roles are listed raw string
 * app engine service account and cloud build service account should be abbreviated only in domain part

### example

```
appspot.gserviceaccount.com
roles/storage.objectAdmin
roles/secretmanager.secretAccessor
roles/cloudsql.admin
```

or 

```
user:foobar@example.com
roles/storage.objectAdmin
roles/editor
```
