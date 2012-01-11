#!/bin/bash

# Marc Pomar Torres - Serveis i Aplicacions Telemˆtiques

##############################################################################
# This script ony handles Socat recived pkt and writes to corresponding Pipe #
##############################################################################

#echo "$SOCAT_IP_DSTADDR, $SOCAT_IP_IF, $SOCAT_IP_LOCADDR, $SOCAT_PEERADDR, $SOCAT_PEERPORT"

#Ignore Local Audio Stream
if [ $ip_origin == $SOCAT_PEERADDR ]; then
	#echo "Drop Local!"
	exit 0
fi

client_name=${SOCAT_PEERADDR//./_}
fifoname="/tmp/partyline_peer_$client_name"

#Create fifo if not exists
if [[ ! -p "$fifoname" ]]; then
	mkfifo $fifoname
fi

#Read incoming packet, copy input stream from socat to client named fifo
dd of=$fifoname conv=notrunc 2>/dev/null

