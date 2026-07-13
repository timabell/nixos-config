#!/usr/bin/env bash
# Minimal bashrc for the bwrap sandbox — just a prompt that names the outer
# working directory. Tool activation (mise etc.) is intentionally absent;
# workloads bring their own PATH via the nix wrapper.

export PS1="\n╭─[🫙 sandbox ${SANDBOX_OUTER_PWD:-?}] \w\n╰─\$ "
