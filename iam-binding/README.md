## script for Google Cloud IAM & Admin

### Usage

```
awk -v project_id=<..> -v project_number=<..> -f add-iam-binding.awk bindings.txt
```

### bindings.txt format

 * 1 binding : described as multilines separated by blank line
 * member and roles are listed raw string
 * some service accounts are expended to a canonical address complemented by the project id

#### account (project-level IAM)

```
appspot.gserviceaccount.com
roles/storage.objectAdmin
roles/secretmanager.secretAccessor
roles/cloudsql.admin
```

or

```
gcp-sa-artifactregistry
roles/storage.objectViewer
```

or

```
user:foobar@example.com
roles/storage.objectAdmin
roles/editor
```

#### run_service (Cloud Run service-level IAM)

Use `run_service:<service-name>` as the first line, followed by gcloud flags and roles.
`--region` is required.

```
run_service:my-service --region asia-northeast1 --member allUsers
roles/run.invoker
```

To add IAM binding without overwriting existing conditional bindings, append `--condition=None`:

```
run_service:my-service --region asia-northeast1 --member allUsers --condition=None
roles/run.invoker
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
