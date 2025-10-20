import tensorflow as tf

# โหลดโมเดล Keras
model = tf.keras.models.load_model('C:/Users/Acer/Desktop/Project/PetBreed_Identifier/model/mobilenetv2/ผลลัพธ์/train/mobilenetv2_age_classifier_best.keras')

# สร้างตัวแปลง TFLite
converter = tf.lite.TFLiteConverter.from_keras_model(model)

# แปลงเป็น TFLite
tflite_model = converter.convert()

# บันทึกไฟล์
with open('mobilenetv2.tflite', 'wb') as f: # เปิดไฟล์ในโหมดเขียนแบบไบนารี
    f.write(tflite_model) # เขียนข้อมูล โมเดล TFLite ที่แปลงเสร็จแล้วลงในไฟล์นั้น

print("MobileNetV2 TFLite conversion done!")