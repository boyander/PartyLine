#!/bin/bash

#Enviroment variables
#SOCAT_IP_DSTADDR
#SOCAT_IP_IF
#SOCAT_IP_LOCADDR
#SOCAT_PEERADDR
#SOCAT_PEERPORT

echo "$SOCAT_IP_DSTADDR, $SOCAT_IP_IF, $SOCAT_IP_LOCADDR, $SOCAT_PEERADDR, $SOCAT_PEERPORT"

client_name=${SOCAT_PEERADDR//./_}
fifoname="/tmp/partyline_peer_$client_name"

#Create fifo if not exists
if [ ! -e $fifo_name ]; then
	echo "Creating fifo for client $SOCAT_PEERADDR ....does not exist!"
	mkfifo $fifoname	
fi

#Read incoming packet
dd of=$fifoname conv=notrunc


