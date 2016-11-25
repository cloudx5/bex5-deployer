#!/bin/sh

error_exit() {
    echo "ERROR DURING BUILDING IMAGE"
    exit 1
}
REGISTRY=${REGISTRY:-"hub.cloudx5.com/"}
TAG=${TAG:-"2"}
IMAGE=${IMAGE:-"justep/bex5-deployer:${TAG}"}

chmod a+x *.sh
docker build --rm=true --tag=${REGISTRY}${IMAGE} . || error_exit
docker push ${REGISTRY}${IMAGE}
