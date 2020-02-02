# FlexVolume driver for Kubernetes: use Image as PersistentVolume

## Summary

Welcome to the `gitrepo` FlexVolume driver for Kubernetes.  This driver makes it possible to nominate a Git repository that is turned into a multi-mount PersistentVolume.  `gitrepo` will pull a single branch of the chosen Git repository into a specified host directory, which is then `bind` mounted into the running container/s as specified by the PersistentVolumeClaim/volumeMounts directives for the Pod.

## Installation

The driver is installed using a DaemonSet that downloads `git` and `jq`, sets environment variables and then places the driver executable in the exec/vendor directory.

The DaemonSet is run using `kustomize` and the easiest way to launch this is using `make`:
```
$ make deploy
```

Environment variables for the deployment are:
* `DEBUG` [default: `false`] - turn on debug output for the driver by setting this to `true`

Use `make`, these values can be passed in with:
```
$ make deploy DEBUG=true
```

The `Makefile` does a lot of things, including building the deployment image for the driver, so type `make` to see:
```
$ make
make targets:
Makefile:cleanall              Clean all
Makefile:clean                 remove deployment DaemonSet and temp vars
Makefile:delete                delete deployment of gitrepo Flexvolume
Makefile:delete_namespace      delete the kubernetes namespace
Makefile:deploy                deploy gitrepo Flexvolume
Makefile:describe              describe Pods executed from deployment
Makefile:help                  show this help.
Makefile:image                 build deployment image
Makefile:k8s                   Which kubernetes are we connected to
Makefile:kubectl_dependencies  Utility target to install kubectl dependencies
Makefile:logs                  deployment logs
Makefile:namespace             create the kubernetes namespace
Makefile:push                  push deployment image
Makefile:push_test             push test image
Makefile:redeploy              redeploy operator
Makefile:show                  show deployment of gitrepo Flexvolume
Makefile:test-clean            clean down test
Makefile:test_image            build test image
Makefile:test                  deploy test
Makefile:test-results          curl test

make vars (+defaults):
Makefile:CI_REGISTRY           docker.io
Makefile:CI_REPOSITORY         piersharding
Makefile:DEBUG                 false
Makefile:DOCKERFILE            Dockerfile ## Which Dockerfile to use for build
Makefile:DRIVER_NAMESPACE      kube-system
Makefile:IMAGE                 $(CI_REPOSITORY)/$(NAME)
Makefile:KUBECTL_VERSION       1.14.1
Makefile:KUBE_NAMESPACE        "default"
Makefile:TAG                   latest
```

## Test

Testing the `gitrepo` driver can be performed using:
```
$ make test && make test-results
$ make test && make test-results
docker build \
  -t k8s-flexvol-gitrepo-test:latest -f Dockerfile.test .
Sending build context to Docker daemon  139.8kB
Step 1/6 : FROM busybox AS build
 ---> 19485c79a9bb
Step 2/6 : WORKDIR /
 ---> Using cache
 ---> 27905904dc0c
Step 3/6 : RUN   echo "This is a test from gitrepo!" >/index.html
 ---> Using cache
 ---> bd69021d211b
Step 4/6 : FROM scratch
 --->
Step 5/6 : WORKDIR /
 ---> Using cache
 ---> 994db783955d
Step 6/6 : COPY --from=build /index.html /index.html
 ---> Using cache
 ---> 70e82947ab0f
Successfully built 70e82947ab0f
Successfully tagged k8s-flexvol-gitrepo-test:latest
docker tag k8s-flexvol-gitrepo-test:latest piersharding/k8s-flexvol-gitrepo-test:latest
docker push piersharding/k8s-flexvol-gitrepo-test:latest
The push refers to repository [docker.io/piersharding/k8s-flexvol-gitrepo-test]
3bd1128f98c6: Layer already exists
latest: digest: sha256:95aff0700e891e6291d3a2cd60a45c8b8617930c3d64f2b52ba2ea8419777145 size: 524
kubectl describe namespace "default" || kubectl create namespace "default"
Name:         default
Labels:       <none>
Annotations:  <none>
Status:       Active

No resource quota.

No resource limits.
kubectl apply -f tests/mount-test.yaml -n "default"
storageclass.storage.k8s.io/gitrepo unchanged
persistentvolume/pv-flex-gitrepo-0001 unchanged
persistentvolumeclaim/data unchanged
service/nginx1 unchanged
deployment.apps/nginx-deployment1 unchanged
service/nginx2 unchanged
deployment.apps/nginx-deployment2 unchanged
kubectl wait --for=condition=available deployment.v1.apps/nginx-deployment1 --timeout=180s
deployment.apps/nginx-deployment1 condition met
SVC_IP=$(kubectl -n "default" get svc nginx1 -o json | jq -r '.spec.clusterIP') && \
curl http://${SVC_IP}
This is a test from gitrepo!
kubectl wait --for=condition=available deployment.v1.apps/nginx-deployment2 --timeout=180s
deployment.apps/nginx-deployment2 condition met
SVC_IP=$(kubectl -n "default" get svc nginx2 -o json | jq -r '.spec.clusterIP') && \
curl http://${SVC_IP}
This is a test from gitrepo!
```

Note: you will need to provide your own registry by passing vars `CI_REGISTRY` and `CI_REPOSITORY` as appropriate.

## Git Repositories

A repository available over open HTTP is addressed by:
```
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-flex-gitrepo-0001
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteMany
  flexVolume:
    driver: "piersharding/gitrepo"
    options:
      repo: "https://github.com/piersharding/k8s-flexvol-gitrepo.git"
      hostTarget: /data/images
  storageClassName: gitrepo

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data
spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 1Gi
  volumeName: "pv-flex-gitrepo-0001"
  storageClassName: gitrepo
```

A repository accessed via `ssh` is addressed by:
```
---
apiVersion: v1
kind: Secret
metadata:
  name: gitrepo-pull-key
type: piersharding/gitrepo
data:
  sshKey: "${SSH_KEY}"

---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-flex-gitrepo-0002ssh
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteMany
  flexVolume:
    driver: "piersharding/gitrepo"
    secretRef:
      name: gitrepo-pull-key
    options:
      repo: "git@github.com:piersharding/k8s-flexvol-gitrepo.git"
      hostTarget: /data/images
  storageClassName: gitrepo

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data
spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 1Gi
  volumeName: "pv-flex-gitrepo-0002ssh"
  storageClassName: gitrepo
```

The `${SSH_KEY}` value should be substituted with the `base64` encoded output of the relevent `ssh` private key for accessing the nominated repository.  Equivalent to the output of `cat ./id_rsa | base64 -w0`.
