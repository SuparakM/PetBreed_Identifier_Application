import os
import shutil
import random
from collections import defaultdict

# พาธต้นทาง กำหนดที่อยู่รูปภาพต้นทางและไฟล์ label
image_dir = 'C:/Users/Acer/Desktop/Project/PetBreed_Identifier/model/yolov11/datasets/train/images'
label_dir = 'C:/Users/Acer/Desktop/Project/PetBreed_Identifier/model/yolov11/datasets/train/labels'

# พาธปลายทาง
output_base = 'C:/Users/Acer/Desktop/Project/PetBreed_Identifier/model/yolov11/datasets_breeds'
# กำหนดสัดส่วนการแบ่งข้อมูล
splits = ['train', 'valid', 'test']
split_ratio = {'train': 0.8, 'valid': 0.15, 'test': 0.05}

# สร้างโฟลเดอร์สำหรับชุดข้อมูลที่แบ่งแล้ว
for split in splits:
    os.makedirs(os.path.join(output_base, split, 'images'), exist_ok=True)
    os.makedirs(os.path.join(output_base, split, 'labels'), exist_ok=True)

# Step 1: จัดกลุ่มภาพตามคลาส
# สร้างกล่องเก็บข้อมูลที่เตรียมไว้สำหรับจัดกลุ่มรูปภาพ โดยกุญแจคือ หมายเลขคลาส และค่าที่เก็บคือ รายการไฟล์รูปภาพ
class_to_files = defaultdict(list)

# อ่านไฟล์ label เพื่อจัดกลุ่มรูปภาพตามคลาส
for label_file in os.listdir(label_dir):
    if not label_file.endswith('.txt'):
        continue
    path = os.path.join(label_dir, label_file)
    with open(path, 'r') as f:
        lines = f.readlines()
        
        # ดึงหมายเลขคลาสจากไฟล์ label
        classes_in_file = set(int(line.split()[0]) for line in lines if len(line.split()) >= 5)
        
        # เพิ่มไฟล์รูปภาพลงในกลุ่มตามคลาส เช่น ถ้ารูปมีหมาคลาส 0 และแมวคลาส 1, รูปภาพนี้ก็จะถูกเก็บไว้ทั้งในกลุ่มของคลาส 0 และคลาส 1
        for cls in classes_in_file:
            image_filename = os.path.splitext(label_file)[0] + '.jpg'
            class_to_files[cls].append(image_filename)

# Step 2: แบ่งข้อมูลโดยให้คลาสมีสัดส่วนใกล้เคียงกัน
# สร้างกล่องเก็บไฟล์ที่ถูกแบ่งแล้ว
final_split_files = {'train': set(), 'valid': set(), 'test': set()}

# สำหรับแต่ละคลาส ให้ทำการสับไฟล์และแบ่งตามสัดส่วนที่กำหนด
for cls, files in class_to_files.items():
    unique_files = list(set(files))  # ป้องกันซ้ำ
    random.shuffle(unique_files) # สับไฟล์เพื่อให้การแบ่งข้อมูลเป็นแบบสุ่ม
    total = len(unique_files) # นับจำนวนไฟล์ทั้งหมดในคลาสนี้

    # คำนวณจำนวนไฟล์ในแต่ละชุด
    train_count = int(total * split_ratio['train']) # คำนวณจำนวนไฟล์ในชุด train
    val_count = int(total * split_ratio['valid'])   # คำนวณจำนวนไฟล์ในชุด valid
    test_count = total - train_count - val_count  # คำนวณจำนวนไฟล์ในชุด test

    # เพิ่มไฟล์ไปยังชุดข้อมูลที่แบ่งแล้ว
    final_split_files['train'].update(unique_files[:train_count])
    final_split_files['valid'].update(unique_files[train_count:train_count + val_count])
    final_split_files['test'].update(unique_files[train_count + val_count:])

# Step 3: คัดลอกไฟล์รูปและ label ไปยังโฟลเดอร์ปลายทาง
# ฟังก์ชันสำหรับคัดลอกไฟล์
def copy_files(split, filenames):
    for img_file in filenames:  # วนลูปแต่ละไฟล์รูปภาพ
        label_file = os.path.splitext(img_file)[0] + '.txt' # ชื่อไฟล์ label ที่สอดคล้องกัน

        src_img = os.path.join(image_dir, img_file) # เส้นทางต้นทางของรูปภาพ
        src_lbl = os.path.join(label_dir, label_file)   # เส้นทางต้นทางของไฟล์ label

        dst_img = os.path.join(output_base, split, 'images', img_file)  # เส้นทางปลายทางของรูปภาพ
        dst_lbl = os.path.join(output_base, split, 'labels', label_file)    # เส้นทางปลายทางของไฟล์ label

        if os.path.exists(src_img) and os.path.exists(src_lbl): # ตรวจสอบว่าทั้งรูปภาพและไฟล์ label มีอยู่
            shutil.copy2(src_img, dst_img) # คัดลอกรูปภาพ จากต้นทางไปยังปลายทาง
            shutil.copy2(src_lbl, dst_lbl) # คัดลอกไฟล์ label จากต้นทางไปยังปลายทาง

# คัดลอกแต่ละชุด
for split in splits:    # วนลูปแต่ละชุดข้อมูล
    copy_files(split, final_split_files[split])   # คัดลอกไฟล์ไปยังโฟลเดอร์ปลายทาง

    # แสดงผลลัพธ์
    print(f"{split}: {len(final_split_files[split])} files copied.")

print("✅ Dataset split completed.")

'''
datasets_breeds
'train': 0.8, 'valid': 0.15, 'test': 0.05
train: 9977 files copied.
valid: 1864 files copied.
test: 643 files copied.
✅ Dataset split completed.
'''

'''
dataset_breeds
'train': 0.8, 'valid': 0.1, 'test': 0.1
train: 9975 files copied.
valid: 1242 files copied.
test: 1265 files copied.
✅ Dataset split completed.
'''