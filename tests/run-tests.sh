#!/bin/bash

set -euo pipefail

set -x

DRIVER="../gitrepo"
HOST_TARGET="/tmp/gitrepo-data"
MNTPATH="/tmp/gitrepo-mnt"
VOLUME=pv-flex-gitrepo-test-0001
VOLUME_DIR=${MNTPATH}/${VOLUME}
GIT_EXE=$(which git)
JQ_EXE=$(which jq)
DEBUG=true
MOUNTINFO=/proc/self/mountinfo

export HOST_TARGET GIT_EXE JQ_EXE DEBUG

INIT_PARAMS=''
INIT_OUTPUT='{"status":"Success","capabilities":{"attach":false}}'

MOUNT_PARAMS="mount ${VOLUME_DIR} {\"hostTarget\":\"${HOST_TARGET}\",\"kubernetes.io/fsType\":\"\",\"kubernetes.io/pod.name\":\"nginx-deployment1-569cf9d797-zgtd9\",\"kubernetes.io/pod.namespace\":\"default\",\"kubernetes.io/pod.uid\":\"0b710895-6481-4e79-99ad-481cc0a9df85\",\"kubernetes.io/pvOrVolumeName\":\"${VOLUME}\",\"kubernetes.io/readwrite\":\"rw\",\"kubernetes.io/serviceAccount.name\":\"default\",\"repo\":\"git@github.com:piersharding/k8s-flexvol-gitrepo.git\"}"
MOUNT_OUTPUT='{"status":"Success"}'

UMOUNT_PARAMS="unmount ${VOLUME_DIR}"
UMOUNT_OUTPUT='{"status":"Success"}'

echo "Setup gitrepo test ..."
# clean down test space
cat /proc/self/mountinfo | grep ${VOLUME_DIR} && sudo umount ${VOLUME_DIR}
rm -rf ${HOST_TARGET} ${MNTPATH}
mkdir -p ${HOST_TARGET} ${MNTPATH}

echo "begin to run gitrepo test ..."
echo "${DRIVER} init test..."
RES=`${DRIVER} init ${INIT_PARAMS}`
retcode=$?
echo ${RES}
if [ $retcode -gt 0 ]; then
	exit $retcode
fi
if [ "${RES}" != "${INIT_OUTPUT}" ]; then
    echo "init: \"${RES}\" != \"${INIT_OUTPUT}\""
    exit 1
fi

# mount
mkdir -p $MNTPATH
echo "${DRIVER} mount test..."
RES=`${DRIVER} ${MOUNT_PARAMS}`
retcode=$?
echo ${RES}
if [ $retcode -gt 0 ]; then
	exit $retcode
fi
if [ "${RES}" != "${MOUNT_OUTPUT}" ]; then
    echo "mount: \"${RES}\" != \"${MOUNT_OUTPUT}\""
    exit 1
fi

echo "PVC state file:"
STATE_FILE=${VOLUME_DIR}/.gitrepo_state/to
ls -latr ${STATE_FILE}
STATE=`cat ${STATE_FILE}`
echo ${STATE}
grep ${VOLUME_DIR} ${MOUNTINFO}
retcode=$?
if [ $retcode -gt 0 ]; then
echo "failed to find ${VOLUME_DIR} in ${MOUNTINFO}"
	exit $retcode
fi

# umount
mkdir -p $MNTPATH
echo "${DRIVER} unmount test..."
RES=`${DRIVER} ${UMOUNT_PARAMS}`
retcode=$?
echo ${RES}
if [ $retcode -gt 0 ]; then
	exit $retcode
fi
if [ "${RES}" != "${UMOUNT_OUTPUT}" ]; then
    echo "unmount: \"${RES}\" != \"${UMOUNT_OUTPUT}\""
    exit 1
fi

# Clean down tests
rm -rf ${HOST_TARGET} ${MNTPATH}
mkdir -p ${HOST_TARGET} ${MNTPATH}

echo "gitrepo test is completed."
exit 0
