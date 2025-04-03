# vaibs-manifest-merger
A manifest merge bot to help reduce the mundane tasks performed by super awesome Oracle IDC devs!

- important steps before running the sh script
- (from the folder these files are in) chmod +x easymanifestmerger.sh raiseReview.sh cleanAndRefreshView.sh runPMC.sh
- jq needs to be preinstalled (its a command line json parser). jq is usually available in the system, so no worries :D
- Set BUGDB_USERID and BUGDB_PASSWORD in bashrc. For example, run ```nano ~/.bashrc``` then add ```export VARIABLE_NAME="value"``` inside it. finally, run ```source ~/.bashrc``` to apply your changes
- make sure you've filled all required fields in the bug db to prevent bug validation failure