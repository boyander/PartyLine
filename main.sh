#/bin/bash

# Marc Pomar Torres - Serveis i Aplicacions Telemˆtiques
# Projecte Final

#MacPorts binary path (For MarcP Macbook coniguration)
PATH=$PATH:/opt/local/bin:/opt/local/sbin
export PATH

#Client Settings
port=8888
protocol="_partyline._udp"
domain="local"
instance="sat-partyline"
codec="vox"
samplerate="8k"
buffSizeBytes="1024"
TXT_RECORD="codec=${codec}"

#Start Service Routine
function startService()
{
	#Register local Service with Apple Bonjour
	mDNS -R $instance $protocol $domain $port $TXT_RECORD > dnsLog.txt &
	dnsPid=$!
	echo "Service Registered (mDNS pid -> ${dnsPid})"
	
	#Configure SOX audio options
	recOptions="-V -t $codec -c 1 -r $samplerate --buffer $buffSizeBytes"
	playOptions="-t $codec -c 1 -r $samplerate --buffer $buffSizeBytes"
	
	#Create recording fifo
	recfifo="/tmp/recSat.tmp"
	mkfifo $recfifo
	
	#Start Recording
	rec $recOptions $recfifo & 
	recPid=$!
	
	play $playOptions $recfifo &
	playPid=$!
}

#Stop Service routine
function stopService()
{
	echo "ByeBye, killing service and sox audio..."
	
	#Remove bonjour local service
	echo "Killed bonjour service ${dnsPid}"
	kill -9 $dnsPid
	
	#Kill sox audio
	echo "Killed rec ${recPid}"
	kill -9 $recPid
	echo "Killed play ${recPid}"
	kill -9 $playPid
	#Remove fifo
	rm -f $recfifo
	
	#Kill script ;)
	exit 0
}




#Start PartyLine Service
startService
echo "Service started -> Play[${playPid}], Rec[${recPid}]"

#Stop Service on Exit
# On SIGTERM stop PartyLine Service
trap 'stopService' TERM

#Wait until exit
wait
