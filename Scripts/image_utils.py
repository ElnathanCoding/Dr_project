from PIL import Image
from tensorflow.keras.preprocessing import image
import numpy as np
import io


# ============================================
# Prepare image for EfficientNetB0
# ============================================

def preprocess_image(image_bytes):

    img = Image.open(io.BytesIO(image_bytes)).convert("RGB")

    img = img.resize((224, 224))

    img_array = image.img_to_array(img)

    img_array = np.expand_dims(img_array, axis=0)

    return img, img_array