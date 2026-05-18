#!/usr/bin/env bash
# Infer the current experiment from the FQDN and export CURRENT_EXPERIMENT.
#
# Recognised hostname patterns:
#   <experiment>gpvm<NN>.fnal.gov
#   <experiment>build<NN>.fnal.gov
#
# Source this script (do not execute) so the export is visible to the caller:
#   source /exp/dune/app/users/yuhw/claude-utilities/set-current-experiment.sh

_host=$(hostname -f 2>/dev/null || hostname)

if [[ $_host =~ ^([a-zA-Z]+)(gpvm|build)[0-9]+\.fnal\.gov$ ]]; then
    export CURRENT_EXPERIMENT="${BASH_REMATCH[1]}"
    echo "CURRENT_EXPERIMENT=${CURRENT_EXPERIMENT}"
else
    echo "set-current-experiment.sh: hostname '${_host}' does not match <exp>{gpvm,build}NN.fnal.gov" >&2
    unset CURRENT_EXPERIMENT
    return 1 2>/dev/null || exit 1
fi

unset _host
