## script for Google Cloud Logging Sink

### Features

* Automatically creates or updates existing sinks
* Supports Cloud Storage and BigQuery destinations
* Handles partitioned tables for BigQuery destinations

### Prerequisites

IAM permissions must be granted **before** running this script using `iam-binding/add-iam-binding.awk`.

#### Cloud Storage destination

Grant permissions to the custom service account specified in `service-account:`.

**iam-binding/bindings.txt:**

```
service_account:my-logging-sa
roles/storage.objectCreator
```

#### BigQuery destination

GCP automatically assigns `service-{PROJECT_NUMBER}@gcp-sa-logging.iam.gserviceaccount.com` as the writer identity.
Grant permissions to this service agent.

**iam-binding/bindings.txt:**

> **Note**: `add-iam-binding.awk` grants at project level (all datasets). Dataset-level grants are not yet supported.

```
gcp-sa-logging
roles/bigquery.dataEditor
```

### Usage

```
awk -v project_id=<..> -f sink-creator.awk sink.txt
```

### sink.txt format

 * 1 sink : described as multilines separated by blank line
 * sink configuration : YAML-like tagged ( separator is `: ` not `:` )
 * destination supports Cloud Storage buckets and BigQuery datasets
 * use PROJECT_ID placeholder in destination for dynamic project substitution
 * `gcloud` options are written **without** the `--` prefix — the script prepends `--` automatically

### Configuration fields

* `name`: (required) Sink name
* `destination`: (required) Log destination
  * `bigquery.googleapis.com/projects/:PROJECT_ID/datasets/your_dataset_name`
  * `storage.googleapis.com/your_bucket_name`
  * `:PROJECT_ID` is replaced with the `project_id` variable at runtime
* `service-account`: (optional) Service account to use as the sink's writer identity
  * Required for Cloud Storage and other non-BigQuery destinations
  * Omit for BigQuery destinations — GCP assigns the logging service agent automatically
  * Short form: `my-logging-sa` → resolved to `serviceAccount:my-logging-sa@PROJECT_ID.iam.gserviceaccount.com`
  * Full form: `my-logging-sa@example.iam.gserviceaccount.com` → `serviceAccount:` prefix is added
* `log-filter`: (optional) Filter expression for logs to forward
* `use-partitioned-tables`: (optional) Set to `true` to use partitioned tables for BigQuery destinations
* Other `gcloud logging sinks create` options can be added the same way (without `--` prefix)

### example

#### Cloud Storage destination

```
name: audit-logs-sink
destination: storage.googleapis.com/:PROJECT_ID-audit-logs
service-account: my-logging-sa
log-filter: protoPayload.serviceName="cloudaudit.googleapis.com"
```

#### BigQuery destination

```
name: app-logs-sink
destination: bigquery.googleapis.com/projects/:PROJECT_ID/datasets/app_logs
log-filter: resource.type="gce_instance"
use-partitioned-tables: true
```

#### Multiple sinks example

```
name: error-logs-sink
destination: storage.googleapis.com/:PROJECT_ID-error-logs
service-account: my-logging-sa
log-filter: severity>=ERROR

name: security-logs-sink
destination: bigquery.googleapis.com/projects/:PROJECT_ID/datasets/security_logs
log-filter: protoPayload.serviceName="cloudaudit.googleapis.com" AND protoPayload.methodName!="storage.objects.get"
use-partitioned-tables: true
```

### Notes

* `service-account` is optional. Omit it for BigQuery destinations — GCP automatically assigns the logging service agent. Required for Cloud Storage and other destinations.
* The caller must have `iam.serviceAccounts.actAs` permission on the specified service account (required when `--custom-writer-identity` is used).
* **Pub/Sub destinations**: Sinks are created but write permissions (`roles/pubsub.publisher`) are not automatically granted.
* **No delete support**: Removing a sink definition from the config file does not delete it from GCP. Delete manually with `gcloud logging sinks delete`.
