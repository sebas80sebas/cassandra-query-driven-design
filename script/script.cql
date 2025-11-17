-- =====================================================
-- CREACIÓN DEL KEYSPACE
-- =====================================================
CREATE KEYSPACE IF NOT EXISTS titanic_db 
WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1};

USE titanic_db;

-- =====================================================
-- CREACIÓN DE TABLAS
-- =====================================================

-- TABLA 1: survivors_by_class
-- Consulta 5.1: Supervivientes por clase
-- PK: (Pclass, Survived) - Permite filtrar por clase y supervivencia
-- CK: PassengerId - Para ordenación y unicidad
DROP TABLE IF EXISTS survivors_by_class;
CREATE TABLE survivors_by_class (
    passengerid int,
    pclass int,
    survived int,
    name text,
    sex text,
    age double,
    PRIMARY KEY ((pclass, survived), passengerid)
);

-- TABLA 2: passengers_by_port_age
-- Consulta 5.2: Pasajeros por puerto ordenados por edad
-- PK: Embarked - Particiona por puerto
-- CK: Age, PassengerId - Ordena por edad (menor a mayor)
DROP TABLE IF EXISTS passengers_by_port_age;
CREATE TABLE passengers_by_port_age (
    embarked text,
    age double,
    passengerid int,
    name text,
    sex text,
    pclass int,
    survived int,
    PRIMARY KEY (embarked, age, passengerid)
) WITH CLUSTERING ORDER BY (age ASC, passengerid ASC);

-- TABLA 3: women_survivors_by_class
-- Consulta 5.3: Mujeres supervivientes por clase
-- PK: (Pclass, Sex, Survived) - Permite filtrar por clase, sexo y supervivencia
-- CK: PassengerId - Para unicidad
DROP TABLE IF EXISTS women_survivors_by_class;
CREATE TABLE women_survivors_by_class (
    pclass int,
    sex text,
    survived int,
    passengerid int,
    name text,
    age double,
    PRIMARY KEY ((pclass, sex, survived), passengerid)
);

-- TABLA 4: passengers_by_age_range
-- Consulta 5.4: Pasajeros por rango de edad ordenados por edad
-- PK: AgeRange - Particiona por rango de edad
-- CK: Age, PassengerId - Ordena por edad dentro del rango
DROP TABLE IF EXISTS passengers_by_age_range;
CREATE TABLE passengers_by_age_range (
    agerange text,
    age double,
    passengerid int,
    name text,
    sex text,
    pclass int,
    survived int,
    PRIMARY KEY (agerange, age, passengerid)
) WITH CLUSTERING ORDER BY (age ASC, passengerid ASC);

-- TABLA 5: port_survival_analysis
-- Consulta 5.5: Análisis por puerto y supervivencia
-- PK: (Embarked, Survived) - Particiona por puerto y supervivencia
-- CK: PassengerId - Para unicidad
DROP TABLE IF EXISTS port_survival_analysis;
CREATE TABLE port_survival_analysis (
    embarked text,
    survived int,
    passengerid int,
    name text,
    pclass int,
    sex text,
    age double,
    PRIMARY KEY ((embarked, survived), passengerid)
);

-- TABLA 6: class_age_survival_analysis
-- Consulta 5.6: Análisis por clase, edad y supervivencia
-- PK: (AgeRange, Pclass) - Particiona por rango de edad y clase
-- CK: Survived, PassengerId - Agrupa por supervivencia
DROP TABLE IF EXISTS class_age_survival_analysis;
CREATE TABLE class_age_survival_analysis (
    agerange text,
    pclass int,
    survived int,
    passengerid int,
    name text,
    sex text,
    age double,
    PRIMARY KEY ((agerange, pclass), survived, passengerid)
);

-- =====================================================
-- CARGA DE DATOS
-- =====================================================

-- Tabla 1: survivors_by_class
COPY survivors_by_class (passengerid, pclass, survived, name, sex, age) 
FROM 'survivors_by_class.csv' WITH HEADER = TRUE;

-- Tabla 2: passengers_by_port_age
COPY passengers_by_port_age (embarked, age, passengerid, name, sex, pclass, survived) 
FROM 'passengers_by_port_age.csv' WITH HEADER = TRUE;

-- Tabla 3: women_survivors_by_class
COPY women_survivors_by_class (pclass, sex, survived, passengerid, name, age) 
FROM 'women_survivors_by_class.csv' WITH HEADER = TRUE;

-- Tabla 4: passengers_by_age_range
COPY passengers_by_age_range (agerange, age, passengerid, name, sex, pclass, survived) 
FROM 'passengers_by_age_range.csv' WITH HEADER = TRUE;

-- Tabla 5: port_survival_analysis
COPY port_survival_analysis (embarked, survived, passengerid, name, pclass, sex, age) 
FROM 'port_survival_analysis.csv' WITH HEADER = TRUE;

-- Tabla 6: class_age_survival_analysis
COPY class_age_survival_analysis (agerange, pclass, survived, passengerid, name, sex, age) 
FROM 'class_age_survival_analysis.csv' WITH HEADER = TRUE;

-- =====================================================
-- VERIFICACIÓN DE CARGA
-- =====================================================

-- Contar registros en cada tabla
SELECT COUNT(*) FROM survivors_by_class;
SELECT COUNT(*) FROM passengers_by_port_age;
SELECT COUNT(*) FROM women_survivors_by_class;
SELECT COUNT(*) FROM passengers_by_age_range;
SELECT COUNT(*) FROM port_survival_analysis;
SELECT COUNT(*) FROM class_age_survival_analysis;

-- =====================================================
-- CONSULTAS DEL APARTADO 5
-- =====================================================

-- 5.1. Supervivientes por clase
-- Ejemplo: Supervivientes de primera clase
SELECT * FROM survivors_by_class WHERE pclass = 1 AND survived = 1;

-- Ejemplo: Supervivientes de segunda clase
SELECT * FROM survivors_by_class WHERE pclass = 2 AND survived = 1;

-- Ejemplo: Supervivientes de tercera clase
SELECT * FROM survivors_by_class WHERE pclass = 3 AND survived = 1;

-- Contar supervivientes por clase
SELECT COUNT(*) FROM survivors_by_class WHERE pclass = 1 AND survived = 1;
SELECT COUNT(*) FROM survivors_by_class WHERE pclass = 2 AND survived = 1;
SELECT COUNT(*) FROM survivors_by_class WHERE pclass = 3 AND survived = 1;

-- 5.2. Pasajeros por puerto ordenados por edad
-- Puerto S (Southampton)
SELECT * FROM passengers_by_port_age WHERE embarked = 'S' LIMIT 20;

-- Puerto C (Cherbourg)
SELECT * FROM passengers_by_port_age WHERE embarked = 'C' LIMIT 20;

-- Puerto Q (Queenstown)
SELECT * FROM passengers_by_port_age WHERE embarked = 'Q' LIMIT 20;

-- 5.3. Mujeres supervivientes por clase
-- Mujeres supervivientes de primera clase
SELECT COUNT(*) FROM women_survivors_by_class WHERE pclass = 1 AND sex = 'female' AND survived = 1;

-- Mujeres supervivientes de segunda clase
SELECT COUNT(*) FROM women_survivors_by_class WHERE pclass = 2 AND sex = 'female' AND survived = 1;

-- Mujeres supervivientes de tercera clase
SELECT COUNT(*) FROM women_survivors_by_class WHERE pclass = 3 AND sex = 'female' AND survived = 1;

-- Ver detalles
SELECT * FROM women_survivors_by_class WHERE pclass = 1 AND sex = 'female' AND survived = 1;

-- 5.4. Pasajeros por rango de edad
-- Rango 18-29 años
SELECT * FROM passengers_by_age_range WHERE agerange = '18-29' LIMIT 20;

-- Rango 30-44 años
SELECT * FROM passengers_by_age_range WHERE agerange = '30-44' LIMIT 20;

-- Rango 0-17 años (menores)
SELECT * FROM passengers_by_age_range WHERE agerange = '0-17' LIMIT 20;

-- Contar por rango
SELECT COUNT(*) FROM passengers_by_age_range WHERE agerange = '18-29';

-- 5.5. Análisis por puerto y supervivencia
-- Puerto S: supervivientes y no supervivientes
SELECT COUNT(*) FROM port_survival_analysis WHERE embarked = 'S' AND survived = 1;
SELECT COUNT(*) FROM port_survival_analysis WHERE embarked = 'S' AND survived = 0;

-- Puerto C: supervivientes y no supervivientes
SELECT COUNT(*) FROM port_survival_analysis WHERE embarked = 'C' AND survived = 1;
SELECT COUNT(*) FROM port_survival_analysis WHERE embarked = 'C' AND survived = 0;

-- Puerto Q: supervivientes y no supervivientes
SELECT COUNT(*) FROM port_survival_analysis WHERE embarked = 'Q' AND survived = 1;
SELECT COUNT(*) FROM port_survival_analysis WHERE embarked = 'Q' AND survived = 0;

-- 5.6. Análisis por clase, edad y supervivencia
-- Rango 18-29, por clase
-- Clase 1
SELECT COUNT(*) FROM class_age_survival_analysis WHERE agerange = '18-29' AND pclass = 1 AND survived = 1;
SELECT COUNT(*) FROM class_age_survival_analysis WHERE agerange = '18-29' AND pclass = 1 AND survived = 0;

-- Clase 2
SELECT COUNT(*) FROM class_age_survival_analysis WHERE agerange = '18-29' AND pclass = 2 AND survived = 1;
SELECT COUNT(*) FROM class_age_survival_analysis WHERE agerange = '18-29' AND pclass = 2 AND survived = 0;

-- Clase 3
SELECT COUNT(*) FROM class_age_survival_analysis WHERE agerange = '18-29' AND pclass = 3 AND survived = 1;
SELECT COUNT(*) FROM class_age_survival_analysis WHERE agerange = '18-29' AND pclass = 3 AND survived = 0;

-- Rango 30-44, por clase
SELECT COUNT(*) FROM class_age_survival_analysis WHERE agerange = '30-44' AND pclass = 1 AND survived = 1;
SELECT COUNT(*) FROM class_age_survival_analysis WHERE agerange = '30-44' AND pclass = 2 AND survived = 1;
SELECT COUNT(*) FROM class_age_survival_analysis WHERE agerange = '30-44' AND pclass = 3 AND survived = 1;
