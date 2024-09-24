
import os
import sys 
import shutil

from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from pyspark.ml.feature import StringIndexer, VectorAssembler
from pyspark.ml.stat import Correlation



if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(-1)

    spark = (SparkSession.builder.appName("Module 05").getOrCreate())

    sf_fire = sys.argv[1] 
    
    sf_fire_df = spark.read.format("csv").option("header","true").option("inferSchema","true").load(sf_fire)

    sf_fire_df = sf_fire_df.withColumn("CallDate", to_date(sf_fire_df["CallDate"], "MM/dd/yyyy")) \
                       .withColumn("WatchDate", to_date(sf_fire_df["WatchDate"], "MM/dd/yyyy")) \
                       .withColumn("AvailableDtTm", to_timestamp(sf_fire_df["AvailableDtTm"], "MM/dd/yyyy hh:mm:ss a"))
  
# 1. What were all the different types of fire calls in 2018?

    fire_calls_2018 = sf_fire_df.filter(year("CallDate") == 2018)
    fire_call_types_2018 = fire_calls_2018.select("CallType").distinct()
    fire_call_types_2018.show(truncate=False)


# 2. What months within the year 2018 saw the highest number of fire calls?

    fire_calls_by_month = (fire_calls_2018.groupBy(month("CallDate").alias("Month")).agg(count("IncidentNumber").alias("NumFireCalls")).orderBy("NumFireCalls", ascending=False))
    fire_calls_by_month.show()


# 3. Which neighborhood in San Francisco generated the most fire calls in 2018? 

    fire_calls_by_neighborhood = (fire_calls_2018.groupBy("Neighborhood").agg(count("IncidentNumber").alias("NumFireCalls")).orderBy("NumFireCalls", ascending=False))
    fire_calls_by_neighborhood.show(1)

# 4. Which neighborhoods had the worst response times to fire calls in 2018? 

    response_time_by_neighborhood = (fire_calls_2018.groupBy("Neighborhood").agg(avg("Delay").alias("AvgResponseTime")).orderBy("AvgResponseTime", ascending=False))
    response_time_by_neighborhood.show(5)


# 5. Which week in the year in 2018 had the most fire calls?

    fire_calls_by_week = (fire_calls_2018.groupBy(weekofyear("CallDate").alias("Week")).agg(count("IncidentNumber").alias("NumFireCalls")).orderBy("NumFireCalls", ascending=False))
    fire_calls_by_week.show(1)

# 6. Is there a correlation between neighborhood, zip code, and number of fire calls? 

    # Group by Neighborhood and Zipcode, and count the number of fire calls
    fire_calls_by_neighborhood_zip = sf_fire_df.groupBy("Neighborhood", "Zipcode") \
    .agg(count("IncidentNumber").alias("NumberOfCalls")) \
    .orderBy("NumberOfCalls", ascending=False)

    # StringIndexer to encode categorical variables (Neighborhood and Zipcode)
    neigh_indexer = StringIndexer(inputCol="Neighborhood", outputCol="Neighborhood_index").setHandleInvalid("skip")
    zip_indexer = StringIndexer(inputCol="Zipcode", outputCol="Zipcode_index").setHandleInvalid("skip")

    # Apply the indexers
    df_with_indices = neigh_indexer.fit(fire_calls_by_neighborhood_zip).transform(fire_calls_by_neighborhood_zip)
    df_with_indices = zip_indexer.fit(df_with_indices).transform(df_with_indices)

    # Prepare the data for correlation calculation using VectorAssembler
    vector_col = "features"
    assembler = VectorAssembler(inputCols=["Neighborhood_index", "Zipcode_index", "NumberOfCalls"], outputCol=vector_col)
    df_vector = assembler.transform(df_with_indices).select(vector_col)

    # Calculate the Pearson correlation matrix
    correlation_matrix = Correlation.corr(df_vector, vector_col).head()[0]

    # Extract the correlation values for Neighborhood, Zipcode, and Number of Calls
    neigh_calls_corr = correlation_matrix[0, 2]
    zip_calls_corr = correlation_matrix[1, 2]

    # Print the correlation results
    print(f"Correlation between Neighborhood and NumberOfCalls: {neigh_calls_corr}")
    print(f"Correlation between Zipcode and NumberOfCalls: {zip_calls_corr}")
    
    if neigh_calls_corr > zip_calls_corr:
        print(f"The higher correlation is between Neighborhood and NumberOfCalls: {neigh_calls_corr}")
    else:
        print(f"The higher correlation is between Zipcode and NumberOfCalls: {zip_calls_corr}")  



# 7. How can we use Parquet files or SQL tables to store this data and read it back?

    # Get the current working directory
    current_dir = os.getcwd()

    # Define the path for the Parquet file directory
    parquet_dir = os.path.join(current_dir, "fire_calls_2018")

    # Write data to Parquet directory
    fire_calls_2018.write.mode("overwrite").parquet(parquet_dir)

    # Read data back from Parquet directory
    fire_calls_2018_parquet = spark.read.parquet(parquet_dir)
    fire_calls_2018_parquet.show()

    # Create a temporary SQL table and query it
    fire_calls_2018.createOrReplaceTempView("fire_calls_2018")
    result = spark.sql("SELECT Neighborhood, COUNT(*) as NumFireCalls FROM fire_calls_2018 GROUP BY Neighborhood")
    result.show()

    # Remove the Parquet directory
    if os.path.exists(parquet_dir):
        shutil.rmtree(parquet_dir)
        print(f"Parquet directory {parquet_dir} has been removed.")
    else:
        print(f"Parquet directory {parquet_dir} does not exist.")
    
    spark.stop()
    