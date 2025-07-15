#!/bin/bash

if [ -f "/app/script/deploy_done.flag" ]; then
  exit 0
else
  exit 1
fi
