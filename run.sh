#!/bin/bash
interactive=false
if [ "$1" = "--interactive" ]; then
    interactive=true
fi

# Helper function to parse yaml file as environment variables
# Reference: https://gist.github.com/pkuczynski/8665367
parse_yaml() {
    local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
    sed -ne "s|^\($s\)\($w\)$s:$s\"\(.*\)\"$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
    awk -F$fs '{
        indent = length($1)/2;
        vname[indent] = $2;
        for (i in vname) {if (i > indent) {delete vname[i]}}
        if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
         printf("%s%s=\"%s\"\n", vn, $2, $3);
        }
    }'
}

# Helper function to print timestamp in place of echo
function timestamp() {
    printf "[$(date "+%Y-%m-%d %T")] $(date -ud "@$SECONDS" "+elapsed: %T") %s\n" "$*" >&2
    SECONDS=0
}
SECONDS=0

# Read yaml file
eval $(parse_yaml parameters.yaml)
timestamp "Parsed parameters from parameters.yaml"

# Log output to file
if [ "$1" = "--logging" ]; then
    mkdir -p ${LOGDIR}
    exec >${LOGDIR}/$EPOCHSECONDS.log 2>&1
fi

# GitLab CI/CD doesn't yet support the feature to run after_script when jobs are canceled...
# Ref: https://gitlab.com/gitlab-org/gitlab-runner/-/issues/4843
# Ref: https://gitlab.com/gitlab-org/gitlab/-/issues/15603
# Run manual clean-up
docker ps -q --filter "name=$NAME" | grep -q . && docker stop $NAME

# Pull Docker image
timestamp "Pulling Docker image..."
docker build --network=host -t $NAME . \
    --build-arg FROM_IMAGE=${FROM_IMAGE} \
    --build-arg CUDA_VER=${CUDA_VER} \
    --build-arg IMAGE_TYPE=${IMAGE_TYPE} \
    --build-arg LINUX_VER=${LINUX_VER} \
    --build-arg CONTAINER_DEST=${CONTAINER_DEST}
timestamp "Done"

# Start Docker container
# --network='host' fixes known issue with accessing resources while on VPN
# --user sets UID/GID
# %store magic doesn't work with when user flag is set as --user $(id -u):$(id -g)
# -v mounts local volume (to /rapids/notebooks/host to be consistent with container documentation)
# -a binds to container's STDIN, STDOUT, & STDERR
# `Docker runs as `root` user by default & creates files owned by `root` user that can't be cleaned up by `git clean -ffdx` in the next run
# Change file mode creation mask temporarily as workaround; note that files created by Docker are now world-writable files
timestamp "Start running Docker container..."
if [ $interactive = true ]; then 
    docker run --rm -it \
        --name $NAME \
        --gpus ${GPUS} \
        --network='host' \
        -v ${PWD}:${CONTAINER_DEST} \
        $NAME \
        /bin/bash
else
    docker run --rm \
        --name $NAME \
        --gpus ${GPUS} \
        --network='host' \
        -v ${PWD}:${CONTAINER_DEST} \
        --log-driver=none -a stdin -a stdout -a stderr \
        $NAME \
        /bin/bash -c "mask=$(umask); \
        umask 0 && echo File mode creation mask set to $(umask); \
        mkdir -p output && \
        echo Running notebooks... && \
        papermill 01_download.ipynb output/01_download_output_$EPOCHSECONDS.ipynb -f parameters.yaml && \
        papermill 02_preprocess.ipynb output/02_preprocess_output_$EPOCHSECONDS.ipynb -f parameters.yaml && \
        papermill 03_model.ipynb output/03_model_output_$EPOCHSECONDS.ipynb -f parameters.yaml && \
        papermill 04_deploy.ipynb output/04_deploy_output_$EPOCHSECONDS.ipynb -f parameters.yaml && \
        umask ${mask} && echo File mode creation mask set to $(umask)"
fi
timestamp "Done"