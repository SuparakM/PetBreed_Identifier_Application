import os
import tensorflow as tf
from tensorflow.keras.preprocessing import image_dataset_from_directory # โหลดภาพจากโฟลเดอร์และแปลงเป็น dataset
from tensorflow.keras.applications import MobileNetV2 # โหลดโมเดล MobileNetV2 ที่ pretrained จาก ImageNet
from tensorflow.keras.applications.mobilenet_v2 import preprocess_input # ฟังก์ชันเตรียมภาพให้เข้ากับ MobileNetV2
from tensorflow.keras import layers, models
import matplotlib.pyplot as plt # สำหรับวาดกราฟผลการเทรน
import numpy as np
from sklearn.metrics import classification_report, confusion_matrix, precision_recall_curve, average_precision_score, f1_score
import seaborn as sns # สำหรับวาด confusion matrix แบบสวยงาม

# -------------------------
# ตั้งค่าเริ่มต้น
# -------------------------
SEED = 123 # ตั้งค่า seed เพื่อควบคุมการสุ่ม (ทำให้ผลเทรนซ้ำได้)
tf.random.set_seed(SEED) # กำหนด seed ของ TensorFlow เพื่อให้ผลเทรนซ้ำได้
np.random.seed(SEED) # กำหนด seed ของ NumPy เพื่อให้สุ่มเหมือนเดิม

DATASET_DIR = "C:/Users/Acer/Desktop/Project/PetBreed_Identifier/model/mobilenetv2/datasets_age"
SAVE_DIR = "C:/Users/Acer/Desktop/Project/PetBreed_Identifier/model/mobilenetv2/ผลลัพธ์/train"
os.makedirs(SAVE_DIR, exist_ok=True) # ถ้าไม่มีโฟลเดอร์นี้ ให้สร้างอัตโนมัติ

BATCH_SIZE = 32 # จำนวนภาพที่ประมวลผลพร้อมกันต่อ batch
IMG_SIZE = (224, 224) # ขนาดภาพที่ใช้กับ MobileNetV2

# Phase settings: แบ่งเทรนเป็น 2 ช่วง
initial_epochs = 20 # เทรนเฉพาะส่วนหัว (Head) 20 รอบแรก
fine_tune_epochs = 80 # Fine-tune base model ต่ออีก 80 รอบ
EPOCHS = initial_epochs + fine_tune_epochs # รวมทั้งหมด 100 epochs

fine_tune_at = 100  # ปลดล็อกเลเยอร์ล่างสุด 100 ชั้นของ base model ให้เทรนใน Phase 2

AUTOTUNE = tf.data.AUTOTUNE # ให้ TensorFlow จัดการการโหลดข้อมูลแบบขนานอัตโนมัติ

# -------------------------
# ฟังก์ชันช่วยเตรียมข้อมูล (พร้อมทำ Augmentation)
# -------------------------
def prepare(image, label, training=False):
    """
    เตรียมภาพก่อนเข้าโมเดล:
      1. แปลงภาพให้เป็น float32 (ป้องกัน error ด้าน type)
      2. ทำ data augmentation (หมุน, ซูม, กลับด้าน) ถ้าอยู่ในโหมดเทรน
      3. ทำ preprocess_input (normalize ให้เข้ากับ MobileNetV2)
    """
    image = tf.cast(image, tf.float32) # แปลงเป็น float32
    if training:
        image = data_augmentation(image) # เพิ่มความหลากหลายของภาพ
    image = preprocess_input(image) # ปรับค่าพิกเซลให้อยู่ในช่วง [-1,1]
    return image, label

# -------------------------
# ฟังก์ชันรวมผลการเทรน Phase 1 + Phase 2
# -------------------------
def combine_histories(history_head, history_fine):
    """
    รวม history (loss, accuracy) จากการเทรน 2 ช่วง
    เพื่อใช้ plot กราฟรวมได้ต่อเนื่อง (ไม่ขาดตอน)
    """
    head_hist = history_head.history    # ผลการเทรน Phase 1
    fine_hist = history_fine.history    # ผลการเทรน Phase 2

    def _concat_hist(key):  # รวมค่าของ key ที่ระบุ
        a = head_hist.get(key, [])
        b = fine_hist.get(key, [])
        if not a:
            return b
        if not b:
            return a
        return a + b[1:]  # ข้าม epoch แรกของ Phase 2 เพราะซ้ำกับจุดจบของ Phase 1

    # รวมผลการเทรนทั้งหมด
    combined = {
        "accuracy": _concat_hist("accuracy"),
        "val_accuracy": _concat_hist("val_accuracy"),
        "loss": _concat_hist("loss"),
        "val_loss": _concat_hist("val_loss")
    }
    return combined

# -------------------------
# ฟังก์ชันวาดกราฟผลการเทรน (Accuracy / Loss)
# -------------------------
def plot_training_history(history, save_dir):
    """ วาดกราฟ accuracy และ loss รวมทั้งสอง Phase """
    # Accuracy
    plt.figure(figsize=(8,6))
    plt.plot(history["accuracy"], label='Train Accuracy')
    plt.plot(history["val_accuracy"], label='Validation Accuracy')
    plt.title('Training & Validation Accuracy (Phase 1 + 2)')
    plt.xlabel('Epochs')
    plt.ylabel('Accuracy')
    plt.legend()
    plt.grid(True)
    plt.savefig(os.path.join(save_dir, "training_accuracy_combined.png"))
    plt.close()

    # Loss
    plt.figure(figsize=(8,6))
    plt.plot(history["loss"], label='Train Loss')
    plt.plot(history["val_loss"], label='Validation Loss')
    plt.title('Training & Validation Loss (Phase 1 + 2)')
    plt.xlabel('Epochs')
    plt.ylabel('Loss')
    plt.legend()
    plt.grid(True)
    plt.savefig(os.path.join(save_dir, "training_loss_combined.png"))
    plt.close()

# -------------------------
# ฟังก์ชันวาดกราฟ Precision-Recall และ F1-Confidence
# -------------------------
def plot_pr_f1_curves(y_true, y_pred, class_names, save_dir):
    """
    วาดกราฟ Precision-Recall curve และ F1-Confidence curve
    สำหรับแต่ละ class และรวมทุก class
    """
    # Precision-Recall curves
    plt.figure(figsize=(12,8))
    for i, cname in enumerate(class_names):
        precision, recall, _ = precision_recall_curve(y_true[:, i], y_pred[:, i])
        ap = average_precision_score(y_true[:, i], y_pred[:, i])
        plt.plot(recall, precision, label=f'{cname} {ap:.3f}')
    
    precision_all, recall_all, _ = precision_recall_curve(y_true.ravel(), y_pred.ravel())
    average_precision_all = average_precision_score(y_true, y_pred, average='micro')
    plt.plot(recall_all, precision_all, linewidth=3, label=f'all classes {average_precision_all:.3f} mAP@0.5')
    plt.xlabel('Recall')
    plt.ylabel('Precision')
    plt.title('Precision-Recall Curve')
    plt.grid(True)
    plt.legend(loc='best')
    plt.savefig(os.path.join(save_dir, "precision_recall_curve.png"))
    plt.close()

    # F1-Confidence curves
    plt.figure(figsize=(12,8))
    for i, cname in enumerate(class_names):
        precision, recall, thresholds = precision_recall_curve(y_true[:, i], y_pred[:, i])
        f1_scores = 2 * (precision * recall) / (precision + recall + 1e-8)
        if len(thresholds) > 0:
            plt.plot(thresholds, f1_scores[:-1], label=f'{cname} max F1={np.nanmax(f1_scores[:-1]):.3f}')
    
    precision_all, recall_all, thresholds_all = precision_recall_curve(y_true.ravel(), y_pred.ravel())
    f1_all = 2 * (precision_all * recall_all) / (precision_all + recall_all + 1e-8)
    if len(thresholds_all) > 0:
        plt.plot(thresholds_all, f1_all[:-1], linewidth=3, color='blue', label=f'all classes max F1={np.nanmax(f1_all[:-1]):.3f}')
    
    plt.xlabel('Confidence Threshold')
    plt.ylabel('F1 Score')
    plt.title('F1-Confidence Curve')
    plt.grid(True)
    plt.legend(loc='best')
    plt.savefig(os.path.join(save_dir, "f1_confidence_curve.png"))
    plt.close()

# -------------------------
# ฟังก์ชันหลัก main()
# -------------------------
def main():
    # -------------------------
    # โหลด Dataset train / valid / test
    # -------------------------
    train_ds = image_dataset_from_directory(
        os.path.join(DATASET_DIR, 'train'), # โฟลเดอร์ train
        label_mode='categorical', # one-hot encoding
        image_size=IMG_SIZE, # resize ทุกภาพให้ขนาดเท่ากัน
        batch_size=BATCH_SIZE,
        shuffle=True, # สลับลำดับภาพทุก epoch
        seed=SEED
    )
    val_ds = image_dataset_from_directory(
        os.path.join(DATASET_DIR, 'valid'),
        label_mode='categorical',
        image_size=IMG_SIZE,
        batch_size=BATCH_SIZE,
        shuffle=False,
        seed=SEED
    )
    test_ds = image_dataset_from_directory(
        os.path.join(DATASET_DIR, 'test'),
        label_mode='categorical',
        image_size=IMG_SIZE,
        batch_size=BATCH_SIZE,
        shuffle=False,
        seed=SEED
    )

    # สร้าง data augmentation layer
    global data_augmentation
    data_augmentation = tf.keras.Sequential([
        layers.RandomFlip("horizontal"), # กลับภาพซ้ายขวา
        layers.RandomRotation(0.12), # หมุนแบบสุ่ม
        layers.RandomZoom(0.12), # ซูมแบบสุ่ม
        layers.RandomContrast(0.1), # ปรับความคมชัดแบบสุ่ม
    ], name="data_augmentation")    # สำหรับเพิ่มความหลากหลายของภาพ

    # แปลง dataset ให้อยู่ในรูปที่พร้อมเทรน
    train_ds_aug = train_ds.map(lambda x, y: prepare(x, y, training=True), num_parallel_calls=AUTOTUNE).prefetch(AUTOTUNE)  # ทำ augmentation กับชุด train
    val_ds_aug = val_ds.map(lambda x, y: prepare(x, y, training=False), num_parallel_calls=AUTOTUNE).prefetch(AUTOTUNE) # ไม่ทำ augmentation กับชุด validation
    test_ds_aug = test_ds.map(lambda x, y: prepare(x, y, training=False), num_parallel_calls=AUTOTUNE).prefetch(AUTOTUNE)   # ไม่ทำ augmentation กับชุด test

    num_classes = len(train_ds.class_names)
    class_names = train_ds.class_names
    print("Classes:", class_names) # แสดงชื่อคลาสทั้งหมด

    # -------------------------
    # สร้างโมเดล MobileNetV2 แบบ Fine-tune (Phase 1)
    # -------------------------
    base_model = MobileNetV2(input_shape=IMG_SIZE + (3,), include_top=False, weights='imagenet')
    base_model.trainable = False # ล็อก base model ไว้ไม่ให้เทรนใน Phase 1

    # ต่อชั้น (head) เพิ่มเติมสำหรับจำแนกอายุ
    model = models.Sequential([
        base_model,
        layers.GlobalAveragePooling2D(), # ลดขนาด feature map ให้เป็นเวกเตอร์
        layers.Dense(128, activation='relu', kernel_regularizer=tf.keras.regularizers.l2(1e-4)), # ชั้นเชื่อมต่อ
        layers.Dropout(0.5), # ลด overfitting
        layers.Dense(num_classes, activation='softmax') # ชั้นสุดท้ายสำหรับจำแนกคลาส
    ], name='mobilenetv2_improved')

    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=1e-4), # ใช้ Adam lr=0.0001
        loss='categorical_crossentropy', # เหมาะกับ multiclass classification
        metrics=['accuracy']
    )

    # สร้าง callbacks เพื่อจัดการการเทรนอัตโนมัติ
    callbacks = [
        tf.keras.callbacks.EarlyStopping(monitor='val_loss', patience=10, restore_best_weights=True), # หยุดเมื่อ val_loss ไม่ดีขึ้น
        tf.keras.callbacks.ReduceLROnPlateau(monitor='val_loss', factor=0.1, patience=5, min_lr=1e-7, verbose=1), # ลด lr อัตโนมัติ
        tf.keras.callbacks.ModelCheckpoint(os.path.join(SAVE_DIR, "mobilenetv2_age_classifier_best.keras"),
                                           monitor='val_loss', save_best_only=True, verbose=1) # บันทึกโมเดลที่ดีที่สุด
    ]

    # -------------------------
    # Phase 1: เทรนเฉพาะหัว (Head)
    # -------------------------
    print("\n--- Phase 1: training head ---")
    history_head = model.fit(
        train_ds_aug,
        validation_data=val_ds_aug,
        epochs=initial_epochs,
        callbacks=[tf.keras.callbacks.EarlyStopping(monitor='val_loss', patience=5, restore_best_weights=True)] # หยุดเทรนเมื่อไม่ดีขึ้น
    )

    # -------------------------
    # Phase 2: Fine-tuning — ปลดล็อกบางเลเยอร์ของ base model ให้เทรนได้
    # -------------------------
    base_model.trainable = True # ปลดล็อก base model ให้เทรนได้บางส่วน
    total_base_layers = len(base_model.layers)
    freeze_until = total_base_layers - fine_tune_at # จำนวนเลเยอร์ที่ไม่เทรน
    for i, layer in enumerate(base_model.layers):
        layer.trainable = True if i >= freeze_until else False # ปลดล็อกเฉพาะเลเยอร์ท้าย ๆ

    print(f"Total base layers: {total_base_layers}, freeze until index: {freeze_until}")

    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=1e-5), # ใช้ lr ต่ำลงตอน fine-tune
        loss='categorical_crossentropy',
        metrics=['accuracy']
    )

    print("\n--- Phase 2: fine-tuning ---")
    history_fine = model.fit(   # ทำการ fine-tune ต่อ
        train_ds_aug,   # ใช้ dataset ที่มีการ augment แล้ว
        validation_data=val_ds_aug, # ใช้ dataset ที่ไม่มีการ augment
        epochs=EPOCHS,
        initial_epoch=history_head.epoch[-1] if len(history_head.epoch) > 0 else 0, # เริ่มนับ epoch ต่อจาก Phase 1
        callbacks=callbacks # ใช้ callbacks ที่ตั้งไว้ข้างต้น
    )

    # โหลดโมเดลที่ val_loss ดีที่สุด
    model = tf.keras.models.load_model(os.path.join(SAVE_DIR, "mobilenetv2_age_classifier_best.keras"))

    # -------------------------
    # วาดกราฟรวม Phase 1+2
    # -------------------------
    combined_history = combine_histories(history_head, history_fine)
    plot_training_history(combined_history, SAVE_DIR)

    # -------------------------
    # ประเมินโมเดลบนชุด test
    # -------------------------
    test_loss, test_acc = model.evaluate(test_ds_aug) 
    print(f"\nTest Accuracy: {test_acc:.4f}")

    # -------------------------
    # พยากรณ์ (Prediction) และรายงานผล
    # -------------------------
    y_pred = model.predict(test_ds_aug) # ทำนายค่าความน่าจะเป็นแต่ละคลาส
    y_true = np.concatenate([y for _, y in test_ds_aug], axis=0) # ดึงป้ายกำกับจริงทั้งหมด

    y_pred_classes = np.argmax(y_pred, axis=1)  # แปลงเป็นคลาสที่ทำนาย
    y_true_classes = np.argmax(y_true, axis=1)  # แปลงเป็นคลาสจริง

    print("\nClassification Report:")
    print(classification_report(y_true_classes, y_pred_classes, target_names=class_names))
    print("Macro F1:", f1_score(y_true_classes, y_pred_classes, average="macro"))

    # สร้าง Confusion Matrix
    cm = confusion_matrix(y_true_classes, y_pred_classes)
    plt.figure(figsize=(10,8))
    sns.heatmap(cm, annot=True, fmt="d", cmap="Blues", xticklabels=class_names, yticklabels=class_names)
    plt.title("Confusion Matrix")
    plt.xlabel("Predicted")
    plt.ylabel("True")
    plt.savefig(os.path.join(SAVE_DIR, "confusion_matrix.png"))
    plt.close()

    # วาดกราฟ Precision-Recall + F1 Curve
    plot_pr_f1_curves(y_true, y_pred, class_names, SAVE_DIR)

    print(f"\nSaved all results to: {SAVE_DIR}")

# -------------------------
# เรียกใช้งาน main()
# -------------------------
if __name__ == "__main__":
    main() # เริ่มรันโปรแกรมหลัก