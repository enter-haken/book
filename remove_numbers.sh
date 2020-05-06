#!/bin/bash

ls -1 | while read line;
do
  mv $line `echo $line | cut -d'-' -f2-`;
done
