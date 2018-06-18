#!/bin/sh
rm -R /var/grafana/data/sessions
rm -R /var/bluenote/var/log
chmod -R 777 /var/bluenote/var/log
chown -R grafana:grafana /var/grafana \

#cd /var/bluenote/csv_feeder
#python3 csv_feeder.py conf/comed.json docker.json
