#!/bin/bash

echo "======================================"
echo " INICIANDO PLATAFORMA ACADÉMICA"
echo "======================================"

export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export ORACLE_SID=orclcdb
export LD_LIBRARY_PATH=$ORACLE_HOME/lib
export PATH=$ORACLE_HOME/bin:$PATH

if [ ! -f /root/.env ]; then
    echo "No existe /root/.env"
    exit 1
fi

set -a
. /root/.env
set +a

echo ""
echo "[1] Verificando MariaDB..."
systemctl is-active --quiet mariadb
if [ $? -ne 0 ]; then
    echo "MariaDB está apagado. Iniciando..."
    systemctl start mariadb
else
    echo "MariaDB ya está activo."
fi

echo ""
echo "[2] Verificando SQL Server..."
systemctl is-active --quiet mssql-server
if [ $? -ne 0 ]; then
    echo "SQL Server está apagado. Iniciando..."
    systemctl start mssql-server
else
    echo "SQL Server ya está activo."
fi

echo ""
echo "[3] Verificando Listener Oracle..."
su - oracle -c "export ORACLE_HOME=$ORACLE_HOME; export PATH=$ORACLE_HOME/bin:\$PATH; lsnrctl status" > /tmp/listener_status.txt 2>&1

grep -q "STATUS of the LISTENER" /tmp/listener_status.txt
if [ $? -ne 0 ]; then
    echo "Listener apagado. Iniciando..."
    su - oracle -c "export ORACLE_HOME=$ORACLE_HOME; export PATH=$ORACLE_HOME/bin:\$PATH; lsnrctl start"
else
    echo "Listener ya está activo."
fi

echo ""
echo "[4] Iniciando Oracle Database si es necesario..."
su - oracle -c "export ORACLE_HOME=$ORACLE_HOME; export ORACLE_SID=orclcdb; export PATH=$ORACLE_HOME/bin:\$PATH; sqlplus -s / as sysdba <<EOF
WHENEVER SQLERROR EXIT SQL.SQLCODE
SELECT status FROM v\\\$instance;
EXIT;
EOF" > /tmp/oracle_status.txt 2>&1

grep -q "OPEN" /tmp/oracle_status.txt
if [ $? -ne 0 ]; then
    echo "Oracle no está abierto. Ejecutando STARTUP..."
    su - oracle -c "export ORACLE_HOME=$ORACLE_HOME; export ORACLE_SID=orclcdb; export PATH=$ORACLE_HOME/bin:\$PATH; sqlplus -s / as sysdba <<EOF
STARTUP;
EXIT;
EOF"
else
    echo "Oracle ya está abierto."
fi

echo ""
echo "[5] Abriendo PDB ORCLPDB..."
su - oracle -c "export ORACLE_HOME=$ORACLE_HOME; export ORACLE_SID=orclcdb; export PATH=$ORACLE_HOME/bin:\$PATH; sqlplus -s / as sysdba <<EOF
ALTER PLUGGABLE DATABASE ORCLPDB OPEN;
ALTER SYSTEM REGISTER;
EXIT;
EOF" > /tmp/pdb_open.txt 2>&1

echo "PDB verificado."

echo ""
echo "[6] Verificando servicios Oracle..."
su - oracle -c "export ORACLE_HOME=$ORACLE_HOME; export PATH=$ORACLE_HOME/bin:\$PATH; lsnrctl status | grep -E 'orclcdb|orclpdb'"

echo ""
echo "[7] Ejecutando ETL de prueba..."
python3 /root/etl_academico.py

echo ""
echo "[8] Verificando conteo final en SQL Server..."
/opt/mssql-tools18/bin/sqlcmd -S "$SQLSERVER_HOST" -U "$SQLSERVER_USER" -P "$SQLSERVER_PASSWORD" -C -Q "USE $SQLSERVER_DATABASE; SELECT COUNT(*) AS total_reportes FROM reporte_academico;"

echo ""
echo "======================================"
echo " PLATAFORMA LISTA"
echo "======================================"
