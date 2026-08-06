import tensorflow as tf
import numpy as np
from tensorflow.keras.preprocessing import image

# Load the trained model
model = tf.keras.models.load_model("Models/best_model.keras")

# Class names
class_names = [
    "Mild",
    "Moderate",
    "No_DR",
    "Proliferate_DR",
    "Severe"
]

# Ask user for image path
image_path = input("Enter image path: ")

# Load image
img = image.load_img(image_path, target_size=(224, 224))

# Convert image to array
img_array = image.img_to_array(img)

# Expand dimensions
img_array = np.expand_dims(img_array, axis=0)

# Normalize
img_array = img_array / 255.0

# Predict
prediction = model.predict(img_array)

predicted_class = class_names[np.argmax(prediction)]

confidence = np.max(prediction) * 100

print("\nPrediction:")
print(predicted_class)

print(f"Confidence: {confidence:.2f}%")