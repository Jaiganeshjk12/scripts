# imagePush.sh - Script to Manage K10 Images for Private Registries

This bash script generates the commands for pulling, re-tagging, and pushing container images required for Kasten K10 to a private container registry. 

It factors in the usage of `k10tools` for K10 versions 7.5.0 and above, and `k10offline` for the older versions.

## Description

The `imagePush.sh` script generates a series of commands that you can execute to mirror the necessary K10 images from the public Google Container Registry (`gcr.io/kasten-images`) to your private container registry. This is useful for environments with limited or no direct access to internet/public registries.

The script performs the following steps:

1.  **Retrieves Image List:** Based on the provided K10 version, the script uses either `k10tools` (for versions >= 7.5.0) or `k10offline` (for versions < 7.5.0) to fetch the list of required container images.
2.  **Generates Pull Commands:** Creates `docker` or `podman` commands to pull each image from the source registry (`gcr.io` or `docker.io`).
3.  **Generates Re-tag Commands:** Creates `docker` or `podman` commands to re-tag each pulled image with your specified private registry and a consistent naming convention. For `gcr.io` images, the original tag is preserved. For other images (like those from `docker.io`), a `k10-` prefix is added to the tag.
4.  **Generates Push Commands:** Creates `docker` or `podman` commands to push the re-tagged images to your private registry.

## Usage

```bash
./imagePush.sh -t <target_registry> -v <k10_version> [-c <client>] [-h]
```
## Options
| Option | Description                                                                 | Mandatory | Default Value |
| :----- | :-------------------------------------------------------------------------- | :-------- | :------------ |
| `-t`   | Target image registry to which the images need to be pushed.               | Yes       |               |
| `-v`   | K10 version (e.g., 7.5.0, 7.0.3).                                         | Yes       |               |
| `-c`   | Client used to push/pull images (`docker` or `podman`).                   | No        | `podman`      |
| `-h`   | Print this help message and exit.                                         | No        |               |

### Prerequisites
- Bash: The script is written in bash and requires a bash interpreter.
- Docker or Podman: You need to have either docker or podman installed on the machine where you run the script. The script will verify the availability of the chosen client.
- Access to Target Registry: Ensure that the machine running the script has network access to your private container registry and that you have the necessary credentials configured for pushing images.

### Important Notes
- **Execution of Commands**: This script only generates the commands. You will need to copy and execute these commands in your terminal to actually pull, re-tag, and push the images.

- **Image Tags**: For images originating from gcr.io, the original tag is used in your private registry. For images from docker.io (like jimmidyson/kube-apiserver-proxy), the tag in your private registry will be prefixed with k10-.

- **Error Handling**: The script includes basic error handling for invalid options, missing mandatory arguments, and failures during image list retrieval.

- **Permissions**: Ensure that the user running the script has the necessary permissions to run docker or podman commands.

- **Network Connectivity**: The machine running the script needs internet access to pull images from gcr.io and docker.io (if applicable).

### Example Usage

#### Using podman (default) to mirror K10 version 7.0.3 to my.private.registry.com:

```
./imagePush.sh -t my.private.registry.com -v 7.0.3
```
This will output a series of podman pull, podman tag, and podman push commands.

#### Using docker to mirror K10 version 7.5.6 to internal-registry:5000:
```
./imagePush.sh -t internal-registry:5000 -v 7.5.6 -c docker
```
This will output a series of docker pull, docker tag, and docker push commands.

### Getting help information:
```
./imagePush.sh -h
```
This will display the usage instructions and available options.



After running the script, carefully review the generated commands and execute them in your terminal to complete the image mirroring process.
