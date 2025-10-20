#! /usr/bin/awk -f

#
# Usage:
#
# awk [-v region=$REGION] -f scheduler.awk schedules.txt
#
# If the App Engine region is already set, it will be used as the default
# and the list can be retrieved without explicitly specifying the region.
# Otherwise, the region must be explicitly specified.
#

BEGIN {
  true = 1
  false = 0
  gcloud_cmd = "gcloud beta scheduler jobs"
  read_jobs(jobs, region)

  RS = ""
}

#
# main
#
{
  split_to_assoc($0, job)
  deployed_state = jobs[job["id"],"state"]
  deployed_region = jobs[job["id"],"location"]

  if (job["location"] && (job["location"] != region)) {
    msg = "Job \"" job["id"] "\" has different region " "\"" job["location"] "\""
    if (region) {
      msg = msg " ( than \"" region "\" )"
    }
    msg = msg ". Skipped."
    print msg
    next
  }

  if (length(deployed_state) > 0) {
    if (deployed_state == "ENABLED") {
      update_job(job, region)
    } else {
      # job's state must be ENABLED for update
      print "Job \"" job["id"] "\" exists, but not ENABLED. Nothing to do."
    }
  } else {
    create_job(job, region)
  }
}

#
# ID   LOCATION        ....  STATE
# job1 us-central1           ENABLED
# job2 asia-northeast1       PAUSE
#
# -> [job1, state] = "ENABLED"
#    [job2, state] = "PAUSE"
#    [job1, location] = "us-central1"
#    [job2, location] = "asia-northeast1"
#
# [param] Associative Array jobs
#
function read_jobs(jobs, region) {
  header = true

  cmd = gcloud_cmd " list"
  if (region) { cmd = cmd " --location " region }

  while ((cmd | getline line) > 0) {
    if (header) {
      header = false
      continue
    }

    $0 = line
    jobs[$1,"location"] = $2
    jobs[$1,"state"] = $NF

    line_num++
  }
}

function create_job(job) {
  print gcloud_cmd " create " job["type"] " " job["id"] build_options(job)
  system(gcloud_cmd " create " job["type"] " " job["id"] build_options(job))
}

function update_job(job) {
  print gcloud_cmd " update " job["type"] " " job["id"] build_options(job)
  system(gcloud_cmd " update " job["type"] " " job["id"] build_options(job))
}

#
# schedule の内容を gcloud コマンドの option で表現するために文字列に
# 組み立てて返す
#
# [param] Accociative Array job
# [return] String
#
function build_options(job) {
  opts = ""

  for (key in job) {
    if (key != "id" && key != "type") {
      opts = opts " --" key "='" job[key] "'"
    }
  }

  return opts
}

#
# [param] String record
# [param] Array lines
# [return] Number
#
function split_to_lines(record, lines) {
  num = split(record, lines, /\n/)

  return num
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
function split_to_assoc(record, assoc,    lines, capture) {
  split(record, lines, /\n/)

  split("", assoc)
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
# [param] Associcative Array assoc
#
function dump_assoc(assoc) {
  for (key in assoc) {
    print key ": " assoc[key]
  }
}
