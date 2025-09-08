#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
AWS ZERO to YETO - S3 Temel İşlemler
Bu dosya S3'ün temel CRUD işlemlerini gösterir
"""

import boto3
import json
from botocore.exceptions import ClientError
import os

class S3Manager:
    def __init__(self, bucket_name=None, region='eu-west-1'):
        """
        S3 Manager sınıfı başlatıcısı
        """
        self.s3_client = boto3.client('s3', region_name=region)
        self.s3_resource = boto3.resource('s3', region_name=region)
        self.bucket_name = bucket_name
        self.region = region
    
    def create_bucket(self, bucket_name):
        """
        Yeni bir S3 bucket oluşturur
        """
        try:
            print(f"🪣 Bucket oluşturuluyor: {bucket_name}")
            self.s3_client.create_bucket(
                Bucket=bucket_name,
                CreateBucketConfiguration={'LocationConstraint': self.region}
            )
            self.bucket_name = bucket_name
            print(f"✅ Bucket başarıyla oluşturuldu: {bucket_name}")
            return True
        except ClientError as e:
            print(f"❌ Bucket oluşturma hatası: {e}")
            return False
    
    def upload_file(self, file_path, object_name=None):
        """
        Dosya yükler
        """
        if object_name is None:
            object_name = os.path.basename(file_path)
        
        try:
            print(f"📤 Dosya yükleniyor: {file_path} -> {object_name}")
            self.s3_client.upload_file(file_path, self.bucket_name, object_name)
            print(f"✅ Dosya başarıyla yüklendi: s3://{self.bucket_name}/{object_name}")
            return True
        except ClientError as e:
            print(f"❌ Dosya yükleme hatası: {e}")
            return False
    
    def download_file(self, object_name, file_path):
        """
        Dosya indirir
        """
        try:
            print(f"📥 Dosya indiriliyor: {object_name} -> {file_path}")
            self.s3_client.download_file(self.bucket_name, object_name, file_path)
            print(f"✅ Dosya başarıyla indirildi: {file_path}")
            return True
        except ClientError as e:
            print(f"❌ Dosya indirme hatası: {e}")
            return False
    
    def list_objects(self, prefix=''):
        """
        Bucket içindeki nesneleri listeler
        """
        try:
            print(f"📋 Nesneler listeleniyor (prefix: {prefix})")
            response = self.s3_client.list_objects_v2(
                Bucket=self.bucket_name,
                Prefix=prefix
            )
            
            if 'Contents' in response:
                print(f"📁 Toplam {len(response['Contents'])} nesne bulundu:")
                for obj in response['Contents']:
                    print(f"  - {obj['Key']} ({obj['Size']} bytes)")
            else:
                print("📁 Bucket boş veya belirtilen prefix ile nesne bulunamadı")
            
            return response.get('Contents', [])
        except ClientError as e:
            print(f"❌ Nesne listeleme hatası: {e}")
            return []
    
    def delete_object(self, object_name):
        """
        Nesne siler
        """
        try:
            print(f"🗑️ Nesne siliniyor: {object_name}")
            self.s3_client.delete_object(Bucket=self.bucket_name, Key=object_name)
            print(f"✅ Nesne başarıyla silindi: {object_name}")
            return True
        except ClientError as e:
            print(f"❌ Nesne silme hatası: {e}")
            return False
    
    def get_object_url(self, object_name, expires_in=3600):
        """
        Nesne için geçici URL oluşturur
        """
        try:
            url = self.s3_client.generate_presigned_url(
                'get_object',
                Params={'Bucket': self.bucket_name, 'Key': object_name},
                ExpiresIn=expires_in
            )
            print(f"🔗 Geçici URL oluşturuldu (1 saat geçerli): {url}")
            return url
        except ClientError as e:
            print(f"❌ URL oluşturma hatası: {e}")
            return None
    
    def create_folder(self, folder_name):
        """
        Klasör oluşturur (S3'te klasörler boş nesnelerdir)
        """
        try:
            if not folder_name.endswith('/'):
                folder_name += '/'
            
            print(f"📁 Klasör oluşturuluyor: {folder_name}")
            self.s3_client.put_object(Bucket=self.bucket_name, Key=folder_name)
            print(f"✅ Klasör başarıyla oluşturuldu: {folder_name}")
            return True
        except ClientError as e:
            print(f"❌ Klasör oluşturma hatası: {e}")
            return False
    
    def copy_object(self, source_key, destination_key):
        """
        Nesne kopyalar
        """
        try:
            print(f"📋 Nesne kopyalanıyor: {source_key} -> {destination_key}")
            copy_source = {'Bucket': self.bucket_name, 'Key': source_key}
            self.s3_resource.meta.client.copy(copy_source, self.bucket_name, destination_key)
            print(f"✅ Nesne başarıyla kopyalandı: {destination_key}")
            return True
        except ClientError as e:
            print(f"❌ Nesne kopyalama hatası: {e}")
            return False
    
    def get_bucket_info(self):
        """
        Bucket bilgilerini getirir
        """
        try:
            response = self.s3_client.head_bucket(Bucket=self.bucket_name)
            print(f"📊 Bucket bilgileri:")
            print(f"  - Bucket: {self.bucket_name}")
            print(f"  - Bölge: {self.region}")
            print(f"  - Durum: Aktif")
            return response
        except ClientError as e:
            print(f"❌ Bucket bilgisi alma hatası: {e}")
            return None

def main():
    """
    Ana fonksiyon - S3 örneklerini çalıştırır
    """
    print("🚀 AWS ZERO to YETO - S3 Temel İşlemler")
    print("=" * 50)
    
    # S3 Manager'ı başlat
    bucket_name = f"aws-zero-to-yeto-demo-{int(time.time())}"
    s3_manager = S3Manager(region='eu-west-1')
    
    try:
        # 1. Bucket oluştur
        if s3_manager.create_bucket(bucket_name):
            print("\n" + "="*30)
            
            # 2. Test dosyası oluştur
            test_file = "test_dosyasi.txt"
            with open(test_file, 'w', encoding='utf-8') as f:
                f.write("Bu bir test dosyasıdır.\nAWS ZERO to YETO projesi için oluşturulmuştur.\n")
            
            # 3. Dosya yükle
            s3_manager.upload_file(test_file, "ornekler/test_dosyasi.txt")
            
            # 4. Klasör oluştur
            s3_manager.create_folder("dokumanlar")
            s3_manager.create_folder("resimler")
            
            # 5. Nesneleri listele
            s3_manager.list_objects()
            
            # 6. Geçici URL oluştur
            s3_manager.get_object_url("ornekler/test_dosyasi.txt")
            
            # 7. Dosya kopyala
            s3_manager.copy_object("ornekler/test_dosyasi.txt", "dokumanlar/kopya_dosya.txt")
            
            # 8. Bucket bilgilerini al
            s3_manager.get_bucket_info()
            
            # 9. Dosyayı indir
            s3_manager.download_file("ornekler/test_dosyasi.txt", "indirilen_dosya.txt")
            
            # 10. Test dosyasını sil
            s3_manager.delete_object("ornekler/test_dosyasi.txt")
            
            print("\n" + "="*30)
            print("🎉 Tüm işlemler başarıyla tamamlandı!")
            print(f"📁 Bucket: {bucket_name}")
            print("🧹 Temizlik için: aws s3 rb s3://{bucket_name} --force")
            
        else:
            print("❌ Bucket oluşturulamadı, işlemler durduruldu.")
    
    except Exception as e:
        print(f"❌ Beklenmeyen hata: {e}")
    
    finally:
        # Temizlik
        if os.path.exists(test_file):
            os.remove(test_file)
        if os.path.exists("indirilen_dosya.txt"):
            os.remove("indirilen_dosya.txt")

if __name__ == "__main__":
    import time
    main()
