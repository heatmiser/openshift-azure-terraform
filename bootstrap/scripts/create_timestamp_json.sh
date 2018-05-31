#!/bin/bash
set -e
# This works
TS=$(date +%s)
echo {\"timestamp\":\""${TS}"\"}