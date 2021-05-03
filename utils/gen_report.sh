#!/bin/bash

ROOT_DIR=$1
SRC_DIR="$ROOT_DIR/src"
DATA_DIR="$ROOT_DIR/data"

$SRC_DIR/get_all_slots.pl \
  --district_config_file $DATA_DIR/districts.txt \
  --log_dir $DATA_DIR \
  --generate_report
