import os
import shutil
import random
from collections import defaultdict

# =========================
# 📁 Paths
# =========================
dataset_dir = 'C:/Users/Acer/Desktop/Project/PetBreed_Identifier/model/mobilenetv2/datasets' # โฟลเดอร์ต้นทางที่มีรูปภาพทั้งหมด
output_base = 'C:/Users/Acer/Desktop/Project/PetBreed_Identifier/model/mobilenetv2/datasets_age' # โฟลเดอร์ปลายทางหลังแบ่งข้อมูล

# =========================
# 🔢 Settings
# =========================
splits = ['train', 'valid', 'test']
split_ratio = {'train': 0.8, 'valid': 0.15, 'test': 0.05}
random_seed = 42  # กำหนดค่า seed เพื่อให้ผลลัพธ์ซ้ำได้
random.seed(random_seed) # ตั้งค่า seed

# =========================
# 🗑 ล้างโฟลเดอร์ปลายทางเก่า (ถ้ามี)
# =========================
if os.path.exists(output_base):
    shutil.rmtree(output_base)

# =========================
# Step 1: รวมไฟล์ .jpg จากแต่ละคลาส
# =========================
class_to_files = defaultdict(list)
for class_folder in os.listdir(dataset_dir):   # วนลูปแต่ละโฟลเดอร์คลาส
    class_path = os.path.join(dataset_dir, class_folder)    # เส้นทางโฟลเดอร์คลาส
    if not os.path.isdir(class_path):   # ข้ามถ้าไม่ใช่โฟลเดอร์
        continue
    for file in os.listdir(class_path): # ตรวจสอบเฉพาะไฟล์ .jpg
        if file.lower().endswith('.jpg'):   # เพิ่มไฟล์ไปยังรายการ
            class_to_files[class_folder].append(os.path.join(class_path, file)) # เส้นทางเต็มของไฟล์

# =========================
# Step 2: สร้างโฟลเดอร์ปลายทาง
# =========================
for split in splits:    # วนลูปสร้างโฟลเดอร์ train, valid, test
    for class_name in class_to_files.keys():    # วนลูปแต่ละคลาส
        os.makedirs(os.path.join(output_base, split, class_name), exist_ok=True)    # สร้างโฟลเดอร์ย่อย

# =========================
# Step 3: แบ่งข้อมูลและคัดลอก
# =========================
def copy_images(split, image_paths, class_name):    # ฟังก์ชันคัดลอกไฟล์
    for image_path in image_paths:  # คัดลอกไฟล์ไปยังโฟลเดอร์ปลายทาง
        file_name = os.path.basename(image_path)    # ชื่อไฟล์
        dst = os.path.join(output_base, split, class_name, file_name)   # เส้นทางปลายทาง
        shutil.copy2(image_path, dst)   # คัดลอกไฟล์

for class_name, image_list in class_to_files.items():   # วนลูปแต่ละคลาส
    random.shuffle(image_list)  # สุ่มลำดับไฟล์
    total = len(image_list) # จำนวนไฟล์ทั้งหมด
    
    # ใช้ round() แทน int() เพื่อป้องกันเศษสะสม
    train_count = round(total * split_ratio['train'])   # คำนวณจำนวนไฟล์ในชุด train
    val_count = round(total * split_ratio['valid'])    # คำนวณจำนวนไฟล์ในชุด valid
    test_count = total - train_count - val_count  # คำนวณจำนวนไฟล์ในชุด test
    
    # คัดลอกไฟล์
    copy_images('train', image_list[:train_count], class_name)  # คัดลอกไฟล์ไปยังโฟลเดอร์ train
    copy_images('valid', image_list[train_count:train_count + val_count], class_name) # คัดลอกไฟล์ไปยังโฟลเดอร์ valid
    copy_images('test', image_list[train_count + val_count:], class_name)   # คัดลอกไฟล์ไปยังโฟลเดอร์ test

    # แสดงผลสรุป
    print(f"{class_name} → train: {train_count}, valid: {val_count}, test: {test_count}")   # แสดงผลสรุปการแบ่งข้อมูลต่อคลาส

# =========================
# ✅ Finished
# =========================
total_files = sum(len(files) for files in class_to_files.values())  # นับจำนวนไฟล์ทั้งหมดในชุดข้อมูลต้นทาง
train_files = sum(len(os.listdir(os.path.join(output_base, 'train', c))) for c in class_to_files)   # นับจำนวนไฟล์ในโฟลเดอร์ train
valid_files = sum(len(os.listdir(os.path.join(output_base, 'valid', c))) for c in class_to_files)   # นับจำนวนไฟล์ในโฟลเดอร์ valid
test_files  = sum(len(os.listdir(os.path.join(output_base, 'test', c)))  for c in class_to_files)   # นับจำนวนไฟล์ในโฟลเดอร์ test

print("\n📊 Summary:")
print(f"Total original images: {total_files}")
print(f"Train: {train_files}, Valid: {valid_files}, Test: {test_files}")
print(f"All images after split: {train_files + valid_files + test_files}")
print("✅ Dataset split complete and ready for training.")

"""
datasets_age
'train': 0.8, 'valid': 0.15, 'test': 0.05
cat_adult → train: 1262, valid: 237, test: 79
cat_kitten → train: 1270, valid: 238, test: 79
cat_senior → train: 1229, valid: 230, test: 77
cat_young → train: 1250, valid: 234, test: 79
dog_adult → train: 1260, valid: 236, test: 79
dog_puppy → train: 1265, valid: 237, test: 79
dog_senior → train: 1289, valid: 242, test: 80
dog_young → train: 1279, valid: 240, test: 80

📊 Summary:
Total original images: 12630
Train: 10104, Valid: 1894, Test: 632
All images after split: 12630
✅ Dataset split complete and ready for training.
"""

"""
datasets_ages
'train': 0.8, 'valid': 0.1, 'test': 0.1
cat_adult → train: 1262, valid: 158, test: 158
cat_kitten → train: 1270, valid: 159, test: 158
cat_senior → train: 1229, valid: 154, test: 153
cat_young → train: 1250, valid: 156, test: 157
dog_adult → train: 1260, valid: 158, test: 157
dog_puppy → train: 1265, valid: 158, test: 158
dog_senior → train: 1289, valid: 161, test: 161
dog_young → train: 1279, valid: 160, test: 160

📊 Summary:
Total original images: 12630
Train: 10104, Valid: 1264, Test: 1262
All images after split: 12630
✅ Dataset split complete and ready for training.
"""