FROM oraclelinux:8

ARG TARGETPLATFORM

ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=all

RUN dnf update -y && \
    dnf group install -y "Development Tools" && \
    dnf install -y \
        git wget \
        ocl-icd

RUN mkdir /tmp-install && \
    cd /tmp-install && \
    wget https://github.com/conda-forge/miniforge/releases/download/4.9.2-7/Mambaforge-4.9.2-7-Linux-$(uname -m).sh \
        -O mamba-install.sh && \
    bash mamba-install.sh -b -p /miniconda

ENV PATH=/miniconda/bin:${PATH}

COPY conda-requirements.yml /tmp-install/
RUN mamba env update -n base -f /tmp-install/conda-requirements.yml

WORKDIR /app/segmentation

COPY scripts/python /app/segmentation/scripts
