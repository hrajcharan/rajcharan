import org.apache.spark.sql.SparkSession
import org.apache.spark.sql.types._

object DivvyPrintSchema {

  def main(args: Array[String]): Unit = {
    if (args.length != 1) {
      System.exit(-1)
    }

    // Initialize SparkSession
    val spark = SparkSession.builder
      .appName("Divvy Print Schema")
      .getOrCreate()

    val divvyFile = args(0)

    // Reading CSV with inferred schema
    val dfInferredSchema = spark.read
      .format("csv")
      .option("header", "true")
      .option("inferSchema", "true")
      .load(divvyFile)

    // Print inferred schema and count
    dfInferredSchema.printSchema()
    println(s"Row count with inferred schema: ${dfInferredSchema.count()}")

    // Define programmatic schema
    val programmaticSchema = StructType(Array(
      StructField("trip_id", IntegerType, false),
      StructField("starttime", TimestampType, true),
      StructField("stoptime", TimestampType, true),
      StructField("bikeid", IntegerType, true),
      StructField("tripduration", IntegerType, true),
      StructField("from_station_id", IntegerType, true),
      StructField("from_station_name", StringType, true),
      StructField("to_station_id", IntegerType, true),
      StructField("to_station_name", StringType, true),
      StructField("usertype", StringType, true),
      StructField("gender", StringType, true),
      StructField("birthyear", IntegerType, true)
    ))

    // Reading CSV with programmatic schema
    val dfProgrammatic = spark.read
      .format("csv")
      .schema(programmaticSchema)
      .option("header", "true")
      .load(divvyFile)

    // Print programmatic schema and count
    dfProgrammatic.printSchema()
    println(s"Row count with programmatic schema: ${dfProgrammatic.count()}")

    // Define DDL schema
    val ddlSchema = """
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

    // Reading CSV with DDL schema
    val dfDDL = spark.read
      .format("csv")
      .schema(ddlSchema)
      .option("header", "true")
      .load(divvyFile)

    // Print DDL schema and count
    dfDDL.printSchema()
    println(s"Row count with DDL schema: ${dfDDL.count()}")

    // Stop the Spark session
    spark.stop()
  }
}
