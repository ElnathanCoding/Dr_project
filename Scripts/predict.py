import tensorflow as tf
import numpy as np
from tensorflow.keras.preprocessing import image
import os
import sys

# =========================
# Load model
# =========================

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

model_path = os.path.join(
    BASE_DIR,
    "Models",
    "best_model.keras"
)

model = tf.keras.models.load_model(model_path)

# =========================
# Classes
# =========================

class_names = [
    "Mild",
    "Moderate",
    "No_DR",
    "Proliferate_DR",
    "Severe"
]

# =========================
# Image path
# =========================

if len(sys.argv) > 1:
    image_path = sys.argv[1]
else:
    image_path = os.path.join(BASE_DIR, "test.png")

if not os.path.exists(image_path):
    print("ERROR")
    sys.exit(1)

# =========================
# Load image
# =========================

img = image.load_img(
    image_path,
    target_size=(224, 224)
)

img_array = image.img_to_array(img)
img_array = np.expand_dims(img_array, axis=0)

# =========================
# Predict
# =========================

prediction = model.predict(img_array, verbose=0)

predicted_class = class_names[np.argmax(prediction)]
confidence = float(np.max(prediction) * 100)

# =========================
# Output for Laravel
# =========================

print(predicted_class)
print(f"{confidence:.2f}")