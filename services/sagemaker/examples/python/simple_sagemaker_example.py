#!/usr/bin/env python3
"""
AWS ZERO to YETO - Basit SageMaker Örneği
Bu script AWS SageMaker'nin temel özelliklerini gösterir
"""

import boto3
import json

def main():
    """Ana fonksiyon - SageMaker örneklerini çalıştırır"""
    
    print("🚀 AWS ZERO to YETO - Basit SageMaker Örneği")
    print("=" * 45)
    
    # SageMaker client'ı başlat
    sagemaker = boto3.client('sagemaker', region_name='eu-west-1')
    
    # Proje adı
    project_name = "aws-zero-to-yeto"
    
    try:
        # 1. Notebook instance'ları listele
        print("📓 Mevcut notebook instance'lar:")
        response = sagemaker.list_notebook_instances()
        
        if response['NotebookInstances']:
            for instance in response['NotebookInstances']:
                print(f"  - {instance['NotebookInstanceName']}")
                print(f"    Durum: {instance['NotebookInstanceStatus']}")
                print(f"    Tip: {instance['InstanceType']}")
        else:
            print("  Henüz notebook instance yok")
        
        # 2. Training job'ları listele
        print(f"\n🏋️ Mevcut training job'lar:")
        response = sagemaker.list_training_jobs()
        
        if response['TrainingJobSummaries']:
            for job in response['TrainingJobSummaries'][:5]:  # İlk 5'i göster
                print(f"  - {job['TrainingJobName']}")
                print(f"    Durum: {job['TrainingJobStatus']}")
                print(f"    Başlangıç: {job['CreationTime']}")
        else:
            print("  Henüz training job yok")
        
        # 3. Model'leri listele
        print(f"\n🤖 Mevcut model'ler:")
        response = sagemaker.list_models()
        
        if response['Models']:
            for model in response['Models'][:5]:  # İlk 5'i göster
                print(f"  - {model['ModelName']}")
                print(f"    Oluşturulma: {model['CreationTime']}")
        else:
            print("  Henüz model yok")
        
        # 4. Endpoint'leri listele
        print(f"\n🌐 Mevcut endpoint'ler:")
        response = sagemaker.list_endpoints()
        
        if response['Endpoints']:
            for endpoint in response['Endpoints']:
                print(f"  - {endpoint['EndpointName']}")
                print(f"    Durum: {endpoint['EndpointStatus']}")
        else:
            print("  Henüz endpoint yok")
        
        print(f"\n🎉 SageMaker örneği tamamlandı!")
        print(f"📚 Öğrendikleriniz:")
        print(f"  - SageMaker kaynaklarını listeleme")
        print(f"  - Notebook instance'ları görme")
        print(f"  - Training job'ları takip etme")
        print(f"  - Model ve endpoint'leri izleme")
        
        print(f"\n🔧 Sonraki adımlar:")
        print(f"  1. AWS SageMaker Console'u açın")
        print(f"  2. Notebook instance oluşturun")
        print(f"  3. Jupyter notebook ile ML modeli eğitin")
        print(f"  4. Model'i deploy edin")
        
    except Exception as e:
        print(f"❌ Hata: {str(e)}")

if __name__ == "__main__":
    main()
