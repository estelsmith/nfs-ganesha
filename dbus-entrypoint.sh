#!/bin/bash

set -eu

# Create /run/dbus
install --directory --owner=root --group=root --mode=0755 /run/dbus

# Create /var/lib/dbus/machine-id if it does not exist
dbus-uuidgen --ensure

exec dbus-daemon --nofork --nopidfile --nosyslog --config-file /usr/share/dbus-1/system.conf
