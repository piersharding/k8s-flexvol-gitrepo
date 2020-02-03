#!/bin/sh

# Copyright 2020 Piers harding.
#
# Deploy the FlexVolume driver gitrepo
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit
set -o pipefail

# TODO change to your desired driver name.
VENDOR=${VENDOR:-piersharding}
DRIVER=${DRIVER:-gitrepo}
GIT_VERSION=${GIT_VERSION:-2.17.1-1ubuntu0.5}
JQ_VERSION=${JQ_VERSION:-1.6}
DRIVER_LOCATION=${DRIVER_LOCATION:-/usr/libexec/kubernetes/kubelet-plugins/volume/}
HOST_TARGET=${HOST_TARGET:-/var/tmp/images}
DEBUG=${DEBUG:-false}

cd /flexmnt

# the driver uses git for image pull and export
if [ ! -f "/flexmnt/git" ]; then
    echo "no git in /flexmnt"
    rm -rf /flexmnt/git_${GIT_VERSION}_amd64.deb /flexmnt/git_${GIT_VERSION}
    mkdir -p /flexmnt/git_${GIT_VERSION}
    wget -O /flexmnt/git_${GIT_VERSION}_amd64.deb http://security.ubuntu.com/ubuntu/pool/main/g/git/git_${GIT_VERSION}_amd64.deb
    cd /flexmnt/git_${GIT_VERSION}
    ar -xv /flexmnt/git_${GIT_VERSION}_amd64.deb
    tar -xvf data.tar.xz
    mv usr/lib/git-core/git /flexmnt/git
    chmod a+x /flexmnt/git
    rm -rf /flexmnt/git_${GIT_VERSION}_amd64.deb /flexmnt/git_${GIT_VERSION}
fi
GIT_EXE="${DRIVER_LOCATION}/git"
echo "git at: $(ls -latr /flexmnt/git)"

# jq is used for parsing out details passed to driver
if [ ! -f "/flexmnt/jq" ]; then
    echo "no jq in /flexmnt"
    rm -f /flexmnt/jq-linux64
    wget -O /flexmnt/jq-linux64 https://github.com/stedolan/jq/releases/download/jq-${JQ_VERSION}/jq-linux64
    mv /flexmnt/jq-linux64 /flexmnt/jq
    chmod a+x /flexmnt/jq
fi
JQ_EXE="${DRIVER_LOCATION}/jq"
echo "jq at: $(ls -latr /flexmnt/jq)"

# set the environment file for the driver
cat <<EOF >/flexmnt/gitrepo_env.rc
DRIVER_LOCATION=${DRIVER_LOCATION}
GIT_EXE=${GIT_EXE}
JQ_EXE=${JQ_EXE}
HOST_TARGET=${HOST_TARGET}
DEBUG=${DEBUG}
EOF
echo "configuration in /flexmnt/gitrepo_env.rc:"
cat /flexmnt/gitrepo_env.rc

driver_dir=$VENDOR${VENDOR:+"~"}${DRIVER}
if [ ! -d "/flexmnt/exec/$driver_dir" ]; then
    mkdir -p "/flexmnt/exec/$driver_dir"
fi

tmp_driver=.tmp_$DRIVER
cp "/$DRIVER" "/flexmnt/exec/$driver_dir/$tmp_driver"
mv -f "/flexmnt/exec/$driver_dir/$tmp_driver" "/flexmnt/exec/$driver_dir/$DRIVER"

printf "\n\n\n##### Deployment Complete #####\n"
