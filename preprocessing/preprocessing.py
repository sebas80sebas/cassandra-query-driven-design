import pandas as pd
import numpy as np

# Cargar los datasets
passenger_info = pd.read_csv('titanic_passager_info_10000.csv')
passenger_trip = pd.read_csv('titanic_passager_trip_10000.csv')

# Unir los datasets por PassengerId
df = pd.merge(passenger_info, passenger_trip, on='PassengerId')

# Limpieza de datos
# 1. Eliminar filas sin PassengerId
df = df.dropna(subset=['PassengerId'])

# 2. Imputar valores nulos en Age con la mediana
median_age = df['Age'].median()
df['Age'] = df['Age'].fillna(median_age)

# 3. Rellenar valores nulos en Embarked con 'U' (Unknown)
df['Embarked'] = df['Embarked'].fillna('U')

# 4. Rellenar valores nulos en Survived con -1 (desconocido)
df['Survived'] = df['Survived'].fillna(-1).astype(int)

# 5. Rellenar Pclass nulo con 0
df['Pclass'] = df['Pclass'].fillna(0).astype(int)

# 6. Rellenar Cabin vacío
df['Cabin'] = df['Cabin'].fillna('Unknown')

# 7. Crear columna de rango de edad
def age_range(age):
    if pd.isna(age) or age < 0:
        return 'Unknown'
    elif age < 18:
        return '0-17'
    elif age < 30:
        return '18-29'
    elif age < 45:
        return '30-44'
    elif age < 60:
        return '45-59'
    else:
        return '60+'

df['AgeRange'] = df['Age'].apply(age_range)

# Redondear Age a 2 decimales
df['Age'] = df['Age'].round(2)
df['Fare'] = df['Fare'].round(2)

# Convertir tipos de datos
df['PassengerId'] = df['PassengerId'].astype(int)
df['SibSp'] = df['SibSp'].astype(int)
df['Parch'] = df['Parch'].astype(int)

print(f"Total de registros después de limpieza: {len(df)}")
print(f"\nDistribución por clase:")
print(df['Pclass'].value_counts().sort_index())
print(f"\nDistribución por puerto:")
print(df['Embarked'].value_counts())
print(f"\nDistribución por supervivencia:")
print(df['Survived'].value_counts())

# TABLA 1: survivors_by_class
# Query 5.1: Supervivientes por clase
# Partition key: Pclass, Survived
# Clustering key: PassengerId
survivors_by_class = df[['PassengerId', 'Pclass', 'Survived', 'Name', 'Sex', 'Age']].copy()
survivors_by_class.to_csv('survivors_by_class.csv', index=False)
print(f"\nTabla survivors_by_class: {len(survivors_by_class)} registros")

# TABLA 2: passengers_by_port_age
# Query 5.2: Pasajeros por puerto ordenados por edad
# Partition key: Embarked
# Clustering key: Age, PassengerId
passengers_by_port_age = df[['Embarked', 'Age', 'PassengerId', 'Name', 'Sex', 'Pclass', 'Survived']].copy()
passengers_by_port_age.to_csv('passengers_by_port_age.csv', index=False)
print(f"Tabla passengers_by_port_age: {len(passengers_by_port_age)} registros")

# TABLA 3: women_survivors_by_class
# Query 5.3: Mujeres supervivientes por clase
# Partition key: Pclass, Sex, Survived
# Clustering key: PassengerId
women_survivors = df[['Pclass', 'Sex', 'Survived', 'PassengerId', 'Name', 'Age']].copy()
women_survivors.to_csv('women_survivors_by_class.csv', index=False)
print(f"Tabla women_survivors_by_class: {len(women_survivors)} registros")

# TABLA 4: passengers_by_age_range
# Query 5.4: Pasajeros por rango de edad
# Partition key: AgeRange
# Clustering key: Age, PassengerId
passengers_by_age_range = df[['AgeRange', 'Age', 'PassengerId', 'Name', 'Sex', 'Pclass', 'Survived']].copy()
passengers_by_age_range.to_csv('passengers_by_age_range.csv', index=False)
print(f"Tabla passengers_by_age_range: {len(passengers_by_age_range)} registros")

# TABLA 5: port_survival_analysis
# Query 5.5: Análisis por puerto y supervivencia
# Partition key: Embarked, Survived
# Clustering key: PassengerId
port_survival = df[['Embarked', 'Survived', 'PassengerId', 'Name', 'Pclass', 'Sex', 'Age']].copy()
port_survival.to_csv('port_survival_analysis.csv', index=False)
print(f"Tabla port_survival_analysis: {len(port_survival)} registros")

# TABLA 6: class_age_survival_analysis
# Query 5.6: Análisis por clase, edad y supervivencia
# Partition key: AgeRange, Pclass
# Clustering key: Survived, PassengerId
class_age_survival = df[['AgeRange', 'Pclass', 'Survived', 'PassengerId', 'Name', 'Sex', 'Age']].copy()
class_age_survival.to_csv('class_age_survival_analysis.csv', index=False)
print(f"Tabla class_age_survival_analysis: {len(class_age_survival)} registros")

print("\n✓ Todos los archivos CSV generados correctamente")
print("\nArchivos generados:")
print("- survivors_by_class.csv")
print("- passengers_by_port_age.csv")
print("- women_survivors_by_class.csv")
print("- passengers_by_age_range.csv")
print("- port_survival_analysis.csv")
print("- class_age_survival_analysis.csv")
