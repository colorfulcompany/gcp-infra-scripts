#! /usr/bin/awk -f

#
# Usage:
# awk -v project_id=<> -f table-creator.awk tables.txt
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

  # change to multiline mode
  RS = ""
}

#
# main
#
{
  split_to_assoc($0, dataset)
  if (!find_dataset(dataset["name"])) {
    print "dataset " dataset["name"] " not exist"
    create_dataset(dataset)
  } else {
    print "A dataset " dataset["name"] " is already exist. Nothing to do."
  }
}

#
# print usage message
#
function usage() {
  print "Usage:"
  print "awk -v project_id=<..> -f dataset-creator.awk datasets.txt"
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
function read_datasets(datasets,      i, dataset) {
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
function dataset_name(name) {
  return project_id ":" name
}

#
# [param] Associative Array dataset
#
function create_dataset(dataset) {
  system("bq" location_option(dataset) " mk --dataset" options(dataset) " " dataset_name(dataset["name"]))
}

#
# [param] Associative Array dataset
# [return] String
#
function location_option(dataset) {
  location = ""
  for(key in dataset) {
    if (key == "location") {
      location = " --" key "=" dataset[key]
    }
  }
  return location
}

#
# [param] Associative Array dataset
# [return] String
#
function options(dataset) {
  opts = ""

  for (key in dataset) {
    if (key != "name" && key != "location") {
      opts = opts " --" key " " dataset[key]
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
