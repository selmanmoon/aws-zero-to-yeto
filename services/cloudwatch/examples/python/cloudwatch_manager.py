#!/usr/bin/env python3
"""
AWS ZERO to YETO - CloudWatch Python Örneği
"""

import boto3
import time
import json
from datetime import datetime, timedelta

class CloudWatchManager:
    def __init__(self, region='eu-west-1'):
        self.cloudwatch = boto3.client('cloudwatch', region_name=region)
        self.logs = boto3.client('logs', region_name=region)
    
    def send_custom_metric(self, namespace, metric_name, value, unit='Count'):
        """Custom metric gönder"""
        try:
            print(f"📊 Custom metric gönderiliyor: {metric_name} = {value}")
            
            self.cloudwatch.put_metric_data(
                Namespace=namespace,
                MetricData=[
                    {
                        'MetricName': metric_name,
                        'Value': value,
                        'Unit': unit,
                        'Timestamp': datetime.utcnow()
                    }
                ]
            )
            print(f"✅ Metric gönderildi: {namespace}/{metric_name}")
            return True
        except Exception as e:
            print(f"❌ Metric gönderme hatası: {str(e)}")
            return False
    
    def create_alarm(self, alarm_name, metric_name, namespace, threshold, comparison='GreaterThanThreshold'):
        """CloudWatch alarm oluştur"""
        try:
            print(f"🚨 Alarm oluşturuluyor: {alarm_name}")
            
            self.cloudwatch.put_metric_alarm(
                AlarmName=alarm_name,
                ComparisonOperator=comparison,
                EvaluationPeriods=2,
                MetricName=metric_name,
                Namespace=namespace,
                Period=300,
                Statistic='Average',
                Threshold=threshold,
                ActionsEnabled=False,  # Demo için action yok
                AlarmDescription=f'AWS ZERO to YETO - {metric_name} alarm'
            )
            print(f"✅ Alarm oluşturuldu: {alarm_name}")
            return True
        except Exception as e:
            print(f"❌ Alarm oluşturma hatası: {str(e)}")
            return False
    
    def send_log(self, log_group, log_stream, message):
        """CloudWatch Logs'a mesaj gönder"""
        try:
            # Log group var mı kontrol et
            try:
                self.logs.describe_log_groups(logGroupNamePrefix=log_group)
            except:
                self.logs.create_log_group(logGroupName=log_group)
                print(f"📝 Log group oluşturuldu: {log_group}")
            
            # Log stream var mı kontrol et
            try:
                self.logs.describe_log_streams(
                    logGroupName=log_group,
                    logStreamNamePrefix=log_stream
                )
            except:
                self.logs.create_log_stream(
                    logGroupName=log_group,
                    logStreamName=log_stream
                )
                print(f"📝 Log stream oluşturuldu: {log_stream}")
            
            # Log gönder
            self.logs.put_log_events(
                logGroupName=log_group,
                logStreamName=log_stream,
                logEvents=[
                    {
                        'timestamp': int(time.time() * 1000),
                        'message': json.dumps({
                            'timestamp': datetime.now().isoformat(),
                            'message': message,
                            'source': 'AWS-ZERO-TO-YETO'
                        })
                    }
                ]
            )
            print(f"✅ Log gönderildi: {message}")
            return True
        except Exception as e:
            print(f"❌ Log gönderme hatası: {str(e)}")
            return False
    
    def get_metrics(self, namespace, metric_name, hours=1):
        """Metric verilerini al"""
        try:
            print(f"📈 Metrik verileri alınıyor: {namespace}/{metric_name}")
            
            end_time = datetime.utcnow()
            start_time = end_time - timedelta(hours=hours)
            
            response = self.cloudwatch.get_metric_statistics(
                Namespace=namespace,
                MetricName=metric_name,
                StartTime=start_time,
                EndTime=end_time,
                Period=300,  # 5 dakika
                Statistics=['Sum', 'Average', 'Maximum']
            )
            
            datapoints = response['Datapoints']
            if datapoints:
                print(f"📊 {len(datapoints)} veri noktası bulundu:")
                for point in sorted(datapoints, key=lambda x: x['Timestamp']):
                    timestamp = point['Timestamp'].strftime('%H:%M')
                    print(f"   {timestamp}: Sum={point.get('Sum', 0)}, Avg={point.get('Average', 0):.2f}")
            else:
                print("📊 Veri bulunamadı")
            
            return datapoints
        except Exception as e:
            print(f"❌ Metrik alma hatası: {str(e)}")
            return []

def main():
    """Ana fonksiyon"""
    print("📊 AWS ZERO to YETO - CloudWatch Python Örnekleri")
    print("=" * 50)
    
    cw = CloudWatchManager()
    
    try:
        # 1. Custom metric gönder
        print("\n📊 Custom Metrics")
        cw.send_custom_metric('AWS/ZeroToYeto', 'UserActions', 5)
        cw.send_custom_metric('AWS/ZeroToYeto', 'PageViews', 10)
        
        # 2. Log gönder
        print("\n📝 CloudWatch Logs")
        cw.send_log('/aws/zero-to-yeto/demo', 'app-stream', 'Uygulama başlatıldı')
        cw.send_log('/aws/zero-to-yeto/demo', 'app-stream', 'Kullanıcı login oldu')
        
        # 3. Alarm oluştur
        print("\n🚨 CloudWatch Alarms")
        cw.create_alarm('HighUserActions', 'UserActions', 'AWS/ZeroToYeto', 3.0)
        
        # 4. Metrics kontrolü (1 dakika bekle)
        print("\n⏳ Metriklerin işlenmesi için 60 saniye bekleniyor...")
        time.sleep(60)
        
        print("\n📈 Metric Verileri")
        cw.get_metrics('AWS/ZeroToYeto', 'UserActions')
        
        print("\n🎉 CloudWatch demo tamamlandı!")
        print("\n📋 AWS Console'da kontrol edin:")
        print("- CloudWatch > Metrics > AWS/ZeroToYeto")
        print("- CloudWatch > Logs > /aws/zero-to-yeto/demo")
        print("- CloudWatch > Alarms > HighUserActions")
        
    except Exception as e:
        print(f"❌ Beklenmeyen hata: {str(e)}")

if __name__ == "__main__":
    main()
