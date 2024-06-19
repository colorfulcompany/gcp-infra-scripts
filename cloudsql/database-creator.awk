#! /usr/bin/awk -f

#
# Usage:
# awk -v <project_id=PROJECT_ID> -f database-creator.awk databases.txt
#
function usage() {
  print "Usage:"
  print "awk -v <project_id=PROJECT_ID> -f database-creator.awk databases.txt"
}

BEGIN {
  if (!project_id) {
    print "project_id not given"
    usage()
    exit 1
  }

  gcloud_cmd = "gcloud sql"
  true = 1
  false = 0

  read_instances(instances)
  read_databases(databases)

  # change to multiline mode
  RS = ""
}

# 
# main
# 
{
  split_to_assoc($0, database)

  if (instance_exists(databases, database["instance"])) {
    split(databases[database["instance"]], resources)
    if (!find_resource(database["name"], resources)) {
      print "cloud sql database not exist. creat cloud sql database..."
      create_database(database)
    } else {
      print "cloud sql database already exists!"
    }
  } else {
    print "[ERROR] instance " database["instance"] " is not exists! Please create instance."
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
  
  cmd = gcloud_cmd " instances list"
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
# response format
#  $ gcloud sql databases list --instance=instance-name
#  NAME           CHARSET  COLLATION
#  database-name  UTF8     en_US.UTF8
#
# => {instance-name: "database database" ,...]}
#  => awk に多次元配列がないのでデータベースはスペース区切りの文字列で保持
# 
# [param] Array databases
#
function read_databases(databases, i, database, header, cmd) {
  for(j in instances) {
    i = 0
    database = ""
    header = true
    cmd = gcloud_cmd " databases list --instance=" instances[j]

    while ((cmd | getline line) > 0) {
      if (header) {
        header = false
        continue
      }

      $0 = line
      database = database " " $1

      i++
    }
    databases[instances[j]] = database
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

function create_database(database, cmd) {
  cmd = gcloud_cmd " databases create "

  system(cmd database["name"] options(database))
}

#
# [param] Associative Array bucket
# [return] String
#
function options(database) {
  opts = ""

  for (key in database) {
    if (key != "name") {
      opts = opts " --" key "=" database[key]
    }
  }

  return opts
}

# 
# [param] Hash databases
# [param] String instance
# [return] Boolean
# 
function instance_exists(databases, instance) {
  ret = false

  for (key in databases) {
    if (key == instance) {
      ret = true
      break
    }
  }
  return ret
}
