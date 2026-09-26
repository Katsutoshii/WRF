#!/bin/bash
# Run the idealized case baked into the image: ideal.exe, then wrf.exe under MPI.
# Output (wrfout_*, rsl.*) lands in /work. Set NP for the number of MPI ranks.
set -euo pipefail

cd /work
# Seed the work dir from the image, keeping any namelist/sounding the user provided.
cp -r --update=none /opt/wrf/case/. /work/

if [ "$#" -gt 0 ]; then
    exec "$@"
fi

echo ">>> ideal.exe"
./ideal.exe
tail -n 1 rsl.out.0000 2>/dev/null || true

echo ">>> wrf.exe on ${NP} ranks"
mpirun -np "${NP}" ./wrf.exe
tail -n 3 rsl.out.0000

grep -q "SUCCESS COMPLETE WRF" rsl.out.0000
ls -lh wrfout_* 
