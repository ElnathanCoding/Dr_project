import random
import shutil
from pathlib import Path

# ==========================================
# SETTINGS
# ==========================================

random.seed(42)

dataset_path = Path("Dataset/colored_images/colored_images")
output_path = Path("Dataset")

classes = [
    "No_DR",
    "Mild",
    "Moderate",
    "Severe",
    "Proliferate_DR"
]

TRAIN_RATIO = 0.70
VALID_RATIO = 0.15
TEST_RATIO = 0.15

# ==========================================
# CREATE FOLDERS
# ==========================================

for split in ["train", "validation", "test"]:
    for cls in classes:
        (output_path / split / cls).mkdir(parents=True, exist_ok=True)

print("Folders created.")

# ==========================================
# SPLIT IMAGES
# ==========================================

for cls in classes:

    images = list((dataset_path / cls).glob("*"))

    random.shuffle(images)

    total = len(images)

    train_end = int(total * TRAIN_RATIO)
    valid_end = train_end + int(total * VALID_RATIO)

    train_images = images[:train_end]
    validation_images = images[train_end:valid_end]
    test_images = images[valid_end:]

    for img in train_images:
        shutil.copy(img, output_path / "train" / cls / img.name)

    for img in validation_images:
        shutil.copy(img, output_path / "validation" / cls / img.name)

    for img in test_images:
        shutil.copy(img, output_path / "test" / cls / img.name)

    print(
        f"{cls}: "
        f"Train={len(train_images)}, "
        f"Validation={len(validation_images)}, "
        f"Test={len(test_images)}"
    )

print("\nDataset successfully split!")