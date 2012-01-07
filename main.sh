#/bin/bash

# Marc Pomar Torres - Serveis i Aplicacions Telemˆtiques
# Projecte Final

#MacPorts binary path (For MarcP Macbook coniguration)
PATH=/opt/local/bin:/opt/local/sbin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/X11/bin
export PATH

#Client Settings
port=8888
destination=224.1.0.1
interface="en1"
protocol="_partyline._udp"
domain="local"
instance="sat-partyline"
codec="cvsd"
samplerate="8k"
buffSizeBytes="1024"
TXT_RECORD="codec=${codec}"
recfifo="/tmp/recSat.tmp"
playfifo="/tmp/playSat.tmp"


#Origin IP ADDRESS
function setIP_ADDR()
{
	host_type=$( uname -s )
	if [ $host_type == "Linux" ]; then
		ip_origin=$(ifconfig $interface | grep 'inet addr:' | cut -d: -f2 | awk '{print $1}')
	elif [ $host_type == "Darwin" ]; then
		ip_origin=$(ipconfig getifaddr $interface)
	fi
	echo "Origin IP is $ip_origin"
}

#Start Service Routine
function startRecordingService()
{
	#Register local Service with Apple Bonjour
	mDNS -R $instance $protocol $domain $port $TXT_RECORD > dnsLog.txt &
	dnsPid=$!
	echo "Service Registered (mDNS pid -> ${dnsPid})"
	
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

function startPlayIncoming(){
	#Create playfifo
	rm -f $playfifo
	mkfifo $playfifo
	
	#Read local network multicast
	socat -u UDP-RECV:8888,ip-add-membership=224.1.0.1:$ip_origin PIPE:$playfifo &	 
	rcvPid=$!
	
	playOptions="-V -t $codec -c 1 -r $samplerate --buffer $buffSizeBytes"
	play $playOptions $playfifo &
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
	
	#Kill script ;)
	exit 0
}

#Set origin IP ADRESS
setIP_ADDR

#Start PartyLine Service
startRecordingService
startPlayIncoming

echo "Service started -> Play[${playPid}], Rec[${recPid}]"

#Stop Service on Exit
# On SIGTERM stop PartyLine Service
trap 'stopService' TERM

#Wait until exit
wait
