FROM oraclelinux:9

ARG TARGETPLATFORM

ENV MATLAB_RUNTIME_VERSION=R2023b

RUN dnf update -y && \
    dnf install -y \
        wget unzip \
        java-1.8.0-openjdk

RUN dnf install -y \
        atk \
        gsound \
        gdk-pixbuf2 \
        gtk2 \
        libnsl \
        libX11 \
        libX11-xcb \
        libXScrnSaver \
        libXxf86vm \
        nss \
        zlib

RUN dnf install -y \
        libXt libXtst libXext libXmu libXrandr libXrender libXcomposite

WORKDIR /tmp-install

# Download and install conda
ENV PATH=/miniconda/bin:${PATH}

RUN wget https://repo.anaconda.com/miniconda/Miniconda3-py311_23.5.2-0-Linux-$(uname -m).sh \
        -nv -O miniconda-install.sh && \
    bash miniconda-install.sh -b -p /miniconda && \
    conda config --set always_yes yes --set changeps1 no && \
    conda update -n base conda && \
    conda install -n base conda-libmamba-solver && \
    conda config --set solver libmamba && \
    conda install python=3.11

# Download and install Matlab
RUN wget https://ssd.mathworks.com/supportfiles/downloads/R2023b/Release/0/deployment_files/installer/complete/glnxa64/MATLAB_Runtime_R2023b_glnxa64.zip \
        -nv -O matlab-runtime-package.zip && \
    unzip matlab-runtime-package.zip && \
    ./install -mode silent -agreeToLicense yes && \
    rm -f matlab-runtime-package.zip

ENV LD_LIBRARY_PATH=/usr/lib64:/usr/lib:\
/usr/local/MATLAB/MATLAB_Runtime/${MATLAB_RUNTIME_VERSION}/runtime/glnxa64:\
/usr/local/MATLAB/MATLAB_Runtime/${MATLAB_RUNTIME_VERSION}/bin/glnxa64:\
/usr/local/MATLAB/MATLAB_Runtime/${MATLAB_RUNTIME_VERSION}/sys/os/glnxa64:\
/usr/local/MATLAB/MATLAB_Runtime/${MATLAB_RUNTIME_VERSION}/sys/opengl/lib/glnxa64

ENV XAPPLRESDIR=/usr/local/MATLAB/MATLAB_Runtime/${MATLAB_RUNTIME_VERSION}/X11/app-defaults

ENV MCR_CACHE_VERBOSE=true
ENV KMP_DUPLICATE_LIB_OK=TRUE

RUN cd /usr/local/MATLAB/MATLAB_Runtime/${MATLAB_RUNTIME_VERSION}/toolbox/compiler_sdk/pysdk_py && \
    python setup.py install

WORKDIR /app/airlocalize

# Install all required conda packages
COPY conda-requirements.yml .
RUN conda env update -n base -f conda-requirements.yml

# Copy code to the container
COPY compiled_matlab /app/airlocalize
COPY compiled_matlab/AIRLOCALIZE_N5/AIRLOCALIZE_N5.ctf /app/airlocalize/compiled_matlab/AIRLOCALIZE_N5

COPY scripts/python /app/airlocalize/scripts
COPY params /app/airlocalize/params

RUN cd /app/airlocalize && \
    python setup.py install

COPY scripts/*.sh /app/airlocalize
RUN chmod 555 /app/airlocalize/*.sh
