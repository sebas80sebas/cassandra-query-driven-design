# APARTADO 6: CUESTIONES TEÓRICAS

## 6.1. Impacto de ALLOW FILTERING

### ¿Cómo cambiarían las consultas?

Con ALLOW FILTERING permitido, podríamos simplificar el modelo a una o dos tablas genéricas:

```sql
-- Modelo simplificado con ALLOW FILTERING
CREATE TABLE passengers (
    passengerid int PRIMARY KEY,
    pclass int,
    survived int,
    sex text,
    age double,
    embarked text,
    name text
);

-- Consulta 5.1 con ALLOW FILTERING
SELECT * FROM passengers 
WHERE pclass = 1 AND survived = 1 
ALLOW FILTERING;

-- Consulta 5.3 con ALLOW FILTERING
SELECT * FROM passengers 
WHERE pclass = 1 AND sex = 'female' AND survived = 1 
ALLOW FILTERING;
```

### ¿Serían eficientes?

**NO**, por las siguientes razones:

1. **Scan completo de particiones:** ALLOW FILTERING obliga a Cassandra a leer TODAS las particiones del cluster y filtrar en memoria. En un cluster distribuido con millones de registros, esto implica:
   - Lectura de todos los nodos
   - Transferencia masiva de datos por la red
   - Filtrado en el nodo coordinador

2. **Latencia inaceptable:** Para un dataset de 10,000 registros la diferencia podría ser de milisegundos vs segundos. Con millones de registros: segundos vs minutos u horas.

3. **Escalabilidad comprometida:** El rendimiento empeora linealmente con el tamaño del dataset, anulando la ventaja de escalabilidad horizontal de Cassandra.

4. **Recursos desperdiciados:** CPU y memoria se utilizan para filtrar datos que nunca debieron leerse.

**Comparación práctica:**
- Con diseño correcto (partition key = pclass): Lee solo 1 partición (~3,300 registros)
- Con ALLOW FILTERING: Lee todas las particiones (10,000 registros), descarta ~6,700

**Conclusión:** ALLOW FILTERING convierte Cassandra en una base de datos relacional ineficiente. El diseño query-driven existe precisamente para evitar esta ineficiencia.

---

## 6.2. Índices Secundarios en Cassandra

### ¿Por qué parecen útiles pero no son adecuados?

Los índices secundarios pueden parecer la solución obvia para consultas sobre columnas no-clave, pero tienen **limitaciones fundamentales en entornos distribuidos**:

### Problemas en producción:

1. **Implementación local por nodo:**
   - Cada nodo mantiene índices solo de sus propios datos
   - Una consulta debe contactar TODOS los nodos del cluster
   - No hay optimización de red ni paralelización eficiente

2. **Alto overhead de mantenimiento:**
   - Escrituras adicionales por cada índice (impacto en throughput)
   - Compactación más compleja y costosa
   - Mayor uso de disco y memoria

3. **Rendimiento degradado con cardinalidad:**
   - **Alta cardinalidad** (ej: PassengerId): Cada entrada del índice apunta a pocos registros, pero el índice es enorme
   - **Baja cardinalidad** (ej: Sex): Cada entrada apunta a muchos registros, provocando lecturas masivas
   - **Cardinalidad óptima:** Muy estrecha, raramente se cumple en práctica

4. **Tombstones y fragmentación:**
   - Los índices acumulan tombstones de registros eliminados
   - Degradan el rendimiento de lectura progresivamente
   - Requieren compactación frecuente

5. **Falta de control sobre distribución:**
   - No puedes diseñar cómo se distribuyen los datos
   - Imposible evitar hot spots o particiones desbalanceadas

### Ejemplo práctico:

```sql
-- Parece conveniente
CREATE INDEX ON passengers(sex);
SELECT * FROM passengers WHERE sex = 'female';

-- Realidad:
-- 1. Query contacta todos los nodos
-- 2. Cada nodo escanea su índice local
-- 3. Devuelve ~50% de todos los registros (female)
-- 4. Coordinador debe paginar millones de filas
```

### Alternativa correcta:

Desnormalización y diseño query-driven:
```sql
-- Tabla específica para consultas por sexo
CREATE TABLE passengers_by_sex (
    sex text,
    passengerid int,
    ...
    PRIMARY KEY (sex, passengerid)
);
-- Solo lee la partición 'female', sin overhead
```

**Conclusión:** En clusters grandes, los índices secundarios transforman consultas que deberían ser O(1) en O(n). El "costo" de desnormalizar y duplicar datos es marginal comparado con la ganancia en rendimiento.

---

## 6.3. Impacto de un Mal Diseño de Claves

Un diseño deficiente de partition keys y clustering keys tiene efectos **cascada** en múltiples aspectos:

### 1. Rendimiento de Consultas

**Problema: Partition key incorrecta**
```sql
-- MAL DISEÑO: Usar solo Survived como partition key
PRIMARY KEY (survived, passengerid)
-- Solo 2 particiones: survived=0 y survived=1
```

**Consecuencias:**
- Particiones gigantes (~5,000 registros cada una)
- Lecturas lentas incluso con partition key específica
- Timeouts en queries de agregación

**Problema: Falta de clustering key apropiada**
```sql
-- Sin ordenación útil
PRIMARY KEY ((embarked), passengerid)
-- Para consulta "ordenar por edad" requiere ordenación en cliente
```

### 2. Distribución del Anillo (Hot Spots)

**Problema: Baja cardinalidad en partition key**
```sql
-- Solo 2-3 valores posibles
PRIMARY KEY (sex, ...)  -- male/female
PRIMARY KEY (pclass, ...) -- 1/2/3
```

**Consecuencias:**
- Nodos con carga desigual
- Algunos nodos saturados, otros infrautilizados
- Imposibilidad de escalar horizontalmente
- Bottleneck en nodos "calientes"

**Ejemplo numérico:**
- Cluster de 10 nodos
- Partition key = sex (2 valores)
- 50% de datos en 1 nodo, 50% en otro nodo
- 8 nodos prácticamente vacíos

### 3. Compactación Ineficiente

**Problema: Particiones muy grandes**

Cassandra organiza datos en **SSTables** (Sorted String Tables):
- Compactación fusiona SSTables para eliminar duplicados y tombstones
- Particiones grandes complican y ralentizan la compactación

**Consecuencias:**
- Mayor uso de CPU y disco I/O
- Compactación puede no completarse durante ventanas de mantenimiento
- Acumulación de SSTables fragmentadas
- Degradación progresiva del rendimiento

**Problema: Particiones muy pequeñas**
- Miles de particiones minúsculas
- Overhead de metadatos por cada partición
- Bloom filters ineficientes
- Mayor consumo de memoria

### 4. Lecturas Excesivas

**Problema: Wide partitions sin límites**
```sql
-- Partición puede crecer indefinidamente
PRIMARY KEY (embarked, passengerid)
-- Si un puerto tiene 100,000 pasajeros...
```

**Consecuencias:**
- Lecturas de partición completa aunque solo necesites 10 registros
- Paginación ineficiente
- Memory pressure en nodos
- Riesgo de OutOfMemory errors

**Problema: Scatter-gather queries**
- Consultas que tocan múltiples particiones
- Latencia acumulativa (worst-case latency de todas las particiones)
- Mayor probabilidad de fallo parcial

### 5. Escrituras Ineficientes

**Problema: Hot partitions en escritura**
```sql
-- Timestamp-based key con mala granularidad
PRIMARY KEY ((date_hour), timestamp)
-- Todas las escrituras de 1 hora van al mismo nodo
```

**Consecuencias:**
- Cuello de botella en escritura
- Write timeouts
- Necesidad de throttling artificial

### Ejemplo Real de Impacto:

**Diseño deficiente:**
```sql
CREATE TABLE bad_design (
    passengerid int PRIMARY KEY,
    pclass int,
    survived int,
    ...
);
SELECT * FROM bad_design WHERE pclass = 1; -- ALLOW FILTERING
```
- Latencia: 2-5 segundos (full scan)
- Throughput: ~100 queries/segundo
- Nodos: Todos involucrados, carga balanceada pero ineficiente

**Diseño optimizado:**
```sql
CREATE TABLE good_design (
    pclass int,
    survived int,
    passengerid int,
    PRIMARY KEY ((pclass, survived), passengerid)
);
SELECT * FROM good_design WHERE pclass = 1 AND survived = 1;
```
- Latencia: 5-20 ms (single partition read)
- Throughput: ~10,000 queries/segundo
- Nodos: Solo 1 nodo procesando la query

**Mejora:** 100-1000x en rendimiento

---

## Conclusión General

El diseño de claves en Cassandra no es solo una cuestión de sintaxis, sino la **decisión arquitectónica fundamental** que determina:
- Si tu aplicación puede escalar horizontalmente
- Si puedes cumplir SLAs de latencia
- Si necesitarás sobre-provisionar hardware
- Si el sistema será mantenible a largo plazo

La inversión en diseño query-driven inicial evita refactorizaciones costosas y migraciones de datos en producción.
