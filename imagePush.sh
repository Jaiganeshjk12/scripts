#!/bin/bash
set -eou pipefail
# Script to generate commands for pull, re-tag, and push K10 images to a private repo
# Using k10tools image list for K10 versions 7.5.0 and above.

# COLOR CONSTANTS
GREEN='\033[0;32m'
RED='\033[1;31m'
LIGHT_BLUE='\033[1;34m'
BOLD='\033[1m'
NC='\033[0m'

# Requirements: podman or docker, k10tools (for k10 versions >= 7.5.0)

#function to compare kasten semantic versions to determine whether to use k10offline or k10tools image.
#returns 1 if the K10_VERSION used is greater than the Version provided for compare and -1 otherwise.
compare_versions() {
  local ver1="$1"
  local ver2="$2"

  local IFS="."
  local ver1_parts=($ver1)
  local ver2_parts=($ver2)

  for i in {0..2}; do
    local part1="${ver1_parts[$i]:-0}" # Use default value 0 if part is empty
    local part2="${ver2_parts[$i]:-0}" # Use default value 0 if part is empty

    if [[ "$part1" -gt "$part2" ]]; then
      echo "1" # ver1 is greater
      return
    elif [[ "$part1" -lt "$part2" ]]; then
      echo "-1" # ver2 is greater
      return
    fi
  done

  echo "0" # Versions are equal
  return
}


# Help function with usage details
helpFunction() {
  echo -e $LIGHT_BLUE "USAGE." $NC
  echo -e $RED "Use the below options to input the target image registry and K10 version details"
  echo -e "  Syntax: ./imagePush.sh -t <target_registry> -v <k10_version> [-c <client>] [-h]" $NC
  echo -e "  options:"
  echo -e "  -t    Target image registry to which the images need to be pushed. (Mandatory)"
  echo -e "  -v    K10 version. (Mandatory)"
  echo -e "  -c    Client used to push/pull images - Supported arguments are docker & podman (defaults to podman)"
  echo -e "  -h    Print this Help."
  exit 1
}

# Function to get image list
get_image_list() {
  local k10_version="$1"
  local client="$2"
  local images=""
  local comparison_result

  comparison_result=$(compare_versions "$k10_version" "7.5.0")

  # Send informational messages to stderr (> &2)
  echo -e "${GREEN}Attempting to retrieve image list using '$client'...${NC}" >&2

  if [[ "$comparison_result" -ge 0 ]]; then
    # Send informational messages to stderr (> &2)
    echo -e "${LIGHT_BLUE}Using k10tools for K10 version $k10_version (>= 7.5.0)${NC}" >&2
    # Capture only the command output to stdout
    images=$(${client} run --rm gcr.io/kasten-images/k10tools:${k10_version} image list | tr -d '\r') || {
        # Error messages already go to stderr
        echo -e "${RED}Error: Failed to get image list using k10tools with '$client'.${NC}" >&2
        echo -e "${RED}Check if '$client' daemon/service is running and you have permissions.${NC}" >&2
        exit 1
    }
  else
    # Send informational messages to stderr (> &2)
    echo -e "${LIGHT_BLUE}Using k10offline for K10 version $k10_version (< 7.5.0)${NC}" >&2
     # Capture only the command output to stdout
    images=$(${client} run --rm gcr.io/kasten-images/k10offline:${k10_version} list-images | tr -d '\r') || {
        # Error messages already go to stderr
        echo -e "${RED}Error: Failed to get image list using k10offline with '$client'.${NC}" >&2
        echo -e "${RED}Check if '$client' daemon/service is running and you have permissions.${NC}" >&2
        exit 1
    }
  fi
  # This echo sends the actual image list to stdout, which IS captured
  echo "$images"
}


# Function to generate pull commands
# * Keep jimmidyson check for docker.io prefix *
generate_pull_commands() {
  local images="$1"
  local client="$2"

  echo
  echo -e $GREEN $BOLD "=====Commands to pull the images locally===============" $NC
  echo

  for i in $images; do
    [[ -z "$i" ]] && continue
    if [[ $i == jimmidyson* ]]; then
      echo "${client} pull docker.io/$i"
    else
      echo "${client} pull $i"
    fi
  done
}

# Function to generate re-tag commands
# * Keep jimmidyson check as requested ("as is before") *
generate_retag_commands() {
  local images="$1"
  local target_registry="$2"
  local client="$3"

  echo
  echo -e $GREEN $BOLD "=====Commands to re-tag the images with your image registry===============" $NC
  echo

  for j in $images; do
    [[ -z "$j" ]] && continue
    local tag=$(echo "$j" | cut -f 2 -d ':')
    if [[ -z "$tag" ]]; then
      echo -e "${RED}Warning: Could not extract tag from image '$j'. Skipping re-tag.${NC}" >&2
      continue
    fi
    local k10tag="k10-$tag"
    local imagenamewithouttag=$(echo "$j" | awk -F '/' '{print $NF}' | cut -f 1 -d ':')

    # Use $j as the source image (assuming it's pulled)
    # Apply specific logic based on source image for the TARGET tag format
    if [[ $j == jimmidyson* ]]; then
      # Target tag uses k10- prefix
      echo "${client} tag $j ${target_registry}/${imagenamewithouttag}:${k10tag}"
    elif [[ $j == gcr.* ]]; then
      # Target tag uses original tag
      echo "${client} tag $j ${target_registry}/${imagenamewithouttag}:${tag}"
    else
      # Target tag uses k10- prefix for other non-gcr images
      echo "${client} tag $j ${target_registry}/${imagenamewithouttag}:${k10tag}"
    fi
  done
}

# Function to generate push commands
# * Simplified logic as requested (no jimmidyson check needed HERE) *
generate_push_commands() {
  local images="$1"
  local target_registry="$2"
  local client="$3"

  echo
  echo -e $GREEN $BOLD "=====Commands to push the images to your image registry===============" $NC
  echo

  for j in $images; do
    [[ -z "$j" ]] && continue
    local tag=$(echo "$j" | cut -f 2 -d ':')
    if [[ -z "$tag" ]]; then
      echo -e "${RED}Warning: Could not extract tag from image '$j'. Skipping push.${NC}" >&2
      continue
    fi
    local k10tag="k10-$tag"
    local imagenamewithouttag=$(echo "$j" | awk -F '/' '{print $NF}' | cut -f 1 -d ':')

    # Simplified logic: Push with original tag for gcr.io, push with k10- prefix for all others
    if [[ $j == gcr.* ]]; then
      echo "${client} push ${target_registry}/${imagenamewithouttag}:${tag}"
    else
      # This covers jimmidyson and any other non-gcr.io image for the PUSH command
      echo "${client} push ${target_registry}/${imagenamewithouttag}:${k10tag}"
    fi
  done
}

# --- Main Script Logic ---

# Default client to use podman if the option is not provided while running the script
CLIENT="podman"
TARGET_REGISTRY=""
K10_VERSION=""

while getopts "t:v:c:h" opt; do
  case "$opt" in
  t) TARGET_REGISTRY="$OPTARG" ;;
  v) K10_VERSION="$OPTARG" ;;
  c) CLIENT="$OPTARG" ;;
  h) helpFunction ;;
  \?) echo -e "${RED}Invalid option: -$OPTARG${NC}" >&2; helpFunction ;;
  :) echo -e "${RED}Option -$OPTARG requires an argument.${NC}" >&2; helpFunction ;;
  esac
done
shift $((OPTIND-1)) # Remove parsed options

# Validate client argument
if [[ "$CLIENT" != "podman" && "$CLIENT" != "docker" ]]; then
    echo -e "${RED}Error: Invalid client specified: '$CLIENT'. Must be 'podman' or 'docker'.${NC}" >&2
    helpFunction
fi

# Check if mandatory arguments are provided
if [[ -z "$TARGET_REGISTRY" || -z "$K10_VERSION" ]]; then
  echo -e "${RED}Error: Target registry (-t) and K10 version (-v) are mandatory.${NC}" >&2
  helpFunction
fi

# --- START: Unified Client Binary Check ---
# Check if the selected client binary ($CLIENT) exists in the PATH
echo -e "${LIGHT_BLUE}Verifying selected client '$CLIENT' is available...${NC}" >&2 # Also redirect this
if ! command -v "$CLIENT" &> /dev/null; then
  echo -e "${RED}Error: The selected client '$CLIENT' command was not found in your PATH.${NC}" >&2
  echo -e "${RED}Please install '$CLIENT' or ensure its location is included in your PATH environment variable.${NC}" >&2
  if [[ "$CLIENT" == "podman" ]]; then
    echo -e "${RED}If docker is installed, you could try running the script with '-c docker'.${NC}" >&2
  elif [[ "$CLIENT" == "docker" ]]; then
     echo -e "${RED}If podman is installed, you could try running the script without '-c' (uses podman by default) or with '-c podman'.${NC}" >&2
  fi
  exit 1
else
   echo -e "${GREEN}Client '$CLIENT' found.${NC}" >&2 # Also redirect this
fi
# --- END: Unified Client Binary Check ---


# Fetch the image list
# Send informational messages to stderr (> &2)
echo -e "${LIGHT_BLUE}Fetching image list for K10 version $K10_VERSION...${NC}" >&2
IMAGES_LIST=$(get_image_list "$K10_VERSION" "$CLIENT")

if [[ -z "$IMAGES_LIST" ]]; then
    echo -e "${RED}Error: Failed to retrieve a list of images. The list was empty.${NC}" >&2
    echo -e "${RED}Please check the K10 version '$K10_VERSION' is valid and that '$CLIENT' can pull and run images from gcr.io/kasten-images.${NC}" >&2
    exit 1
fi
# Send informational messages to stderr (> &2)
echo -e "${GREEN}Successfully retrieved image list.${NC}" >&2

# Generate the commands
generate_pull_commands "$IMAGES_LIST" "$CLIENT"
generate_retag_commands "$IMAGES_LIST" "$TARGET_REGISTRY" "$CLIENT"
generate_push_commands "$IMAGES_LIST" "$TARGET_REGISTRY" "$CLIENT"

echo # Keep this echo to stdout for spacing if desired
# Send informational messages to stderr (> &2)
echo -e $GREEN $BOLD "===== Script finished =====" $NC >&2
exit 0
