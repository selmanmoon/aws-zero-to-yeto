import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql import functions as F

# Job parametrelerini al
args = getResolvedOptions(sys.argv, ['JOB_NAME', 'INPUT_PATH', 'OUTPUT_PATH'])

# Spark ve Glue context oluştur
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

print("🚀 JSON to Parquet ETL Job başlatılıyor...")
print(f"📥 Input Path: {args['INPUT_PATH']}")
print(f"📤 Output Path: {args['OUTPUT_PATH']}")

try:
    # JSON dosyasını oku
    print("📊 JSON dosyası okunuyor...")
    df = spark.read.json(args['INPUT_PATH'])
    
    print(f"✅ JSON dosyası okundu. Kayıt sayısı: {df.count()}")
    
    # Veri tiplerini düzelt
    print("🔄 Veri tipleri düzeltiliyor...")
    df = df.withColumn("id", F.col("id").cast("int")) \
           .withColumn("age", F.col("age").cast("int")) \
           .withColumn("salary", F.col("salary").cast("double")) \
           .withColumn("hire_date", F.to_date(F.col("hire_date"), "yyyy-MM-dd"))
    
    # JSON'a özel dönüşümler
    print("🔄 JSON dönüşümleri yapılıyor...")
    df_transformed = df.withColumn(
        "experience_years",
        F.datediff(F.current_date(), F.col("hire_date")) / 365
    ).withColumn(
        "salary_per_experience",
        F.col("salary") / (F.datediff(F.current_date(), F.col("hire_date")) / 365 + 1)
    ).withColumn(
        "city_category",
        F.when(F.col("city").isin(["İstanbul", "Ankara", "İzmir"]), "Büyük Şehir")
        .otherwise("Diğer")
    ).withColumn(
        "processing_timestamp",
        F.current_timestamp()
    )
    
    # Parquet olarak kaydet
    print("💾 Parquet formatında kaydediliyor...")
    df_transformed.write.mode("overwrite").parquet(args['OUTPUT_PATH'])
    
    print("✅ JSON to Parquet dönüşümü tamamlandı!")
    print(f"📈 İşlenen kayıt sayısı: {df_transformed.count()}")
        
        # İstatistikler
    print("\n📊 Veri İstatistikleri:")
    df_transformed.groupBy("city_category").count().show()
    df_transformed.select(F.avg("experience_years").alias("avg_experience")).show()
        
    except Exception as e:
        print(f"❌ ETL işlemi hatası: {str(e)}")
        raise e
    
    finally:
        job.commit()
    print("🎉 Job tamamlandı!")
