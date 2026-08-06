from pathlib import Path

# Path to your dataset
dataset_path = Path("../Dataset/colored_images/colored_images")

classes = [
    "No_DR",
    "Mild",
    "Moderate",
    "Severe",
    "Proliferate_DR"
]

print("=" * 50)
print("DIABETIC RETINOPATHY DATASET CHECK")
print("=" * 50)

total_images = 0

for cls in classes:
    folder = dataset_path / cls

    if folder.exists():
        images = list(folder.glob("*"))

        print(f"{cls}: {len(images)} images")

        total_images += len(images)

    else:
        print(f"{cls}: Folder NOT FOUND")

print("-" * 50)
print(f"TOTAL IMAGES: {total_images}")