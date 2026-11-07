#!/bin/sh
# protonvpn 1.0.5 checks for a running GUI over the *session* D-Bus bus before
# every command. On a headless box reached over SSH there is no session bus, so
# every command dies with dbus_fast InvalidAddressError. Point it at the system
# bus: the check simply finds no GUI, which is the correct answer here.
: "${DBUS_SESSION_BUS_ADDRESS:=unix:path=/run/dbus/system_bus_socket}"
export DBUS_SESSION_BUS_ADDRESS
exec /usr/bin/protonvpn "$@"
