## Google Cloud Service Enabler

### Usage

```
awk -f enabler.awk services.txt
```

### services.txt format

 * 1 line : 1 service URL
 * ignore comment line ( The first character of line is `#` )
 * ignore blank line
 * ignore inline comment

### example

```
cloudbuild.googleapis.com
bigquery.googleapis.com
pubsub.googleapis.com
cloudscheduler.googleapis.com
appengine.googleapis.com
```
