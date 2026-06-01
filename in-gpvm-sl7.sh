#!/bin/bash
# Run a command inside the Fermilab SL7 apptainer with the per-experiment
# wirecell environment already sourced. Mirrors the user's interactive `sl7`
# function plus `wcdev-<exp>/setup.sh`, but non-interactive so tools (Claude
# Code, CI, scripts) can drive builds.
#
# The experiment is taken from $CURRENT_EXPERIMENT; if unset, it is derived
# from the hostname via set-current-experiment.sh.
set -euo pipefail

if [[ -z "${CURRENT_EXPERIMENT:-}" ]]; then
    # shellcheck source=set-current-experiment.sh
    source "$(dirname "${BASH_SOURCE[0]}")/set-current-experiment.sh" >/dev/null
fi

IMG=/cvmfs/singularity.opensciencegrid.org/fermilab/fnal-dev-sl7:latest
SETUP=/exp/${CURRENT_EXPERIMENT}/app/users/yuhw/wcdev-${CURRENT_EXPERIMENT}/setup.sh
WCT=/exp/${CURRENT_EXPERIMENT}/app/users/yuhw/wire-cell-toolkit
APPTAINER=/cvmfs/oasis.opensciencegrid.org/mis/apptainer/current/bin/apptainer

exec "$APPTAINER" exec --ipc --pid \
    -B /cvmfs,/exp,/nashome,/opt,/pnfs,/run/user,/etc/hostname,/etc/hosts,/etc/krb5.conf \
    "$IMG" \
    /bin/bash -c "source '$SETUP' >/dev/null 2>&1 || true; cd '$WCT' && \"\$@\"" \
    _ "$@"
