#!/bin/sh

############################################
# @author:Aminur
# v4 Included SCM and CRM in supported pillars. 
# v3 include major/minor version of dependency too
# 2024-04-17
############################################


usage() { printInfo "Usage: $0 [-e <string>] [-v <version of extension if not in ade_view>] [true if you want to skip checking static-stage]" 1>&2; exit 1; }

printError(){
	printf '\e[1;31m%s\n\e[m' "FAILURE: $1"
}
printWarning(){
	printf '\e[1;33m%s\n\e[m' "$1"
}

printInfo(){
	printf '\e[1;34m%s\n\e[m' "$1"
}

printFine(){
	printf '\e[1;32m%s\n\e[m' "$1"
}
version_for_extension_in_context=""

readVersionFromADE(){
	extension_name_l=$1
	isDependency=$2
	pillar='hcm'
	if [[ "$extension_name_l" == "oracle_scm"* ]]; then
 		pillar='scm'
	fi
	if [[ "$extension_name_l" == "oracle_cx"* ]]; then
 		pillar='crm'
	fi
	manifest_file_l="${ADE_PRODUCT_ROOT}/${pillar}/vbs/${extension_name_l}_manifest.json"
  	if [[ ! -f  "${manifest_file_l}" ]]; then
		error_l="${manifest_file_l} does not exist."
	  	if [[ $isDependency = "true"  ]]; then
		 	error_l="[DEPENDENCY]: $error_l"
	  	fi
		printError "$error_l"
	  	exit 0;
  	else
		using_ade="true"
		manifest_file_content=$(< $manifest_file_l)
		#printInfo "$manifest_file_content"
		if [[ $manifest_file_content =~ :([^\"]+)?(\"([^\"]+)\") ]]; then
            space_check=${BASH_REMATCH[2]}
            actual_version=${BASH_REMATCH[3]}
            #echo "space_check: $space_check"
            #echo "actual_version: $actual_version"
   
            if [[ $space_check =~ \"([[:space:]]+[^\"]+|[^\"]+[[:space:]]+)\"  ]]; then
			   error_l="Version: ${BASH_REMATCH[1]} for extension, ${extension_name_l} cannot have space"
               printError "$error_l"
			   exit 0;
            else
               version_for_extension_in_context=$actual_version
            fi
		else
			error_l="Unable to recognise manifest version from ${manifest_file_content}"
            printError "$error_l"
		    exit 0;    
        fi
		#version_for_extension_in_context=($(grep "\"version\"" ${manifest_file_l} |  cut -d':' -f 2 | cut -d'"' -f 2))
	fi
  	if [[ -z "${version_for_extension_in_context}" ]]; then
		error_l="Can not read version in file : ${version_for_extension_in_context}"
	  	if [[ $isDependency = "true"  ]]; then
		 	error_l="[DEPENDENCY]: $error_l"
	  	fi
		printError "$error_l"
  	else
		info_l="Version ${version_for_extension_in_context} found in file: ${manifest_file_l}"
		if [[ $isDependency = "true"  ]]; then
		 	info_l="[DEPENDENCY]: $info_l"
	  	fi
		printInfo "$info_l"
 	fi
}

while getopts ":e:v:" o; do
    case "${o}" in
        e)
            extension_name=${OPTARG}
            ;;
        v)
            version=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done

shift $((OPTIND-1))

if [ -z "${extension_name}" ]; then
	printError  "Please Provide the extension name."
    usage
fi
# Use version if specified. Else use version from ADE
if [[ -z "${version}" ]]; then
	if [[ -z "${ADE_PRODUCT_ROOT}" ]]; then
		printError "No version provided and not in ade view either."
	  	usage
  	else
		readVersionFromADE $extension_name
		version=$version_for_extension_in_context
  	fi
else
	printf '\e[1;34m%s\n\e[m' "version = ${version}"
	printf '\e[1;34m%s\n\e[m' "extension_name = ${extension_name}"
fi
fre="https://fre.appoci.oraclecorp.com/mockcdn/cdn/fa"
static="https://static-stage.oracle.com/cdn/fa"
objectstorage="https://static-dev.oracle.com/cdn/fa"
PROXY_SERVER="www-proxy-ash7.us.oracle.com:80"
skipStage=$1
servers=($fre)
if [[ $skipStage != "true"  ]]; then
	servers+=($static)
else
	printInfo "Will skip check on static-stage"
fi
python_version=""
if [[ "$(python3 -V  2>&1)" == "Python 3"* ]]; then
  python_version=3
elif [[ "$(python2 -V  2>&1)" == "Python 2"* ]]; then
   python_version=2
else
   echo ""
   printWarning "Python (either python3 or python2 is not installed on machine.). Following checks won't be made:"
   printWarning "Dependencies check"
   printWarning "Only fixed set of files will be checked. Kindly validate manually if all required files available at $fre/$currentExtensionName/$currentVersion/extension-digest, is available on static-stage as well."
   echo ""
fi

readBuildFile(){
	currentExtensionName=$1
	currentVersion=$2
	buildFileUrl="$fre/$currentExtensionName/$currentVersion/build-info.json";
	#printInfo "Build file url:$buildFileUrl"
	buildFileContent=$(curl -sS --noproxy '*' $buildFileUrl)

	if [ -z "$buildFileContent" ]; then
		error_message="Can't read build info at : $buildFileUrl"
		issues+=("\"$error_message\"")
	else
		if [ "$python_version"  = 3 ] ; then
                        #echo "$manifest_fileContent"
                        filePaths=($(echo $buildFileContent | \
                                     python3 -c "import sys, json; data=json.load(sys.stdin)['resources'];print(list(filter(lambda d: d.startswith('extension-digest/') or d.startswith('bundles/') , data)));" | tr -d '[],'))
                        ojHcmOverridden=($(echo $buildFileContent | \
                                     python3 -c "import sys, json; data=json.load(sys.stdin)['requirePaths'];print('oj-hcm/' in data['oj-hcm']);" | tr -d '[],'))
                        #echo "$ojHcmOverridden"
		elif [ "$python_version"  = 2 ] ; then
                        #echo "python_version $python_version"
                        filePaths=($(echo $buildFileContent | \
                                     python -c "import sys, json; data=json.load(sys.stdin)['resources'];print([str(r) for r in list(filter(lambda d: d.startswith('extension-digest/') or d.startswith('bundles/') , data))]);" | tr -d '[],'))
                        ojHcmOverridden=($(echo $buildFileContent | \
                                     python -c "import sys, json; data=json.load(sys.stdin)['requirePaths'];print('oj-hcm/' in data['oj-hcm']);" | tr -d '[],'))
                        #echo "$ojHcmOverridden"
		fi
                filePaths=(${filePaths[@]//\'/})
                filePaths+=('build-info.json')
                filePaths+=('manifest.json')
	fi
}

ojHcmOverridden="False"
filePaths=("manifest.json" "build-info.json" "bundles/base-config-bundle.js" "bundles/base-config-bundle.js.map" "extension-digest/app-ui-info.json"  "extension-digest/build-info.json"  "extension-digest/package-info.json"  "extension-digest/requirejs-info.json")
readBuildFile $extension_name $version

#First read manifest version. Then proceed.
manifestFileName="manifest.json"

#sed '/dependencies/,/]/!d;//d'
#sed s/"\"dependencies\""//  |sed 's/[^:]*://'
#python3 -c "import sys, json; print(json.load(sys.stdin)[0]['id'])")
dependencies_of_current_context=()
readManifest(){
	currentExtensionName=$1
	currentVersion=$2
	manifestFileURL=$fre/$currentExtensionName/$currentVersion/$manifestFileName;
	#printInfo "Manifest file url:$manifestFileURL"
	manifest_fileContent=$(curl -sS --noproxy '*' $manifestFileURL)
	#echo "$manifest_fileContent"
	if [ -n "$manifest_fileContent" ]; then
		#printInfo "Loading json"
		if [ "$python_version"  = 3 ] ; then
			dependencies_of_current_context=($(echo $manifest_fileContent | \
					python3 -c "import sys, json; data=json.load(sys.stdin).get('dependencies',[]);print(list(map(lambda n: n['id']+':'+n['version'],data)));" | tr -d '[],'))
		elif [ "$python_version"  = 2 ] ; then
			dependencies_of_current_context=($(echo $manifest_fileContent | \
					python -c "import sys, json; data=json.load(sys.stdin).get('dependencies',[]);print([str(r) for r in list(map(lambda n: n['id']+':'+n['version'],data))]);" | tr -d '[],'))
		fi
	fi

}


IFS=""
issues=()
completed_ext=()
treePath=$extension_name

validate(){
	extension_name_l=$1
	version_l_v=$2
	isDependency=$3
	if [[ $isDependency = "true"  ]]; then
		readBuildFile $extension_name_l $version_l_v
	fi 
	#For later use when we go check cyclic dependency
	if [[ " ${completed_ext[*]} " =~ "\"${extension_name_l}\"" ]]; then
	    printError "There exist a cyclic or repeat dependency for ${extension_name_l}"
		exit 0;
	fi
        if [[ $ojHcmOverridden = "True" ]]; then
            error_message="oj-hcm version overridden in this extension version"
            issues+=("\"$error_message\"")
        fi
	for server in ${servers[@]}; do
		for path in ${filePaths[@]}; do
			fullurl=$server/$extension_name_l/$version_l_v/$path;
			#echo $fullurl
			status_code=0;
			retried='';
			server_name="$server"
			if [ "$server"  = "$static" ] || [ "$server" = "$objectstorage" ]; then
				#server_name='static-stage'
				status_code=$(curl --proxy $PROXY_SERVER --write-out %{http_code} --silent --output /dev/null --head $fullurl)
				if [[ "$status_code" -eq 503 ]] ; then
					retried='[G] '
				    status_code=$(curl --proxy $PROXY_SERVER --write-out %{http_code} --silent --output /dev/null $fullurl)
				fi
			else
				status_code=$(curl --noproxy '*' --write-out %{http_code} --silent --output /dev/null --head $fullurl)
			fi
			if [[ "$status_code" -ne 200 ]] ; then
		  	  #echo "$fullurl does not exist. Returned status code $status_code"
			  error_message="$status_code : $fullurl"
			  if [[ $isDependency = "true"  ]]; then
				  error_message="[DEPENDENCY]: $error_message"
			  fi
			  issues+=("\"$error_message\"")
			  printf '\e[1;41m%s\e[m' "."
			  #exit 0;
			else
				printf '\e[0;32m%s\e[m' "." $retried
			fi
		done
		if [[ $isDependency = "true"  ]]; then
			printf "\nDependency check completed on $server_name server\n"
		else
			printf "\n Extension check completed on $server_name server\n"
		fi
	done
	completed_ext+=("\"$extension_name_l\"")
}

checkDependency(){
	if [[ $using_ade != "true"  ]]; then
		printInfo "Not using ade version. Dependencies won't be checked"
	elif [ -n "$python_version" ]; then
		printInfo "*********************************************************************"
		printInfo "Going to read dependencies for $extension_name $version"
		printInfo "*********************************************************************"
		readManifest $extension_name $version
		dependenciesLocal=$dependencies_of_current_context
		IFS=" "
		#if (( ${#dependenciesLocal[@]} ));  then
		if [ ${#dependencies_of_current_context[@]} -eq 0 ]; then
			printInfo "No dependencies found"
		else
			for dependency in ${dependenciesLocal[@]}; do
				depd=$(echo "$dependency" | tr -d "'" )
				dependency_id=$(echo $depd | cut -d ":" -f 1)
				versionDefinedInDependency=$(echo $depd | cut -d ":" -f 2)
				printInfo "Validating dependency $dependency_id"
				readVersionFromADE ${dependency_id} true
				versionFromADE=$version_for_extension_in_context
				if [[ "$versionDefinedInDependency" == \=* ]]; then
					printWarning "Dependency for $dependency_id is defined as \"=\" match which is not recommended."
				else
					if [[ "$versionDefinedInDependency" == \>* ]]; then
						versionWithoutEqualiser=$(echo $versionDefinedInDependency |  sed 's/[^0-9]*//')
						majorVersionDefinedInDependency=$(echo $versionWithoutEqualiser | cut -d '.' -f 1)
						majorVersionDefinedInADE=$(echo $versionFromADE | cut -d '.' -f 1)
						if [[ $majorVersionDefinedInDependency -gt $majorVersionDefinedInADE ]]; then
						   printError "Major version [$versionWithoutEqualiser] of defined dependency $dependency_id is greater than the major version[$versionFromADE] defined in ADE."
						   exit 11;
						elif [[ $majorVersionDefinedInDependency -eq $majorVersionDefinedInADE ]]; then
							middleVersionDefinedInDependency=$(echo $versionWithoutEqualiser | cut -d '.' -f 2)
							middleVersionDefinedInADE=$(echo $versionFromADE | cut -d '.' -f 2)
							if [[ $middleVersionDefinedInDependency -gt $middleVersionDefinedInADE ]]; then
						   		printError "Version [$versionWithoutEqualiser] of defined dependency $dependency_id is greater than the version[$versionFromADE] defined in ADE."
						   		exit 12;
							elif [[ $middleVersionDefinedInDependency -eq $middleVersionDefinedInADE ]]; then
								minorVersionDefinedInDependency=$(echo $versionWithoutEqualiser | cut -d '.' -f 3)
								minorVersionDefinedInADE=$(echo $versionFromADE | cut -d '.' -f 3)
								minorVersionDefinedInADE=$(echo $minorVersionDefinedInADE | cut -d '-' -f 1)
								if [[ $minorVersionDefinedInDependency -gt $minorVersionDefinedInADE ]]; then
						   			printError "Version [$versionWithoutEqualiser] of defined dependency $dependency_id is greater than the version[$versionFromADE] defined in ADE."
						   			exit 13;
								fi
							fi
						fi
					else
						printError "Dependency for $dependency_id does not have a valid operator in version $versionDefinedInDependency"
						exit 14;
					fi
				fi
				validate $id $dependency_id $versionFromADE true
			done
		fi
		IFS=""
		printInfo "First level dependency check completed. "
	fi
}

validate $extension_name $version
checkDependency

if (( ${#issues[@]} )); then
	printError  "Validation issues:"
	for each in "${issues[@]}"
	do
	   printError  "${each//\"}"
	done
	IFS=" "
	exit 10;
else
	if [[ $skipStage != "true"  ]]; then
		printFine " Version : ${version} exist for ${extension_name} at $fre/$extension_name/$version and at $static/$extension_name/$version."
	else
		printFine "Version : ${version} exist for ${extension_name} at $fre/$extension_name/$version."
	fi

fi
IFS=" "
