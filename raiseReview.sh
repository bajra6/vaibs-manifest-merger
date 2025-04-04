#!/bin/bash
# raiseReview.sh

codeline="$1"
bug_numbers="$2"
directory_names="$3"
directory_versions="$4"
view_name="$5"

echo "========================================================================================================="

echo "Tadaa inside raiseReview.sh"

echo "Codeline: $codeline"
echo "Bug numbers: $bug_numbers"
echo "Directory names: $directory_names"
echo "Directory versions: $directory_versions"
echo "View name: $view_name"
echo "========================================================================================================="

# Step 1: Process bug numbers
IFS=',' read -ra bugs <<< "$bug_numbers"

# 1.a: Pick the first bug number and begin the transaction
first_bug="${bugs[0]}"
echo "Running command - ade begintrans -bug $first_bug -no_restore"
ade begintrans -bug "$first_bug" -no_restore

# 1.b: Process the rest of the bug numbers
for ((i=1; i<${#bugs[@]}; i++)); do
    echo "Running command - ade settransproperty -p BUG_NUM -v ${bugs[$i]}"
    ade settransproperty -p BUG_NUM -v "${bugs[$i]}"
done

# Step 2: Process directory names and versions (same as before)
IFS=',' read -ra dirs <<< "$directory_names"
IFS=',' read -ra version_pairs <<< "$directory_versions"

declare -A versions_map

for pair in "${version_pairs[@]}"; do
  IFS='=' read -ra parts <<< "$pair"
  versions_map["${parts[0]}"]="${parts[1]}"
done

for dir in "${dirs[@]}"; do
    filepath="hcm/vbs/${dir}_manifest.json"
    ade co -nc "$filepath"

    # Step 3: Update version if necessary (same as before)
    if [[ -f "$filepath" ]]; then
        current_version=$(jq -r '.version' "$filepath")
        new_version="${versions_map[$dir]}"

        if [[ "$current_version" != "$new_version" ]]; then
            jq ".version = \"$new_version\"" "$filepath" > temp.json && mv temp.json "$filepath"
            echo "Updated $filepath version from $current_version to $new_version"
        else
            echo "$filepath version is already $new_version"
        fi
    else
        echo "Error: $filepath does not exist."
    fi
done

echo "========================================================================================================="
echo "All necessary changes to manifest files are done! Now we check in all files, save transaction and raise orareview"
echo "========================================================================================================="


# Step 4: Check in and save transaction
echo "Running command - ade ci -all"
ade ci -all
echo "Running command - ade savetrans"
ade savetrans

# Step 5: Prepare and raise ORAREVIEW
ORAREVIEW_DESCRIPTION="
##! PLEASE PROVIDE REVIEW MESSAGE BELOW
manifest merge from manifest bot

##! PLEASE PROVIDE TRANSACTION DESCRIPTION BELOW
transaction contains latest manifest versions"

echo "$ORAREVIEW_DESCRIPTION" > /tmp/bot_orareview.txt

echo "Running command - orareview -u -r vkaimal,assingsi -H /tmp/bot_orareview.txt"
orareview -u -r vkaimal,assingsi -H /tmp/bot_orareview.txt

# Clean up temporary file
rm /tmp/bot_orareview.txt



echo "========================================================================================================="
echo "Raise ORAREVIEW script complete"
echo "========================================================================================================="

# to test: bash raiseReview.sh bronze 123,456,789 oracle_hcm_documentrecordsUI,oracle_hcm_workforcedirectorypublicUI 101,102 viewname