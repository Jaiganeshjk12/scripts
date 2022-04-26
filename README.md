This repository contains the scripts that can be used with K10 for specific use-cases.

## imagePush.sh
The image push script can be used to generate the podman pull/re-tag/push commands for pushing K10 images to private repositories. 
This script uses `K10offline` tool and is particlarly useful when customer's doesn't have `docker` installed in their environment.

USAGE.
Use the below options to input the target image registry and K10 version details"
```
Syntax: ./imagepush.sh [-t|v|h] 
options:"
  -t     Target image registry to which the images needs to be pushed.(Required)
  -v     K10 version.(Required)
  -h     Print this Help.
```
