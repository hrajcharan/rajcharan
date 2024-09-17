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
    
    df_infer.printSchema()
    print(f"Row count with inferred schema: {df_infer.count()}")

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
    
    df_programmatic.printSchema()
    print(f"Row count with programmatic schema: {df_programmatic.count()}")

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
 
    df_ddl = spark.read.csv(divvy_file, schema=StructType.fromDDL(ddl_schema), header=True)

    df_ddl.printSchema()
    print(f"Row count with DDL schema: {df_ddl.count()}")

    spark.stop()