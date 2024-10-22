
import os
import sys 
import shutil

from pyspark.sql import SparkSession
from pyspark.sql.functions import *



if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(-1)

    spark = (SparkSession.builder.appName("Module 06").getOrCreate())

    departure_delays = sys.argv[1] 
    
    departure_delays_df = spark.read.format("csv").option("header","true").option("inferSchema","true").load(departure_delays)


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


#Part II

    departure_delays_df.createOrReplaceTempView("us_delay_flights_tbl")

    ord_flights = spark.sql("""
    SELECT * 
    FROM us_delay_flights_tbl 
    WHERE origin = 'ORD' AND month = 3 AND day BETWEEN 1 AND 15
    """)
    ord_flights.createOrReplaceTempView("ord_flights_view")
    ord_flights.show(5)

    spark.catalog.listColumns("us_delay_flights_tbl")


#Part III
