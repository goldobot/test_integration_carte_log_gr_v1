#!/bin/bash

#cd ./soft
#make clean
#cd ..
rm -rf ./altera_quartus/db
rm -rf ./altera_quartus/incremental_db
mv ./altera_quartus/output_files/RobotLeon2.cdf .
mv ./altera_quartus/output_files/RobotLeon2.sof .
mv ./altera_quartus/output_files/RobotLeon2.jic .
rm -f ./altera_quartus/output_files/*
mv ./RobotLeon2.cdf ./altera_quartus/output_files/
mv ./RobotLeon2.sof ./altera_quartus/output_files/
mv ./RobotLeon2.jic ./altera_quartus/output_files/


