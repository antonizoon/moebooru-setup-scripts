#!/bin/bash
# Create a puma config for moebooru to use.

function puma_config() {
    # create required folders for unix sockets
    mkdir -p "$workdir/shared/sockets"
    mkdir -p "$workdir/shared/log"
    mkdir -p "$workdir/shared/pid"
    
    # get number of processor cores
    cores=`grep -c processor /proc/cpuinfo`
    
    # write up config/puma.rb, custom puma settings
    
    # For centos you will need a systemd service rather than upstart
    # https://gist.github.com/velenux/6883dc221a7d2eae7dcb
    
}

puma_config