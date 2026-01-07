import torchvision
import torchvision.transforms as transforms
import numpy as np
import boto3
import os

# MNIST verisini indir
print("MNIST verisi indiriliyor...")
transform = transforms.Compose([
    transforms.ToTensor(),
])

# Training ve test setlerini indir
trainset = torchvision.datasets.MNIST(
    root='./data', 
    train=True, 
    download=True, 
    transform=transform
)

testset = torchvision.datasets.MNIST(
    root='./data', 
    train=False, 
    download=True, 
    transform=transform
)

# Tensor'leri NumPy array'e çevir
print("Veriler işleniyor...")
train_data = trainset.data.numpy()
train_labels = trainset.targets.numpy()
test_data = testset.data.numpy()
test_labels = testset.targets.numpy()

# Normalize et (0-1 arası) daha güzel oluroyr 
train_data = train_data.astype('float32') / 255.0
test_data = test_data.astype('float32') / 255.0


os.makedirs('/tmp/mnist-data', exist_ok=True)

# NumPy formatında kaydet
print("Veriler kaydediliyor...")
np.save('/tmp/mnist-data/train_data.npy', train_data)
np.save('/tmp/mnist-data/train_labels.npy', train_labels)
np.save('/tmp/mnist-data/test_data.npy', test_data)
np.save('/tmp/mnist-data/test_labels.npy', test_labels)

print(f"Train data shape: {train_data.shape}")
print(f"Train labels shape: {train_labels.shape}")
print(f"Test data shape: {test_data.shape}")
print(f"Test labels shape: {test_labels.shape}")

# S3'e yükle
print("\nS3'e yükleniyor...")

# AWS Region ve Bucket bilgilerini al
region_name = input("AWS Region (örn: us-east-1, eu-central-1): ").strip()
if not region_name:
    print("❌ Region gerekli!")
    exit(1)

bucket_name = input("S3 Bucket Name: ").strip()
if not bucket_name:
    print("❌ Bucket name gerekli!")
    exit(1)

s3 = boto3.client('s3', region_name=region_name)

files = ['train_data.npy', 'train_labels.npy', 'test_data.npy', 'test_labels.npy']
for file in files:
    local_path = f'/tmp/mnist-data/{file}'
    s3_path = f'mnist-data/{file}'
    s3.upload_file(local_path, bucket_name, s3_path)
    print(f"✓ {file} yüklendi")

print("\n✅ Tüm veriler S3'e yüklendi!")
print(f"S3 konumu: s3://{bucket_name}/mnist-data/")