#To build;
# docker build -t jettoyhidocker .
# to run;
# mkdir output
# docker run -v $(pwd)/output:/tohost -ti jettoyhidocker

# base image - contains root
FROM rootproject/root:latest

# some meta data
LABEL version=1.0
LABEL description="A docker container for JetQuenchingTools/JetToyHI, from the authors of https://arxiv.org/pdf/1808.03689.pdf"
LABEL author="Henry Day-Hall"

# install package manager packages
RUN apt update && \
    apt -y install python3 \
                   vim-tiny nano \
                   make g++ xutils-dev \
                   git
RUN echo "alias vim=vim.tiny" >> ~/.bashrc

ENV PROGRAMS_DIR=/opt

# download fastjet
RUN cd $PROGRAMS_DIR && \
    curl http://fastjet.fr/repo/fastjet-3.3.4.tar.gz --output fastjet-3.3.4.tar.gz && \
    tar zxvf fastjet-3.3.4.tar.gz

# make and check
# may get some errors here - it still passes checks
RUN cd $PROGRAMS_DIR/fastjet-3.3.4 && \
    ./configure --prefix=$PWD/../fastjet-install && \
    make && \
    make check && \
    make install 

ENV FASTJET=$PROGRAMS_DIR/fastjet-install

# download the fastjet contrib fragile packake
ENV FJ_CONTRIB_VER="1.041"
RUN cd $PROGRAMS_DIR && \
    ADDRESS="http://fastjet.hepforge.org/contrib/downloads/fjcontrib-"${FJ_CONTRIB_VER}".tar.gz" && \
    curl -L $ADDRESS --output fastjet_contrib.tar.gz  && \
    tar xzf fastjet_contrib.tar.gz

# make
RUN cd $PROGRAMS_DIR/fjcontrib-${FJ_CONTRIB_VER}  && \
    ./configure --fastjet-config=$FASTJET/bin/fastjet-config --prefix=`$FASTJET/bin/fastjet-config --prefix` && \
    make && \
    make install && \
    make fragile-shared && \
    make fragile-shared-install

# download pythia
RUN cd $PROGRAMS_DIR && \
    curl http://home.thep.lu.se/~torbjorn/pythia8/pythia8303.tgz --output pythia8303.tgz && \
    tar xvfz pythia8303.tgz

# make and check
RUN cd $PROGRAMS_DIR/pythia8303 && \
    ./configure --with-root && \
    make && \
    cd examples && \
    ./runmains

ENV PYTHIA8=$PROGRAMS_DIR/pythia8303

# download JetToyHI package
RUN git clone https://github.com/JetQuenchingTools/JetToyHI.git

# tell it where to find pythia and fastjet
RUN echo $FASTJET > $PROGRAMS_DIR/JetToyHI/.fastjet  && \
    echo $FASTJET > $PROGRAMS_DIR/JetToyHI/PU14/.fastjet  && \
    echo $PYTHIA8 > $PROGRAMS_DIR/JetToyHI/.pythia8  && \
    echo $PYTHIA8 > $PROGRAMS_DIR/JetToyHI/PU14/.pythia8

# make it
RUN cd $PROGRAMS_DIR/JetToyHI/PU14 && \
    ./mkmk  && \
    make    && \
    cd ../  && \
    scripts/mkcxx.pl -f -s -1 -r -8 '-IPU14' -l '-LPU14 -lPU14 -lz' && \
    make

# test run
RUN cd $PROGRAMS_DIR/JetToyHI  && \
    ./runFromFile -hard samples/PythiaEventsTune14PtHat120.pu14 -pileup samples/ThermalEventsMult12000PtAv0.70.pu14 -nev 10

# clean up
RUN rm $PROGRAMS_DIR/*gz

# overwrite root dockers tendancy to launch root
CMD /bin/bash
