#!/bin/bash

# Marc Pomar Torres - Serveis i Aplicacions Telemˆtiques

#MacPorts binary path (For OSX macports coniguration)
PATH=/opt/local/bin:/opt/local/sbin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/X11/bin
export PATH

#################################################
# Client Settings, please configure before use! #
#################################################

port=8888
destination=224.1.0.1 #Multicast local group, this address will be ok!
interface="en1" #Maybe need to configure only this!
codec="cvsd"
samplerate="8k"
buffSizeBytes="1024"
recfifo="/tmp/recSat.tmp"
playfifo="/tmp/playSat.tmp"

#####################
# end configuration #
#####################

#Handle script
handle_script="./handle_cnx.sh"

#Get current interface ip adress
function setIP_ADDR() {
	host_type=$( uname -s )
	if [ $host_type == "Linux" ]; then
		ip_origin=$(ifconfig $interface | grep 'inet addr:' | cut -d: -f2 | awk '{print $1}')
	elif [ $host_type == "Darwin" ]; then
		ip_origin=$(ipconfig getifaddr $interface)
	fi
	export ip_origin
}

#Register local Service with Apple Bonjour if possible
function registerBonjourService() {
	#Register local Service with Apple Bonjour (only OSX)
	if [ "$(uname -s)" == "Darwin" ]; then
		domain="local"
		instance="sat-partyline"
		protocol="_partyline._udp"
		TXT_RECORD="machine=$(uname -n),codec=${codec}"
		mDNS -R $instance $protocol $domain $port $TXT_RECORD &
		dnsPid=$!
		echo "Bonjour Service Registered (mDNS pid -> ${dnsPid})"
	fi
}

#Start recording service Routine
function startRecordingService() {
	#Try to register service
	registerBonjourService
	
	#Create recording fifo
	rm -f $recfifo
	mkfifo $recfifo
	
	#Configure SOX audio options
	recOptions="-V -t $codec -c 1 -r $samplerate --buffer $buffSizeBytes "
	
	#Start Recording
	rec $recOptions $recfifo 2>/dev/null & 
	recPid=$!

	#Start Sending multicast stream
	socat -u PIPE:$recfifo UDP4-DATAGRAM:$destination:$port &
	sendPid=$!
}

# Listen from Multicast adress on settings (destination). A fork will be made every
# new packet arrives. handle_cnx.sh will handle packet data to correct place
function listenClients() {
	#Read local network multicast
	socat -u UDP-RECVFROM:8888,ip-add-membership=$destination:$ip_origin,ip-pktinfo,fork SYSTEM:"$handle_script" &
	rcvPid=$!
}

# Start playing stream from file (passed as arg.)
function startPlayIncoming() {
	playOptions="-t $codec -c 1 -r $samplerate --buffer $buffSizeBytes"
	#while true; do cat $1; done | play $playOptions $1 &
	play $playOptions $1 &
	playPid=$!
}

# Stop Service routine, called when script exists to clean enviroment
function stopService() {
	echo "ByeBye, killing service and sox audio..."
	
	#Remove bonjour local service
	kill -9 $dnsPid
	
	#Kill sox audio
	kill -9 $recPid
	kill -9 $playPid
	
	#Stop Sending packets tru network
	kill -9 $sendPid
	kill -9 $rcvPid
	
	#Remove all fifos
	rm -f /tmp/partyline_peer_*
		
	#Kill script ;)
	exit 0
}

# Check if a value exists in an array
# @param $1 mixed  Needle  
# @param $2 array  Haystack
# @return  Success (0) if value exists, Failure (1) otherwise
# Usage: in_array "$needle" "${haystack[@]}"
# See: http://fvue.nl/wiki/Bash:_Check_if_array_element_exists
function in_array() {
    local hay needle=$1
    shift
    for hay; do
        [[ $hay == $needle ]] && return 0
    done
    return 1
}

#Gets last modification time from file as unix timestamp
function last_modification() {
	host_type=$( uname -s )
	if [ $host_type == "Linux" ]; then
		m_time=$(stat -c %Y $1)
	elif [ $host_type == "Darwin" ]; then
		m_time=$(stat -f '%m' $1)
	fi
	echo $m_time
}


#Set origin IP ADRESS
setIP_ADDR

#Start PartyLine Service
startRecordingService
#Listen from multicast adress
listenClients

echo "Service started -> Play[${playPid}], Rec[${recPid}]"

#Clean all Pid's and temporal audio streams
trap 'stopService' TERM

echo "To exit press Ctrl+C"

####################
# Main Listen loop #
####################

while true; do
	#Find all active Pipes and update client list
	for f in $( ls /tmp/partyline_peer_* 2>/dev/null); do
		#Check for new clients
		if [ "$(in_array $f "${clients[@]}" && echo yes || echo no)" == "no" ]; then
			#Append client to array
			clients=( "${clients[@]}" $f )
			echo "New client, saving new stream on named pipe $f..."
			#Sleep 2 seconds to not got a buffer underrun, so we get a 2 seconds delay on audio
			sleep 2
			#Start play incoming audio stream
			startPlayIncoming $f
			
		else
			#Normal update time was 2-3 seconds, we set a limit of 5 seconds for disconect
			s_old=$( expr $(date +%s) - $(last_modification $f) )
			s_limit=5
			if [ $s_old -gt $s_limit ]; then
				echo "Client $f disconnected, fifo removed. You can reconnect safely now!"
				#Remove client from clients array
				clients=${clients[@]#$f}
				#Remove client fifo
				rm -f $f
			fi
		fi
	done;
	#Sleep to not saturate system
	sleep 1;
done;

