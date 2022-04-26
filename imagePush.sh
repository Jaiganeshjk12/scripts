#!/bin/bash
#script to get the commands for pull, re-tag and push K10 images to the private repo

set -euo pipefail

#requirements
if ! hash podman 2>/dev/null; then
  echo "podman command not found! Please install podman and run the script again"
  exit 1
fi


helpFunction()
{
   # Display Help
   echo "USAGE."
   echo "Use the below options to input the target image registry and K10 version details"
   echo "Syntax: scriptTemplate [-t|v|h]"
   echo "options:"
   echo "-t     Target image registry to which the images needs to be pushed."
   echo "-v     K10 version."
   echo "-h     Print this Help."
   exit 1
}

while getopts "t:v:h:" opt
do
   case "$opt" in
      t ) TARGET_REGISTRY="$OPTARG" ;;
      v ) K10_VERSION="$OPTARG" ;;
      h ) helpFunction ;;
      ? ) helpFunction ;; # Print helpFunction in case parameter is non-existent
   esac
done

if [[ -z ${TARGET_REGISTRY} || -z ${K10_VERSION} ]]
then
    helpFunction
fi

IMAGES=$(podman run --rm -it gcr.io/kasten-images/k10offline:${K10_VERSION} list-images | tr -d '\r')

echo =====Commands to pull the images locally===============
for i in ${IMAGES}
do
echo podman pull $i
done

echo =====Commands to re-tag the images with your image registry ===============

for j in ${IMAGES}
do
    TAG=$(echo $j | cut -f 2 -d ':')
    K10TAG=k10-${TAG}
    IMAGENAMEWITHOUTTAG=$(echo $j | awk -F '/' '{print $NF}'|cut -f 1 -d ':')

    if [[ $j = gcr.* ]]
    then
        echo "podman tag ${j} ${TARGET_REGISTRY}/${IMAGENAMEWITHOUTTAG}:${TAG}"
    else
        echo "podman tag ${j} ${TARGET_REGISTRY}/${IMAGENAMEWITHOUTTAG}:${K10TAG}"
    fi
done

echo =====Commands to push the images to your image registry ===============

for j in ${IMAGES}
do
    TAG=$(echo $j | cut -f 2 -d ':')
    K10TAG=k10-${TAG}
    IMAGENAMEWITHOUTTAG=$(echo $j | awk -F '/' '{print $NF}'|cut -f 1 -d ':')
    if [[ $j = gcr.* ]]
    then
        echo podman push ${TARGET_REGISTRY}/${IMAGENAMEWITHOUTTAG}:${TAG}
    else
        echo podman push ${TARGET_REGISTRY}/${IMAGENAMEWITHOUTTAG}:${K10TAG}
    fi
done

exit 0
