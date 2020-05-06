#!/bin/bash
i=0

ls -1r | while read line;
do
  mv $line `printf "%02d-$line" $i`;
  ((i++))
done
