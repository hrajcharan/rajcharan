
import os
import sys 
import shutil

from pyspark.sql import SparkSession
from pyspark.sql.functions import *

if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(-1)

    spark = (SparkSession.builder.appName("Module-06").getOrCreate())

    departure_delays = sys.argv[1] 
    
    schema = "date STRING, delay INT, distance INT, origin STRING, destination STRING"

    departure_delays_df = spark.read.format("csv").schema(schema).option("header", "true").load(departure_delays)


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

    flights_with_delays = (departure_delays_df
    .withColumn(
        "Flight_Delays",
        when(departure_delays_df.delay > 360, 'Very Long Delays')
        .when((departure_delays_df.delay > 120) & (departure_delays_df.delay <= 360), 'Long Delays')
        .when((departure_delays_df.delay > 60) & (departure_delays_df.delay <= 120), 'Short Delays')
        .when((departure_delays_df.delay > 0) & (departure_delays_df.delay <= 60), 'Tolerable Delays')
        .when(departure_delays_df.delay == 0, 'No Delays')
        .otherwise('Early'))
    .select("delay", "origin", "destination", "Flight_Delays")
    .orderBy("origin", "delay", ascending=False))
    flights_with_delays.show(10)


#Part II

    ord_flights = departure_delays_df.filter(
    (departure_delays_df.origin == 'ORD') &
    (departure_delays_df.date.substr(1, 2) == "03") &  
    (departure_delays_df.date.substr(3, 2).between("01", "15")))

    ord_flights.createOrReplaceTempView("us_delay_flights_tbl")

    spark.sql("SELECT * FROM us_delay_flights_tbl LIMIT 5").show()

    spark.catalog.listColumns("us_delay_flights_tbl")


#Part III


    spark.stop()