#!/bin/bash

bug="$1"
repositories="$2"

BASE_DIR=$(dirname $(realpath $0))

echo "========================================================================================================="
echo "Now we begin the Pre-Merge Checker. Pray god (if you believe in one) that this doesn't fail, it'd be a hassle to run it again."
echo "========================================================================================================="

# Echo the argument
echo "The provided variable is: $bug"

echo "Running command - $HCMDEV_ROOT/bin/pmc_wrapper -d fusion/fusion@bomvm41.bomsubnet1.fusionappsdbom1.oraclevcn.com:1597/ems9175_FDB -DupdateBug=Y -bugid $bug"
$HCMDEV_ROOT/bin/pmc_wrapper -d fusion/fusion@bomvm41.bomsubnet1.fusionappsdbom1.oraclevcn.com:1597/ems9175_FDB -DupdateBug=Y -bugid "$bug"


echo "========================================================================================================="
echo "Now we are going to generate VBSBundle and validate extenstion explicitly beacause IDK why (prolly something faild in PMC)"


echo "Running command - ade expand com/deploy"
ade expand com/deploy
echo "Running command - ade expand build_metadata/buildLogs"
ade expand build_metadata/buildLogs
echo "Running command - ant generateVBSBundle >freVbsDelivery.log"
ant generateVBSBundle >freVbsDelivery.log


#  set BUGDB_USERID and BUGDB_PASSWORD in your own shell 
#  sample command: export BUGDB_USERID="xxxxxxxx"
echo "Running command to upload VBS Bundle directly to bug (Please have your BUGDB_USERID and BUGDB_PASSWORD variables set already or else this step will fail"
echo "Running command - $HCMDEV_ROOT/bin/update_bugdb -u $BUGDB_USERID -p $BUGDB_PASSWORD -b $bug -f build_metadata/buildLogs/freVbsDelivery.log"

$HCMDEV_ROOT/bin/update_bugdb -u "$BUGDB_USERID" -p "$BUGDB_PASSWORD" -b "$bug" -f build_metadata/buildLogs/freVbsDelivery.log


echo "Running command to run valExtD for manifests and uploading them directly to bug"

if [ -n "$repositories" ]; then
  IFS=',' read -ra REPOS <<< "$repositories"
  for repo in "${REPOS[@]}"; do
    repo_output="/tmp/validationExtenstion_${repo}_output.log"
    echo "Running command - sh $BASE_DIR/valExtD.sh -e $repo > $repo_output 2>&1"
    sh $BASE_DIR/valExtD.sh -e "$repo" > "$repo_output" 2>&1
    echo "Running command - $HCMDEV_ROOT/bin/update_bugdb -u $BUGDB_USERID -p $BUGDB_PASSWORD -b $bug -f $repo_output"
    $HCMDEV_ROOT/bin/update_bugdb -u "$BUGDB_USERID" -p "$BUGDB_PASSWORD" -b "$bug" -f "$repo_output"
  done
fi


echo "Raising Merge Request"
echo "Running command - mergereq -y -m vkaimal"
mergereq -y -m vkaimal

