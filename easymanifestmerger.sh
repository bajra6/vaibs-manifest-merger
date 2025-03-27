#!/bin/bash
# easymanifestmerger.sh

#important steps before running the sh script
chmod +x easymanifestmerger.sh raiseReview.sh cleanAndRefreshView.sh runPMC.sh
# jq needs to be preinstalled (its a command line json parser). jq is usually available in the system, so no worries :D
# Set BUGDB_USERID and BUGDB_PASSWORD in bashrc. For example, run ```nano ~/.bashrc``` then add ```export VARIABLE_NAME="value"``` inside it. finally, run ```source ~/.bashrc``` to apply your changes
# make sure you've filled all required fields in the bug db to prevent bug validation failure

clean_csv() {
  local input="$1"
  local trimmed=$(echo "$input" | sed 's/^\s*//; s/\s*$//; s/\s*,\s*/,/g')
  echo "$trimmed"
}

echo "========================================================================================================="
echo "THE SUPER AWESOME MANIFEST MERGER! all thanks to good @vaibs"
echo "========================================================================================================="

# 1. Ask for the codeline
read -p "Enter the codeline (FUSIONAPPS_PT.V2MIBHCMBRONZE_LINUX.X64 for bronze, FUSIONAPPS_PT.V2MIBHCMSILVER_LINUX.X64 for silver, etc): " codeline

# 2. Get bug numbers as comma-separated values (and trim spaces)
read -p "Enter bug numbers (comma-separated): " bug_numbers
bug_numbers_var=$(clean_csv "$bug_numbers")
IFS=',' read -r -a bugs <<< "$bug_numbers_var"

# 3. Get directory names as comma-separated values (and trim spaces)
read -p "Enter directory names (comma-separated): " directory_names
directory_names_var=$(clean_csv "$directory_names")
IFS=',' read -r -a dirs <<< "$directory_names_var"

# 4. For each directory, request a manifest version value
declare -A directory_versions  # Associative array to store directory-version pairs
for dir in "${dirs[@]}"; do
    read -p "Enter manifest version for $dir: " version
    directory_versions["$dir"]="$version"
done


# Store data into variables
view_name="manifest_bot_view"
codeline_var="$codeline"
bug_numbers_var="$(IFS=','; echo "${bugs[*]}")"
directory_names_var="$(IFS=','; echo "${dirs[*]}")"
directory_versions_var=""
for dir in "${!directory_versions[@]}"; do
  directory_versions_var+="$dir=${directory_versions[$dir]},"
done
directory_versions_var="${directory_versions_var%,}" # Remove trailing comma
view_name_var="$view_name"



# Print stored variables
echo "========================================================================================================="
echo "Codeline: $codeline_var"
echo "Bug numbers: $bug_numbers_var"
echo "Directory names: $directory_names_var"
echo "Directory versions: $directory_versions_var"
echo "View name: $view_name_var"
echo "========================================================================================================="

# Pass data to raiseReview.sh
# ade useview manifest_bot_view -exec "bash /home/vaibs/'gemini bot'/raiseReview.sh $codeline_var $bug_numbers_var $directory_names_var $directory_versions_var $view_name_var"

echo "========================================================================================================="
echo "Running command - ade destroyview manifest_bot_view -no_ask -force"
ade destroyview manifest_bot_view -no_ask -force
echo "Running command - ade createview manifest_bot_view -latest -series $codeline"
ade createview manifest_bot_view -latest -series "$codeline"
echo "========================================================================================================="


echo "========================================================================================================="
echo "We are now starting the ORAREVIEW PROCESS"
echo "========================================================================================================="

if ade useview manifest_bot_view -exec "bash /home/vaibs/'gemini bot'/raiseReview.sh $codeline_var $bug_numbers_var $directory_names_var $directory_versions_var $view_name_var"; then
  # clean and refresh view
  ade useview manifest_bot_view -exec "bash /home/vaibs/'gemini bot'/cleanAndRefreshView.sh"

  # Pick the first bug number to pass to PMC
  IFS=',' read -ra bugs <<< "$bug_numbers_var"
  first_bug="${bugs[0]}"

  # run pmc
  ade useview manifest_bot_view -exec "bash /home/vaibs/'gemini bot'/runPMC.sh $first_bug $directory_names_var"

  echo "========================================================================================================="
  echo "The scripts have all run. Kindly check once if everything is in place. If everything seems alright and all approvals are done, go ahead with your merge. May your day be filled with happy @vaibs"
  echo "========================================================================================================="

  echo "Running command - ade useview manifest_bot_view"
  ade useview manifest_bot_view

else
  echo "Raising orareview failed. Please check logs"
fi
