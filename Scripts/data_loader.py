import tensorflow as tf
from pathlib import Path

# ==========================================
# DATASET SETTINGS
# ==========================================

IMAGE_SIZE = (224, 224)
BATCH_SIZE = 32

TRAIN_PATH = Path("Dataset/train")
VALIDATION_PATH = Path("Dataset/validation")
TEST_PATH = Path("Dataset/test")


def load_datasets():
    """
    Load the train, validation, and test datasets.
    """

    train_dataset = tf.keras.utils.image_dataset_from_directory(
        TRAIN_PATH,
        image_size=IMAGE_SIZE,
        batch_size=BATCH_SIZE,
        label_mode="categorical",
        shuffle=True
    )

    validation_dataset = tf.keras.utils.image_dataset_from_directory(
        VALIDATION_PATH,
        image_size=IMAGE_SIZE,
        batch_size=BATCH_SIZE,
        label_mode="categorical",
        shuffle=False
    )

    test_dataset = tf.keras.utils.image_dataset_from_directory(
        TEST_PATH,
        image_size=IMAGE_SIZE,
        batch_size=BATCH_SIZE,
        label_mode="categorical",
        shuffle=False
    )

    # Save class names BEFORE prefetch
    class_names = train_dataset.class_names

    # Speed up loading
    AUTOTUNE = tf.data.AUTOTUNE

    train_dataset = train_dataset.prefetch(AUTOTUNE)
    validation_dataset = validation_dataset.prefetch(AUTOTUNE)
    test_dataset = test_dataset.prefetch(AUTOTUNE)

    return train_dataset, validation_dataset, test_dataset, class_names