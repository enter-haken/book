#!/bin/bash
i=0

ls -1 | while read line;
do
  mv $line `printf "%02d-$line" $((i++))`      
done
