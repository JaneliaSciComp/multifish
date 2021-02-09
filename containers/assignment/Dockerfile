FROM centos:8

ENV DOWNLOAD_CONDA_URL=https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh

RUN dnf install -y \
        wget

RUN mkdir /tmp-install && \
    cd /tmp-install && \
    wget ${DOWNLOAD_CONDA_URL} -O miniconda-install.sh && \
    bash miniconda-install.sh -b -p /miniconda && \
    rm miniconda-install.sh && \
    rm -rf /tmp-install
    
ENV PATH=/miniconda/bin:${PATH}

WORKDIR /app

COPY scripts/python/intensity_measurement /app/intensity_measurement/scripts

COPY scripts/python/spot_assignment /app/spot_assignment/scripts

COPY conda-requirements.yml .

RUN conda config --set always_yes yes --set changeps1 no && \
    conda update -q conda

RUN conda install python=3.6

RUN conda env update -n base -f conda-requirements.yml && \
    rm -f conda-requirements.yml
