#!/bin/bash

# If a command fails then the deploy stops
set -e

printf "\033[0;32mDeploying updates to GitHub...\033[0m\n"

# Build the project, and output to ../
/opt/repos/GO_REPO/bin/hugo -t timeline -D # if using a theme, replace with `hugo -t <YOURTHEME>`

rm -rf ../categories ../fonts ../tags ../timeline ../js
mv public/* ../

rm -rf public

cd ..

# Add changes to git.
git add .

# Commit changes.
msg="rebuilding site $(date)"
if [ -n "$*" ]; then
	msg="$*"
fi
git commit -m "$msg"

# Push source and build repos.
git push origin master

