#! /usr/bin/awk -f

#
# Usage: awk -f enabler.awk services.txt
#

{
  if ( $0 !~ /^#/ && $0 !~ /^[ 　]*$/ ) {
    cmd = "gcloud services enable " $1
    print cmd
    if (system(cmd)) { # exit status of system 0 : sucess, 1 : failure
      print "failed that enable service " $1
      exit 1
    }
  }
}
