#!/bin/sh

echo "------- START: 01_print_tool_versions.sh -------"

echo "Running command ruby --version"
ruby --version

echo "Running command gem --version"
gem --version

echo "Running command bundler --version"
bundler --version

echo "Running command puma --version"
puma --version

echo "Running command psql --version"
psql --version

echo "Running command node --version"
node --version

echo "Running command npm --version"
npm --version

echo "Running command yarn --version"
yarn --version

echo "Running command npx yarn --version"
npx yarn --version

echo "------- END: 01_print_tool_versions.sh -------"
