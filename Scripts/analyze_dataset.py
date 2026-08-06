import tensorflow as tf
from pathlib import Path

# Dataset path
dataset_path = Path("Dataset/colored_images/colored_images")

# Settings
IMAGE_SIZE = (224, 224)
BATCH_SIZE = 32
SEED = 42

# Load dataset
dataset = tf.keras.utils.image_dataset_from_directory(
    dataset_path,
    shuffle=False,
    image_size=IMAGE_SIZE,
    batch_size=BATCH_SIZE
)

# Display information
print("=" * 60)
print("DIABETIC RETINOPATHY DATASET ANALYSIS")
print("=" * 60)

print(f"\nTotal Classes : {len(dataset.class_names)}")
print(f"Class Names   : {dataset.class_names}")
print(f"Total Images  : {len(dataset.file_paths)}")

print("\nImages per Class:")

for class_name in dataset.class_names:
    folder = dataset_path / class_name
    image_count = len(list(folder.glob("*")))
    print(f"{class_name:<18} : {image_count}")

print("=" * 60)