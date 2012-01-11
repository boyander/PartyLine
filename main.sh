#!/bin/bash

# Marc Pomar Torres - Serveis i Aplicacions Telemˆtiques
# Projecte Final

#MacPorts binary path (For MarcP Macbook coniguration)
PATH=/opt/local/bin:/opt/local/sbin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/X11/bin
export PATH

#Client Settings
port=8888
destination=224.1.0.1
interface="en1"
codec="cvsd"
samplerate="8k"
buffSizeBytes="1024"
recfifo="/tmp/recSat.tmp"
playfifo="/tmp/playSat.tmp"

#Handle script
handle_script="./handle_cnx.sh"


#Origin IP ADDRESS
function setIP_ADDR()
{
	host_type=$( uname -s )
	if [ $host_type == "Linux" ]; then
		ip_origin=$(ifconfig $interface | grep 'inet addr:' | cut -d: -f2 | awk '{print $1}')
	elif [ $host_type == "Darwin" ]; then
		ip_origin=$(ipconfig getifaddr $interface)
	fi
}

#Register local Service with Apple Bonjour if possible
function registerBonjourService(){
	#Register local Service with Apple Bonjour (only OSX)
	if [ "$(uname -s)" == "Darwin" ]; then
		domain="local"
		instance="sat-partyline"
		protocol="_partyline._udp"
		TXT_RECORD="machine=$(uname -n),codec=${codec}"
		mDNS -R $instance $protocol $domain $port $TXT_RECORD > dnsLog.txt &
		dnsPid=$!
		echo "Bonjour Service Registered (mDNS pid -> ${dnsPid})"
	fi
}


#Start Service Routine
function startRecordingService()
{
	#Try to register service
	registerBonjourService
	
	#Create recording fifo
	rm -f $recfifo
	mkfifo $recfifo
	
	#Configure SOX audio options
	recOptions="-V -t $codec -c 1 -r $samplerate --buffer $buffSizeBytes "
	
	#Start Recording
	rec $recOptions $recfifo & 
	recPid=$!
	
	#Start Sending multicast stream
	socat -u PIPE:$recfifo UDP4-DATAGRAM:$destination:$port &
	sendPid=$!
}

function listenClients(){
	#Read local network multicast
	#socat -u UDP-RECVFROM:8888,ip-add-membership=224.1.0.1:$ip_origin,ip-pktinfo,fork SYSTEM:$handle_script PIPE:$playfifo &	 
	socat -u UDP-RECVFROM:8888,ip-add-membership=224.1.0.1:$ip_origin,ip-pktinfo,fork SYSTEM:"$handle_script" &
	rcvPid=$!
}

function startPlayIncoming(){
	playOptions="-t $codec -c1 -r $samplerate"
	#while true; do cat $1; done | play $playOptions $1 &
	play $playOptions $1 &
	playPid=$!
}

#Stop Service routine
function stopService()
{
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

# http://fvue.nl/wiki/Bash:_Check_if_array_element_exists
# Check if a value exists in an array
# @param $1 mixed  Needle  
# @param $2 array  Haystack
# @return  Success (0) if value exists, Failure (1) otherwise
# Usage: in_array "$needle" "${haystack[@]}"
# See: http://fvue.nl/wiki/Bash:_Check_if_array_element_exists
in_array() {
    local hay needle=$1
    shift
    for hay; do
        [[ $hay == $needle ]] && return 0
    done
    return 1
}

function last_modification()
{
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
#startRecordingService
#startPlayIncoming
listenClients

echo "Service started -> Play[${playPid}], Rec[${recPid}]"

#Stop Service on Exit
# On SIGTERM stop PartyLine Service
trap 'stopService' TERM



#Recive Test
#testfifo=/tmp/partyline_peer_192_168_1_109
#while [[ ! -p $testfifo ]]
#  do
#	sleep 1
#	printf ".*" 
#done
#sleep 1
#startPlayIncoming $testfifo
#echo "Client $testfifo connected!"

echo "To exit press Ctrl+C"

#Main Listen loop
IFS=$'\n'
while true; do
	echo "List of clients:"
	echo ${clients[@]}
	
	#Find all active Pipes and update client list
	for f in $( ls /tmp/partyline_peer_* 2>/dev/null); do
		#Check for new clients
		if [ "$(in_array $f "${clients[@]}" && echo yes || echo no)" == "no" ]; then
			#Append client to array
			clients=( "${clients[@]}" $f )
			echo "New Client $f on PlayList!"
			#Start play incoming audio stream
			startPlayIncoming $f
		else
			#Normal update time was 2-3 seconds, we set a limit of 5 seconds for disconect
			s_old=$( expr $(date +%s) - $(last_modification $f) )
			s_limit=5
			if [ $s_old -gt $s_limit ]; then
				echo "Client $f disconnected!"
			fi
		fi
	done
	sleep 1
done

