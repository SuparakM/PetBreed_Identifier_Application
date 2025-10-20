from ultralytics import YOLO

# โหลดโมเดลตรวจจับวัตถุที่ฝึกจนเก่งที่สุด (ไฟล์ best.pt) มาใช้
model = YOLO('C:/Users/Acer/Desktop/Project/PetBreed_Identifier/model/yolov11/runs/detect/train/weights/best.pt')

# ใช้โมเดลที่โหลดมา ตรวจจับวัตถุในภาพตัวอย่าง
results = model("C:/Users/Acer/Desktop/Project/อ้างอิง/ทดสอบ/Winnie.jpeg")

# แสดงผลลัพธ์การตรวจจับ
results[0].show()