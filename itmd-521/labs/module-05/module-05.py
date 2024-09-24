
import sys 

from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from pyspark.sql.types import *
from scipy.stats import f_oneway, chi2_contingency


def fill_missing_values(df):
    # Fill missing values in numerical columns with the mean of the column
    numerical_cols = [field.name for field in df.schema.fields if isinstance(field.dataType, (IntegerType, DoubleType))]
    for col_name in numerical_cols:
        mean_value = df.agg({col_name: "mean"}).collect()[0][0]
        if mean_value is not None:  # Ensure mean_value is not None
            df = df.fillna(mean_value, subset=[col_name])
    
    # Fill missing values in categorical columns with the most frequent value
    categorical_cols = [field.name for field in df.schema.fields if isinstance(field.dataType, StringType)]
    for col_name in categorical_cols:
        most_frequent_row = df.groupBy(col_name).count().orderBy('count', ascending=False).first()
        if most_frequent_row and most_frequent_row[0] is not None:  # Ensure most_frequent_value is not None
            most_frequent_value = most_frequent_row[0]
            df = df.fillna(most_frequent_value, subset=[col_name]) 
    
    return df


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(-1)

    spark = (SparkSession.builder.appName("Module 05").getOrCreate())

    sf_fire = sys.argv[1] 
    
    sf_fire_df = spark.read.format("csv").option("header","true").option("inferSchema","true").load(sf_fire)

    # Fill missing values
    sf_fire_df = fill_missing_values(sf_fire_df)

    sf_fire_df = sf_fire_df.withColumn("CallDate", to_date(sf_fire_df["CallDate"], "MM/dd/yyyy")) \
                       .withColumn("WatchDate", to_date(sf_fire_df["WatchDate"], "MM/dd/yyyy")) \
                       .withColumn("AvailableDtTm", to_timestamp(sf_fire_df["AvailableDtTm"], "MM/dd/yyyy hh:mm:ss a"))
  
# What were all the different types of fire calls in 2018?

    fire_calls_2018 = sf_fire_df.filter(year("CallDate") == 2018)
    fire_call_types_2018 = fire_calls_2018.select("CallType").distinct()
    fire_call_types_2018.show(truncate=False)


# What months within the year 2018 saw the highest number of fire calls?

    fire_calls_by_month = (fire_calls_2018.groupBy(month("CallDate").alias("Month")).agg(count("IncidentNumber").alias("NumFireCalls")).orderBy("NumFireCalls", ascending=False))
    fire_calls_by_month.show()


# Which neighborhood in San Francisco generated the most fire calls in 2018? 

    fire_calls_by_neighborhood = (fire_calls_2018.groupBy("Neighborhood").agg(count("IncidentNumber").alias("NumFireCalls")).orderBy("NumFireCalls", ascending=False))
    fire_calls_by_neighborhood.show(1)

# Which neighborhoods had the worst response times to fire calls in 2018? 

    response_time_by_neighborhood = (fire_calls_2018.groupBy("Neighborhood").agg(avg("Delay").alias("AvgResponseTime")).orderBy("AvgResponseTime", ascending=False))
    response_time_by_neighborhood.show(5)


# Which week in the year in 2018 had the most fire calls?

    fire_calls_by_week = (fire_calls_2018.groupBy(weekofyear("CallDate").alias("Week")).agg(count("IncidentNumber").alias("NumFireCalls")).orderBy("NumFireCalls", ascending=False))
    fire_calls_by_week.show(1)

# Is there a correlation between neighborhood, zip code, and number of fire calls? 

    # Group by Zipcode and count the number of calls
    zipcode_grouped = fire_calls_2018.groupBy("Zipcode").agg(count("IncidentNumber").alias("NumberOfCalls")).collect()
    zipcode_groups = [row["NumberOfCalls"] for row in zipcode_grouped]
    
    # Perform ANOVA (f_oneway) for Zipcode
    anova_zipcode = f_oneway(*zipcode_groups)
    print(f"ANOVA result between Zipcode and NumberOfCalls: F-statistic={anova_zipcode.statistic}, p-value={anova_zipcode.pvalue}")

    # Group by Neighborhood and count the number of calls
    neighborhood_grouped = fire_calls_2018.groupBy("Neighborhood").agg(count("IncidentNumber").alias("NumberOfCalls")).collect()
    neighborhood_groups = [row["NumberOfCalls"] for row in neighborhood_grouped]

    # Perform ANOVA (f_oneway) for Neighborhood
    anova_neighborhood = f_oneway(*neighborhood_groups)
    print(f"ANOVA result between Neighborhood and NumberOfCalls: F-statistic={anova_neighborhood.statistic}, p-value={anova_neighborhood.pvalue}")

    # Compare the two ANOVA results
    if anova_zipcode.statistic > anova_neighborhood.statistic:
        print(f"The correlation between Zipcode and NumberOfCalls is stronger with F-statistic = {anova_zipcode.statistic}.")
    else:
        print(f"The correlation between Neighborhood and NumberOfCalls is stronger with F-statistic = {anova_neighborhood.statistic}.")


# How can we use Parquet files or SQL tables to store this data and read it back?


    spark.stop()
    