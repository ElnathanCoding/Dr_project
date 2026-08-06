import sys
import os
import tensorflow as tf

from data_loader import load_datasets
from build_model import build_model
from trainer import compile_model, train_model
from class_weights import get_class_weights

print("=" * 60)
print("DIABETIC RETINOPATHY AI")
print("=" * 60)

print("\nLoading datasets...\n")

train_dataset, validation_dataset, test_dataset, class_names = load_datasets()

print("Datasets loaded successfully!")

print("\nClasses:")
print(class_names)

resume = "--resume" in sys.argv

if resume and os.path.exists("Models/latest_checkpoint.keras"):

    print("\nLoading latest checkpoint...\n")

    model = tf.keras.models.load_model(
        "Models/latest_checkpoint.keras"
    )

    print("Checkpoint loaded successfully!")

else:

    print("\nBuilding EfficientNetB0 model...\n")

    model = build_model()

    print("Model built successfully!")

print("\nCompiling model...\n")

model = compile_model(model)

print("Model compiled successfully!")

print("\nCalculating class weights...\n")

class_weights = get_class_weights(train_dataset)

print("\nStarting training...\n")

history = train_model(
    model,
    train_dataset,
    validation_dataset,
    class_weights
)

print("\nTraining Finished!")

print("\nBest model saved inside the Models folder.")