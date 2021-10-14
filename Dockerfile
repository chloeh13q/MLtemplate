# https://github.com/rapidsai/gpuci-build-environment
ARG FROM_IMAGE
ARG CUDA_VER
ARG IMAGE_TYPE
ARG LINUX_VER

FROM ${FROM_IMAGE}:cuda${CUDA_VER}-${IMAGE_TYPE}-${LINUX_VER}

# TODO: Add other package dependencies here
# Specify version wherever possible/necessary
RUN source activate rapids && pip install papermill

# Change working directory to mounted host volume
# Jupyter will be started from this directory
ARG CONTAINER_DEST

WORKDIR ${CONTAINER_DEST}