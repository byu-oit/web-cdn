#!/bin/sh

#echo "Installing Nodejs, Yarn, jq, and yq"
#
#apt-get update -q
#apt-get install -yq apt-transport-https
#
#curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
#echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
#
#curl -sL https://deb.nodesource.com/setup_10.x | bash -
#
#apt-get update -q && apt-get install -yq nodejs yarn #jq
#
#pip install yq

#Just for logging purposes
node --version
npm --version

npm install -g yarn

echo "Installing lerna"

yarn global add "lerna@^6.0.0"

yarn global add mustache

