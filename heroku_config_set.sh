#!/bin/sh

while read line
do
  heroku config:set $line
done < ./apikey.env
