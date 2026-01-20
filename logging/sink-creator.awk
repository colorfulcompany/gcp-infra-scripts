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
  read_sinks(sinks)

  RS = ""
}

#
# main
#
{
  split_to_assoc($0, sink)
  state = sinks[sink["name"]]

  if (length(state) > 0) {
    update_sink(sink)
  } else {
    create_sink(sink)
  }
}

#
# print usage message
#
function usage() {
  print "Usage:"
  print "awk -v project_id=<..> -f sink-creator.awk sink.txt"
}

#
# ID   ....  STATE
# sink1      ENABLED
# sink2      PAUSE
#
# -> { sink2: "ENABLED", sink2: "PAUSE" }
#
# [param] Associative Array sinks
#
function read_sinks(sinks) {
  header = true

  cmd = gcloud_cmd " list"
  while ((cmd | getline line) > 0) {
    if (header) {
      header = false
      continue
    }

    $0 = line
    # ID = STATE
    sinks[$1] = $NF

    line_num++
  }
}

function create_sink(sink) {
  print gcloud_cmd " create " sink["name"] " " destination(sink) " " build_options(sink) " " use_partitioned_tables(sink)
  system(gcloud_cmd " create " sink["name"] " " destination(sink) " " build_options(sink) " " use_partitioned_tables(sink))
  grant_service_account_to_write(sink)
}

function update_sink(sink) {
  print gcloud_cmd " update " sink["name"] " " destination(sink) " " build_options(sink) " " use_partitioned_tables(sink)
  system(gcloud_cmd " update " sink["name"] " " destination(sink) " " build_options(sink)) " " use_partitioned_tables(sink)
  grant_service_account_to_write(sink)
}

function grant_service_account_to_write(sink) {
  if (role_for_destination(sink)) {
    writer = writer_identity(sink)
    print "Assign " role_for_destination(sink) " to " writer
    system("gcloud projects add-iam-policy-binding " project_id " --member=" writer " --role=" role_for_destination(sink))
  }
}

function writer_identity(sink) {
  (gcloud_cmd " describe " sink["name"] " --format='value(writerIdentity)'") | getline writer
  return writer
}

function role_for_destination(sink) {
  if (destination(sink) ~ /^storage.googleapis.com\/.+$/) {
    return "roles/storage.objectCreator"
  } else if (destination(sink) ~ /^bigquery.googleapis.com\/.+$/) {
    return "roles/bigquery.dataEditor"
  } else {
    return false
  }
}

function destination(sink) {
  sub(":PROJECT_ID", project_id, sink["destination"])
  return sink["destination"]
}

function use_partitioned_tables(sink) {
  if (sink["use-partitioned-tables"] == "true") {
    return "--use-partitioned-tables"
  }
}

#
# sink の内容を gcloud コマンドの option で表現するために文字列に
# 組み立てて返す
#
# [param] Accociative Array sink
# [return] String
#
function build_options(sink) {
  opts = ""

  for (key in sink) {
    if (key != "name" && key != "destination" && key != "use-partitioned-tables") {
      if (sink[key] == true || sink[key] == false) {
        opts = opts " --" key
      } else {
        opts = opts " --" key "='" sink[key] "'"
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
