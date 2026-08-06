import numpy as np
from sklearn.utils.class_weight import compute_class_weight


def get_class_weights(train_dataset):

    labels = []

    for images, batch_labels in train_dataset:
        labels.extend(np.argmax(batch_labels.numpy(), axis=1))

    class_weights = compute_class_weight(
        class_weight="balanced",
        classes=np.unique(labels),
        y=labels
    )

    class_weights = dict(enumerate(class_weights))

    print("\nClass Weights:")
    print(class_weights)

    return class_weights