#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
AWS ZERO to YETO - IAM Python Örneği
Bu dosya IAM yönetimini gösterir
"""

import boto3
import json
import time
from datetime import datetime, timedelta
from botocore.exceptions import ClientError

class IAMManager:
    def __init__(self, region='eu-west-1'):
        """
        IAM Manager sınıfı başlatıcısı
        """
        self.iam_client = boto3.client('iam', region_name=region)
        self.sts_client = boto3.client('sts', region_name=region)
        self.region = region
    
    def get_current_user(self):
        """
        Geçerli kullanıcı bilgilerini alır
        """
        try:
            print("🔍 Geçerli kullanıcı bilgileri alınıyor...")
            
            # STS ile kimlik bilgilerini al
            identity = self.sts_client.get_caller_identity()
            
            user_arn = identity.get('Arn')
            account_id = identity.get('Account')
            user_id = identity.get('UserId')
            
            print(f"✅ Kimlik doğrulandı:")
            print(f"   Account ID: {account_id}")
            print(f"   User ARN: {user_arn}")
            print(f"   User ID: {user_id}")
            
            return identity
            
        except Exception as e:
            print(f"❌ Kimlik bilgisi alma hatası: {str(e)}")
            return None
    
    def list_users(self, path_prefix='/'):
        """
        IAM kullanıcılarını listeler
        """
        try:
            print(f"👥 IAM kullanıcıları listeleniyor (Path: {path_prefix})...")
            
            users = []
            paginator = self.iam_client.get_paginator('list_users')
            
            for page in paginator.paginate(PathPrefix=path_prefix):
                for user in page['Users']:
                    user_info = {
                        'UserName': user['UserName'],
                        'UserId': user['UserId'],
                        'Arn': user['Arn'],
                        'CreateDate': user['CreateDate'],
                        'Path': user['Path']
                    }
                    
                    # Son login tarihini al (varsa)
                    try:
                        login_profile = self.iam_client.get_login_profile(UserName=user['UserName'])
                        user_info['HasConsoleAccess'] = True
                    except ClientError:
                        user_info['HasConsoleAccess'] = False
                    
                    # Access key'leri kontrol et
                    try:
                        access_keys = self.iam_client.list_access_keys(UserName=user['UserName'])
                        user_info['AccessKeyCount'] = len(access_keys['AccessKeyMetadata'])
                        user_info['AccessKeys'] = [
                            {
                                'AccessKeyId': key['AccessKeyId'],
                                'Status': key['Status'],
                                'CreateDate': key['CreateDate']
                            }
                            for key in access_keys['AccessKeyMetadata']
                        ]
                    except ClientError:
                        user_info['AccessKeyCount'] = 0
                        user_info['AccessKeys'] = []
                    
                    users.append(user_info)
            
            print(f"📊 Toplam {len(users)} kullanıcı bulundu:")
            for user in users:
                print(f"  👤 {user['UserName']}")
                print(f"     Path: {user['Path']}")
                print(f"     Console Access: {'✅' if user['HasConsoleAccess'] else '❌'}")
                print(f"     Access Keys: {user['AccessKeyCount']}")
                print(f"     Created: {user['CreateDate'].strftime('%Y-%m-%d %H:%M')}")
                print()
            
            return users
            
        except Exception as e:
            print(f"❌ Kullanıcı listeleme hatası: {str(e)}")
            return []
    
    def list_roles(self, path_prefix='/'):
        """
        IAM rollerini listeler
        """
        try:
            print(f"🎭 IAM rolleri listeleniyor (Path: {path_prefix})...")
            
            roles = []
            paginator = self.iam_client.get_paginator('list_roles')
            
            for page in paginator.paginate(PathPrefix=path_prefix):
                for role in page['Roles']:
                    role_info = {
                        'RoleName': role['RoleName'],
                        'RoleId': role['RoleId'],
                        'Arn': role['Arn'],
                        'CreateDate': role['CreateDate'],
                        'Path': role['Path'],
                        'AssumeRolePolicyDocument': role['AssumeRolePolicyDocument']
                    }
                    
                    # Attached policies
                    try:
                        attached_policies = self.iam_client.list_attached_role_policies(RoleName=role['RoleName'])
                        role_info['AttachedPolicies'] = [
                            {
                                'PolicyName': policy['PolicyName'],
                                'PolicyArn': policy['PolicyArn']
                            }
                            for policy in attached_policies['AttachedPolicies']
                        ]
                    except ClientError:
                        role_info['AttachedPolicies'] = []
                    
                    roles.append(role_info)
            
            print(f"📊 Toplam {len(roles)} rol bulundu:")
            for role in roles:
                print(f"  🎭 {role['RoleName']}")
                print(f"     Path: {role['Path']}")
                print(f"     Attached Policies: {len(role['AttachedPolicies'])}")
                print(f"     Created: {role['CreateDate'].strftime('%Y-%m-%d %H:%M')}")
                
                # Trust relationship analizi
                trust_policy = json.loads(role['AssumeRolePolicyDocument'])
                principals = []
                for statement in trust_policy.get('Statement', []):
                    principal = statement.get('Principal', {})
                    if isinstance(principal, dict):
                        for key, value in principal.items():
                            if isinstance(value, list):
                                principals.extend(value)
                            else:
                                principals.append(value)
                
                if principals:
                    print(f"     Trust: {', '.join(principals[:3])}")
                print()
            
            return roles
            
        except Exception as e:
            print(f"❌ Rol listeleme hatası: {str(e)}")
            return []
    
    def analyze_user_permissions(self, username):
        """
        Kullanıcının izinlerini analiz eder
        """
        try:
            print(f"🔍 {username} kullanıcısının izinleri analiz ediliyor...")
            
            permissions = {
                'DirectPolicies': [],
                'GroupPolicies': [],
                'Groups': []
            }
            
            # Direct attached policies
            try:
                attached_policies = self.iam_client.list_attached_user_policies(UserName=username)
                for policy in attached_policies['AttachedPolicies']:
                    permissions['DirectPolicies'].append({
                        'PolicyName': policy['PolicyName'],
                        'PolicyArn': policy['PolicyArn']
                    })
            except ClientError as e:
                print(f"⚠️ Direct policy kontrolü hatası: {str(e)}")
            
            # Group memberships
            try:
                groups = self.iam_client.get_groups_for_user(UserName=username)
                for group in groups['Groups']:
                    group_info = {
                        'GroupName': group['GroupName'],
                        'AttachedPolicies': []
                    }
                    
                    # Group'un policy'lerini al
                    try:
                        group_policies = self.iam_client.list_attached_group_policies(GroupName=group['GroupName'])
                        for policy in group_policies['AttachedPolicies']:
                            group_info['AttachedPolicies'].append({
                                'PolicyName': policy['PolicyName'],
                                'PolicyArn': policy['PolicyArn']
                            })
                            permissions['GroupPolicies'].append({
                                'PolicyName': policy['PolicyName'],
                                'PolicyArn': policy['PolicyArn'],
                                'ViaGroup': group['GroupName']
                            })
                    except ClientError:
                        pass
                    
                    permissions['Groups'].append(group_info)
            except ClientError as e:
                print(f"⚠️ Group membership kontrolü hatası: {str(e)}")
            
            # Sonuçları göster
            print(f"📋 {username} izin analizi:")
            
            print(f"\n👤 Direct Policies ({len(permissions['DirectPolicies'])}):")
            for policy in permissions['DirectPolicies']:
                print(f"   - {policy['PolicyName']}")
            
            print(f"\n👥 Groups ({len(permissions['Groups'])}):")
            for group in permissions['Groups']:
                print(f"   - {group['GroupName']} ({len(group['AttachedPolicies'])} policies)")
                for policy in group['AttachedPolicies']:
                    print(f"     • {policy['PolicyName']}")
            
            total_policies = len(permissions['DirectPolicies']) + len(permissions['GroupPolicies'])
            print(f"\n📊 Toplam Policy Sayısı: {total_policies}")
            
            return permissions
            
        except Exception as e:
            print(f"❌ İzin analizi hatası: {str(e)}")
            return {}
    
    def check_mfa_status(self, username):
        """
        Kullanıcının MFA durumunu kontrol eder
        """
        try:
            print(f"🔐 {username} kullanıcısının MFA durumu kontrol ediliyor...")
            
            mfa_devices = self.iam_client.list_mfa_devices(UserName=username)
            
            if mfa_devices['MFADevices']:
                print(f"✅ MFA aktif - {len(mfa_devices['MFADevices'])} device")
                for device in mfa_devices['MFADevices']:
                    print(f"   📱 {device['SerialNumber']}")
                    print(f"   📅 Enabled: {device['EnableDate'].strftime('%Y-%m-%d %H:%M')}")
                return True
            else:
                print(f"❌ MFA aktif değil")
                return False
                
        except ClientError as e:
            if e.response['Error']['Code'] == 'NoSuchEntity':
                print(f"❌ Kullanıcı bulunamadı: {username}")
            else:
                print(f"❌ MFA kontrol hatası: {str(e)}")
            return False
    
    def generate_credential_report(self):
        """
        Credential report oluşturur ve analiz eder
        """
        try:
            print("📊 Credential report oluşturuluyor...")
            
            # Report generation başlat
            try:
                self.iam_client.generate_credential_report()
            except ClientError as e:
                if 'ReportInProgress' not in str(e):
                    raise e
            
            # Report'un hazır olmasını bekle
            max_attempts = 10
            for attempt in range(max_attempts):
                try:
                    report_response = self.iam_client.get_credential_report()
                    break
                except ClientError as e:
                    if 'ReportNotPresent' in str(e) or 'ReportInProgress' in str(e):
                        print(f"⏳ Report hazırlanıyor... ({attempt + 1}/{max_attempts})")
                        time.sleep(3)
                        continue
                    else:
                        raise e
            else:
                print("❌ Report hazırlanamadı")
                return None
            
            # CSV report'u parse et
            report_content = report_response['Content'].decode('utf-8')
            lines = report_content.strip().split('\n')
            headers = lines[0].split(',')
            
            print(f"✅ Credential report hazır ({len(lines) - 1} kullanıcı)")
            
            # Güvenlik analizi
            security_issues = []
            
            for line in lines[1:]:  # Header'ı atla
                values = line.split(',')
                user_data = dict(zip(headers, values))
                
                username = user_data.get('user', '')
                if username == '<root_account>':
                    continue
                
                # MFA kontrolü
                mfa_active = user_data.get('mfa_active', 'false').lower() == 'true'
                if not mfa_active:
                    security_issues.append(f"❌ {username}: MFA aktif değil")
                
                # Password kullanımı kontrolü
                password_enabled = user_data.get('password_enabled', 'false').lower() == 'true'
                password_last_used = user_data.get('password_last_used', '')
                
                if password_enabled and password_last_used:
                    try:
                        last_used = datetime.strptime(password_last_used, '%Y-%m-%dT%H:%M:%S+00:00')
                        days_ago = (datetime.now() - last_used).days
                        if days_ago > 90:
                            security_issues.append(f"⚠️ {username}: Password {days_ago} gün önce kullanılmış")
                    except ValueError:
                        pass
                
                # Access key kontrolü
                access_key_1_active = user_data.get('access_key_1_active', 'false').lower() == 'true'
                access_key_2_active = user_data.get('access_key_2_active', 'false').lower() == 'true'
                
                if access_key_1_active or access_key_2_active:
                    key_count = (1 if access_key_1_active else 0) + (1 if access_key_2_active else 0)
                    print(f"🔑 {username}: {key_count} aktif access key")
            
            # Güvenlik sorunlarını göster
            if security_issues:
                print(f"\n🚨 Güvenlik Uyarıları ({len(security_issues)}):")
                for issue in security_issues[:10]:  # İlk 10'unu göster
                    print(f"  {issue}")
                if len(security_issues) > 10:
                    print(f"  ... ve {len(security_issues) - 10} daha")
            else:
                print("\n✅ Güvenlik sorunu bulunamadı")
            
            return report_content
            
        except Exception as e:
            print(f"❌ Credential report hatası: {str(e)}")
            return None

def main():
    """
    Ana fonksiyon - IAM örneklerini çalıştırır
    """
    print("🔐 AWS ZERO to YETO - IAM Python Örnekleri")
    print("=" * 50)
    
    # IAM Manager'ı başlat
    iam = IAMManager(region='eu-west-1')
    
    try:
        # 1. Geçerli kullanıcı bilgileri
        print("\n" + "="*30)
        print("🔍 Kimlik Bilgileri")
        identity = iam.get_current_user()
        
        if not identity:
            print("❌ Kimlik doğrulaması başarısız!")
            return
        
        # 2. Kullanıcıları listele
        print("\n" + "="*30)
        print("👥 IAM Kullanıcıları")
        users = iam.list_users()
        
        # 3. Rolleri listele  
        print("\n" + "="*30)
        print("🎭 IAM Rolleri")
        roles = iam.list_roles()
        
        # 4. Demo kullanıcısı varsa analiz et
        demo_users = [user for user in users if 'demo' in user['UserName'].lower()]
        if demo_users:
            demo_user = demo_users[0]
            print("\n" + "="*30)
            print(f"🔍 Demo Kullanıcısı Analizi: {demo_user['UserName']}")
            iam.analyze_user_permissions(demo_user['UserName'])
            iam.check_mfa_status(demo_user['UserName'])
        
        # 5. Credential report
        print("\n" + "="*30)
        print("📊 Credential Report")
        iam.generate_credential_report()
        
        # 6. Güvenlik önerileri
        print("\n" + "="*30)
        print("🛡️ Güvenlik Önerileri")
        print("✅ Root kullanıcıyı günlük işlerde kullanmayın")
        print("✅ Tüm kullanıcılar için MFA aktif edin")
        print("✅ Least privilege prensibini uygulayın")
        print("✅ Access key'leri düzenli rotate edin")
        print("✅ Unused credentials'ları temizleyin")
        print("✅ CloudTrail ile API call'ları monitör edin")
        
        print("\n🎉 IAM analizi tamamlandı!")
        
    except Exception as e:
        print(f"❌ Beklenmeyen hata: {str(e)}")

if __name__ == "__main__":
    main()
