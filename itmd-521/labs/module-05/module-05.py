
import sys 

from pyspark.sql import SparkSession
from pyspark.sql.functions import *

if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(-1)

    spark = (SparkSession.builder.appName("Module 05").getOrCreate())

    sf_fire = sys.argv[1] 
    
    sf_fire_df = spark.read.format("csv").option("header","true").option("inferSchema","true").load(sf_fire)

    sf_fire_df = sf_fire_df.withColumn("CallDate", to_date(sf_fire_df["CallDate"], "MM/dd/yyyy")) \
                       .withColumn("WatchDate", to_date(sf_fire_df["WatchDate"], "MM/dd/yyyy")) \
                       .withColumn("AvailableDtTm", to_timestamp(sf_fire_df["AvailableDtTm"], "MM/dd/yyyy hh:mm:ss a"))
  
#What were all the different types of fire calls in 2018?

    fire_calls_2018 = sf_fire_df.filter(year("CallDate") == 2018)
    fire_call_types_2018 = fire_calls_2018.select("CallType").distinct()
    fire_call_types_2018.show(truncate=False)


#What months within the year 2018 saw the highest number of fire calls?

    fire_calls_by_month = (fire_calls_2018.groupBy(month("CallDate").alias("Month")).agg(count("IncidentNumber").alias("NumFireCalls")).orderBy("NumFireCalls", ascending=False))
    fire_calls_by_month.show()


#Which neighborhood in San Francisco generated the most fire calls in 2018? 

    fire_calls_by_neighborhood = (fire_calls_2018.groupBy("Neighborhood").agg(count("IncidentNumber").alias("NumFireCalls")).orderBy("NumFireCalls", ascending=False))
    fire_calls_by_neighborhood.show(1)

#Which neighborhoods had the worst response times to fire calls in 2018? 

    response_time_by_neighborhood = (fire_calls_2018.groupBy("Neighborhood").agg(avg("ResponseDelayedinMins").alias("AvgResponseTime")).orderBy("AvgResponseTime", ascending=False))
    response_time_by_neighborhood.show(5)


#Which week in the year in 2018 had the most fire calls?


#Is there a correlation between neighborhood, zip code, and number of fire calls? 


#How can we use Parquet files or SQL tables to store this data and read it back?


    spark.stop()
    