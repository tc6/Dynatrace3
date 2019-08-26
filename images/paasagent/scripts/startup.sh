#!/usr/bin/env bash
if /opt/dynatrace/sap/agent.sh start ; then
  java -jar /work/spring-music.jar
else
  exit 1
fi