#!/bin/bash

#echo "$SOCAT_IP_DSTADDR, $SOCAT_IP_IF, $SOCAT_IP_LOCADDR, $SOCAT_PEERADDR, $SOCAT_PEERPORT"

client_name=${SOCAT_PEERADDR//./_}
fifoname="/tmp/partyline_peer_$client_name"

#Create fifo if not exists
if [[ ! -p "$fifoname" ]]; then
	echo "New client, saving new stream on named pipe $SOCAT_PEERADDR..."
	mkfifo $fifoname
fi

#Read incoming packet, copy input stream from socat to client named fifo
dd of=$fifoname conv=notrunc 

