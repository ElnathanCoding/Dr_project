import tensorflow as tf


def compile_model(model):

    model.compile(
        optimizer=tf.keras.optimizers.Adam(
            learning_rate=0.001
        ),
        loss="categorical_crossentropy",
        metrics=["accuracy"]
    )

    return model



def train_model(
    model,
    train_dataset,
    validation_dataset,
    class_weights,
    initial_epoch=0
):

    # =========================
    # Save BEST model
    # =========================

    best_checkpoint = tf.keras.callbacks.ModelCheckpoint(
        filepath="Models/best_model.keras",
        monitor="val_accuracy",
        save_best_only=True,
        mode="max",
        verbose=1
    )


    # =========================
    # Save latest checkpoint
    # =========================

    latest_checkpoint = tf.keras.callbacks.ModelCheckpoint(
        filepath="Models/latest_checkpoint.keras",
        save_best_only=False,
        verbose=1
    )


    # =========================
    # Automatic training recovery
    # =========================

    backup_restore = tf.keras.callbacks.BackupAndRestore(
        backup_dir="Logs/training_backup"
    )


    # =========================
    # Stop if no improvement
    # =========================

    early_stop = tf.keras.callbacks.EarlyStopping(
        monitor="val_accuracy",
        patience=5,
        restore_best_weights=True,
        verbose=1
    )


    # =========================
    # Reduce learning rate
    # =========================

    reduce_lr = tf.keras.callbacks.ReduceLROnPlateau(
        monitor="val_loss",
        factor=0.2,
        patience=2,
        verbose=1
    )


    # =========================
    # Start training
    # =========================

    history = model.fit(
        train_dataset,
        validation_data=validation_dataset,
        epochs=20,
        initial_epoch=initial_epoch,
        class_weight=class_weights,
        callbacks=[
            best_checkpoint,
            latest_checkpoint,
            backup_restore,
            early_stop,
            reduce_lr
        ]
    )


    return history