#!/bin/bash

################################################################################
# Author:   Wynand Marais
# Date:     17/11/2019
# Purpose:  To find all git repositories in a particular path. The script
#           recursively searches, so be careful of symlinks.
################################################################################
# The path to start searching from.
WM_BASE_PATH=$(pwd)

# The list of discovered git repos.
WM_GIT_REPOS=()

# Set to true to enable debug messages, else false.
WM_DEBUG="false"

################################################################################
function print_debug() {
	if [ "${WM_DEBUG}" = "true" ]; then
		echo "${1}"
	fi
}

################################################################################
# Find all git repositories in the specified directory and all it's sub
# directories. Since it's only convention to append ".git" to directories
# where git repos live, there is no guarnetee that a particular directory is
# a git repo or not by simply looking for ".git". The best way is to call the
# git command:
#
#    git rev-parse --is-inside-git-dir
#
# This function uses this command to check if the specified directory is a git
# repo or not. If the directory is a git repo, then the direcotry is added to
# the repo list, else the sub directories are checked recursively until either
# no more sub directories are found, or until a git repo(s) is found.
################################################################################
function find_repos() {
	# Save the current working path.
	local WM_CUR_PATH=$(pwd)

	#local files=*
	print_debug "Backed up current working path: ${WM_CUR_PATH}"

	# Change to the specified path.
	cd "${1}" &> /dev/null
	if [ $? -eq 0 ]; then
		print_debug "Changed directory to: $(pwd)"

		# Check if the current dir is a git repo.
		git rev-parse --is-inside-git-dir &> /dev/null

		if [ $? -eq 0 ]; then
			WM_GIT_REPOS+=($1)
			print_debug "Git repo found: $(pwd)"
		else
			print_debug "Git repo not found."
			for f in *; do
				if [ -d "${f}" ]; then
					print_debug "Next dir: $(pwd)/${f}"
					find_repos "$(pwd)/${f}"
				fi
			done
		fi

		# 	Restore the working path.
		cd "${WM_CUR_PATH}"
	fi
}

################################################################################
# Check if the user specified a path.
if [ "$#" -eq 1 ]; then
	WM_BASE_PATH="${1}"
fi

# Start the recursive search.
find_repos "${WM_BASE_PATH}"
printf '%s\n' "${WM_GIT_REPOS[@]}"

