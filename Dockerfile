FROM ubuntu:18.04

# set Miniconda3 in path
ENV PATH="/root/miniconda3/bin:${PATH}"
ARG PATH="/root/miniconda3/bin:${PATH}"
ENV PORT=8180

RUN apt update && apt upgrade -y
RUN apt install software-properties-common wget curl libcurl4 vim -y

# Anaconda (MiniConda) https://docs.conda.io/projects/conda/en/latest/user-guide/install/macos.html
RUN wget \
    https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh \
    && mkdir -p /root/.conda \
    && bash Miniconda3-latest-Linux-x86_64.sh -b \
    && rm -f Miniconda3-latest-Linux-x86_64.sh

# conda env setup
RUN conda init bash

# install all Anaconda packages silently
RUN conda config --env --set always_yes true

# add channels
RUN conda config --add channels defaults
RUN conda config --add channels bioconda
RUN conda config --add channels conda-forge
RUN conda config --set channel_priority strict

# Snakefile dependencies
RUN conda update conda

RUN conda install mamba

# RUN conda init bash
# RUN conda create -n ogv python=3.9
# # RUN conda init ogv
# RUN conda activate ogv

RUN conda install python=3.9
RUN conda install snakemake
RUN conda install raxml-ng
RUN conda install bioconda:hyphy==2.5.61
RUN conda install mafft==7.508
RUN mamba install nodejs==12.4.0

# Conda installs FastTree Double-Precision
# Use this version for unique branch lengths
COPY ./FastTree /usr/bin/FastTree

# result-summary.py dependency
RUN pip3 install biopython

WORKDIR /home/node/app

COPY package.json /home/node/app/package.json
RUN npm install

EXPOSE $PORT

# BUILD HYPHY DEVELOPMENT BRANCH
#add-apt-repository ppa:ubuntu-toolchain-r/test -y
#apt update
#apt install git build-essential gcc-12 g++-12 -y
#mamba install cmake=3.12.2
# CC=/path/to/gcc/12.2.0/bin/gcc CXX=/path/to/gcc/12.2.0/bin/g++ cmake ./
#git clone https://github.com/veg/hyphy /home/node/hyphy -b development
# cd /home/node/hyphy && cmake . && make -j MP

CMD sleep infinity
