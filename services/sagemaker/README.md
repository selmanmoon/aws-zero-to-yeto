# Amazon SageMaker

## 📖 Servis Hakkında

Amazon SageMaker, makine öğrenmesi modellerini geliştirmek, eğitmek ve deploy etmek için kapsamlı bir platformdur. ML projelerinin tüm yaşam döngüsünü yönetmenizi sağlar.

### 🎯 SageMaker'ın Temel Özellikleri

- **End-to-End ML Platform**: Veri hazırlama, eğitim, deployment
- **Managed Infrastructure**: Sunucu yönetimi yok
- **Built-in Algorithms**: Hazır algoritmalar
- **AutoML**: Otomatik model seçimi
- **Real-time & Batch Inference**: Canlı ve toplu tahmin
- **Model Monitoring**: Model performans takibi

### 🏗️ SageMaker Mimarisi

```
Data Preparation (Veri Hazırlama)
    ↓
Model Training (Model Eğitimi)
    ↓
Model Evaluation (Model Değerlendirme)
    ↓
Model Deployment (Model Deployment)
    ↓
Inference (Tahmin)
```

## 🔧 SageMaker Bileşenleri

### 1. SageMaker Studio
- **Jupyter Notebook** tabanlı geliştirme ortamı
- **Real-time collaboration** özelliği
- **Integrated development** araçları
- **Version control** entegrasyonu

### 2. SageMaker Notebooks
- **Managed Jupyter notebooks**
- **Pre-configured instances**
- **Auto-shutdown** özelliği
- **IAM integration**

### 3. SageMaker Training
- **Distributed training** desteği
- **Spot instances** ile maliyet optimizasyonu
- **Hyperparameter tuning**
- **Built-in algorithms**

### 4. SageMaker Inference
- **Real-time endpoints**
- **Batch transform**
- **Multi-model endpoints**
- **A/B testing**

## 💰 Maliyet Hesaplama

### Fiyatlandırma Modeli
- **Notebook Instances**: Saatlik ücret
- **Training Jobs**: Saatlik ücret
- **Endpoints**: Saatlik ücret + veri işleme
- **Data Processing**: Saatlik ücret

### Örnek Hesaplama
```
Notebook Instance (ml.t3.medium): $0.046/saat
Training Job (ml.m5.large): $0.115/saat × 2 saat = $0.23
Endpoint (ml.m5.large): $0.115/saat × 24 saat = $2.76/gün
Toplam: ~$3/gün
```

## 🚀 SageMaker Workflow

### 1. Veri Hazırlama
```python
import sagemaker
from sagemaker import get_execution_role

# SageMaker session
session = sagemaker.Session()
role = get_execution_role()

# Veri yükleme
data_location = 's3://my-bucket/data/'
```

### 2. Model Eğitimi
```python
from sagemaker.sklearn import SKLearn

# Estimator oluştur
sklearn_estimator = SKLearn(
    entry_point='train.py',
    role=role,
    instance_count=1,
    instance_type='ml.m5.large',
    framework_version='0.23-1'
)

# Eğitim başlat
sklearn_estimator.fit({'train': data_location})
```

### 3. Model Deployment
```python
# Model deploy et
predictor = sklearn_estimator.deploy(
    initial_instance_count=1,
    instance_type='ml.m5.large'
)

# Tahmin yap
result = predictor.predict(data)
```

## 📊 Built-in Algorithms

### 1. Supervised Learning
- **Linear Learner**: Regresyon ve sınıflandırma
- **XGBoost**: Gradient boosting
- **Random Cut Forest**: Anomaly detection
- **Factorization Machines**: Recommendation systems

### 2. Unsupervised Learning
- **K-Means**: Clustering
- **Principal Component Analysis**: Dimensionality reduction
- **Neural Topic Model**: Topic modeling

### 3. Computer Vision
- **Image Classification**: Resim sınıflandırma
- **Object Detection**: Nesne tespiti
- **Semantic Segmentation**: Piksel bazlı sınıflandırma

### 4. Natural Language Processing
- **BlazingText**: Word embeddings
- **LDA**: Topic modeling
- **Sequence-to-Sequence**: Machine translation

## 🔧 Custom Training

### Training Script Örneği
```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
AWS ZERO to YETO - SageMaker Custom Training Script
"""

import os
import json
import joblib
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score, classification_report

def train():
    """
    Model eğitim fonksiyonu
    """
    # Veri yolları
    train_data_path = os.path.join(os.environ['SM_CHANNEL_TRAIN'], 'train.csv')
    model_dir = os.environ['SM_MODEL_DIR']
    
    # Veriyi yükle
    print("Veri yükleniyor...")
    data = pd.read_csv(train_data_path)
    
    # Veriyi hazırla
    X = data.drop('target', axis=1)
    y = data['target']
    
    # Train-test split
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42
    )
    
    # Model eğitimi
    print("Model eğitiliyor...")
    model = RandomForestClassifier(n_estimators=100, random_state=42)
    model.fit(X_train, y_train)
    
    # Model değerlendirme
    y_pred = model.predict(X_test)
    accuracy = accuracy_score(y_test, y_pred)
    
    print(f"Model doğruluğu: {accuracy:.4f}")
    print("\nSınıflandırma raporu:")
    print(classification_report(y_test, y_pred))
    
    # Model kaydet
    model_path = os.path.join(model_dir, 'model.joblib')
    joblib.dump(model, model_path)
    
    # Model metadata kaydet
    metadata = {
        'accuracy': accuracy,
        'algorithm': 'RandomForest',
        'n_estimators': 100,
        'features': list(X.columns)
    }
    
    metadata_path = os.path.join(model_dir, 'metadata.json')
    with open(metadata_path, 'w') as f:
        json.dump(metadata, f)
    
    print(f"Model kaydedildi: {model_path}")

if __name__ == "__main__":
    train()
```

### Inference Script Örneği
```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
AWS ZERO to YETO - SageMaker Inference Script
"""

import os
import json
import joblib
import pandas as pd
from io import StringIO

def model_fn(model_dir):
    """
    Model yükleme fonksiyonu
    """
    model_path = os.path.join(model_dir, 'model.joblib')
    model = joblib.load(model_path)
    return model

def input_fn(request_body, request_content_type):
    """
    Input veri işleme fonksiyonu
    """
    if request_content_type == 'application/json':
        input_data = json.loads(request_body)
        return pd.DataFrame(input_data)
    elif request_content_type == 'text/csv':
        return pd.read_csv(StringIO(request_body))
    else:
        raise ValueError(f"Desteklenmeyen content type: {request_content_type}")

def predict_fn(input_data, model):
    """
    Tahmin fonksiyonu
    """
    predictions = model.predict(input_data)
    return predictions

def output_fn(prediction, accept):
    """
    Output veri işleme fonksiyonu
    """
    if accept == 'application/json':
        return json.dumps(prediction.tolist())
    elif accept == 'text/csv':
        return pd.DataFrame(prediction).to_csv(index=False)
    else:
        raise ValueError(f"Desteklenmeyen accept type: {accept}")
```

## 🎯 Hyperparameter Tuning

### Tuning Job Örneği
```python
from sagemaker.tuner import IntegerParameter, CategoricalParameter, ContinuousParameter, HyperparameterTuner

# Hyperparameter tanımları
hyperparameter_ranges = {
    'n_estimators': IntegerParameter(50, 200),
    'max_depth': IntegerParameter(3, 10),
    'min_samples_split': IntegerParameter(2, 10),
    'criterion': CategoricalParameter(['gini', 'entropy'])
}

# Tuner oluştur
tuner = HyperparameterTuner(
    estimator=sklearn_estimator,
    objective_metric_name='validation:accuracy',
    hyperparameter_ranges=hyperparameter_ranges,
    max_jobs=10,
    max_parallel_jobs=2
)

# Tuning başlat
tuner.fit({'train': data_location})
```

## 📊 Model Monitoring

### Data Quality Monitoring
```python
from sagemaker.model_monitor import DataQualityMonitor

# Monitor oluştur
data_quality_monitor = DataQualityMonitor(
    role=role,
    instance_count=1,
    instance_type='ml.m5.large',
    volume_size_in_gb=20,
    max_runtime_in_seconds=1800
)

# Monitoring schedule oluştur
monitoring_schedule = data_quality_monitor.create_monitoring_schedule(
    monitor_schedule_name='my-data-quality-monitor',
    endpoint_input=predictor.endpoint_name,
    output_s3_uri='s3://my-bucket/monitoring/',
    statistics_s3_uri='s3://my-bucket/baseline/statistics.json',
    constraints_s3_uri='s3://my-bucket/baseline/constraints.json',
    schedule_cron_expression='cron(0 * * * ? *)'  # Her saat
)
```

## 🔐 Güvenlik

### IAM Permissions
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "sagemaker:CreateNotebookInstance",
                "sagemaker:CreateTrainingJob",
                "sagemaker:CreateModel",
                "sagemaker:CreateEndpoint",
                "sagemaker:CreateEndpointConfig"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::my-sagemaker-bucket",
                "arn:aws:s3:::my-sagemaker-bucket/*"
            ]
        }
    ]
}
```

## 🧪 Test Senaryoları

Bu klasörde bulunan örnekler ile test edebileceğiniz senaryolar:

1. **Temel ML Pipeline**
   - Veri hazırlama
   - Model eğitimi
   - Model deployment
   - Tahmin yapma

2. **Built-in Algorithm Kullanımı**
   - Linear Learner
   - XGBoost
   - K-Means

3. **Custom Training**
   - Scikit-learn ile özel model
   - PyTorch ile deep learning
   - TensorFlow ile neural network

4. **Hyperparameter Tuning**
   - Otomatik hyperparameter optimizasyonu
   - Grid search vs Bayesian optimization

5. **Model Monitoring**
   - Data quality monitoring
   - Model quality monitoring
   - Drift detection

## 📚 Öğrenme Kaynakları

- [Amazon SageMaker Dokümantasyonu](https://docs.aws.amazon.com/sagemaker/)
- [SageMaker Examples](https://github.com/aws/amazon-sagemaker-examples)
- [SageMaker Pricing](https://aws.amazon.com/sagemaker/pricing/)

## 🎯 Sonraki Adımlar

SageMaker'ı öğrendikten sonra şu servisleri keşfedin:
- **Amazon Comprehend** - Doğal dil işleme
- **Amazon Rekognition** - Görüntü ve video analizi
- **Amazon Forecast** - Zaman serisi tahmini
- **Amazon Personalize** - Recommendation systems
