#! /usr/bin/awk -f

#
# Usage:
# awk -f instance-creator.awk instances.txt
#

BEGIN {
  gcloud_cmd = "gcloud sql instances"
  true = 1
  false = 0

  read_instances(instances)

  # change to multiline mode
  RS = ""
}

# 
# main
# 
{
  split_to_assoc($0, instance)
  if (!find_resource(instance["name"], instances)) {
    print "cloud sql instance not exist. creat cloud sql instance..."
    create_instance(instance)
  } else {
    print "cloud sql instance already exists!"
  }
}

#
# response format
#  $ gcloud sql instances list
#  NAME           DATABASE_VERSION  LOCATION           TIER         PRIMARY_ADDRESS  PRIVATE_ADDRESS  STATUS
#  instance-name  POSTGRES_12       asia-northeast1-a  db-f1-micro  xx.xx.xx.xx      -                RUNNABLE
#
# => [instance-name,...]
#
# [param] Array instances
#
function read_instances(instances, i) {
  header = true
  i = 0
  
  cmd = gcloud_cmd " list"
  while ((cmd | getline line) > 0) {
    if (header) {
      header = false
      continue
    }

    $0 = line
    instances[i] = $1

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
# [param] String records
#
#
function split_to_lines(records, lines) {
  return split(records, lines, /\n/)
}

# 
# [param] String resource
# [param] Array resources
# [return] Boolean
# 
function find_resource(resource, resources) {
  for (i in resources) {
    if (resources[i] == resource) {
      return true
    }
  }
  return false
}

# 
# [param] Array instance
# 
function create_instance(instance, cmd) {
  cmd = gcloud_cmd " create "

  system(cmd instance["name"] options(instance))
}

#
# [param] Associative Array bucket
# [return] String
#
function options(instance) {
  opts = ""

  for (key in instance) {
    if (key != "name") {
      opts = opts " --" key "=" instance[key]
    }
  }

  return opts
}
