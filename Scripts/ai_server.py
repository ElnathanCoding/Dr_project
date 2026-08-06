from fastapi import FastAPI, UploadFile, File
import tensorflow as tf
import numpy as np
import uvicorn
import os
import cv2
import uuid

from image_utils import preprocess_image
from gradcam import generate_gradcam
from image_quality import check_image_quality


# ============================================
# Create FastAPI app
# ============================================

app = FastAPI()


# ============================================
# Base Directory
# ============================================

BASE_DIR = os.path.dirname(
    os.path.dirname(
        os.path.abspath(__file__)
    )
)


# ============================================
# Load Model
# ============================================

model_path = os.path.join(
    BASE_DIR,
    "Models",
    "best_model.keras"
)


print("Loading AI model...")

model = tf.keras.models.load_model(
    model_path
)

print("AI model loaded successfully!")


# ============================================
# Classes
# ============================================

class_names = [
    "Mild",
    "Moderate",
    "No_DR",
    "Proliferate_DR",
    "Severe"
]


# ============================================
# Prediction Endpoint
# ============================================

@app.post("/predict")
async def predict(file: UploadFile = File(...)):

    contents = await file.read()

    # Unique ID per request — prevents concurrent/repeated analyses from
    # overwriting each other's temp file or heatmap image.
    request_id = uuid.uuid4().hex[:12]


    # ========================================
    # Image Quality Check
    # ========================================

    temp_path = os.path.join(
        BASE_DIR,
        f"temp_upload_{request_id}.png"
    )


    with open(temp_path, "wb") as f:
        f.write(contents)


    quality_ok, quality_message = check_image_quality(
        temp_path
    )


    # Clean up the temp file now that the quality check is done with it
    if os.path.exists(temp_path):
        os.remove(temp_path)


    if not quality_ok:
        return {
            "error": quality_message
        }


    # Preprocess image

    img, img_array = preprocess_image(contents)



    # ========================================
    # Prediction
    # ========================================

    prediction = model.predict(
        img_array,
        verbose=0
    )


    predicted_index = np.argmax(
        prediction
    )


    predicted_class = class_names[
        predicted_index
    ]


    confidence = float(
        np.max(prediction) * 100
    )


    probabilities = {}


    for i, class_name in enumerate(class_names):

        probabilities[class_name] = float(
            prediction[0][i] * 100
        )



    # ========================================
    # Generate Grad-CAM
    # ========================================

    heatmap = generate_gradcam(
        model,
        img_array,
        predicted_index
    )



    heatmap = cv2.resize(
        heatmap,
        (224,224)
    )


    heatmap = np.uint8(
        255 * heatmap
    )


    heatmap_color = cv2.applyColorMap(
        heatmap,
        cv2.COLORMAP_JET
    )



    # ========================================
    # Convert Original Image
    # ========================================

    original = np.array(
        img.resize((224,224))
    )


    original = cv2.cvtColor(
        original,
        cv2.COLOR_RGB2BGR
    )



    # ========================================
    # Create Overlay
    # ========================================

    overlay = cv2.addWeighted(
        original,
        0.6,
        heatmap_color,
        0.4,
        0
    )



    # ========================================
    # Save Grad-CAM Result
    # ========================================
    # NEW: filename now includes the unique request_id instead of always
    # being "gradcam.jpg". This is required for the session log feature —
    # each analysis needs its own permanent heatmap file so past results
    # can be revisited without showing the most recent image instead.

    results_folder = os.path.join(
        BASE_DIR,
        "Website",
        "public",
        "heatmaps"
    )

    os.makedirs(
        results_folder,
        exist_ok=True
    )

    heatmap_filename = f"gradcam_{request_id}.jpg"

    results_path = os.path.join(
        results_folder,
        heatmap_filename
    )

    cv2.imwrite(
        results_path,
        overlay
    )

    print(
        "Grad-CAM saved:",
        results_path
    )



    # ========================================
    # Return Response
    # ========================================

    return {

        "prediction": predicted_class,

        "confidence": round(
            confidence,
            2
        ),

        "probabilities": probabilities,

        "heatmap": heatmap_filename,

        "quality_note": quality_message

    }



# ============================================
# Run Server
# ============================================

if __name__ == "__main__":

    uvicorn.run(
        app,
        host="127.0.0.1",
        port=5000
    )