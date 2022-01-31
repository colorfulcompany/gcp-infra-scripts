#! /usr/bin/awk -f

BEGIN {
  if (!project_id) {
    print "project_id not given"
    usage()
    exit 1
  }

  true = 1
  false = 0
  gcloud_cmd = "gcloud logging sinks"
  read_jobs(jobs)

  RS = ""
}

#
# main
#
{
  split_to_assoc($0, job)
  state = jobs[job["name"]]

  if (length(state) > 0) {
    update_job(job)
  } else {
    create_job(job)
  }
}

#
# print usage message
#
function usage() {
  print "Usage:"
  print "awk -v project_id=<..> -f create.awk sink.txt"
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
  print gcloud_cmd " create " job["name"] " " destination(job) " " build_options(job) " " use_partitioned_tables(job)
  system(gcloud_cmd " create " job["name"] " " destination(job) " " build_options(job) " " use_partitioned_tables(job))
  grant_service_account_to_write(job)
}

function update_job(job) {
  print gcloud_cmd " update " job["name"] " " destination(job) " " build_options(job) " " use_partitioned_tables(job)
  system(gcloud_cmd " update " job["name"] " " destination(job) " " build_options(job)) " " use_partitioned_tables(job)
  grant_service_account_to_write(job)
}

function grant_service_account_to_write(job) {
  if (role_for_destination(job)) {
    writer = writer_identity(job)
    print "Assign " role_for_destination(job) " to " writer
    system("gcloud projects add-iam-policy-binding " project_id " --member=" writer " --role=" role_for_destination(job))
  }
}

function writer_identity(job) {
  (gcloud_cmd " describe " job["name"] " --format='value(writerIdentity)'") | getline writer
  return writer
}

function role_for_destination(job) {
  if (destination(job) ~ /^storage.googleapis.com\/.+$/) {
    return "roles/storage.objectCreator"
  } else if (destination(job) ~ /^bigquery.googleapis.com\/.+$/) {
    return "roles/bigquery.dataEditor"
  } else {
    return false
  }
}

function destination(job) {
  sub(":PROJECT_ID", project_id, job["destination"])
  return job["destination"]
}

function use_partitioned_tables(job) {
  if (job["use-partitioned-tables"] == "true") {
    return "--use-partitioned-tables"
  }
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
    if (key != "name" && key != "destination" && key != "use-partitioned-tables") {
      if (job[key] == true || job[key] == false) {
        opts = opts " --" key
      } else {
        opts = opts " --" key "='" job[key] "'"
      }
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
