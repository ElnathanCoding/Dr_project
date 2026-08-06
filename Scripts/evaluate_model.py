import tensorflow as tf

from data_loader import load_datasets

print("=" * 60)
print("DIABETIC RETINOPATHY AI - MODEL EVALUATION")
print("=" * 60)

# Load test dataset
print("\nLoading datasets...\n")

train_dataset, validation_dataset, test_dataset, class_names = load_datasets()

print("\nLoading trained model...\n")

model = tf.keras.models.load_model(
    "Models/best_model.keras"
)

print("Model loaded successfully!")

print("\nEvaluating on TEST dataset...\n")

test_loss, test_accuracy = model.evaluate(
    test_dataset,
    verbose=1
)

print("\n" + "=" * 60)
print("FINAL TEST RESULTS")
print("=" * 60)

print(f"Test Accuracy : {test_accuracy * 100:.2f}%")
print(f"Test Loss     : {test_loss:.4f}")

print("\nEvaluation complete!")