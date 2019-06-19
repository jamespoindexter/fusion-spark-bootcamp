#!/bin/bash
set -e 

SCRIPT_HOME="$(dirname "${BASH_SOURCE-$0}")"
LABS_TIP=${SCRIPT_HOME}/../..
LABS_TIP=`cd "$LABS_TIP"; pwd`

source "$LABS_TIP/myenv.sh"
cd ${SCRIPT_HOME}

if [ "$FUSION_PASS" == "" ]; then
  echo -e "ERROR: Must provide a valid password for Fusion user: $FUSION_USER"
  exit 1
fi

COLL=eventsim

echo -e "\nCreating the $COLL collection in Fusion"
curl -u $FUSION_USER:$FUSION_PASS -X POST -H "Content-type:application/json" -d '{"id":"eventsim","solrParams":{"numShards":3,"maxShardsPerNode":3}}' \
  "$FUSION_API/apps/$BOOTCAMP/collections?relatedObjects=false&defaultFeatures=false"

curl -u $FUSION_USER:$FUSION_PASS -X PUT -H "Content-type:application/json" -d @eventsim-default-index-pipeline.json "$FUSION_API/apps/$BOOTCAMP/index-pipelines/eventsim-default"
curl -u $FUSION_USER:$FUSION_PASS -X PUT "$FUSION_API/apps/$BOOTCAMP/index-pipelines/eventsim-default/refresh"

curl -X POST -H "Content-type:application/json" --data-binary '{
  "add-field": { "name":"ts", "type":"pdate", "stored":true, "indexed":true, "multiValued":false },
  "add-field": { "name":"registration", "type":"pdate", "stored":true, "indexed":true, "multiValued":false },
  "add-field": { "name":"song", "type":"string", "stored":true, "indexed":true, "multiValued":false },
  "add-field": { "name":"lastName", "type":"string", "stored":true, "indexed":true, "multiValued":false },
  "add-field": { "name":"artist", "type":"string", "stored":true, "indexed":true, "multiValued":false },
  "add-field": { "name":"auth", "type":"string", "stored":true, "indexed":true, "multiValued":false },
  "add-field": { "name":"firstName", "type":"string", "stored":true, "indexed":true, "multiValued":false },
  "add-field": { "name":"location", "type":"string", "stored":true, "indexed":true, "multiValued":false },
  "add-field": { "name":"page", "type":"string", "stored":true, "indexed":true, "multiValued":false },
  "add-field": { "name":"itemInSession", "type":"string", "stored":true, "indexed":true, "multiValued":false },
  "add-field": { "name":"gender", "type":"string", "stored":true, "indexed":true, "multiValued":false },
  "add-field": { "name":"method", "type":"string", "stored":true, "indexed":true, "multiValued":false },
  "add-field": { "name":"level", "type":"string", "stored":true, "indexed":true, "multiValued":false },
  "add-field": { "name":"length", "type":"pdouble", "stored":true, "indexed":true, "multiValued":false },
  "add-field": { "name":"userId", "type":"string", "stored":true, "indexed":true, "multiValued":false },
  "add-field": { "name":"status", "type":"pint", "stored":true, "indexed":true, "multiValued":false },
  "add-field": { "name":"sessionId", "type":"string", "stored":true, "indexed":true, "multiValued":false },
  "add-copy-field": [ { "source": "*", "dest": "_text_" } ]
}' "http://$FUSION_SOLR/solr/eventsim/schema?updateTimeoutSecs=20"

curl -X POST -H "Content-type:application/json" -d '{
  "set-property": { "updateHandler.autoSoftCommit.maxTime":5000 }
}' http://$FUSION_SOLR/solr/eventsim/config

echo -e "\nEnabling the partitionByTime feature in Fusion"
curl -u $FUSION_USER:$FUSION_PASS -X PUT -H 'Content-type: application/json' -d '{ "enabled":true, "timestampFieldName":"ts", "timePeriod":"1DAYS", "scheduleIntervalMinutes":1, "preemptiveCreateEnabled":false, "maxActivePartitions":100, "deleteExpired":false }' $FUSION_API/collections/$COLL/features/partitionByTime

curl -u $FUSION_USER:$FUSION_PASS -X PUT -H 'Content-type: application/json' -d '{ "enabled":true, "timestampFieldName":"timestamp_tdt", "timePeriod":"1HOURS", "scheduleIntervalMinutes":1, "preemptiveCreateEnabled":false, "maxActivePartitions":100, "deleteExpired":false }' $FUSION_API/collections/eventsim_signals/features/partitionByTime

EVENTSIM_DATA="$LAB_DIR/control.data.json"

echo -e "EVENTSIM_DATA=$EVENTSIM_DATA"

if [ ! -f "$EVENTSIM_DATA" ]; then
  echo -e "\nExtracting sample data ..."
  unzip -a control.data.json.zip
fi

echo -e "\nUsing the Fusion spark-shell to load events into Fusion ..."
$FUSION_HOME/bin/spark-shell -M local[*] -i load_fusion.scala

