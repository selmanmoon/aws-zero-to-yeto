# Amazon CloudWatch

## 📖 Servis Hakkında

Amazon CloudWatch, AWS kaynaklarınızı ve uygulamalarınızı monitoring eden servistir. Metrikler, loglar, alarmlar ve dashboard'lar ile sisteminizi izler.

### 🎯 CloudWatch Özellikleri

- **Metrics**: CPU, disk, network metrikleri
- **Logs**: Uygulama ve sistem logları
- **Alarms**: Threshold-based uyarılar
- **Dashboards**: Görsel monitoring panelleri
- **Events**: Otomatik event-driven actions

## 💰 Free Tier
- **5GB** log ingestion
- **1M** API requests
- **10** custom metrics
- **10** alarms

## 🔧 Temel Kullanım

### Metrics
```python
import boto3

cloudwatch = boto3.client('cloudwatch')

# Custom metric gönder
cloudwatch.put_metric_data(
    Namespace='AWS/ZERO-TO-YETO',
    MetricData=[
        {
            'MetricName': 'UserLogin',
            'Value': 1,
            'Unit': 'Count'
        }
    ]
)
```

### Logs
```python
logs_client = boto3.client('logs')

# Log group oluştur
logs_client.create_log_group(logGroupName='/aws/zero-to-yeto')

# Log gönder
logs_client.put_log_events(
    logGroupName='/aws/zero-to-yeto',
    logStreamName='app-stream',
    logEvents=[
        {
            'timestamp': int(time.time() * 1000),
            'message': 'Uygulama başladı'
        }
    ]
)
```

### Alarms
```python
# CPU alarm
cloudwatch.put_metric_alarm(
    AlarmName='HighCPU',
    ComparisonOperator='GreaterThanThreshold',
    EvaluationPeriods=2,
    MetricName='CPUUtilization',
    Namespace='AWS/EC2',
    Period=300,
    Statistic='Average',
    Threshold=80.0,
    ActionsEnabled=True,
    AlarmActions=['arn:aws:sns:region:account:topic'],
    AlarmDescription='CPU kullanımı yüksek'
)
```

## 🧪 Test Senaryoları

1. **EC2 Monitoring**: CPU, disk, network
2. **Lambda Logs**: Function execution logs
3. **Custom Metrics**: Uygulama metrikleri
4. **Dashboard**: Görsel izleme paneli
5. **Billing Alarm**: Maliyet uyarıları

## 📚 Kaynaklar
- [CloudWatch Dokümantasyonu](https://docs.aws.amazon.com/cloudwatch/)
- **Selman Ay**: CloudWatch Monitoring videoları
