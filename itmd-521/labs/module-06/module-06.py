
import os
import sys 
import shutil

from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from pyspark.sql import functions as F



if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(-1)

    spark = (SparkSession.builder.appName("Module 06").getOrCreate())

    departure_delays = sys.argv[1] 
    
    schema = "`date` STRING, `delay` INT, `distance` INT, `origin` STRING, `destination` STRING"
    departure_delays_df = spark.read.format("csv").option("header","true").option("inferSchema","true").load(departure_delays)

    #departure_delays_df = departure_delays_df.withColumn("date", F.to_date("date", "yyyyMMdd"))

#Part I

    flights_by_distance = (departure_delays_df
    .filter(departure_delays_df.distance > 1000)
    .select("distance", "origin", "destination")
    .orderBy("distance", ascending=False))
    flights_by_distance.show(10)


    flights_from_sfo_to_ord = (departure_delays_df
    .filter((departure_delays_df.delay > 120) & (departure_delays_df.origin == 'SFO') & (departure_delays_df.destination == 'ORD'))
    .select("date", "delay", "origin", "destination")
    .orderBy("delay", ascending=False))
    flights_from_sfo_to_ord.show(10)

    flights_with_delays = (departure_delays
    .select(
        "delay",
        "origin",
        "destination",
        F.when(departure_delays.delay > 360, 'Very Long Delays')
         .when((departure_delays.delay > 120) & (departure_delays.delay < 360), 'Long Delays')
         .when((departure_delays.delay > 60) & (departure_delays.delay < 120), 'Short Delays')
         .when((departure_delays.delay > 0) & (departure_delays.delay < 60), 'Tolerable Delays')
         .when(departure_delays.delay == 0, 'No Delays')
         .otherwise('Early')
         .alias('Flight_Delays')
    )
    .orderBy("origin", "delay", ascending=False)  # Order by origin and delay descending
)



#Part II

    departure_delays_df.createOrReplaceTempView("us_delay_flights_tbl")

    ord_flights = spark.sql("""
    CREATE OR REPLACE TEMP VIEW ord_flights AS
    SELECT * FROM us_delay_flights_tbl
    WHERE origin = 'ORD' AND date BETWEEN '0301' AND '0315'
    """)
    ord_flights.show(5)

    spark.catalog.listColumns("us_delay_flights_tbl")


#Part III


    spark.stop()