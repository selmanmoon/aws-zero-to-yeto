#!/usr/bin/env python3
"""
AWS RDS Yöneticisi
Bu script RDS instance'ları oluşturur ve yönetir.
"""

import boto3
import json
import time
import pymysql
import psycopg2
from botocore.exceptions import ClientError, WaiterError
from typing import Dict, List, Optional

class RDSManager:
    def __init__(self, region_name: str = 'eu-west-1'):
        """
        RDS Yöneticisi sınıfını başlatır
        
        Args:
            region_name (str): AWS bölgesi
        """
        self.region_name = region_name
        self.rds_client = boto3.client('rds', region_name=region_name)
        self.ec2_client = boto3.client('ec2', region_name=region_name)
        
        # RDS yapılandırması
        self.rds_config = {
            'instance_class': 'db.t3.micro',  # Ücretsiz Katman
            'storage_size': 20,  # GB
            'backup_retention': 7,  # gün
            'multi_az': False,  # Ücretsiz Katman'da Multi-AZ yok
            'storage_type': 'gp2',
            'storage_encrypted': True,
            'auto_minor_version_upgrade': True,
            'publicly_accessible': True
        }
        
        # Veritabanı motoru yapılandırmaları
        self.engines = {
            'mysql': {
                'engine': 'mysql',
                'version': '8.0.35',
                'port': 3306,
                'default_db': 'mysql'
            },
            'postgresql': {
                'engine': 'postgres',
                'version': '15.4',
                'port': 5432,
                'default_db': 'postgres'
            }
        }
        
        # Oluşturulan kaynaklar
        self.resources = {
            'instances': {},
            'subnet_groups': [],
            'parameter_groups': []
        }
    
    def load_vpc_config(self, config_file: str = 'vpc-config.json') -> bool:
        """
        VPC yapılandırmasını yükler
        
        Args:
            config_file (str): VPC yapılandırma dosyası
            
        Returns:
            bool: Başarı durumu
        """
        try:
            with open(config_file, 'r') as f:
                vpc_config = json.load(f)
            
            self.vpc_id = vpc_config.get('vpc_id')
            self.db_subnet_group = vpc_config.get('db_subnet_group')
            self.db_security_group = vpc_config.get('security_groups', {}).get('database')
            
            if not all([self.vpc_id, self.db_subnet_group, self.db_security_group]):
                print("❌ VPC konfigürasyonu eksik")
                return False
            
            print(f"✅ VPC konfigürasyonu yüklendi")
            print(f"  VPC ID: {self.vpc_id}")
            print(f"  DB Subnet Group: {self.db_subnet_group}")
            print(f"  DB Security Group: {self.db_security_group}")
            return True
            
        except FileNotFoundError:
            print(f"❌ {config_file} bulunamadı")
            return False
        except json.JSONDecodeError:
            print(f"❌ {config_file} geçersiz JSON biçimi")
            return False
    
    def create_db_instance(self, engine_type: str, project_name: str = 'aws-zero-to-yeto') -> Optional[str]:
        """
        RDS instance oluşturur
        
        Args:
            engine_type (str): Veritabanı motoru tipi (mysql, postgresql)
            project_name (str): Proje adı
            
        Returns:
            Optional[str]: Instance tanımlayıcısı
        """
        if engine_type not in self.engines:
            print(f"❌ Desteklenmeyen motor: {engine_type}")
            return None
        
        engine_config = self.engines[engine_type]
        instance_identifier = f"{project_name}-{engine_type}"
        
        try:
            print(f"🔨 {engine_type.upper()} instance oluşturuluyor: {instance_identifier}")
            
            # Instance zaten var mı kontrol et
            try:
                self.rds_client.describe_db_instances(DBInstanceIdentifier=instance_identifier)
                print(f"⚠️  {instance_identifier} zaten mevcut")
                return instance_identifier
            except ClientError:
                pass
            
            # Instance oluştur
            response = self.rds_client.create_db_instance(
                DBInstanceIdentifier=instance_identifier,
                DBInstanceClass=self.rds_config['instance_class'],
                Engine=engine_config['engine'],
                EngineVersion=engine_config['version'],
                MasterUsername='admin',
                MasterUserPassword='SecurePassword123!',
                AllocatedStorage=self.rds_config['storage_size'],
                StorageType=self.rds_config['storage_type'],
                StorageEncrypted=self.rds_config['storage_encrypted'],
                VpcSecurityGroupIds=[self.db_security_group],
                DBSubnetGroupName=self.db_subnet_group,
                BackupRetentionPeriod=self.rds_config['backup_retention'],
                MultiAZ=self.rds_config['multi_az'],
                AutoMinorVersionUpgrade=self.rds_config['auto_minor_version_upgrade'],
                PubliclyAccessible=self.rds_config['publicly_accessible'],
                Port=engine_config['port'],
                Tags=[
                    {'Key': 'Name', 'Value': instance_identifier},
                    {'Key': 'Project', 'Value': project_name},
                    {'Key': 'Engine', 'Value': engine_type},
                    {'Key': 'Environment', 'Value': 'development'}
                ]
            )
            
            self.resources['instances'][engine_type] = {
                'identifier': instance_identifier,
                'arn': response['DBInstance']['DBInstanceArn']
            }
            
            print(f"✅ {engine_type.upper()} instance oluşturma başlatıldı")
            return instance_identifier
            
        except ClientError as e:
            print(f"❌ {engine_type.upper()} instance oluşturulamadı: {e}")
            return None
    
    def wait_for_instance_available(self, instance_identifier: str) -> bool:
        """
        Instance'in hazır olmasını bekler
        
        Args:
            instance_identifier (str): Instance identifier
            
        Returns:
            bool: Başarı durumu
        """
        try:
            print(f"⏳ {instance_identifier} hazır olması bekleniyor...")
            
            waiter = self.rds_client.get_waiter('db_instance_available')
            waiter.wait(
                DBInstanceIdentifier=instance_identifier,
                WaiterConfig={'Delay': 30, 'MaxAttempts': 60}
            )
            
            print(f"✅ {instance_identifier} hazır")
            return True
            
        except WaiterError as e:
            print(f"❌ {instance_identifier} hazır olmadı: {e}")
            return False
    
    def get_instance_endpoint(self, instance_identifier: str) -> Optional[str]:
        """
        Instance endpoint'ini alır
        
        Args:
            instance_identifier (str): Instance identifier
            
        Returns:
            Optional[str]: Endpoint
        """
        try:
            response = self.rds_client.describe_db_instances(
                DBInstanceIdentifier=instance_identifier
            )
            
            endpoint = response['DBInstances'][0]['Endpoint']['Address']
            return endpoint
            
        except ClientError as e:
            print(f"❌ Endpoint alınamadı: {e}")
            return None
    
    def test_mysql_connection(self, endpoint: str, username: str = 'admin', password: str = 'SecurePassword123!') -> bool:
        """
        MySQL bağlantısını test eder
        
        Args:
            endpoint (str): Database endpoint
            username (str): Kullanıcı adı
            password (str): Şifre
            
        Returns:
            bool: Başarı durumu
        """
        try:
            print(f"🔍 MySQL bağlantısı test ediliyor: {endpoint}")
            
            connection = pymysql.connect(
                host=endpoint,
                user=username,
                password=password,
                port=3306,
                connect_timeout=10
            )
            
            cursor = connection.cursor()
            cursor.execute("SELECT VERSION()")
            version = cursor.fetchone()
            
            print(f"✅ MySQL bağlantısı başarılı - Version: {version[0]}")
            
            cursor.close()
            connection.close()
            return True
            
        except Exception as e:
            print(f"❌ MySQL bağlantısı başarısız: {e}")
            return False
    
    def test_postgresql_connection(self, endpoint: str, username: str = 'admin', password: str = 'SecurePassword123!') -> bool:
        """
        PostgreSQL bağlantısını test eder
        
        Args:
            endpoint (str): Database endpoint
            username (str): Kullanıcı adı
            password (str): Şifre
            
        Returns:
            bool: Başarı durumu
        """
        try:
            print(f"🔍 PostgreSQL bağlantısı test ediliyor: {endpoint}")
            
            connection = psycopg2.connect(
                host=endpoint,
                database='postgres',
                user=username,
                password=password,
                port=5432,
                connect_timeout=10
            )
            
            cursor = connection.cursor()
            cursor.execute("SELECT version();")
            version = cursor.fetchone()
            
            print(f"✅ PostgreSQL bağlantısı başarılı - Version: {version[0]}")
            
            cursor.close()
            connection.close()
            return True
            
        except Exception as e:
            print(f"❌ PostgreSQL bağlantısı başarısız: {e}")
            return False
    
    def create_database(self, engine_type: str, db_name: str, endpoint: str, username: str = 'admin', password: str = 'SecurePassword123!') -> bool:
        """
        Database oluşturur
        
        Args:
            engine_type (str): Database engine tipi
            db_name (str): Database adı
            endpoint (str): Database endpoint
            username (str): Kullanıcı adı
            password (str): Şifre
            
        Returns:
            bool: Başarı durumu
        """
        try:
            if engine_type == 'mysql':
                connection = pymysql.connect(
                    host=endpoint,
                    user=username,
                    password=password,
                    port=3306
                )
                
                cursor = connection.cursor()
                cursor.execute(f"CREATE DATABASE IF NOT EXISTS {db_name}")
                print(f"✅ MySQL database oluşturuldu: {db_name}")
                
                cursor.close()
                connection.close()
                
            elif engine_type == 'postgresql':
                connection = psycopg2.connect(
                    host=endpoint,
                    database='postgres',
                    user=username,
                    password=password,
                    port=5432
                )
                
                connection.autocommit = True
                cursor = connection.cursor()
                cursor.execute(f"CREATE DATABASE {db_name}")
                print(f"✅ PostgreSQL database oluşturuldu: {db_name}")
                
                cursor.close()
                connection.close()
            
            return True
            
        except Exception as e:
            print(f"❌ Database oluşturulamadı: {e}")
            return False
    
    def create_complete_rds_infrastructure(self, project_name: str = 'aws-zero-to-yeto') -> bool:
        """
        Tam RDS altyapısını oluşturur
        
        Args:
            project_name (str): Proje adı
            
        Returns:
            bool: Başarı durumu
        """
        print(f"🚀 {project_name} RDS altyapısı oluşturuluyor...")
        print(f"📍 Region: {self.region_name}")
        print("")
        
        # VPC konfigürasyonunu yükle
        if not self.load_vpc_config():
            return False
        
        # MySQL instance oluştur
        mysql_identifier = self.create_db_instance('mysql', project_name)
        if not mysql_identifier:
            return False
        
        # PostgreSQL instance oluştur
        postgresql_identifier = self.create_db_instance('postgresql', project_name)
        if not postgresql_identifier:
            return False
        
        # Instance'ların hazır olmasını bekle
        if not self.wait_for_instance_available(mysql_identifier):
            return False
        
        if not self.wait_for_instance_available(postgresql_identifier):
            return False
        
        # Endpoint'leri al
        mysql_endpoint = self.get_instance_endpoint(mysql_identifier)
        postgresql_endpoint = self.get_instance_endpoint(postgresql_identifier)
        
        if not mysql_endpoint or not postgresql_endpoint:
            return False
        
        # Bağlantıları test et
        print("")
        print("🔍 Bağlantı testleri yapılıyor...")
        
        mysql_ok = self.test_mysql_connection(mysql_endpoint)
        postgresql_ok = self.test_postgresql_connection(postgresql_endpoint)
        
        if not mysql_ok or not postgresql_ok:
            print("⚠️  Bazı bağlantı testleri başarısız")
        
        # Database'leri oluştur
        print("")
        print("🗄️  Database'ler oluşturuluyor...")
        
        self.create_database('mysql', 'myapp', mysql_endpoint)
        self.create_database('postgresql', 'myapp', postgresql_endpoint)
        
        # Konfigürasyonu kaydet
        self.save_configuration(project_name, mysql_identifier, postgresql_identifier, mysql_endpoint, postgresql_endpoint)
        
        print("")
        print("🎉 RDS altyapısı başarıyla oluşturuldu!")
        self.print_summary(mysql_identifier, postgresql_identifier, mysql_endpoint, postgresql_endpoint)
        
        return True
    
    def save_configuration(self, project_name: str, mysql_identifier: str, postgresql_identifier: str, mysql_endpoint: str, postgresql_endpoint: str):
        """
        Konfigürasyonu JSON dosyasına kaydeder
        
        Args:
            project_name (str): Proje adı
            mysql_identifier (str): MySQL instance identifier
            postgresql_identifier (str): PostgreSQL instance identifier
            mysql_endpoint (str): MySQL endpoint
            postgresql_endpoint (str): PostgreSQL endpoint
        """
        config = {
            'project_name': project_name,
            'region': self.region_name,
            'vpc_id': self.vpc_id,
            'db_subnet_group': self.db_subnet_group,
            'db_security_group': self.db_security_group,
            'instances': {
                'mysql': {
                    'identifier': mysql_identifier,
                    'endpoint': mysql_endpoint,
                    'port': 3306,
                    'username': 'admin',
                    'password': 'SecurePassword123!',
                    'engine': 'mysql',
                    'version': '8.0.35'
                },
                'postgresql': {
                    'identifier': postgresql_identifier,
                    'endpoint': postgresql_endpoint,
                    'port': 5432,
                    'username': 'admin',
                    'password': 'SecurePassword123!',
                    'engine': 'postgres',
                    'version': '15.4'
                }
            }
        }
        
        filename = f'{project_name}-rds-config.json'
        with open(filename, 'w') as f:
            json.dump(config, f, indent=2)
        
        print(f"✅ Konfigürasyon {filename} dosyasına kaydedildi")
    
    def print_summary(self, mysql_identifier: str, postgresql_identifier: str, mysql_endpoint: str, postgresql_endpoint: str):
        """
        Oluşturulan kaynakların özetini yazdırır
        
        Args:
            mysql_identifier (str): MySQL instance identifier
            postgresql_identifier (str): PostgreSQL instance identifier
            mysql_endpoint (str): MySQL endpoint
            postgresql_endpoint (str): PostgreSQL endpoint
        """
        print("")
        print("📊 Oluşturulan Kaynaklar:")
        print(f"  MySQL Instance: {mysql_identifier}")
        print(f"  MySQL Endpoint: {mysql_endpoint}")
        print(f"  PostgreSQL Instance: {postgresql_identifier}")
        print(f"  PostgreSQL Endpoint: {postgresql_endpoint}")
        print(f"  VPC ID: {self.vpc_id}")
        print(f"  DB Subnet Group: {self.db_subnet_group}")
        print("")
        print("💡 Bağlantı Bilgileri:")
        print("  MySQL:")
        print(f"    Host: {mysql_endpoint}")
        print("    Port: 3306")
        print("    Username: admin")
        print("    Password: SecurePassword123!")
        print("")
        print("  PostgreSQL:")
        print(f"    Host: {postgresql_endpoint}")
        print("    Port: 5432")
        print("    Username: admin")
        print("    Password: SecurePassword123!")
        print("")
        print("💡 Test Komutları:")
        print(f"  # MySQL bağlantısı")
        print(f"  mysql -h {mysql_endpoint} -P 3306 -u admin -p")
        print("")
        print(f"  # PostgreSQL bağlantısı")
        print(f"  psql -h {postgresql_endpoint} -p 5432 -U admin -d postgres")
    
    def cleanup_resources(self, project_name: str = 'aws-zero-to-yeto'):
        """
        Oluşturulan kaynakları temizler
        
        Args:
            project_name (str): Proje adı
        """
        print(f"🧹 {project_name} RDS kaynakları temizleniyor...")
        
        try:
            # Instance'ları sil
            for engine_type, instance_info in self.resources['instances'].items():
                instance_identifier = instance_info['identifier']
                
                try:
                    print(f"🗑️  {instance_identifier} siliniyor...")
                    
                    # Instance'ı durdur
                    self.rds_client.stop_db_instance(DBInstanceIdentifier=instance_identifier)
                    
                    # Silme için bekle
                    waiter = self.rds_client.get_waiter('db_instance_deleted')
                    waiter.wait(
                        DBInstanceIdentifier=instance_identifier,
                        WaiterConfig={'Delay': 30, 'MaxAttempts': 60}
                    )
                    
                    print(f"✅ {instance_identifier} silindi")
                    
                except ClientError as e:
                    print(f"⚠️  {instance_identifier} silinemedi: {e}")
            
            print("🎉 RDS kaynakları temizlendi!")
            
        except Exception as e:
            print(f"❌ Temizleme sırasında hata: {e}")


def main():
    """
    Ana fonksiyon - RDS oluşturma örneği
    """
    print("🚀 AWS RDS Manager")
    print("=" * 50)
    
    # RDS Manager oluştur
    rds_manager = RDSManager(region_name='eu-west-1')
    
    # Tam RDS altyapısını oluştur
    project_name = 'aws-zero-to-yeto'
    success = rds_manager.create_complete_rds_infrastructure(project_name)
    
    if success:
        print("")
        print("✅ RDS altyapısı başarıyla oluşturuldu!")
        print("")
        print("🧪 Test için örnek komutlar:")
        print("  # MySQL bağlantısı")
        print("  mysql -h <mysql-endpoint> -P 3306 -u admin -p")
        print("")
        print("  # PostgreSQL bağlantısı")
        print("  psql -h <postgresql-endpoint> -p 5432 -U admin -d postgres")
        print("")
        print("🗑️  Temizlemek için:")
        print("  rds_manager.cleanup_resources()")
    else:
        print("❌ RDS altyapısı oluşturulamadı!")


if __name__ == "__main__":
    main()
