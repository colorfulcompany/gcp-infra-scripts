#! /usr/bin/awk -f

#
# Usage:
# awk -v project_id=<> f bucket-creator.awk buckets.txt
#

BEGIN {
  if (!project_id) {
    print "project_id not given"
    usage()
    exit 1
  }
  
  true = 1
  false = 0

  read_buckets(buckets)

  # change to multiline mode
  RS = ""
}

#
# main
#
{
  split_to_assoc($0, bucket)
  if (!find_bucket(bucket["name"])) {
    print "bucket not exist"
    create_bucket(bucket)
  } else {
    print "A bucket " bucket["name"] " is already exist. Nothing to do."
  }
}

#
# print usage message
#
function usage() {
  print "Usage:"
  print "awk -v project_id=<..> -f bucket-creator.awk buckets.txt"
}

#
# [param] Array buckets
#
function read_buckets(buckets,      i, bucket) {
  i = 0
  while ("gsutil ls" | getline bucket) {
    buckets[i] = bucket
    i++
  }
}

#
# 複数行のレコードを key-value に変換する
#
# RS = "" のおかげで複数行が1つのレコードになるので、
# 改行で split
# tag で split
# して assoc array に変換する必要あり
# 終端の空行はレコードに含まれてしまうので trim している
#
# [param] String
# [param] Array
# [return] Number
#
function split_to_assoc(record, assoc) {
  split_to_lines(record, lines)
  size = 0
  for (key in lines) {
    line = lines[key]
    if (line != "") {
      split(line, capture, ": ")
      assoc[capture[1]] = capture[2]
      size++
    }
  }

  return size
}

#
# [param] String name
# [return] Boolean
#
function find_bucket(name) {
  exist = false

  for (i in buckets) {
    if (bucket_name(name) == buckets[i]) {
      exist = true
      break
    }
  }

  return exist
}
    
#
# [param] String name
# [return] String
#
function bucket_name(name) {
  return "gs://" project_id "-" name "/"
}

#
# [param] Associative Array bucket
#
function create_bucket(bucket) {
  system("gsutil mb " bucket_name(bucket["name"]) options(bucket))
}

#
# [param] Associative Array bucket
# [return] String
#
function options(bucket) {
  opts = ""

  for (key in bucket) {
    if (key != "name") {
      opts = opts " -" substr(key, 1, 1) " " bucket[key]
    }
  }

  return opts
}

#
# [param] String records
#
#
function split_to_lines(records, lines) {
  return split(records, lines, /\n/)
}

#
# [param] Associative Array assoc
#
function dump_assoc(assoc) {
  for (key in assoc) {
    print key ": " assoc[key]
  }
}
