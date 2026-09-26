# syntax=docker/dockerfile:1
#
# Build WRF (GNU gfortran/gcc, dmpar + OpenMPI) and package an idealized case.
#
#   docker build -t wrf .
#   docker run --rm --shm-size=1g -v "$PWD/out:/work" wrf
#
# See docker/README.md for details.
#
# Build args:
#   WRF_CASE    idealized case to compile (em_quarter_ss, em_b_wave, em_hill2d_x, ...)
#   CONFIG_OPT  ./configure menu choice (34 = Linux x86_64 GNU gfortran/gcc dmpar)
#   JOBS        parallel make jobs

############################ builder ############################
FROM ubuntu:24.04 AS builder

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
        gfortran gcc g++ cpp make m4 perl csh file \
        libnetcdf-dev libnetcdff-dev netcdf-bin libhdf5-dev \
        libopenmpi-dev openmpi-bin \
        libtirpc-dev zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# WRF's configure expects a single $NETCDF prefix holding both the C and Fortran
# libraries; Debian splits them across multiarch dirs, so stitch a prefix together.
RUN mkdir -p /opt/netcdf && \
    ln -s /usr/include /opt/netcdf/include && \
    ln -s /usr/lib/x86_64-linux-gnu /opt/netcdf/lib && \
    ln -s /usr/bin /opt/netcdf/bin
ENV NETCDF=/opt/netcdf \
    NETCDF_classic=1 \
    WRFIO_NCD_LARGE_FILE_SUPPORT=1

ARG WRF_CASE=em_quarter_ss
ARG CONFIG_OPT=34
ARG JOBS=8

WORKDIR /src/WRF
# Leave the container packaging out so editing it doesn't invalidate the compile cache.
COPY --exclude=Dockerfile --exclude=.dockerignore --exclude=docker . .

# configure: menu choice, then nesting (1 = basic)
RUN printf '%s\n1\n' "${CONFIG_OPT}" | ./configure && \
    grep -q '^SFC *= *gfortran' configure.wrf && \
    grep -q 'DMPARALLEL' configure.wrf

RUN ./compile -j "${JOBS}" "${WRF_CASE}" > compile.log 2>&1; \
    tail -n 30 compile.log; \
    test -x main/wrf.exe && test -x main/ideal.exe

# Flatten the case directory (it's a tree of symlinks into run/ and main/).
RUN mkdir -p /opt/wrf && cp -rL "test/${WRF_CASE}" /opt/wrf/case && \
    rm -f /opt/wrf/case/CMakeLists.txt && \
    cp compile.log configure.wrf /opt/wrf/

############################ runtime ############################
FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
        libgfortran5 libnetcdf19t64 libnetcdff7 libhdf5-103-1t64 \
        openmpi-bin libopenmpi3t64 libtirpc3t64 netcdf-bin \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /opt/wrf /opt/wrf
COPY docker/run-case.sh /usr/local/bin/run-case

# Shared-memory single-copy (CMA) needs ptrace, which containers usually lack.
ENV OMPI_MCA_btl_vader_single_copy_mechanism=none \
    OMPI_MCA_rmaps_base_oversubscribe=1 \
    NP=4

# ubuntu:24.04 ships an "ubuntu" user with UID 1000, which matches the usual host
# user so bind-mounted output stays writable. Otherwise pass --user "$(id -u):$(id -g)".
RUN mkdir -p /work && chown ubuntu:ubuntu /work
USER ubuntu
WORKDIR /work
VOLUME /work

ENTRYPOINT ["run-case"]
