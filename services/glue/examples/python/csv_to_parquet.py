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

print("🚀 CSV to Parquet ETL Job başlatılıyor...")
print(f"📥 Input Path: {args['INPUT_PATH']}")
print(f"📤 Output Path: {args['OUTPUT_PATH']}")

try:
    # CSV dosyasını oku
    print("📊 CSV dosyası okunuyor...")
    df = spark.read.option("header", "true").csv(args['INPUT_PATH'])
    
    print(f"✅ CSV dosyası okundu. Kayıt sayısı: {df.count()}")
    
    # Veri tiplerini düzelt
    print("🔄 Veri tipleri düzeltiliyor...")
    df = df.withColumn("id", F.col("id").cast("int")) \
           .withColumn("age", F.col("age").cast("int")) \
           .withColumn("salary", F.col("salary").cast("double")) \
           .withColumn("hire_date", F.to_date(F.col("hire_date"), "yyyy-MM-dd"))
    
    # Veri dönüşümleri ekle
    print("🔄 Veri dönüşümleri yapılıyor...")
    df_transformed = df.withColumn(
        "age_group",
        F.when(F.col("age") < 30, "Genç")
        .when(F.col("age") < 40, "Orta Yaş")
        .otherwise("Deneyimli")
    ).withColumn(
        "salary_category",
        F.when(F.col("salary") < 70000, "Düşük")
        .when(F.col("salary") < 80000, "Orta")
        .otherwise("Yüksek")
    ).withColumn(
        "processing_date",
        F.current_date()
    )
    
    # Parquet olarak kaydet
    print("💾 Parquet formatında kaydediliyor...")
    df_transformed.write.mode("overwrite").parquet(args['OUTPUT_PATH'])
    
    print("✅ CSV to Parquet dönüşümü tamamlandı!")
    print(f"📈 İşlenen kayıt sayısı: {df_transformed.count()}")
    
    # İstatistikler
    print("\n📊 Veri İstatistikleri:")
    df_transformed.groupBy("department").count().show()
    df_transformed.groupBy("age_group").count().show()
        
    except Exception as e:
    print(f"❌ ETL işlemi hatası: {str(e)}")
    raise e

finally:
    job.commit()
    print("🎉 Job tamamlandı!")
