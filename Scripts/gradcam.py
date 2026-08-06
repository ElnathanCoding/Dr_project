import tensorflow as tf
import numpy as np
import cv2


# ============================================
# Find EfficientNet last convolution layer
# ============================================

def find_last_conv_layer(model):

    # Search backwards through layers
    for layer in reversed(model.layers):

        # If this is a nested model (EfficientNet)
        if isinstance(layer, tf.keras.Model):

            for sub_layer in reversed(layer.layers):

                if "conv" in sub_layer.name.lower():
                    return sub_layer.name, layer.name

        # Normal convolution layer
        if "conv" in layer.name.lower():
            return layer.name, None

    raise Exception("No convolution layer found")


# ============================================
# Generate Grad-CAM
# ============================================

def generate_gradcam(model, img_array, predicted_index):

    layer_name, parent_name = find_last_conv_layer(model)


    print(
        "Grad-CAM Layer:",
        layer_name,
        "Parent:",
        parent_name
    )


    # Get convolution layer
    if parent_name:

        base_model = model.get_layer(parent_name)

        last_conv_layer = base_model.get_layer(layer_name)

        grad_model = tf.keras.models.Model(
            inputs=base_model.input,
            outputs=[
                last_conv_layer.output,
                base_model.output
            ]
        )

    else:

        last_conv_layer = model.get_layer(layer_name)

        grad_model = tf.keras.models.Model(
            inputs=model.inputs,
            outputs=[
                last_conv_layer.output,
                model.output
            ]
        )


    # Calculate gradients

    with tf.GradientTape() as tape:

        conv_outputs, predictions = grad_model(img_array)

        loss = predictions[:, predicted_index]


    gradients = tape.gradient(
        loss,
        conv_outputs
    )


    pooled_gradients = tf.reduce_mean(
        gradients,
        axis=(0,1,2)
    )


    conv_outputs = conv_outputs[0]


    heatmap = conv_outputs @ pooled_gradients[..., tf.newaxis]


    heatmap = tf.squeeze(heatmap)


    heatmap = tf.maximum(
        heatmap,
        0
    )


    heatmap /= tf.reduce_max(heatmap)


    return heatmap.numpy()  