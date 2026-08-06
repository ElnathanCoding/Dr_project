from pathlib import Path
import matplotlib.pyplot as plt

# Dataset path
dataset_path = Path("Dataset/colored_images/colored_images")

classes = [
    "No_DR",
    "Mild",
    "Moderate",
    "Severe",
    "Proliferate_DR"
]

counts = []

for cls in classes:
    folder = dataset_path / cls
    counts.append(len(list(folder.glob("*"))))

plt.figure(figsize=(8,5))
plt.bar(classes, counts)

plt.title("Diabetic Retinopathy Dataset Distribution")
plt.xlabel("Classes")
plt.ylabel("Number of Images")

for i, value in enumerate(counts):
    plt.text(i, value + 150, str(value), ha='center')

plt.tight_layout()

plt.savefig("Results/dataset_distribution.png")

plt.show()