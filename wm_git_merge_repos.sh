#!/bin/bash
################################################################################
# Author:   Wynand Marais
# Date:     17/11/2019
# Purpose:  To find all repositories in a file system, merge them into a single
#           repository including all braches, tags and histories and maintaining
#           the directory structure in the output repository.
################################################################################
# The path to the output repo.
WM_OUTPUT_REPO=""

# The path to search for git repos to merge.
WM_SEARCH_PATH=""

# The array of repos discovered at the search path.
WM_SRC_REPOS=()

# The branches in a particular repo.
WM_SRC_BRANCHES=()

# Set to "true" to enable debug messages, else set to "false".
WM_DEBUG="false"

################################################################################
# Print the help information for the script.
################################################################################
function wm_print_help()
{
	echo ""
	echo "Usage: "
	echo "   wm_git_merge_repos -o <output repo> -s <repo search path>"
	echo ""
	echo "Parameters:"
	echo "  -o  Specify the output path of the repo that will be created. This"
	echo "      can be a relative or absolute path."
	echo ""
	echo "  -s  Specify where the script should search for repos to merge into"
	echo "      the new repo."
	echo ""
	echo "  -h  Print this help page."
	echo ""
	echo "Purpose: "
	echo "   This script reclusively searches for all git repositories at a"
	echo "   specified search path. It then creates a new git repository and"
	echo "   merges all the discovered git repos into the new repo. The"
	echo "   discovered repos are merged in such that their position repository"
	echo "   mirrors their locations as discovered relative to the search path."
	echo "   That is it mirrors the structure as shown in the file explorer."
	echo ""
	echo "   As long as the user executing the script has access to the"
	echo "   required repositories, elevated permissions are not required."
	echo ""
}

################################################################################
# Shown on sucessful completion.
################################################################################
function wm_print_end()
{
	echo ""
	echo "Looks like everything went well, check the output to be sure."
	echo ""
	echo "Now finish the job by pushing to a the remote repo by calling: "
	echo "  git push <url> --all"
	echo "  git push <url> --tags"
	echo ""
	exit 0
}

################################################################################
# Print a debug message.
################################################################################
function wm_print_debug ()
{
	if [ "${WM_DEBUG}" = "true" ]; then
		echo "DEBUG - ${1}"
	fi
}

################################################################################
# Print an error message.
################################################################################
function wm_print_error() {
	echo "ERROR - ${1}"
}

################################################################################
# A helper function to add a remote to the current git repository. Mostly 
# required to do clean error checking.
#
# $1 = Name of Remote.
# $2 = Path of Remote.
################################################################################
function wm_git_remote_add_and_fetch() 
{
	# Print a debug message.
	wm_print_debug "Adding remote repo: ${1} ${2}"

	# Add the src repo to the DST repo and perform a fetch.
	git remote add -f --tags "${1}" "${2}"

	# Check for any errors.
	if [ $? -ne 0 ]; then
		wm_print_error "Failed to add remote repo: ${1} ${2}"
		exit 1
	fi
}

################################################################################
# A helper function to check out a remote branch. Mostly required to do clean
# error checking.
#
# $1 = Branch to check out.
################################################################################
function wm_git_checkout()
{
	# Print a debug message.
	wm_print_debug "Checking out brach: ${1}"

	# Check out the specified branch.
	git checkout "${1}"

	# Check for any errors.
	if [ $? -ne 0 ]; then
		wm_print_error "Failed to check out branch: ${1}"
		exit 1
	fi
}

################################################################################
# A helper function to merge a specific branch of the remote into the local
# repo. Mostly required to do clea error checking.
#
# $1 = Name of remote.
# $2 = Name of branch.
################################################################################
function wm_git_merge()
{
	# Print a debug message.
	wm_print_debug "Merging contents of: ${1}/${2}"

	# Attempt to merge the contents of the remote branch.
	git merge -s ours --no-commit --allow-unrelated-histories "${1}/${2}"

	# Check for any errors.
	if [ $? -ne 0 ]; then
		wm_print_error "Failed to merge contents of: ${1}/${2}"
		exit 1
	fi
}

################################################################################
# $1 = Sub directory where the new remote tree contents must be located.
# $2 = Name of remote.
# $3 = Name of branch.
################################################################################
function wm_git_move_to_sub_dir()
{
	# Print a debug message.
	wm_print_debug "Moving the remote: ${2}/${3} to: ${1}"

	# Move the contents of the remote into the specified sub directory.
	git read-tree --prefix="${1}" -u "${2}/${3}"

	# Check for any errors.
	if [ $? -ne 0 ]; then
		wm_print_error "Failed to move contents of: ${2}/${3} into: ${1}"
		exit 1
	fi
}

################################################################################
# $1 = Name of the remote.
# $2 = Name of the branch.
################################################################################
function wm_git_commit()
{
	# Print a debug message.
	wm_print_debug "Commiting changes from: ${1}/${2}"

	# Commit the changes to keep them save.
	git commit -a -m "Subtree merged in ${1}/${2}"

	# Check for any errors.
	if [ $? -ne 0 ]; then
		wm_print_error "Failed to commit changes: ${1}/${2}"
		exit 1
	fi
}

################################################################################
# $1 = Name of the remote.
################################################################################
function wm_git_remote_remove()
{
	# Print a debug message.
	wm_print_debug "Remove the remote: ${1}"

	# Remove the specified remote from the repo.
	git remote remove "${1}"

	# Check for any errors.
	if [ $? -ne 0 ]; then
		wm_print_error "Failed to remove remote: ${1}"
		exit 1
	fi
}

################################################################################
# Populate the variable WM_SRC_BRANCES with a list of branches beloning to the
# specified git repository.
################################################################################
function wm_get_branches() {
	# Save the current working path.
	local WM_CUR_PATH=$(pwd)
	WM_SRC_BRANCHES=()

	cd ${1}
	WM_BRANCHES=$(git branch -a)
	
	SAVEIFS=$IFS
	IFS=$'\n'
	WM_BRANCHES=($WM_BRANCHES)
	IFS=$SAVEIFS

	for WM_BRANCH in "${WM_BRANCHES[@]}"
	do
		WM_BRANCH=$(echo ${WM_BRANCH#"*"})
		#WM_BRANCH=$(echo "${WM_BRANCH##*( )}")
		#WM_BRANCH=$(echo "${WM_BRANCH%%*(*)}")
		WM_SRC_BRANCHES+=("${WM_BRANCH}")
	done

	# Restore the working path.
	cd "${WM_CUR_PATH}"
}

################################################################################
function wm_print_plan()
{
	echo ""
	echo "THE PLAN:"
	echo "---------"
	echo "  The following Repos and Branches will be merged: "
	echo ""

	# Iterate through all the detected source repos.
	for WM_SRC_REPO in "${WM_SRC_REPOS[@]}"
	do
		# Calculate where to insert the repo into the new repo.
		WM_REMOTE_NAME=$(basename "${WM_SRC_REPO}")
		WM_REMOTE_SUB_DIR=$(echo ${WM_SRC_REPO#"${WM_SEARCH_PATH}/"})

		# Get a list of all the branches in the repo.
		wm_get_branches "${WM_SRC_REPO}"

		echo "      REPO:"
		echo "         REMOTE:   ${WM_REMOTE_NAME}"
		echo "         PATH:     ${WM_SRC_REPO}"
		echo "         SUB DIR:  ${WM_REMOTE_SUB_DIR}"
		printf "         BRANCH:   %s\n" "${WM_SRC_BRANCHES[@]}"
		echo ""
	done

	echo "  The merged output will live in:"
	echo ""
	echo "     OUTPUT: ${WM_OUTPUT_REPO}"
	echo ""
	read -p "Press [Enter] key to start merging, or [CTRL+C] to stop ..."
	echo ""
}

################################################################################
# Merge in the discovered repositories. We basically do this:
#
#  1. Iterate through the list of detected git repos.
#    1.1. Add the repo to the list of remotes.
#    1.2. Extract all the branches of the repo.
#    1.3. Iterate through each branch.
#      1.3.1 Check out the branch.
#      1.3.2 Merge the contents of the branch into the new repo.
#      1.3.3 Move the branch contents to the appropriate sub directory location.
#      1.3.4 Commit the changes to the new repo.
#
#  https://github.com/git/git/blob/master/contrib/subtree/git-subtree.txt
#  https://help.github.com/en/github/using-git/about-git-subtree-merges
#
################################################################################
function wm_execute_plan()
{
	# Create the directory for the output repo.
	mkdir -p "${WM_OUTPUT_REPO}"
	if [ $? -ne 0 ]; then
		wm_print_error "Failed to create repo path: ${WM_OUTPUT_REPO}"
		exit 1
	fi

	# Create the output repo.
	git init "${WM_OUTPUT_REPO}"
	if [ $? -ne 0 ]; then
		wm_print_error "Failed to initialise destination repo: ${WM_OUTPUT_REPO}"
		exit 1
	fi

	# Save the current working path.
	local WM_CUR_PATH=$(pwd)

	# Change into the output repository path.
	cd "${WM_OUTPUT_REPO}"

	# Iterate through all the detected source repos.
	for WM_SRC_REPO in "${WM_SRC_REPOS[@]}"
	do
		# Calculate where to insert the repo into the new repo.
		WM_REMOTE_NAME=$(basename "${WM_SRC_REPO}")
		WM_REMOTE_SUB_DIR=$(echo ${WM_SRC_REPO#"${WM_SEARCH_PATH}/"})

		# Get a list of all the branches in the repo.
		wm_get_branches "${WM_SRC_REPO}"

		printf "\nCurrent repo to merge:\n"
		printf "  Name:    ${WM_REMOTE_NAME}\n"
		printf "  Path:    ${WM_SRC_REPO}\n"
		printf "  Sub Dir: ${WM_REMOTE_SUB_DIR}\n"
		printf "  Branch:  %s\n" "${WM_SRC_BRANCHES[@]}\n"

		# Add the src repo to the DST repo and perform a fetch.
		wm_git_remote_add_and_fetch "${WM_REMOTE_NAME}" "${WM_SRC_REPO}"

		# Iterate through all the branches and merge the histories in. If we 
		# dont do this, then obviously not all branches will be merged in. I'm
		# not sure if there is a short hand way to do this.
		for WM_BRANCH in "${WM_SRC_BRANCHES[@]}"
		do
			# Check out the branch; 
			wm_git_checkout "${WM_BRANCH}"

			# Merge the contents of the remote repository.
			wm_git_merge ${WM_REMOTE_NAME} ${WM_BRANCH}
			
			# Create the subdirectory for the new remote repo and copy it's 
			# history across.
			wm_git_move_to_sub_dir "${WM_REMOTE_SUB_DIR}/" "${WM_REMOTE_NAME}" \
				"${WM_BRANCH}"

			# Commit the changes to keep them save.
			wm_git_commit "${WM_REMOTE_NAME}" "${WM_BRANCH}"
		done

		# Remove the remote from the new repo.
		wm_git_remote_remove "${WM_REMOTE_NAME}"
	done

	# Restore the working path.
	cd "${WM_CUR_PATH}"
}

################################################################################
# ARGS - Parsing the script arguments.
################################################################################
# Default to no output repo.
WM_OUTPUT_REPO=""

# Default to no search path.
WM_SEARCH_PATH=""

# Parse the args to the script.
while getopts "ho:s:" arg; do
	case $arg in
	h)
		wm_print_help
		exit 0
	;;
	o)
		WM_OUTPUT_REPO=$OPTARG

		# Make sure the path is absolute.
		WM_OUTPUT_REPO=$(readlink -f "${WM_OUTPUT_REPO}")

		# Check for any errors.
		if [ $? -ne 0 ]; then
			wm_print_error "Invalid output repo (-o): ${$OPTARG}"
			exit 1
		fi
	;;
	s)
		WM_SEARCH_PATH=$OPTARG
		# Make sure the path is absolute.
		WM_SEARCH_PATH=$(readlink -f "${WM_SEARCH_PATH}")
	;;

	\?)
		wm_print_help
		exit 1
	;;
	esac
done

# Make sure the output repo was specified.
if [ "${WM_OUTPUT_REPO}" = "" ]; then
	wm_print_error "Output repo (-o) not specified!"
	wm_print_help
	exit 1
fi

# Make sure the search path was specified.
if [ "${WM_SEARCH_PATH}" = "" ]; then
	wm_print_error "Search path (-s) not specified!"
	wm_print_help
	exit 1
fi

################################################################################
# SEARCHING - Find the repos to be merged.
################################################################################
# Ask for concent to proceed.
echo "SEARCH"
echo "------"
echo "The paths provide for processing are: "
echo ""
echo "  OUTPUT REPO: ${WM_OUTPUT_REPO}"
echo "  SEARCH PATH: ${WM_SEARCH_PATH}" 
echo ""
read -p "Press [Enter] key to start searching, or [CTRL+C] to stop ..."
echo ""

# Find all the repos that must be merged.
wm_print_debug "Starting search for all git repos in: ${WM_SEARCH_PATH}"
WM_SRC_REPOS=$(./wm_git_find_repos.sh "${WM_SEARCH_PATH}")

SAVEIFS=$IFS
IFS=$'\n'
WM_SRC_REPOS=($WM_SRC_REPOS)
IFS=$SAVEIFS

echo "Discovered Git Repos:"
printf '  -> %s\n' "${WM_SRC_REPOS[@]}"
echo ""

################################################################################
# MERGE - Perform the actual merge operation.
################################################################################
# Print the plan and ask concent to proceed.
wm_print_plan

# Excute the plan and merge the git git repos to a single output repo.
wm_execute_plan

# Print the end message and exit cleanly.
wm_print_end

