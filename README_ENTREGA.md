#!/bin/bash

export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export LD_LIBRARY_PATH=$ORACLE_HOME/lib
export PATH=$ORACLE_HOME/bin:$PATH

python3 /root/generar_faker_limpio.py
