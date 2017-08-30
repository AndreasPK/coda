#!/usr/bin/env bash

export CODA_SERVER_PATH=`which coda`

if [ "X" = "X$CODA_SERVER_PATH" ]; then
  sleep 5
  echo "Content-Length: 97\r\n\r"
  echo '{"jsonrpc":"2.0","id":1,"error":{"code":-32099,"message":"Cannot find coda in the path"}}'
  exit 1
fi

echo "Starting" 1>&2

tee ~/input.log | coda $@ | tee ~/output.log

echo "Shutting Down" 1>&2

#exec coda $@
