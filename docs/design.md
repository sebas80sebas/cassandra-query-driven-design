# APARTADO 3: DISEÑO DEL MODELO DE DATOS

## 3.1. Principios de Diseño

El modelo se ha diseñado siguiendo el principio fundamental de Cassandra: **"diseñar las tablas según las consultas"** (query-driven design). Cada tabla está optimizada para resolver una consulta específica sin necesidad de ALLOW FILTERING ni índices secundarios.

### Decisiones de Preprocesado

**Limpieza de datos:**
- Imputación de edades nulas con la mediana del dataset
- Valores nulos en Embarked se sustituyen por 'U' (Unknown)
- Cabin vacío se marca como 'Unknown'

**Columnas derivadas:**
- **AgeRange**: Categorización de edades en rangos (0-17, 18-29, 30-44, 45-59, 60+)
  - Justificación: Permite particionar eficientemente las consultas por edad sin crear particiones excesivamente grandes con valores continuos

## 3.2. Diseño de Tablas

### TABLA 1: survivors_by_class
**Consulta objetivo:** 5.1 - Supervivientes filtrados por clase

**Estructura:**
```
PRIMARY KEY ((pclass, survived), passengerid)
```

**Justificación:**
- **Partition Key: (pclass, survived)** - Clave compuesta que permite filtrar directamente por clase y estado de supervivencia
- **Clustering Key: passengerid** - Garantiza unicidad y orden determinista
- **Cardinalidad:** 3 clases × 2 estados = 6 particiones (distribución equilibrada)
- **Riesgo evitado:** Evita full scan al particionar por los campos de filtrado exactos de la consulta

### TABLA 2: passengers_by_port_age
**Consulta objetivo:** 5.2 - Pasajeros por puerto ordenados por edad

**Estructura:**
```
PRIMARY KEY (embarked, age, passengerid)
WITH CLUSTERING ORDER BY (age ASC)
```

**Justificación:**
- **Partition Key: embarked** - Separa datos por puerto (S, C, Q, U)
- **Clustering Keys: age, passengerid** - Ordenación natural por edad ascendente
- **Cardinalidad:** 4 puertos = 4 particiones principales
- **Riesgo evitado:** La distribución de pasajeros entre puertos es relativamente equilibrada (~70% S, ~20% C, ~10% Q), evitando hot spots

### TABLA 3: women_survivors_by_class
**Consulta objetivo:** 5.3 - Análisis de mujeres supervivientes por clase

**Estructura:**
```
PRIMARY KEY ((pclass, sex, survived), passengerid)
```

**Justificación:**
- **Partition Key: (pclass, sex, survived)** - Clave compuesta para filtrado específico
- **Clustering Key: passengerid** - Unicidad
- **Cardinalidad:** 3 clases × 2 sexos × 2 estados = 12 particiones
- **Riesgo evitado:** Particionar por los tres criterios evita scanning innecesario y permite análisis comparativos eficientes

### TABLA 4: passengers_by_age_range
**Consulta objetivo:** 5.4 - Pasajeros por rango de edad ordenados

**Estructura:**
```
PRIMARY KEY (agerange, age, passengerid)
WITH CLUSTERING ORDER BY (age ASC)
```

**Justificación:**
- **Partition Key: agerange** - Distribuye por rangos categóricos
- **Clustering Keys: age, passengerid** - Ordenación precisa dentro del rango
- **Cardinalidad:** 5-6 rangos = distribución controlada
- **Riesgo evitado:** Usar rangos en lugar de edad exacta evita crear miles de particiones minúsculas. Las particiones tienen tamaño manejable (~1000-2500 registros cada una)

### TABLA 5: port_survival_analysis
**Consulta objetivo:** 5.5 - Volumen y distribución por puerto y supervivencia

**Estructura:**
```
PRIMARY KEY ((embarked, survived), passengerid)
```

**Justificación:**
- **Partition Key: (embarked, survived)** - Combina puerto y supervivencia para análisis agregado
- **Clustering Key: passengerid** - Unicidad
- **Cardinalidad:** 4 puertos × 2 estados = 8 particiones
- **Riesgo evitado:** Permite contar directamente supervivientes/no supervivientes por puerto sin aggregations costosas

### TABLA 6: class_age_survival_analysis
**Consulta objetivo:** 5.6 - Comparación por clase dentro de rangos de edad

**Estructura:**
```
PRIMARY KEY ((agerange, pclass), survived, passengerid)
```

**Justificación:**
- **Partition Key: (agerange, pclass)** - Combina rango de edad y clase
- **Clustering Keys: survived, passengerid** - Agrupa por supervivencia dentro de cada partición
- **Cardinalidad:** 5 rangos × 3 clases = 15 particiones
- **Riesgo evitado:** La clave compuesta permite comparar clases dentro del mismo rango de edad sin joins ni filtering

## 3.3. Análisis de Riesgos Evitados

### Particiones Grandes
- **Mitigación:** Uso de claves compuestas y rangos categóricos
- **Resultado:** Ninguna partición supera los ~3000 registros en el dataset de 10,000 pasajeros

### Cardinalidad Problemática
- **Evitado:** No usar Age directa como partition key (sería ~80 particiones con distribución desigual)
- **Solución:** AgeRange proporciona 5-6 particiones equilibradas

### Desequilibrios en el Anillo
- **Análisis:** La distribución de embarked favorece puerto S (~70%)
- **Aceptable:** Con solo 3-4 puertos, el desequilibrio es manejable. En producción con replication_factor > 1, el impacto se diluye

### Hot Spots
- **Evitado:** No usar Survived solo como partition key (solo 2 valores = 2 particiones muy grandes)
- **Solución:** Siempre combinar con otras dimensiones (clase, puerto, rango)

## 3.4. Alternativas Consideradas y Descartadas

1. **Usar PassengerId como partition key universal:**
   - Descartado: Requeriría ALLOW FILTERING para todas las consultas analíticas

2. **Índices secundarios en Age, Sex, Pclass:**
   - Descartado: Rendimiento pobre en clusters distribuidos, no permitido por requisitos

3. **Tabla única desnormalizada:**
   - Descartado: No puede optimizar simultáneamente para todas las queries sin ALLOW FILTERING

4. **Materializar agregaciones:**
   - Considerado pero limitado: Cassandra no soporta agregaciones nativas eficientes, pero COUNT(*) sobre particiones específicas es aceptable para análisis exploratorio
