## script for Google Cloud Scheduler

### Usage

```
awk -f scheduler.awk schedules.txt
```

### schedules.txt format

 * 1 job : desribed as multilines separated by blank line
 * job flag : YAML-like tagged ( separator is `: ` not `:` )

### example

```
id: daily-batch-job
type: pubsub
topic: batch-topic
schedule: every day 18:00
time-zone: Asia/Tokyo
message-body: {}
```

### Known issues

#### Changing `http-method` of an existing job is not applied

For an existing job, this script runs `gcloud beta scheduler jobs update`.
Changing `http-method` in `schedules.txt` has no effect on an existing job:
the command succeeds, but the HTTP method stays the same.

This appears to be a gcloud bug. Calling the Cloud Scheduler API directly
changes the method as expected. Confirmed with Google Cloud SDK 534.0.0
and 591.0.0 (as of 2026-10-30). It may be fixed in a later version.

To change the HTTP method, delete the job and run this script again.
The script creates the job again with the new method.
