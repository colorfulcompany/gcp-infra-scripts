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
