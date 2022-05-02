#!/bin/bash
#script to get the commands for pull, re-tag and push K10 images to the private repo

set -euo pipefail

#requirements
#podman or docker


#helpFunction with the usage details
helpFunction()
{
   # Display Help
   echo "USAGE."
   echo "Use the below options to input the target image registry and K10 version details"
   echo "Syntax: scriptTemplate [-t|v|h]"
   echo "options:"
   echo "-t     Target image registry to which the images needs to be pushed."
   echo "-v     K10 version."
   echo "-c     Client used to push/pull images - Supported arguments are docker & podman(defaults to podman"
   echo "-h     Print this Help."
   exit 1
}

#default client to use podman if the option is not provided while running the script
CLIENT=podman

while getopts "t:v:h:c:" opt
do
   case "$opt" in
      t ) TARGET_REGISTRY="$OPTARG" ;;
      v ) K10_VERSION="$OPTARG" ;;
      c ) CLIENT="$OPTARG" ;;
      h ) helpFunction ;;
      ? ) helpFunction ;; # Print helpFunction in case parameter is non-existent
   esac
done

if [[ -z ${TARGET_REGISTRY} || -z ${K10_VERSION} ]]
then
    helpFunction
fi

IMAGES=$(${CLIENT} run --rm -it gcr.io/kasten-images/k10offline:${K10_VERSION} list-images | tr -d '\r')

echo
echo =====Commands to pull the images locally===============
echo

for i in ${IMAGES}
do
echo ${CLIENT} pull $i
done

echo
echo =====Commands to re-tag the images with your image registry ===============
echo

for j in ${IMAGES}
do
    TAG=$(echo $j | cut -f 2 -d ':')
    K10TAG=k10-${TAG}
    IMAGENAMEWITHOUTTAG=$(echo $j | awk -F '/' '{print $NF}'|cut -f 1 -d ':')

    if [[ $j = gcr.* ]]
    then
        echo "${CLIENT} tag ${j} ${TARGET_REGISTRY}/${IMAGENAMEWITHOUTTAG}:${TAG}"
    else
        echo "${CLIENT} tag ${j} ${TARGET_REGISTRY}/${IMAGENAMEWITHOUTTAG}:${K10TAG}"
    fi
done

echo
echo =====Commands to push the images to your image registry ===============
echo

for j in ${IMAGES}
do
    TAG=$(echo $j | cut -f 2 -d ':')
    K10TAG=k10-${TAG}
    IMAGENAMEWITHOUTTAG=$(echo $j | awk -F '/' '{print $NF}'|cut -f 1 -d ':')
    if [[ $j = gcr.* ]]
    then
        echo ${CLIENT} push ${TARGET_REGISTRY}/${IMAGENAMEWITHOUTTAG}:${TAG}
    else
        echo ${CLIENT} push ${TARGET_REGISTRY}/${IMAGENAMEWITHOUTTAG}:${K10TAG}
    fi
done

exit 0
