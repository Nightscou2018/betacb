#:!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

die() { echo "$@" ; exit 1; }

# only one process can talk to the pump at a time
ls /tmp/openaps.lock >/dev/null 2>/dev/null && die "OpenAPS already running: exiting" && exit

echo "No lockfile: continuing"
touch /tmp/openaps.lock
/home/pi/decoding-carelink/insert.sh 2>/dev/null >/dev/null

function finish {
    rm /tmp/openaps.lock
}
trap finish EXIT

cd /home/pi/betacb

find *.json -mmin -15 -exec mv {} {}.old \;

echo "Querying CGM"
openaps use dex iter_glucose 50 > glucose.json.new
grep glucose glucose.json.new -m 2 && cp glucose.json.new glucose.json 
# tgh: find this file if modified less than 10 minutes ago, pass results to egrep, if egrep successful grep glucose within it, if you can't, die
#find glucose.json -mmin -10 | egrep '.*' && grep glucose glucose.json -m 2 || die "Can't read from CGM"
#head -15 glucose.json

numprocs=$(fuser -n file $(python -m decocare.scan) 2>&1 | wc -l)
if [[ $numprocs -gt 0 ]] ; then
  die "Carelink USB already in use."
fi

echo "Checking pump status"
openaps status || openaps status || die "Can't get pump status"
grep status status.json.new && cp status.json.new status.json
echo "Querying pump time and five other pump queries"
openaps pumptime || openaps pumptime || die "Can't query pump"
openaps report invoke pump_settings.json.new
openaps report invoke bg_targets.json.new
openaps report invoke isf.json.new
openaps report invoke current_basal_profile.json.new
openaps report invoke carb_ratio.json.new
cp pump_settings.json.new pump_settings.json
cp bg_targets.json.new bg_targets.json
cp isf.json.new isf.json
cp current_basal_profile.json.new current_basal_profile.json
cp carb_ratio.json.new carb_ratio.json

find clock.json.new -mmin -10 | egrep -q '.*' && grep T clock.json.new && cp clock.json.new clock.json

nodejs getprofile.js pump_settings.json bg_targets.json isf.json current_basal_profile.json carb_ratio.json > profile.json.new

cp profile.json.new profile.json

openaps report invoke pump_history.json
nodejs iob.js pump_history.json profile.json clock.json > iob.json.new
cp iob.json.new iob.json

openaps report invoke currenttemp.json.new
grep temp currenttemp.json.new && cp currenttemp.json.new currenttemp.json
openaps report invoke pumphistory.json.new
grep timestamp pumphistory.json.new && cp pumphistory.json.new pumphistory.json

nodejs determine-basal.js iob.json currenttemp.json glucose.json profile.json > requestedtemp.json.new

#openaps suggest
grep sens profile.json.new && cp profile.json.new profile.json
grep iob iob.json.new && cp iob.json.new iob.json
grep temp requestedtemp.json.new && cp requestedtemp.json.new requestedtemp.json

tail clock.json
tail currenttemp.json
head -20 pump_history.json

echo "Querying pump settings"
openaps pumpsettings || openaps pumpsettings || die "Can't query pump settings" 
grep insulin_action_curve pump_settings.json.new && cp pump_settings.json.new pump_settings.json
grep "mg/dL" bg_targets.json.new && cp bg_targets.json.new bg_targets.json
grep sensitivity isf.json.new && cp isf.json.new isf.json
grep rate current_basal_profile.json.new && cp current_basal_profile.json.new current_basal_profile.json
grep grams carb_ratio.json.new && cp carb_ratio.json.new carb_ratio.json

#openaps suggest || die "Can't calculate IOB or basal"
nodejs determine-basal.js iob.json currenttemp.json glucose.json profile.json > requestedtemp.json.new
grep sens profile.json.new && cp profile.json.new profile.json
grep iob iob.json.new && cp iob.json.new iob.json
grep temp requestedtemp.json.new && cp requestedtemp.json.new requestedtemp.json

tail profile.json
tail iob.json
tail requestedtemp.json

openaps use pump522 set_temp_basal requestedtemp.json || echo "temp basal not changed"
#grep rate requestedtemp.json && ( openaps enact || openaps enact ) && tail enactedtemp.json
#openaps report invoke enactedtemp.json

