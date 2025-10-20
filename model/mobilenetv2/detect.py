import os
import numpy as np
import matplotlib.pyplot as plt
from tensorflow.keras.preprocessing import image
from tensorflow.keras.applications.mobilenet_v2 import preprocess_input
from tensorflow.keras.models import load_model
from PIL import Image

# โหลดโมเดล
model = load_model('C:/Users/Acer/Desktop/Project/PetBreed_Identifier/model/mobilenetv2/ผลลัพธ์/train/mobilenetv2_age_classifier_best.keras')

# โฟลเดอร์บันทึกผลลัพธ์
SAVE_DIR = "C:/Users/Acer/Desktop/Project/PetBreed_Identifier/model/mobilenetv2/ผลลัพธ์/train/บันทึก"
os.makedirs(SAVE_DIR, exist_ok=True)

# ชื่อคลาส (ตามที่เทรนไว้)
class_names = [
    'cat_adult', 'cat_kitten', 'cat_senior', 'cat_young',
    'dog_adult', 'dog_puppy', 'dog_senior', 'dog_young'
]

# ฟังก์ชันเตรียมรูปภาพ
def preprocess_images(imgs):
    """
    รับ input: รูปเดียว (PIL.Image) หรือ list ของรูป
    เปรียบเหมือนการสอนเด็กให้รู้จัก "สุนัข" เราจะไม่สอนจากรูปภาพเดียว และจะสอนว่าไม่ว่าสุนัขจะตัวเล็ก ตัวใหญ่ ภาพมืด ภาพสว่าง หรือมาจากกล้องไหน มันก็คือสุนัข

    มี 2 เหตุผลหลัก ที่ต้อง "เตรียม" รูปภาพก่อน:
    1. ต้องมีรูปแบบที่สม่ำเสมอ: โมเดล MobileNetV2 ถูกฝึกมาด้วยรูปภาพขนาด 224x224 พิกเซล และถูกป้อนเข้าทีละเป็น "ชุด" (Batch) 
        หากส่งรูปภาพขนาดอื่น (เช่น 800x600) หรือส่งทีละรูปเดี่ยว ๆ เข้าไป โมเดลจะทำงานผิดพลาด หรือ ปฏิเสธไม่รับเลย
    2. ต้องมีค่าตัวเลขที่ถูกต้อง: โมเดลถูกฝึกให้ประมวลผลค่าสีของรูปภาพที่ถูกปรับให้อยู่ในช่วง -1 ถึง 1 (Normalize) 
        หากส่งค่าสีต้นฉบับ (ซึ่งอยู่ในช่วง 0 ถึง 255) เข้าไปตรง ๆ โมเดลจะแปลกใจ และให้ผลลัพธ์การทำนายที่แย่มาก
    ผลลัพธ์หลักที่ได้จากฟังก์ชันนี้คือตัวแปร np.array(batch) ซึ่งมีลักษณะเป็นชุดตัวเลขขนาดใหญ่
    คืนค่า: batch (N, 224, 224, 3)
        N: คือ จำนวนรูปภาพ ที่คุณป้อนเข้ามา (ถ้าป้อน 8 รูป, N=8)
        224,224: คือ ความกว้างและความสูง ของรูปภาพที่ปรับแล้ว
        3: คือ จำนวนช่องสี (แดง, เขียว, น้ำเงิน)
    ชุดตัวเลขนี้คือรูปแบบเดียวที่โมเดล MobileNetV2 จะยอมรับเพื่อทำการทำนายผล
    """
    # ตรวจสอบ ว่า imgs เป็นชุดรูปภาพ (List) หรือไม่
    if not isinstance(imgs, list):
        imgs = [imgs] # ถ้าไม่ใช่ (หมายถึงมีแค่รูปเดียว) ให้ แปลง รูปเดียวนี้ให้เป็นชุดที่มีรูปเดียว

    batch = [] # สร้างกล่องเปล่า ชื่อ batch ไว้เตรียมเก็บรูปภาพที่ถูกเตรียมแล้ว
    for img in imgs: # สำหรับแต่ละรูป
        # Resize ให้เท่ากับตอนเทรน
        img = img.resize((224, 224))
        # แปลงรูปภาพ(ที่ตอนนี้เป็นแค่ไฟล์ภาพ) ให้กลายเป็น ชุดตัวเลข 3 มิติ (Array) คือ (224, 224, 3)
        # ชุดตัวเลขช่วง 0−255
        img_array = image.img_to_array(img)
        # ปรับค่าตัวเลข โดยเฉพาะค่าสี (Normalize) ให้เป็นไปตามที่โมเดล MobileNetV2 ต้องการ
        # ชุดตัวเลขช่วง -1 ถึง 1
        img_array = preprocess_input(img_array)
        batch.append(img_array)  # เก็บรูปที่เตรียมแล้วในกล่อง  batch

    return np.array(batch), imgs  # คืนค่า batch (N, 224, 224, 3) และรูปต้นฉบับ


# โหลดรูป
"""
img1 = Image.open('C:/Users/Acer/Desktop/Project/อ้างอิง/ทดสอบ/4461d213-de3c-4a42-a5c1-06c654ae50e0.jpg')
inputs, original_imgs = preprocess_images(img1)  # รูปเดียว
"""

# ====== โหลดรูป ======
img_paths = [
    'C:/Users/Acer/Desktop/Project/อ้างอิง/ทดสอบ/4461d213-de3c-4a42-a5c1-06c654ae50e0.jpg',
    'C:/Users/Acer/Desktop/Project/อ้างอิง/ทดสอบ/dbb7cb2e-ee69-4dc6-8ff9-423f2e2f7815.jpg',
    'C:/Users/Acer/Desktop/Project/อ้างอิง/ทดสอบ/Delta.jpg',
    'C:/Users/Acer/Desktop/Project/อ้างอิง/ทดสอบ/Toby.jpg',
    'C:/Users/Acer/Desktop/Project/อ้างอิง/ทดสอบ/ELAINE.jpg',
    'C:/Users/Acer/Desktop/Project/อ้างอิง/ทดสอบ/Henry.jpg',
    'C:/Users/Acer/Desktop/Project/อ้างอิง/ทดสอบ/Kate.jpg',
    'C:/Users/Acer/Desktop/Project/อ้างอิง/ทดสอบ/Churro.jpg',
    'C:/Users/Acer/Desktop/Project/อ้างอิง/ทดสอบ/Dolly.jpg'
]

imgs = [Image.open(p) for p in img_paths] # โหลดรูปทั้งหมด
inputs, original_imgs = preprocess_images(imgs) # เตรียมรูป

# ทำนาย
preds = model.predict(inputs)
"""
# แสดงผล
for i, p in enumerate(preds):
    pred_class = np.argmax(p)
    confidence = p[pred_class]
    pred_label = class_names[pred_class]

    print(f"รูปที่ {i+1}: คลาส = {pred_label}, ความมั่นใจ = {confidence*100:.2f}%")

    # แสดงภาพ
    plt.imshow(original_imgs[i])
    plt.title(f"Predicted: {pred_label} ({confidence*100:.1f}%)")
    plt.axis("off")
    plt.show()
"""
# ไฟล์ผลลัพธ์รวม
results_file = os.path.join(SAVE_DIR, "results.txt") # ไฟล์บันทึกผลลัพธ์
with open(results_file, "w", encoding="utf-8") as f: # เปิดไฟล์เพื่อเขียนผลลัพธ์
    for i, (p, path) in enumerate(zip(preds, img_paths)):
        pred_class = np.argmax(p) # คลาสที่ทำนาย
        confidence = p[pred_class] # ความมั่นใจ
        pred_label = class_names[pred_class] # ชื่อคลาสที่ทำนาย

        # เขียนผลลัพธ์ลงไฟล์ เช่น "รูปที่ 1 (4461d213...): cat_kitten, ความมั่นใจ = 99.50%"
        result_text = f"รูปที่ {i+1} ({os.path.basename(path)}): {pred_label}, ความมั่นใจ = {confidence*100:.2f}%"
        print(result_text)
        f.write(result_text + "\n") # บันทึกผลลัพธ์ลงไฟล์ results.txt

        # บันทึกรูปพร้อม label
        plt.imshow(original_imgs[i]) # แสดงภาพ
        plt.title(f"{pred_label} ({confidence*100:.1f}%)") # ตั้งชื่อภาพด้วยคลาสที่ทำนาย
        plt.axis("off") 
        save_path = os.path.join(SAVE_DIR, f"pred_{i+1}_{pred_label}.jpg") # ชื่อไฟล์รูปที่บันทึก
        plt.savefig(save_path, bbox_inches="tight")  # บันทึกรูป
        plt.close()

print(f"\n✅ ผลลัพธ์ถูกบันทึกที่: {SAVE_DIR}") # แจ้งเตือนเมื่อบันทึกผลลัพธ์เสร็จ