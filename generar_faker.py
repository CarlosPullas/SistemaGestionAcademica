import os
import pymysql
import cx_Oracle
import pyodbc
from dotenv import load_dotenv

load_dotenv("/root/.env")


def required_env(name):
    value = os.getenv(name)
    if value is None:
        raise RuntimeError(f"Falta la variable {name} en /root/.env")
    return value

# MariaDB
maria = pymysql.connect(
    host=required_env("MARIADB_HOST"),
    user=required_env("MARIADB_USER"),
    password=required_env("MARIADB_PASSWORD"),
    database=required_env("MARIADB_DATABASE")
)

# Oracle
oracle = cx_Oracle.connect(
    required_env("ORACLE_USER"),
    required_env("ORACLE_PASSWORD"),
    required_env("ORACLE_DSN")
)

# SQL Server
sqlserver = pyodbc.connect(
    "DRIVER={ODBC Driver 18 for SQL Server};"
    f"SERVER={required_env('SQLSERVER_HOST')};"
    f"DATABASE={required_env('SQLSERVER_DATABASE')};"
    f"UID={required_env('SQLSERVER_USER')};"
    f"PWD={required_env('SQLSERVER_PASSWORD')};"
    "TrustServerCertificate=yes;"
)

cur_maria = maria.cursor()
cur_oracle = oracle.cursor()
cur_sql = sqlserver.cursor()

cur_sql.execute("DELETE FROM reporte_academico")

cur_oracle.execute("""
SELECT
    m.periodo,
    m.id_estudiante,
    m.id_asignatura,
    m.id_docente,
    c.nota_final,
    c.estado
FROM ACADEMICO.matriculas m
JOIN ACADEMICO.calificaciones c
ON m.id_matricula = c.id_matricula
""")

for periodo, id_estudiante, id_asignatura, id_docente, nota_final, estado in cur_oracle.fetchall():

    cur_maria.execute(
        "SELECT nombres, apellidos FROM estudiantes WHERE id_estudiante=%s",
        (id_estudiante,)
    )
    est = cur_maria.fetchone()

    cur_maria.execute(
        "SELECT nombre FROM asignaturas WHERE id_asignatura=%s",
        (id_asignatura,)
    )
    asig = cur_maria.fetchone()

    cur_maria.execute(
        "SELECT nombres, apellidos FROM docentes WHERE id_docente=%s",
        (id_docente,)
    )
    doc = cur_maria.fetchone()
    
    if est is None or asig is None or doc is None:
        print("Registro omitido por falta de datos maestros:",
              id_estudiante,
              id_asignatura,
              id_docente)
        continue
    estudiante = est[0] + " " + est[1]
    asignatura = asig[0]
    docente = doc[0] + " " + doc[1]

    cur_sql.execute("""
    INSERT INTO reporte_academico
    (periodo, id_estudiante, estudiante, asignatura, docente, nota_final, estado)
    VALUES (?, ?, ?, ?, ?, ?, ?)
    """, periodo, id_estudiante, estudiante, asignatura, docente, nota_final, estado)

sqlserver.commit()

print("ETL ejecutado correctamente.")

cur_maria.close()
cur_oracle.close()
cur_sql.close()
maria.close()
oracle.close()
sqlserver.close()
