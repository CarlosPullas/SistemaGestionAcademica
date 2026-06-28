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

cm = maria.cursor()
co = oracle.cursor()

print("Limpiando datos...")

cm.execute("DELETE FROM estudiantes")
cm.execute("DELETE FROM docentes")
cm.execute("DELETE FROM asignaturas")

co.execute("DELETE FROM calificaciones")
co.execute("DELETE FROM matriculas")

maria.commit()
oracle.commit()

print("Generando docentes...")

for i in range(300):
    cm.execute("""
        INSERT INTO docentes (nombres, apellidos, especialidad)
        VALUES (%s,%s,%s)
    """, (
        fake.first_name(),
        fake.last_name(),
        random.choice(["Base de Datos", "Ciberseguridad", "Redes", "Programación", "Sistemas Operativos"])
    ))

print("Generando asignaturas...")

for i in range(1, 201):
    cm.execute("""
        INSERT INTO asignaturas (nombre, creditos, carrera)
        VALUES (%s,%s,%s)
    """, (
        f"Asignatura {i}",
        random.randint(2, 6),
        random.choice(["Ciberseguridad", "Software", "Redes", "Telecomunicaciones"])
    ))

print("Generando estudiantes...")

for i in range(5000):
    nombres = fake.first_name()
    apellidos = fake.last_name()
    correo = f"{nombres.lower()}.{apellidos.lower()}{i}@udla.edu.ec"

    cm.execute("""
        INSERT INTO estudiantes (cedula, nombres, apellidos, correo, carrera)
        VALUES (%s,%s,%s,%s,%s)
    """, (
        str(fake.unique.random_number(digits=10)),
        nombres,
        apellidos,
        correo,
        random.choice(["Ciberseguridad", "Software", "Redes", "Telecomunicaciones"])
    ))

maria.commit()

print("Generando matrículas...")

for i in range(1, 50001):
    id_estudiante = random.randint(1, 5000)
    id_asignatura = random.randint(1, 200)
    id_docente = random.randint(1, 300)

    co.execute("""
        INSERT INTO matriculas
        VALUES (:1,:2,:3,:4,:5,:6)
    """, (
        i,
        id_estudiante,
        id_asignatura,
        id_docente,
        random.choice(["2024-1", "2024-2", "2025-1", "2025-2", "2026-1"]),
        "ACTIVA"
    ))

    if i % 1000 == 0:
        oracle.commit()
        print(f"Matrículas generadas: {i}")

oracle.commit()

print("Generando calificaciones...")

for i in range(1, 150001):
    id_matricula = random.randint(1, 50000)
    nota1 = round(random.uniform(0, 10), 2)
    nota2 = round(random.uniform(0, 10), 2)
    nota_final = round((nota1 + nota2) / 2, 2)
    estado = "APROBADO" if nota_final >= 7 else "REPROBADO"

    co.execute("""
        INSERT INTO calificaciones
        VALUES (:1,:2,:3,:4,:5,:6)
    """, (
        i,
        id_matricula,
        nota1,
        nota2,
        nota_final,
        estado
    ))

    if i % 1000 == 0:
        oracle.commit()
        print(f"Calificaciones generadas: {i}")

oracle.commit()

cm.close()
co.close()
maria.close()
oracle.close()

print("Datos masivos generados correctamente.")
