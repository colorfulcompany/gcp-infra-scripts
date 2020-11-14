## script for Google Cloud Storage

### Usage

```
awk -v project_id=<..> -f bucket-creator.awk buckets.txt
```

### buckets.txt format

 * 1 bucket : desribed as multilines separated by blank line
 * job flag : YAML-like tagged ( separator is `: ` not `:` )

### example

```
name: foobarbox
class: regional
bucket-level: on
location: us-central1
```
