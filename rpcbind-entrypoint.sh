#!/bin/bash

set -eu

# Create /run/rpcbind
systemd-tmpfiles --create /usr/lib/tmpfiles.d/rpcbind.conf

exec rpcbind -f -w
