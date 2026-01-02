import argparse
import os
import random
from pathlib import Path

import numpy as np
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader, TensorDataset


class SimpleCNN(nn.Module):
    def __init__(self):
        super().__init__()
        self.features = nn.Sequential(
            nn.Conv2d(1, 32, kernel_size=3, padding=1),
            nn.ReLU(inplace=True),
            nn.MaxPool2d(2),
            nn.Conv2d(32, 64, kernel_size=3, padding=1),
            nn.ReLU(inplace=True),
            nn.MaxPool2d(2),
        )
        self.classifier = nn.Sequential(
            nn.Flatten(),
            nn.Linear(64 * 7 * 7, 128),
            nn.ReLU(inplace=True),
            nn.Dropout(0.25),
            nn.Linear(128, 10),
        )

    def forward(self, x):
        x = self.features(x)
        x = self.classifier(x)
        return x


def parse_args():
    default_data_dir = os.environ.get("SM_CHANNEL_TRAINING") or os.environ.get("DATA_DIR", "./data")
    default_output_dir = os.environ.get("SM_MODEL_DIR") or os.environ.get("OUTPUT_DIR", "./outputs")

    parser = argparse.ArgumentParser(
        description="Train a simple MNIST CNN with PyTorch.",
        add_help=True,
    )
    parser.add_argument("--data-dir", type=str, default=default_data_dir)
    parser.add_argument("--output-dir", type=str, default=default_output_dir)
    parser.add_argument(
        "--model-dir",
        type=str,
        default=default_output_dir,
        help="SageMaker sets this; treated the same as output-dir.",
    )
    parser.add_argument("--batch-size", type=int, default=128)
    parser.add_argument("--epochs", type=int, default=5)
    parser.add_argument("--lr", type=float, default=1e-3)
    parser.add_argument("--num-workers", type=int, default=2)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--device", type=str, default="auto", help='Use "auto", "cuda", or "cpu"')

    # SageMaker may append extra arguments; ignore unknowns to avoid failing with exit code 2.
    args, _ = parser.parse_known_args()
    if not args.output_dir and args.model_dir:
        args.output_dir = args.model_dir
    return args


def get_device(requested: str) -> torch.device:
    if requested == "auto":
        return torch.device("cuda" if torch.cuda.is_available() else "cpu")
    return torch.device(requested)


def set_seed(seed: int):
    random.seed(seed)
    torch.manual_seed(seed)
    torch.cuda.manual_seed_all(seed)


def load_numpy_arrays(data_dir: str):
    data_dir = Path(data_dir)
    required = ["train_data.npy", "train_labels.npy", "test_data.npy", "test_labels.npy"]
    missing = [name for name in required if not (data_dir / name).exists()]
    if missing:
        raise FileNotFoundError(f"Missing data files in {data_dir}: {', '.join(missing)}")

    train_data = np.load(data_dir / "train_data.npy")
    train_labels = np.load(data_dir / "train_labels.npy")
    test_data = np.load(data_dir / "test_data.npy")
    test_labels = np.load(data_dir / "test_labels.npy")
    return train_data, train_labels, test_data, test_labels


def get_data_loaders(data_dir: str, batch_size: int, num_workers: int, device: torch.device):
    train_data, train_labels, test_data, test_labels = load_numpy_arrays(data_dir)

    # Ensure correct shapes: (N, 1, 28, 28) and integer labels.
    train_tensor = torch.tensor(train_data, dtype=torch.float32).unsqueeze(1)
    test_tensor = torch.tensor(test_data, dtype=torch.float32).unsqueeze(1)
    train_labels_tensor = torch.tensor(train_labels, dtype=torch.long)
    test_labels_tensor = torch.tensor(test_labels, dtype=torch.long)

    train_set = TensorDataset(train_tensor, train_labels_tensor)
    test_set = TensorDataset(test_tensor, test_labels_tensor)
    pin_memory = device.type == "cuda"

    train_loader = DataLoader(
        train_set, batch_size=batch_size, shuffle=True, num_workers=num_workers, pin_memory=pin_memory
    )
    test_loader = DataLoader(
        test_set, batch_size=batch_size, shuffle=False, num_workers=num_workers, pin_memory=pin_memory
    )
    return train_loader, test_loader


def evaluate(model, data_loader, device):
    model.eval()
    correct = 0
    total = 0
    loss_sum = 0.0
    criterion = nn.CrossEntropyLoss()
    with torch.no_grad():
        for images, labels in data_loader:
            images, labels = images.to(device), labels.to(device)
            outputs = model(images)
            loss = criterion(outputs, labels)
            loss_sum += loss.item() * labels.size(0)
            _, predicted = torch.max(outputs.data, 1)
            total += labels.size(0)
            correct += (predicted == labels).sum().item()
    avg_loss = loss_sum / total
    accuracy = 100.0 * correct / total
    return avg_loss, accuracy


def train():
    args = parse_args()
    set_seed(args.seed)

    device = get_device(args.device)
    if device.type == "cuda":
        torch.backends.cudnn.benchmark = True

    Path(args.output_dir).mkdir(parents=True, exist_ok=True)
    train_loader, test_loader = get_data_loaders(args.data_dir, args.batch_size, args.num_workers, device)

    model = SimpleCNN().to(device)
    optimizer = optim.Adam(model.parameters(), lr=args.lr)
    criterion = nn.CrossEntropyLoss()
    scaler = torch.cuda.amp.GradScaler(enabled=device.type == "cuda")

    for epoch in range(1, args.epochs + 1):
        model.train()
        running_loss = 0.0
        for images, labels in train_loader:
            images, labels = images.to(device), labels.to(device)

            optimizer.zero_grad(set_to_none=True)
            with torch.cuda.amp.autocast(enabled=device.type == "cuda"):
                outputs = model(images)
                loss = criterion(outputs, labels)
            scaler.scale(loss).backward()
            scaler.step(optimizer)
            scaler.update()

            running_loss += loss.item() * labels.size(0)

        train_loss = running_loss / len(train_loader.dataset)
        val_loss, val_acc = evaluate(model, test_loader, device)
        print(
            f"Epoch {epoch}/{args.epochs} "
            f"- train_loss: {train_loss:.4f} "
            f"- val_loss: {val_loss:.4f} "
            f"- val_acc: {val_acc:.2f}%"
        )

    model_path = Path(args.output_dir) / "mnist_cnn.pt"
    torch.save(model.state_dict(), model_path)
    print(f"Saved model to {model_path}")


if __name__ == "__main__":
    train()
