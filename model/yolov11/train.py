from ultralytics import YOLO

# Load a pretrained YOLO11n model
model = YOLO("yolo11n.pt") #โมเดลตรวจจับวัตถุที่ผ่านการฝึกมาแล้ว

# Train the model on the COCO8 dataset for 100 epochs
train_results = model.train(
    # ชุดข้อมูลสำหรับฝึก data.yaml จะบอกโมเดลว่าภาพฝึกสอนและภาพสำหรับทดสอบอยู่ที่ไหนบ้าง รวมถึงมีสายพันธุ์อะไรบ้าง (Class)
    data="C:/Users/Acer/Desktop/Project/PetBreed_Identifier/model/yolov11/datasets_breeds/data.yaml",  
    epochs=100,  # จำนวนรอบการฝึก
    imgsz=640,  # ขนาดภาพสำหรับการฝึก
    device="0",  # อุปกรณ์ที่ใช้ (เช่น 'cpu', 0 (GPU), [0,1,2,3])
    # จำนวน worker สำหรับโหลดข้อมูล (0 = โหลดทีละชุด (batch), ใช้สำหรับ Windows ป้องกัน crash)
    workers=0,  
    # จำนวนรอบที่รอถ้าความแม่นยำไม่ดีขึ้นก่อนหยุดฝึกสอนทันที (early stopping)เพื่อประหยัดเวลาและป้องกันการฝึกจนเกินไป (Overfit)
    patience=20, 
    lr0=0.0001, # ค่า learning rate เริ่มต้น (0.0001 ช้าและปลอดภัยต่อการ overfit)
    # ลด overfitting ด้วย dropout เป็นเทคนิคที่สุ่มให้เซลล์ประสาทในโมเดล "พัก" การทำงานไป 10% ในแต่ละรอบการฝึก
    dropout=0.1,            
    # ลดความมั่นใจสูงสุดของโมเดลลงเล็กน้อย (0.01) ทำให้โมเดลไม่ยึดติดกับคำตอบ 100% มากเกินไป ช่วยให้ผลลัพธ์มีความยืดหยุ่นและแม่นยำขึ้น
    label_smoothing=0.01,
    warmup_epochs=2    # จำนวน epochs ที่ใช้ "วอร์มอัพ" learning rate จากต่ำขึ้นไปก่อนเข้า training ปกติ
)

# สั่งให้โมเดล "สอบ" โดยการประเมินผลงานของตัวเองด้วยชุดข้อมูลทดสอบ (Validation Set) และเก็บผลลัพธ์ไว้ในตัวแปรชื่อ metrics
metrics = model.val()

"""
train_results = model.train()
ตอน YOLO เทรน มันจะประเมิน Precision, Recall, mAP@0.5, mAP@0.5:0.95 ทุก epoch
เก็บ loss ของแต่ละส่วน เช่น box loss, cls loss, dfl loss
วาดกราฟความแม่นยำ / loss ต่อ epoch
เซฟทุกอย่างไว้ในโฟลเดอร์ชื่อประมาณนี้:
runs/detect/train/
"""
"""
metrics = model.val()
ส่วนนี้จะ "ประเมิน" โมเดลกับ validation/test set อีกครั้ง
และก็จะสร้างกราฟ PR Curve, Confusion Matrix, F1 Curve เหมือนกัน
"""