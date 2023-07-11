#!/bin/bash

echo "Installing `git-format-staged`..."
npm install --global git-format-staged

echo "Moving to project root..."
scriptDir=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")

cd ${scriptDir}
cd ../

echo "Registering pre-commit hook..."
cp ./scripts/git/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit

echo "Done!"