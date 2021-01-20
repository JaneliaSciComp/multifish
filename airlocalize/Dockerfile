FROM centos:8

ENV MATLAB_VERSION=R2018b
ENV DOWNLOAD_FILENAME=MCR_${MATLAB_VERSION}_glnxa64_installer.zip
ENV DOWNLOAD_MATLAB_URL=https://ssd.mathworks.com/supportfiles/downloads/${MATLAB_VERSION}/deployment_files/${MATLAB_VERSION}/installers/glnxa64/${DOWNLOAD_FILENAME}
ENV DOWNLOAD_CONDA_URL=https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh

RUN dnf install -y \
        wget unzip \
        libXt libXext libXmu libXrender libXcomposite
        
RUN mkdir /tmp-install && \
    cd /tmp-install && \
    wget --quiet ${DOWNLOAD_MATLAB_URL} && \
    unzip ${DOWNLOAD_FILENAME} && \
    rm -f ${DOWNLOAD_FILENAME} && \
    ./install -mode silent -agreeToLicense yes && \
    wget ${DOWNLOAD_CONDA_URL} -O miniconda-install.sh && \
    bash miniconda-install.sh -b -p /miniconda && \
    rm miniconda-install.sh && \
    rm -rf /tmp-install

WORKDIR /app

ENV PATH=/miniconda/bin:${PATH}

ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:\
/usr/local/MATLAB/MATLAB_Runtime/v95/runtime/glnxa64:\
/usr/local/MATLAB/MATLAB_Runtime/v95/bin/glnxa64:\
/usr/local/MATLAB/MATLAB_Runtime/v95/sys/os/glnxa64:\
/usr/local/MATLAB/MATLAB_Runtime/v95/sys/opengl/lib/glnxa64:\
/usr/local/MATLAB/MATLAB_Runtime/v95/sys/java/jre/glnxa64/jre/lib/amd64/server:\
/usr/local/MATLAB/MATLAB_Runtime/v95/sys/java/jre/glnxa64/jre/lib/amd64
ENV XAPPLRESDIR=/usr/local/MATLAB/MATLAB_Runtime/v95/X11/app-defaults
ENV MCR_CACHE_VERBOSE=true

COPY compiled_matlab /app/airlocalize
COPY scripts/python /app/airlocalize/scripts
COPY params /app/airlocalize/params

COPY conda-requirements.txt .

RUN conda config --set always_yes yes --set changeps1 no && \
    conda update -q conda && \
    conda info -a && \
    conda install python=3.6 && \
    conda install -c conda-forge z5py && \
    conda install --file conda-requirements.txt && \
    rm -f conda-requirements.txt

RUN cd /app/airlocalize && \
    python setup.py install

WORKDIR /app/airlocalize

