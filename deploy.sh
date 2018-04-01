#/bin/bash
echo -e "\033[0;32mDeploying updates to GitHub...\033[0m"

# Build the project.
hugo
cp -r public/* ../cloudnativeinfra.github.io

# Go To github pages folder
cd ../cloudnativeinfra.github.io

# Add changes to git.
git add -A

# Commit changes.

git commit -m "$1"

# Push source and build repos.
git push origin master

# Come Back
cd ../website
