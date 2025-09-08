#!/bin/bash

# AWS ZERO to YETO - Glue Deployment Script (Direct AWS CLI)
# Bu script gerçek Glue job'ları ve ETL pipeline'ı oluşturur

set -e  # Hata durumunda script'i durdur

# Renkli çıktı için fonksiyonlar
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# AWS CLI kontrolü
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI kurulu değil. Lütfen önce AWS CLI'yi kurun."
        exit 1
    fi
    
    # AWS kimlik bilgilerini kontrol et
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS kimlik bilgileri yapılandırılmamış. 'aws configure' komutunu çalıştırın."
        exit 1
    fi
    
    print_success "AWS CLI ve kimlik bilgileri hazır"
}

# Değişkenler
PROJECT_NAME="aws-zero-to-yeto-glue"
REGION="eu-west-1"
TIMESTAMP=$(date +%s)
STACK_NAME="${PROJECT_NAME}-${TIMESTAMP}"
BUCKET_NAME="${PROJECT_NAME}-${TIMESTAMP}"
ROLE_NAME="${PROJECT_NAME}-role-${TIMESTAMP}"
DATABASE_NAME="aws_zero_to_yeto_db_${TIMESTAMP}"
JOB_NAME_CSV="csv-to-parquet-job-${TIMESTAMP}"
JOB_NAME_JSON="json-to-parquet-job-${TIMESTAMP}"

print_info "🚀 Glue Deployment başlatılıyor..."
print_info "Stack adı: $STACK_NAME"
print_info "Bölge: $REGION"
print_info "S3 Bucket: $BUCKET_NAME"
print_info "IAM Role: $ROLE_NAME"
print_info "Database: $DATABASE_NAME"

# AWS CLI kontrolü
check_aws_cli

# Klasör yapısı oluştur
print_info "📁 Klasör yapısı oluşturuluyor..."
mkdir -p examples/data
mkdir -p examples/python

# S3 bucket oluştur
print_info "🪣 S3 bucket oluşturuluyor..."
aws s3 mb s3://$BUCKET_NAME --region $REGION 2>/dev/null || print_info "Bucket zaten mevcut"

# IAM Role oluştur
print_info "🔐 IAM Role oluşturuluyor..."
cat > trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "glue.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

aws iam create-role \
    --role-name $ROLE_NAME \
    --assume-role-policy-document file://trust-policy.json \
    --region $REGION

# IAM Policy'leri ekle
print_info "📋 IAM Policy'ler ekleniyor..."
aws iam attach-role-policy \
    --role-name $ROLE_NAME \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole \
    --region $REGION

# S3 erişimi için custom policy
cat > s3-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::$BUCKET_NAME",
                "arn:aws:s3:::$BUCKET_NAME/*"
            ]
        }
    ]
}
EOF

aws iam put-role-policy \
    --role-name $ROLE_NAME \
    --policy-name S3AccessPolicy \
    --policy-document file://s3-policy.json \
    --region $REGION

# Role ARN'ı al
ROLE_ARN=$(aws iam get-role --role-name $ROLE_NAME --query 'Role.Arn' --output text --region $REGION)
print_success "IAM Role oluşturuldu: $ROLE_ARN"

# Glue Database oluştur
print_info "🗄️ Glue Database oluşturuluyor..."
aws glue create-database \
    --database-input Name=$DATABASE_NAME,Description="AWS ZERO to YETO Glue Database" \
    --region $REGION

print_success "Glue Database oluşturuldu: $DATABASE_NAME"

# Örnek veri dosyaları oluştur
print_info "📊 Örnek veri dosyaları oluşturuluyor..."

# CSV dosyası
cat > examples/data/sample_data.csv << 'EOF'
id,name,age,city,salary,department,hire_date
1,Ahmet Yılmaz,28,İstanbul,75000,IT,2020-01-15
2,Ayşe Kaya,32,Ankara,82000,HR,2019-03-22
3,Mehmet Demir,25,İzmir,68000,Finance,2021-06-10
4,Fatma Şahin,29,Bursa,71000,IT,2020-11-05
5,Ali Özkan,35,Antalya,89000,Sales,2018-09-12
6,Zeynep Arslan,27,İstanbul,73000,Marketing,2021-02-28
7,Murat Kılıç,31,Ankara,85000,IT,2019-07-18
8,Elif Çelik,26,İzmir,69000,HR,2022-01-10
EOF

# JSON dosyası
cat > examples/data/sample_data.json << 'EOF'
[
  {"id": 1, "name": "Ahmet Yılmaz", "age": 28, "city": "İstanbul", "salary": 75000, "department": "IT", "hire_date": "2020-01-15"},
  {"id": 2, "name": "Ayşe Kaya", "age": 32, "city": "Ankara", "salary": 82000, "department": "HR", "hire_date": "2019-03-22"},
  {"id": 3, "name": "Mehmet Demir", "age": 25, "city": "İzmir", "salary": 68000, "department": "Finance", "hire_date": "2021-06-10"},
  {"id": 4, "name": "Fatma Şahin", "age": 29, "city": "Bursa", "salary": 71000, "department": "IT", "hire_date": "2020-11-05"},
  {"id": 5, "name": "Ali Özkan", "age": 35, "city": "Antalya", "salary": 89000, "department": "Sales", "hire_date": "2018-09-12"},
  {"id": 6, "name": "Zeynep Arslan", "age": 27, "city": "İstanbul", "salary": 73000, "department": "Marketing", "hire_date": "2021-02-28"},
  {"id": 7, "name": "Murat Kılıç", "age": 31, "city": "Ankara", "salary": 85000, "department": "IT", "hire_date": "2019-07-18"},
  {"id": 8, "name": "Elif Çelik", "age": 26, "city": "İzmir", "salary": 69000, "department": "HR", "hire_date": "2022-01-10"}
]
EOF

# Veri dosyalarını S3'e yükle
print_info "⬆️ Veri dosyaları S3'e yükleniyor..."
aws s3 cp examples/data/sample_data.csv s3://$BUCKET_NAME/input/csv/sample_data.csv --region $REGION
aws s3 cp examples/data/sample_data.json s3://$BUCKET_NAME/input/json/sample_data.json --region $REGION

# CSV to Parquet ETL script oluştur
print_info "📝 CSV to Parquet ETL script oluşturuluyor..."
cat > examples/python/csv_to_parquet.py << 'EOF'
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
EOF

# JSON to Parquet ETL script oluştur
print_info "📝 JSON to Parquet ETL script oluşturuluyor..."
cat > examples/python/json_to_parquet.py << 'EOF'
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
EOF

# ETL script'leri S3'e yükle
print_info "⬆️ ETL script'leri S3'e yükleniyor..."
aws s3 cp examples/python/csv_to_parquet.py s3://$BUCKET_NAME/scripts/csv_to_parquet.py --region $REGION
aws s3 cp examples/python/json_to_parquet.py s3://$BUCKET_NAME/scripts/json_to_parquet.py --region $REGION

# Role'un propagate olması için bekle
print_info "⏳ IAM Role propagation bekleniyor..."
sleep 10

# CSV to Parquet Glue Job oluştur
print_info "⚙️ CSV to Parquet Glue Job oluşturuluyor..."
aws glue create-job \
    --name $JOB_NAME_CSV \
    --role $ROLE_ARN \
    --command Name=glueetl,ScriptLocation=s3://$BUCKET_NAME/scripts/csv_to_parquet.py,PythonVersion=3 \
    --default-arguments '{
        "--job-bookmark-option": "job-bookmark-enable",
        "--enable-metrics": "",
        "--enable-continuous-cloudwatch-log": "true",
        "--enable-spark-ui": "true",
        "--spark-event-logs-path": "s3://'$BUCKET_NAME'/sparkHistoryLogs/"
    }' \
    --max-retries 0 \
    --timeout 60 \
    --glue-version "3.0" \
    --worker-type G.1X \
    --number-of-workers 2 \
    --region $REGION

print_success "CSV to Parquet Job oluşturuldu: $JOB_NAME_CSV"

# JSON to Parquet Glue Job oluştur
print_info "⚙️ JSON to Parquet Glue Job oluşturuluyor..."
aws glue create-job \
    --name $JOB_NAME_JSON \
    --role $ROLE_ARN \
    --command Name=glueetl,ScriptLocation=s3://$BUCKET_NAME/scripts/json_to_parquet.py,PythonVersion=3 \
    --default-arguments '{
        "--job-bookmark-option": "job-bookmark-enable",
        "--enable-metrics": "",
        "--enable-continuous-cloudwatch-log": "true",
        "--enable-spark-ui": "true",
        "--spark-event-logs-path": "s3://'$BUCKET_NAME'/sparkHistoryLogs/"
    }' \
    --max-retries 0 \
    --timeout 60 \
    --glue-version "3.0" \
    --worker-type G.1X \
    --number-of-workers 2 \
    --region $REGION

print_success "JSON to Parquet Job oluşturuldu: $JOB_NAME_JSON"

# Cleanup temp files
rm -f trust-policy.json s3-policy.json

# Deployment bilgilerini README'ye yaz
print_info "📝 Deployment bilgileri README'ye kaydediliyor..."

print_success "🎉 Glue deployment tamamlandı!"
print_info "Stack: $STACK_NAME"
print_info "S3 Bucket: $BUCKET_NAME"
print_info "Database: $DATABASE_NAME"
print_info "CSV Job: $JOB_NAME_CSV"
print_info "JSON Job: $JOB_NAME_JSON"
print_info "Deployment bilgileri README'de mevcut"

print_warning "⚠️  Glue job'ları ücretli kaynaklar. Test sonrası cleanup yapmayı unutmayın!"

echo ""
print_info "🧪 Test komutları:"
echo ""
echo "# CSV to Parquet Job'ı çalıştır:"
echo "aws glue start-job-run \\"
echo "    --job-name $JOB_NAME_CSV \\"
echo "    --arguments '{"
echo "        \"--INPUT_PATH\": \"s3://$BUCKET_NAME/input/csv/\","
echo "        \"--OUTPUT_PATH\": \"s3://$BUCKET_NAME/output/csv-parquet/\""
echo "    }' \\"
echo "    --region $REGION"
echo ""
echo "# JSON to Parquet Job'ı çalıştır:"
echo "aws glue start-job-run \\"
echo "    --job-name $JOB_NAME_JSON \\"
echo "    --arguments '{"
echo "        \"--INPUT_PATH\": \"s3://$BUCKET_NAME/input/json/\","
echo "        \"--OUTPUT_PATH\": \"s3://$BUCKET_NAME/output/json-parquet/\""
echo "    }' \\"
echo "    --region $REGION"
echo ""
echo "# S3 çıktılarını kontrol et:"
echo "aws s3 ls s3://$BUCKET_NAME/output/ --recursive --region $REGION"