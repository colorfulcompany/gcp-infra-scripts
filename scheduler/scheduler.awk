#! /usr/bin/awk -f

#
# Usage:
#
# awk -f scheduler.awk schedules.txt
#

BEGIN {
  true = 1
  false = 0
  gcloud_cmd = "gcloud beta scheduler jobs"
  read_jobs(jobs)

  RS = ""
}

#
# main
#
{
  split_to_assoc($0, job)
  state = jobs[job["id"]]

  if (length(state) > 0) {
    if (state == "ENABLED") {
      update_job(job)
    } else {
      # job は ENABLED でないと update できない
      print "Job \"" job["id"] "\" exists, but not ENABLED. Nothing to do."
    }
  } else {
    create_job(job)
  }
}

#
# ID   ....  STATE
# job1       ENABLED
# job2       PAUSE
#
# -> { job2: "ENABLED", job2: "PAUSE" }
#
# [param] Associative Array jobs
#
function read_jobs(jobs) {
  header = true

  cmd = gcloud_cmd " list"
  while ((cmd | getline line) > 0) {
    if (header) {
      header = false
      continue
    }

    $0 = line
    # ID = STATE
    jobs[$1] = $NF

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
function split_to_assoc(record, assoc) {
  split(record, lines, /\n/)
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
