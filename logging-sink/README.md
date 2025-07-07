## script for Google Cloud Logging Sink

### Features

* Automatically creates or updates existing sinks
* Grants appropriate IAM permissions to sink service accounts
* Supports both Cloud Storage and BigQuery destinations
* Handles partitioned tables for BigQuery destinations

### Usage

```
awk -v project_id=<..> -f create.awk sink.txt
```

### sink.txt format

 * 1 sink : described as multilines separated by blank line
 * sink configuration : YAML-like tagged ( separator is `: ` not `:` )
 * destination supports Cloud Storage buckets and BigQuery datasets
 * use PROJECT_ID placeholder in destination for dynamic project substitution

### example

#### Cloud Storage destination

```
name: audit-logs-sink
destination: storage.googleapis.com/PROJECT_ID-audit-logs
log-filter: protoPayload.serviceName="cloudaudit.googleapis.com"
```

#### BigQuery destination

```
name: app-logs-sink
destination: bigquery.googleapis.com/projects/PROJECT_ID/datasets/app_logs
log-filter: resource.type="gce_instance"
use-partitioned-tables: true
```

#### Multiple sinks example

```
name: error-logs-sink
destination: storage.googleapis.com/PROJECT_ID-error-logs
log-filter: severity>=ERROR

name: security-logs-sink
destination: bigquery.googleapis.com/projects/PROJECT_ID/datasets/security_logs
log-filter: protoPayload.serviceName="cloudaudit.googleapis.com" AND protoPayload.methodName!="storage.objects.get"
use-partitioned-tables: true
```
