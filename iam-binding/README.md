## script for Google Cloud IAM & Admin

### Usage

```
awk -v project_id=<..> -v project_number=<..> -f add-iam-binding.awk bindings.txt
```

### bindings.txt format

 * 1 binding : described as multilines separated by blank line
 * member and roles are listed raw string
 * some service accounts are expended to a canonical address complemented by the project id

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

### special service accounts

 * cloudbuild.gserviceaccount.com
     * Legacy CloudBuild Service Account
     * -> \<project number\>@cloudbuild.gserviceaccount.com
 * appspot.gserviceaccount.com
     * App Engine Default Service Account
	 * -> \<project number\>@appspot.gserviceaccount.com
 * compute.gserviceaccount.com
     * Compute Engine Default Service Account
     * -> \<project number\>-compute@developer.gserviceaccount.com
