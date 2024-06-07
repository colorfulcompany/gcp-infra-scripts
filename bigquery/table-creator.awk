#! /usr/bin/awk -f

#
# Usage:
# awk -v project_id=<> -f table-creator.awk tables.txt schema.json schema.json ...
#
BEGIN {
  if (!project_id) {
    print "project_id not given"
    usage()
    exit 1
  }

  true = 1
  false = 0

  read_datasets(datasets)
  read_tables(tables)
  store_schema_files()

  # change to multiline mode
  RS = ""
}

function store_schema_files(      i, filename, copied) {
  if (ARGC > 2) {
    for (i = 0; i + 2 < ARGC; i++) {
      filename = ARGV[i+2]
      copied = substr(filename, 0, length(filename))
      sub(/\.[a-z]+$/, "", copied)
      schema_files[copied] = filename
    }
    ARGC = 2
  }
}

#
# main
#
{
  split_to_assoc($0, table)

  if (dataset_exists(tables, table["dataset"])) {
    split(tables[table["dataset"]], resources)
    if (!find_resource(table["name"], resources)) {
      print "bigquery table " table["name"] " not exist. creat bigquery table " table["name"] " ..."
      create_table(table)
    } else {
      print "bigquery table " table["name"] " already exists!"
    }
    if (schema_files[table["name"]]) {
      update_schema(table, schema_files[table["name"]])
    }
  } else {
    print "[ERROR] dataset " table["dataset"] " is not exists! Please create dataset."
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
# response format
#  $ bq ls
#   datasetId
# --------------
#  dataset_name
#
# [param] Array datasets
#
function read_datasets(datasets, i, dataset) {
  header = true
  sepalator = true
  i = 0

  while ("bq ls" | getline dataset) {
    if (header) {
      header = false
      continue
    } else if (sepalator) {
      sepalator = false
      continue
    }
    gsub(" ", "", dataset)
    datasets[i] = dataset
    i++
  }
}

#
# response format
#  $ bq ls datasetName
#          tableId            Type    Labels   Time Partitioning   Clustered Fields  
# -------------------------- ------- -------- ------------------- ------------------ 
# table-name                  TABLE  
#
# => {dataset-name: ["table table" ,...]}
#  => awk に多次元配列がないのでデータベースはスペース区切りの文字列で保持
#
# [param] Array instances
#
function read_tables(tables, i, table, header, sepalator, cmd) {
  for(j in datasets) {
    i = 0
    table = ""
    header = true
    sepalator = true
    cmd = "bq ls " datasets[j]

    while ((cmd | getline line) > 0) {
      if (header) {
        header = false
        continue
      } else if (sepalator) {
        sepalator = false
        continue
      }

      $0 = line
      table = table " " $1

      i++
    }
    tables[datasets[j]] = table
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
function find_dataset(name) {
  exist = false

  for (i in datasets) {
    if (name == datasets[i]) {
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
function table_name(table) {
  return project_id ":" table["dataset"] "." table["name"]
}

#
# [param] Associative Array table
# [return] String
#
function schema_file(table) {
  return "./cloudbuild/bigquery/schema/" table["schema"]
}

#
# [param] String key
# [return] Boolean
#
function is_bq_cmd_option(key) {
  return key != "name" && key != "dataset" && key != "schema"
}

#
# [param] Associative Array dataset
# [return] String
#
function options(table) {
  opts = ""

  for (key in table) {
    if (is_bq_cmd_option(key)) {
      opts = opts " --" key " " table[key]
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

#
# [param] Associative Array table
#
function create_table(table,     cmd) {
  cmd = "bq mk --table" 

  system(cmd options(table) " " table_name(table))
}

#
# [param] Associative Array table
# [param] String filename
#
function update_schema(table, filename,     exit_status) {
  exit_status = system("bq update " table_name(table) " " filename)
  if (!exit_status) {
    print "    schema updated."
  }
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
# [param] Hash tables
# [param] String dataset
# [return] Boolean
# 
function dataset_exists(tables, dataset) {
  ret = false

  for (key in tables) {
    if (key == dataset) {
      ret = true
      break
    }
  }
  return ret
}
