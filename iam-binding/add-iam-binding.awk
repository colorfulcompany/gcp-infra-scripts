#! /usr/bin/awk -f

#
# Usage:
#   awk -v project_id=PROJECT_ID -v project_number=PROJECT_NUMBER \
#     -f add-iam-binding.awk iam-bindings.txt
#
# require project_number for automatically complement fully qualified account address
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
  role_size = split_to_assoc($0, binding)
  options_by_roles(binding, role_size, options)

  for (i in options) {
    cmd = gcloud_cmd " " project_id options[i] " > /dev/null"
    print cmd
    failure = system(cmd)
    if (failure) exit 1
  }

  cmd = "gcloud projects get-iam-policy " project_id
  print cmd
  system(cmd)
}

#
# [param] Associative Array binding
# [param] Integer role_size
# [param] Associative Array options
# [return] void
#
function options_by_roles(binding, role_size, options,      member) {
  member = ""
  split("", options)

  for (i = 0; i < role_size; i++) {
    options[i] = " --member " account(binding["member"]) " --role " binding["role", i]
  }
}

#
# [param] String line
# [return] Boolean
#
function is_account_line(line) {
  return (line ~ /^account:/) || (line !~ /^roles\//)
}

#
# support account types:
#
#  * human users
#  * default service accounts
#  * service agents
#  * legacy cloud build service account
#  * custom service accounts
#
# (account:)?compute\.gserviceaccount\.com -> serviceAccount:xxxx-computer@developer.gserviceaccount.com
# (account:)?service_account:builder -> serviceAccount:builder@${project_number}.iam.gserviceaccount.com
#
#
# [param] String name
# [return] String
#
function account(name,    tmp) {
  if (is_cloudbuild_account(name)) {
    return "serviceAccount:" cloudbuild_account()
  } else if (is_appengine_account(name)) {
    return "serviceAccount:" appengine_account()
  } else if (is_computeengine_account(name)) {
    return "serviceAccount:" computeengine_account()
  } else if (is_service_agent(name)) {
    return "serviceAccount:" service_agent(name)
  } else if (is_custom_service_account(name)) {
    return "serviceAccount:" custom_service_account(trim_resource_type(name))
  } else if (is_account_line(name)) {
    return trim_resource_type(name)
  } else {
    return name
  }
}

#
# [param] String resource
# [return] String
#
function trim_resource_type(resource,     tmp) {
  if (/^(user|group|serviceAccount):/) {
    return resource
  } else if (/^[^:]+:/) {
    tmp = resource
    sub(/^[^:]+:/, "", tmp)
    return tmp
  } else {
    return resource
  }
}

#
# [param] String name
# [return] String
#
function custom_service_account(name,     trimmed_name) {
  trimmed_name = name
  sub(/^service_account:/, "", trimmed_name)

  return trimmed_name "@" project_id ".iam.gserviceaccount.com"
}

#
# [param] String name
# [return] Boolean
#
function is_custom_service_account(name) {
  return name ~ /^(account:)?service_account:[^@]+$/
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
  return name ~ /^(account:)?cloudbuild\.gserviceaccount\.com$/
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
  return name ~ /^(account:)?compute\.gserviceaccount\.com$/
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
  return name ~ /^(account:)?appspot\.gserviceaccount\.com$/
}

#
# [param] String name
# [return] String
#
function service_agent(name) {
  return "service-" project_number "@" name ".iam.gserviceaccount.com"
}

#
# [param] String name
# [return] Boolean
#
function is_service_agent(name) {
  return name ~ /^(account:)?gcp-sa-[^.]+/
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
# {
#   member: xxx,
#   role0: yyy,
#   role1: zzz
# }
#
# [param] String
# [param] Array
# [return] Number
#
function split_to_assoc(record, assoc,    lines, roles) {
  split_to_lines(record, lines)

  split("", assoc)
  split("", roles)
  size = 0

  for (key in lines) {
    line = lines[key]
    if (line == "") continue

    if (line ~ /^roles\//) {
      roles[size] = line
      size++
    } else if (is_account_line(line)) {
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
