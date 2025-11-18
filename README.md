# Titanic Cassandra Data Model

[![Cassandra](https://img.shields.io/badge/Cassandra-4.0+-blue.svg)](https://cassandra.apache.org/)
[![Python](https://img.shields.io/badge/Python-3.8+-green.svg)](https://www.python.org/)

A scalable NoSQL data model implementation using Apache Cassandra to analyze Titanic passenger data. This project demonstrates query-driven design principles, partitioning strategies, and efficient data modeling for distributed systems.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Usage](#usage)
- [Data Model](#data-model)
- [Queries](#queries)
- [Performance Analysis](#performance-analysis)
- [Project Structure](#project-structure)

## Overview

This project implements an optimized Cassandra data model to answer analytical queries about Titanic passengers. The design follows Cassandra best practices:

- **Query-driven design** - Tables optimized for specific query patterns
- **No ALLOW FILTERING** - All queries use partition keys efficiently
- **No secondary indexes** - Leverages denormalization for performance
- **Balanced partitions** - Carefully designed partition keys to avoid hot spots
- **Optimal clustering** - Natural ordering for range queries

## Features

- **6 specialized tables** for different analytical queries
- **Efficient data preprocessing** with Pandas
- **Complete CQL scripts** for setup and queries
- **Partition balancing** strategies to prevent data skew
- **Age range bucketing** for controlled cardinality
- **Performance benchmarks** and analysis

## Architecture

### Data Flow

```
Raw CSVs → Python Preprocessing → Integrated CSVs → Cassandra Tables → Analytical Queries
```

### Design Principles

1. **Denormalization over Joins** - Cassandra doesn't support joins; data is duplicated across tables
2. **Partition Key Selection** - Based on query filters to ensure single-partition reads
3. **Clustering Keys** - Provide natural ordering within partitions
4. **Composite Keys** - Used to create well-distributed, queryable partitions

## Prerequisites

- **Apache Cassandra** 4.0+ or DataStax Astra
- **Python** 3.8+
- **Pandas** library
- **cqlsh** (Cassandra Query Language Shell)

## Installation

1. **Clone the repository**
```bash
git clone https://github.com/sebas80sebas/titanic-cassandra-model.git
cd titanic-cassandra-model
```

2. **Install Python dependencies**
```bash
pip install -r requirements.txt
```

3. **Start Cassandra** (if running locally)
```bash
cassandra -f
```

## Usage

### Step 1: Preprocess Data

```bash
python preprocessing/preprocess_titanic.py
```

This generates 6 CSV files optimized for each Cassandra table.

### Step 2: Create Tables and Load Data

```bash
cqlsh -f scripts/setup_tables.cql
```

### Step 3: Run Queries

```bash
cqlsh -f scripts/queries.cql
```

### Step 4: Verify Data

```bash
cqlsh -f scripts/verification.cql
```

## Data Model

### Tables Overview

| Table Name | Partition Key | Clustering Key | Query Purpose |
|------------|--------------|----------------|---------------|
| `survivors_by_class` | `(pclass, survived)` | `passengerid` | Filter survivors by class |
| `passengers_by_port_age` | `embarked` | `age, passengerid` | Sort passengers by age per port |
| `women_survivors_by_class` | `(pclass, sex, survived)` | `passengerid` | Analyze female survivors by class |
| `passengers_by_age_range` | `agerange` | `age, passengerid` | Query passengers in age ranges |
| `port_survival_analysis` | `(embarked, survived)` | `passengerid` | Compare survival rates by port |
| `class_age_survival_analysis` | `(agerange, pclass)` | `survived, passengerid` | Multi-dimensional survival analysis |

### Key Design Decisions

#### Age Bucketing
Instead of using exact ages (high cardinality → 80+ partitions), we use ranges:
- `0-17`: Children
- `18-29`: Young adults
- `30-44`: Adults
- `45-59`: Middle-aged
- `60+`: Seniors

**Why?** Reduces partition count from ~80 to 5-6, with balanced distribution.

#### Composite Partition Keys
Example: `(pclass, survived)` creates 6 partitions (3 classes × 2 states) instead of 3 or 2.

**Why?** Better distribution and allows filtering on both dimensions without ALLOW FILTERING.

#### Strategic Denormalization
Same passenger data appears in 6 tables.

**Why?** In Cassandra, reads are cheap, joins are impossible. Optimizing for read performance is paramount.

## Queries

### Example Queries

**Q1: Survivors by Class**
```sql
SELECT * FROM survivors_by_class 
WHERE pclass = 1 AND survived = 1;
```

**Q2: Passengers by Port, Sorted by Age**
```sql
SELECT * FROM passengers_by_port_age 
WHERE embarked = 'S' 
LIMIT 20;
```

**Q3: Female Survivors by Class**
```sql
SELECT COUNT(*) FROM women_survivors_by_class 
WHERE pclass = 1 AND sex = 'female' AND survived = 1;
```

**Q4: Passengers in Age Range**
```sql
SELECT * FROM passengers_by_age_range 
WHERE agerange = '18-29';
```

**Q5: Survival Analysis by Port**
```sql
SELECT COUNT(*) FROM port_survival_analysis 
WHERE embarked = 'S' AND survived = 1;
```

**Q6: Multi-dimensional Survival Analysis**
```sql
SELECT COUNT(*) FROM class_age_survival_analysis 
WHERE agerange = '18-29' AND pclass = 1 AND survived = 1;
```

## Performance Analysis

### Partition Distribution

| Table | Partitions | Avg Size | Max Size |
|-------|------------|----------|----------|
| survivors_by_class | 6 | ~1,667 | ~3,500 |
| passengers_by_port_age | 4 | ~2,500 | ~7,000 |
| passengers_by_age_range | 5 | ~2,000 | ~2,800 |

### Query Performance (10K records)

| Query | Latency | Partitions Read | Scalability |
|-------|---------|-----------------|-------------|
| Q1 | ~15ms | 1 |  O(1) |
| Q2 | ~20ms | 1 |  O(1) |
| Q3 | ~12ms | 1 |  O(1) |
| Q4 | ~18ms | 1 |  O(1) |
| Q5 | ~10ms | 1 |  O(1) |
| Q6 | ~15ms | 1 |  O(1) |

**Without proper design (using ALLOW FILTERING):** ~2-5 seconds, O(n) 


## Project Structure

```
/
├── data/
│   ├── raw/
│   │   ├── titanic_passager_info_10000.csv
│   │   └── titanic_passager_trip_10000.csv
│   └── processed/
│       ├── survivors_by_class.csv
│       ├── passengers_by_port_age.csv
│       ├── women_survivors_by_class.csv
│       ├── passengers_by_age_range.csv
│       ├── port_survival_analysis.csv
│       └── class_age_survival_analysis.csv
│
├── preprocessing/
│   └── preprocessing.py
│
├── scripts/
│   └── script.cql
│
├── docs/
│   ├── design.md
│   ├── theoretical_doubts.md
│   └── architecture_diagram.svg
│
├── requirements.txt
├── README.md
└── LICENSE
```

---
