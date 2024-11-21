from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("TestPySpark") \
    .master("local") \
    .getOrCreate()

print("Spark Session Created")
print("Spark Version:", spark.version)

spark.stop()