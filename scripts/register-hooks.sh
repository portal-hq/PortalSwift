#!/bin/bash

if [ -z "$(which git-format-staged)" ]; then
  echo "Installing 'git-format-staged'..."
  npm install --global git-format-staged
fi

if [ -z "$(which swiftformat)" ]; then
  echo "Installing 'swiftformat'..."
  brew install swiftformat
fi

echo "Moving to project root..."
scriptDir=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")

cd ${scriptDir}
cd ../

echo "Registering pre-commit hook..."
cp ./scripts/git/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit

echo "Done!"