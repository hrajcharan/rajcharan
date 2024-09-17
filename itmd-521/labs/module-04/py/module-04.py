import sys 

from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from pyspark.sql.types import *

if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(-1)
    

    spark = (SparkSession.builder.appName("Divvy Print Schema").getOrCreate())

    divvy_file = sys.argv[1] 
    
    df_infer = (spark.read.format("csv").option("header","true").option("inferSchema","true").load(divvy_file))
    
    print("=== Inferred Schema ===")
    df_infer.printSchema()
    row_count_inferred = df_infer.count()
    print(f"Row count (inferred schema): {row_count_inferred}\n")

    programmatic_schema = StructType([
    StructField("trip_id", IntegerType(), False),
    StructField("starttime", TimestampType(), True),
    StructField("stoptime", TimestampType(), True),
    StructField("bikeid", IntegerType(), True),
    StructField("tripduration", IntegerType(), True),
    StructField("from_station_id", IntegerType(), True),
    StructField("from_station_name", StringType(), True),
    StructField("to_station_id", IntegerType(), True),
    StructField("to_station_name", StringType(), True),
    StructField("usertype", StringType(), True),
    StructField("gender", StringType(), True),
    StructField("birthyear", IntegerType(), True)])
   
    df_programmatic = spark.read.csv(divvy_file, schema=programmatic_schema, header=True)
    
    print("=== Programmatic Schema ===")
    df_programmatic.printSchema()
    row_count_programmatic = df_programmatic.count()
    print(f"Row count (programmatic schema): {row_count_programmatic}\n")

    ddl_schema = """
    trip_id INT,
    starttime TIMESTAMP,
    stoptime TIMESTAMP,
    bikeid INT,
    tripduration INT,
    from_station_id INT,
    from_station_name STRING,
    to_station_id INT,
    to_station_name STRING,
    usertype STRING,
    gender STRING,
    birthyear INT 
    """
 
    df_ddl = spark.read.csv(divvy_file, schema=ddl_schema, header=True)

    print("=== DDL Schema ===")
    df_ddl.printSchema()
    row_count_ddl = df_ddl.count()
    print(f"Row count (DDL schema): {row_count_ddl}\n")

    spark.stop()