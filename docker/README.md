# Running WRF in Docker

The [`Dockerfile`](../Dockerfile) at the repo root compiles WRF with GNU
gfortran/gcc, OpenMPI (`dmpar`) and NetCDF on Ubuntu 24.04. It then packages
one idealized case into a slim runtime image of about 650 MB.

## Build

```bash
docker build -t wrf:em_quarter_ss .
```

The compile takes about 15 minutes on 16 cores.

| Build arg    | Default         | Meaning                                                     |
|--------------|-----------------|-------------------------------------------------------------|
| `WRF_CASE`   | `em_quarter_ss` | Idealized case to compile (`em_b_wave`, `em_hill2d_x`, ...) |
| `CONFIG_OPT` | `34`            | `./configure` menu choice (34 = x86_64 gfortran/gcc dmpar)  |
| `JOBS`       | `8`             | Parallel make jobs                                          |

## Run

```bash
mkdir -p out
docker run --rm --shm-size=1g -v "$PWD/out:/work" wrf:em_quarter_ss
```

The entrypoint ([`run-case.sh`](run-case.sh)) does the following:

1. Copies the case into `/work`. Files already there are kept, so you can drop in
   your own `namelist.input` or `input_sounding` first.
2. Runs `ideal.exe`.
3. Runs `mpirun -np $NP wrf.exe`.

History output (`wrfout_d01_*`) and `rsl.*` logs land in `out/`.

- Set the number of MPI ranks with `-e NP=8`.
- The container runs as UID 1000. If your host UID differs, add
  `--user "$(id -u):$(id -g)"`.
- Pass a command to get a shell or run tools inside the case directory, for example
  `docker run --rm -it -v "$PWD/out:/work" wrf:em_quarter_ss bash` or
  `... wrf:em_quarter_ss ncdump -h wrfout_d01_0001-01-01_00:00:00`.

## Scope

Only idealized cases are packaged. Real-data runs (`em_real`) also need WPS and
the static geography dataset, which this image doesn't include.
