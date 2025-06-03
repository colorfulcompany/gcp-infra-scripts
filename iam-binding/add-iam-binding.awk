#! /usr/bin/awk -f

#
# Usage:
#
function usage() {
  print "Usage:"
  print "awk -v project_id=PROJECT_ID -v project_number=PROJECT_NUMBER -f add-iam-binding.awk bindings.txt"
}

BEGIN {
  if (!project_id || !project_number) {
    print "project_id and/or project_number missing !!"
    usage()
    exit 1
  }

  true = 1
  false = 0
  gcloud_cmd = "gcloud projects add-iam-policy-binding"
  
  # multiline mode
  RS = ""
}

#
# main
#
{
  split_to_assoc($0, binding)
  cmd = gcloud_cmd " " project_id options(binding)
  print cmd
  system(cmd)
}

#
# [param] Associative Array binding
# [return] String
#
function options(binding) {
  opts = ""
  
  for (key in binding) {
    if (key == "member") {
      opts = opts " --member " account(binding[key])
    } else if (key ~ /^role/) {
      opts = opts " --role " binding[key]
    }
  }

  return opts
}

#
# [param] String name
# [return] String
#
function account(name) {
  if (is_cloudbuild_account(name)) {
    return "serviceAccount:" cloudbuild_account()
  } else if (is_appengine_account(name)) {
    return "serviceAccount:" appengine_account()
  } else if (is_computeengine_account(name)) {
    return "serviceAccount:" computeengine_account()
  } else {
    return name
  }
}

#
# [return] String
#
function cloudbuild_account() {
  return project_number "@cloudbuild.gserviceaccount.com"
}

#
# [param] String name
# [return] Boolean
#
function is_cloudbuild_account(name) {
  return name == "cloudbuild.gserviceaccount.com"
}

#
# [return] String
#
function computeengine_account() {
  return project_number "-compute@developer.gserviceaccount.com"
}

#
# [param] String name
# [return] Boolean
#
function is_computeengine_account(name) {
  return name == "compute.gserviceaccount.com"
}

#
# [param] String id
# [return] String
#
function appengine_account() {
  return project_id "@appspot.gserviceaccount.com"
}

#
# [param] String name
# [return] String
#
function is_appengine_account(name) {
  return name == "appspot.gserviceaccount.com"
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
  role_size = 0
  for (key in lines) {
    line = lines[key]
    if (line == "") continue

    if (line ~ /^roles\//) {
      roles[role_size] = line
      role_size++
    } else {
      member = line
    }
  }
  assoc["member"] = member
  for (i in roles) {
    assoc["role", i] = roles[i]
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
# [param] Associative Array assoc
#
function dump_assoc(assoc) {
  for (key in assoc) {
    if (key ~ SUBSEP) {
      split(key, cap, SUBSEP)
      print cap[1] ": " assoc[key]
    } else {
      print key ": " assoc[key]
    }
  }
}
