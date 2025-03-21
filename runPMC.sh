#!/bin/bash

bug="$1"
repositories="$2"

# Echo the argument
echo "The provided variable is: $bug"

$HCMDEV_ROOT/bin/pmc_wrapper -d fusion/fusion@bomvm41.bomsubnet1.fusionappsdbom1.oraclevcn.com:1597/ems9175_FDB -DupdateBug=Y -bugid "$bug"

ade expand com/deploy
ade expand build_metadata/buildLogs
ant generateVBSBundle >freVbsDelivery.log


#  set BUGDB_USERID and BUGDB_PASSWORD in your own shell 
#  sample command: export BUGDB_USERID="xxxxxxxx"

$HCMDEV_ROOT/bin/update_bugdb -u "$BUGDB_USERID" -p "$BUGDB_PASSWORD" -b "$bug" -f build_metadata/buildLogs/freVbsDelivery.log

if [ -n "$repositories" ]; then
  IFS=',' read -ra REPOS <<< "$repositories"
  for repo in "${REPOS[@]}"; do
    repo_output="/tmp/${repo}_output.log"
    sh /home/vaibs/valExtD.sh -e "$repo" > "$repo_output" 2>&1
    $HCMDEV_ROOT/bin/update_bugdb -u "$BUGDB_USERID" -p "$BUGDB_PASSWORD" -b "$bug" -f "$repo_output"
  done
fi

echo \"yes\" | mergereq -y;

