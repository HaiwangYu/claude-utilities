# wire-cell-toolkit — build environment

This project must be built inside the Fermilab SL7 apptainer with the
per-experiment wirecell environment sourced. **Do not run `./wcb`, `cmake`,
`pytest`, or compiled test binaries directly on the host** — they will pick
up the wrong toolchain (host system gcc/spdlog instead of `e26 prof` from
cvmfs) and fail in confusing ways.

The experiment is determined from the hostname (`<exp>{gpvm,build}NN.fnal.gov`)
and exported as `$CURRENT_EXPERIMENT`.

## How to build / test

Prefix every build or test command with the SL7 wrapper from
`/exp/dune/app/users/yuhw/claude-utilities`. It is a non-interactive mirror
of the user's interactive `sl7` shell function + the per-experiment
`setup.sh`.

- Full build: `/exp/dune/app/users/yuhw/claude-utilities/in-gpvm-sl7.sh ./wcb -p --notests build install`
- Single subpackage: `… in-gpvm-sl7.sh ./wcb --notests --target=WireCellApps`
- Run a unit test binary: `… in-gpvm-sl7.sh build/util/test_<foo>`
- Inspect environment: `… in-gpvm-sl7.sh bash -c 'which wcb; echo $CMAKE_PREFIX_PATH'`

## Fresh clone + configure + build

`/exp/sbnd/app/users/yuhw/claude-utilities/build-wct.sh` clones
wire-cell-toolkit fresh, checks out a ref/PR (or merges a PR into a base
ref), runs `./wcb configure` with all dependency paths from the sourced
environment (`$TBBROOT`, `$ROOTSYS`, `$BOOST_*`, `$HDF5_FQ_DIR`,
`$LIBTORCH_FQ_DIR`, …), and builds + installs. Must be invoked through
the SL7 wrapper so those vars are populated.

Usage: `build-wct.sh <ref|pr|merge-pr> <tag|master|PR#> <src_dir> <install_dir> [base_ref]`

- Build a tag/master:
  `… in-gpvm-sl7.sh /exp/sbnd/app/users/yuhw/claude-utilities/build-wct.sh ref master ~/wct/src ~/wct/install`
- Build a PR head as-is:
  `… in-gpvm-sl7.sh …/build-wct.sh pr 1234 ~/wct/src ~/wct/install`
- Build a PR merged into a base ref:
  `… in-gpvm-sl7.sh …/build-wct.sh merge-pr 1234 ~/wct/src ~/wct/install master`

Existing `<src_dir>` is removed before cloning. Build log is written to
`<src_dir>/build.log`.

## Environment source of truth

- Image: `/cvmfs/singularity.opensciencegrid.org/fermilab/fnal-dev-sl7:latest`
- Experiment selector: `/exp/dune/app/users/yuhw/claude-utilities/set-current-experiment.sh`
  (parses the FQDN, exports `CURRENT_EXPERIMENT`)
- Wrapper: `/exp/dune/app/users/yuhw/claude-utilities/in-gpvm-sl7.sh`
  (auto-sources the selector if `CURRENT_EXPERIMENT` is unset; binds `/cvmfs,/exp,/nashome,/opt,...` into the container)
- Setup script: **user-provided, chosen at run time** for the task at hand
  (sets up the experiment's UPS/Spack environment plus user paths). It is not a
  fixed path — pick the one that matches the purpose, e.g. for SBND:
  `sbnd/setup-local-opt.sh` (legacy `opt` install), `sbnd/setup-ap.sh`
  (AP matching/imaging: toolkit cfg + sbnd_xin + photodet), or
  `setup-0.35.0.sh`. Source it inside the container after
  `source /nashome/y/yuhw/.bashrc`.

## Quick CPU / memory vs time profiling

For a lightweight per-process CPU and memory timeline (no perf/valgrind setup),
use the scripts at <https://github.com/HaiwangYu/activity_logger> as a
reference:

- `top.sh <program-name>` — bash sampler that logs `top` metrics for a named
  process; redirect to a file (`./top.sh my-prog | tee log`).
- `cpu-plot.py` — plots CPU% and RSS over time from that log.
- `nvidia-smi.sh` + `gpu-plot.py` — same idea for GPU jobs.

Use this when you need a fast "did memory grow / where did CPU go" view of a
running build or test; reach for `perf`/`valgrind massif` only when you need
finer attribution.

## Hints to compile larwirecell

larwirecell (the `wcls*` art modules + the WCT `QLMatching` plugin) is built
under MRB, separately from wire-cell-toolkit, and its runtime libs are
**hand-copied** into the `opt` install. Build only inside the SL7 apptainer.

### Source tree

- **MRB tree (the only one to use):**
  `/exp/sbnd/app/users/yuhw/larsoft-wct036/v10_14_02/srcs/larwirecell/`
  (this is the `local larwirecell` path in the project CLAUDE.md). Edit and
  build here.

(Do NOT use `/exp/sbnd/app/users/yuhw/larwirecell/` for now.)

### Build + install to runtime

1. Inside the container, source the SBND setup, then `mrbsetenv` (NOT `mrbslp`
   alone — `mrbslp` fails larwirecell with a "larevt v10_00_17 vs v10_00_16"
   version conflict; `mrbsetenv` loads the build-dir larwirecell that works).
   In non-interactive shells, `source /nashome/y/yuhw/.bashrc` first (for
   `path-prepend`/`rs`) and do not run under `set -u` (setup_sbnd.sh references
   `$UPS_OVERRIDE` unconditionally). See [[project-wct-0-35-setup]].
2. Build against the existing CMake cache (avoids the re-cmake landmines below):
   `make -j8 install` in `$MRB_BUILDDIR/larwirecell`. Install lands in
   `$MRB_INSTALL/larwirecell/v10_01_28/slf7.x86_64.e26.prof/lib/`.
3. **Hand-copy to the runtime dir** that `sbnd/setup-local-opt.sh` /
   `setup-ap.sh` load (separate inodes from `$MRB_INSTALL`, so this step is
   required for the change to take effect):
   `cp $MRB_INSTALL/larwirecell/v10_01_28/slf7.x86_64.e26.prof/lib/lib*.so \`
   `   /exp/sbnd/app/users/yuhw/opt/larwirecell/v10_01_28/slf7.x86_64.e26.prof/lib/`

### Re-cmake landmines (only when CMakeCache.txt is wiped / fresh build dir)

- `FindWireCell.cmake` needs `export WIRECELL_FQ_DIR=/exp/sbnd/app/users/yuhw/opt`
  (+ prepend that to `CMAKE_PREFIX_PATH`); otherwise it finds the cvmfs WCT
  v0_32_1 product, which **lacks `WireCellIface/IDetectorVolumes.h`** and
  `QLMatching.cxx` won't compile.
- A bare `cmake $MRB_SOURCE/larwirecell` loses `CMAKE_INSTALL_PREFIX` (defaults
  to `/usr/local`, fails at install) — pass
  `-DCMAKE_INSTALL_PREFIX=$MRB_INSTALL/larwirecell/v10_01_28/slf7.x86_64.e26.prof`
  or skip `install` and hand-copy the `.so` from the build dir.
- Prefer plain `make install` against an existing cache to dodge both.

### Undefined-symbol gotcha (WCT-side, no larwirecell rebuild)

larwirecell plugins link against WCT-exported symbols. If a WCT change alters a
symbol's linkage (e.g. a `clus` helper made file-`static`), loading the
larwirecell `.so` fails at runtime with `undefined symbol: ...`. The fix is
**WCT-side** (re-export the symbol with external linkage and rebuild WCT) — do
NOT rebuild larwirecell. Example: `WireCell::Clus::Facade::normalize_cluster_flags`
(needed by `libWireCellQLMatch.so`); re-exported in
`clus/src/MultiAlgBlobClustering.cxx`. Decode the mangled name with `c++filt` and
confirm presence with `nm -DC opt/lib/libWireCellClus.so | grep <name>`.

See [[project-larwirecell-dual-tree]], [[project-wct-0-35-setup]], [[project-match-plugin-pin]].
