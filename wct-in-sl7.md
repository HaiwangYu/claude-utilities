# wire-cell-toolkit — build environment

This project must be built inside the Fermilab SL7 apptainer with the
per-experiment wirecell environment sourced. **Do not run `./wcb`, `cmake`,
`pytest`, or compiled test binaries directly on the host** — they will pick
up the wrong toolchain (host system gcc/spdlog instead of `e26 prof` from
cvmfs) and fail in confusing ways.

The experiment is determined from the hostname (`<exp>{gpvm,build}NN.fnal.gov`)
and exported as `$CURRENT_EXPERIMENT`, which selects the matching
`/exp/$CURRENT_EXPERIMENT/app/users/yuhw/wcdev-*/setup.sh`.

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
- Setup script: `/exp/$CURRENT_EXPERIMENT/app/users/yuhw/wcdev-*/setup.sh`
  (sets up the experiment's UPS/Spack environment plus user paths)

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
