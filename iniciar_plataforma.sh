import os
from faker import Faker
import pymysql
import cx_Oracle
import random
from dotenv import load_dotenv

fake = Faker("es_ES")
load_dotenv("/root/.env")


def required_env(name):
    value = os.getenv(name)
    if value is None:
        raise RuntimeError(f"Falta la variable {name} en /root/.env")
    return value

maria = pymysql.connect(
    host=required_env("MARIADB_HOST"),
    user=required_env("MARIADB_USER"),
    password=required_env("MARIADB_PASSWORD"),
    database=required_env("MARIADB_DATABASE")
)

oracle = cx_Oracle.connect(
    required_env("ORACLE_USER"),
    required_env("ORACLE_PASSWORD"),
    required_env("ORACLE_DSN")
)

cm = maria.cursor()
co = oracle.cursor()

print("Limpiando MariaDB...")

cm.execute("SET FOREIGN_KEY_CHECKS=0")
cm.execute("TRUNCATE TABLE estudiantes")
cm.execute("TRUNCATE TABLE docentes")
cm.execute("TRUNCATE TABLE asignaturas")
cm.execute("SET FOREIGN_KEY_CHECKS=1")
maria.commit()

print("Limpiando Oracle...")

co.execute("TRUNCATE TABLE calificaciones")
co.execute("TRUNCATE TABLE matriculas")

print("Generando 300 docentes...")

for i in range(1, 301):
    cm.execute("""
        INSERT INTO docentes (id_docente, nombres, apellidos, especialidad)
        VALUES (%s,%s,%s,%s)
    """, (
        i,
        fake.first_name(),
        fake.last_name(),
        random.choice(["Base de Datos", "Ciberseguridad", "Redes", "Programación", "Sistemas Operativos"])
    ))

print("Generando 200 asignaturas...")

for i in range(1, 201):
    cm.execute("""
        INSERT INTO asignaturas (id_asignatura, nombre, creditos, carrera)
        VALUES (%s,%s,%s,%s)
    """, (
        i,
        f"Asignatura {i}",
        random.randint(2, 6),
        random.choice(["Ciberseguridad", "Software", "Redes", "Telecomunicaciones"])
    ))

print("Generando 5000 estudiantes...")

for i in range(1, 5001):
    nombres = fake.first_name()
    apellidos = fake.last_name()
    correo = f"{nombres.lower().replace(' ', '')}.{apellidos.lower().replace(' ', '')}{i}@udla.edu.ec"

    cm.execute("""
        INSERT INTO estudiantes (id_estudiante, cedula, nombres, apellidos, correo, carrera)
        VALUES (%s,%s,%s,%s,%s,%s)
    """, (
        i,
        str(fake.unique.random_number(digits=10)),
        nombres,
        apellidos,
        correo,
        random.choice(["Ciberseguridad", "Software", "Redes", "Telecomunicaciones"])
    ))

maria.commit()

print("Generando 50000 matrículas...")

for i in range(1, 50001):
    co.execute("""
        INSERT INTO matriculas
        VALUES (:1,:2,:3,:4,:5,:6)
    """, (
        i,
        random.randint(1, 5000),
        random.randint(1, 200),
        random.randint(1, 300),
        random.choice(["2024-1", "2024-2", "2025-1", "2025-2", "2026-1"]),
        "ACTIVA"
    ))

    if i % 5000 == 0:
        oracle.commit()
        print(f"Matrículas generadas: {i}")

oracle.commit()

print("Generando 150000 calificaciones...")

for i in range(1, 150001):
    nota1 = round(random.uniform(0, 10), 2)
    nota2 = round(random.uniform(0, 10), 2)
    nota_final = round((nota1 + nota2) / 2, 2)
    estado = "APROBADO" if nota_final >= 7 else "REPROBADO"

    co.execute("""
        INSERT INTO calificaciones
        VALUES (:1,:2,:3,:4,:5,:6)
    """, (
        i,
        random.randint(1, 50000),
        nota1,
        nota2,
        nota_final,
        estado
    ))

    if i % 10000 == 0:
        oracle.commit()
        print(f"Calificaciones generadas: {i}")

oracle.commit()

cm.close()
co.close()
maria.close()
oracle.close()

print("Carga masiva con Faker finalizada correctamente.")
