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

echo "Querying CGM"
openaps use dex iter_glucose 50 > glucose.json.new
#openaps report invoke glucose.json.new || openaps report invoke glucose.json.new 
grep glucose glucose.json.new -m 15 && cp glucose.json.new glucose.json 
# tgh: find this file if modified less than 10 minutes ago, pass results to egrep, if egrep successful grep glucose within it, if you can't, die
find glucose.json -mmin -10 | egrep '.*' && grep glucose glucose.json -m 15|| die "Can't read from CGM"
head -15 glucose.json

find *.json -mmin 15 -exec mv {} {}.old \;

numprocs=$(fuser -n file $(python -m decocare.scan) 2>&1 | wc -l)
if [[ $numprocs -gt 0 ]] ; then
  die "Carelink USB already in use."
fi

echo "Checking pump status"
openaps status || openaps status || die "Can't get pump status"
grep status status.json.new && cp status.json.new status.json
echo "Querying pump time and five other pump queries"
openaps pumptime || openaps pumptime || die "Can't query pump"
#openaps pumpquery || openaps pumpquery
openaps report pump_settings.json.new
openaps report invoke bg_targets.json.new
openaps report invoke isf.json.new
openaps report invoke current_basal_profile.json.new
openaps report invoke carb_ratio.json.new
nodejs getprofile.js pumpsettings.json.new bg_targets.json.new isf.json.new current_basal_profile.json.new carb_ratio.json.new > profile.json.new

openaps report invoke pump_history.json
nodejs iob.js pump_history.json profile.json.new clock.json.new > iob.json.new


nodejs determine-basal.js iob.json.new currenttemp.json glucose.json profile.json > requestedtemp.json.new

find clock.json.new -mmin -10 | egrep -q '.*' && grep T clock.json.new && cp clock.json.new clock.json
openaps report invoke currenttemp.json.new
grep temp currenttemp.json.new && cp currenttemp.json.new currenttemp.json
openaps report invoke pumphistory.json.new
grep timestamp pumphistory.json.new && cp pumphistory.json.new pumphistory.json


#openaps suggest
grep sens profile.json.new && cp profile.json.new profile.json
grep iob iob.json.new && cp iob.json.new iob.json
grep temp requestedtemp.json.new && cp requestedtemp.json.new requestedtemp.json

tail clock.json
tail currenttemp.json
head -20 pumph_history.json

echo "Querying pump settings"
openaps pumpsettings || openaps pumpsettings || die "Can't query pump settings" && git pull && git push
grep insulin_action_curve pump_settings.json.new && cp pump_settings.json.new pump_settings.json
grep "mg/dL" bg_targets.json.new && cp bg_targets.json.new bg_targets.json
grep sensitivity isf.json.new && cp isf.json.new isf.json
grep rate current_basal_profile.json.new && cp current_basal_profile.json.new current_basal_profile.json
grep grams carb_ratio.json.new && cp carb_ratio.json.new carb_ratio.json

#openaps suggest || die "Can't calculate IOB or basal"
nodejs determine-basal.js iob.json.new currenttemp.json glucose.json profile.json > requestedtemp.json.new
grep sens profile.json.new && cp profile.json.new profile.json
grep iob iob.json.new && cp iob.json.new iob.json
grep temp requestedtemp.json.new && cp requestedtemp.json.new requestedtemp.json

tail profile.json
tail iob.json
tail requestedtemp.json

grep rate requestedtemp.json && ( openaps enact || openaps enact ) && tail enactedtemp.json
openaps report invoke enactedtemp.json


