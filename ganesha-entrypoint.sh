#!/bin/bash

set -eu

exec ganesha.nfsd -F -f /config.conf
