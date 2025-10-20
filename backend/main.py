from fastapi import FastAPI, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import shutil, uuid, os, cv2, numpy as np
from ultralytics import YOLO
import tensorflow as tf
from tensorflow.keras.applications.mobilenet_v2 import preprocess_input
import json

# สร้างเซิร์ฟเวอร์หลักชื่อ app ที่จะคอยรับส่งข้อมูลกับภายนอก
app = FastAPI()

# การตั้งค่า CORS (Cross-Origin Resource Sharing) สำหรับ FastAPI เพื่อให้ API สามารถรับคำขอจากทุกโดเมน
app.add_middleware( #   
    CORSMiddleware,
    allow_origins=["*"], # อนุญาตทุกโดเมน (ทุกเว็บไซต์สามารถเรียก API นี้ได้)
    allow_credentials=True, # อนุญาตให้ส่งข้อมูลพวก cookie หรือ header ที่เกี่ยวกับการยืนยันตัวตน
    allow_methods=["*"],    # อนุญาตทุก HTTP method เช่น GET, POST, PUT, DELETE
    allow_headers=["*"],    # อนุญาตทุก heade
)

# โฟลเดอร์ชั่วคราว
UPLOAD_FOLDER = "temp_images"
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

# โหลดโมเดล YOLOv11 สำหรับการจำแนกสายพันธุ์ สุนัขและแมว
yolo_model = YOLO("best.pt")
# โหลดโมเดล MobileNetV2 สำหรับการจำแนกอายุ
age_model = "mobilenetv2.tflite"

# โหลด TFLite interpreter
age_interpreter = tf.lite.Interpreter(model_path=age_model) 
age_interpreter.allocate_tensors() # จัดสรรหน่วยความจำสำหรับโมเดล

# เตรียมรายละเอียด input/output ของ TFLite
age_input_details = age_interpreter.get_input_details()
age_output_details = age_interpreter.get_output_details()

# ช่วงวัย (ตามที่โมเดลเทรนไว้)
age_labels = ["cat_adult","cat_kitten","cat_senior","cat_young",
              "dog_adult","dog_puppy","dog_senior","dog_young"]

# สร้าง mapping สำหรับแปลง label ระหว่างแมวกับหมา เพื่อให้ YOLO + Age model ตรงกัน
age_mapping = {
    # cat → dog
    "cat_kitten": "dog_puppy",
    "cat_young": "dog_young",
    "cat_adult": "dog_adult",
    "cat_senior": "dog_senior",
    # dog → cat
    "dog_puppy": "cat_kitten",
    "dog_young": "cat_young",
    "dog_adult": "cat_adult",
    "dog_senior": "cat_senior"
}

# =========================
# Helper Functions
# =========================
# สร้างฟังก์ชันสำหรับเตรียมภาพก่อนส่งเข้าโมเดลทำนายอายุ
def preprocess_for_age(crop_img):
    """
    รับ crop_img (BGR uint8) -> คืนค่าเป็น array shape (1,224,224,3) float32 ที่ preprocess_input ทำแล้ว
    NOTE: ถ้า TFLite รองรับ uint8 จะถูกแปลงใน predict function
    """
    # ตรวจสอบว่าภาพที่รับเข้ามาว่างหรือไม่ ถ้าว่างให้คืนค่า None
    if crop_img is None or crop_img.size == 0:
        return None
    # แปลงภาพจากสี BGR (ที่ OpenCV ใช้) เป็น RGB (ที่โมเดลต้องการ)
    img = cv2.cvtColor(crop_img, cv2.COLOR_BGR2RGB)
    # ปรับขนาดภาพให้เป็น 224x224 พิกเซล ตามที่โมเดล MobileNetV2 ต้องการ
    img = cv2.resize(img, (224,224))
    # เพิ่มมิติให้กลายเป็น (1,224,224,3) เพื่อให้เหมาะกับ input ของโมเดล และแปลงเป็น float32
    img = np.expand_dims(img, axis=0).astype(np.float32)  # (1,224,224,3)
    # ใช้ฟังก์ชัน preprocess_input ของ MobileNetV2 เพื่อปรับค่าสีให้อยู่ในช่วง [-1,1] ตามที่โมเดลเทรนไว้
    img = preprocess_input(img)
    return img # คืนค่าภาพที่เตรียมเสร็จแล้วสำหรับนำไปทำนายอายุ

# ทำนายอายุ
def tflite_predict_age(interpreter, input_details, output_details, preprocessed_img):
    """
    ทำ inference ด้วย tflite interpreter
    - preprocessed_img: numpy array float32 shape (1,224,224,3) in [-1,1]
    - จัดการกรณี input dtype เป็น uint8 (quantized) หรือ float32
    คืนค่า: (age_idx, probs_array) หรือ (None, None) ถ้ามีปัญหา
    """
    # ตรวจสอบว่า input ที่เตรียมมาไม่ว่าง ถ้าว่างคืน None
    if preprocessed_img is None:
        return None, None

    # ดึงชนิดข้อมูล (dtype), index ของ input และ output tensor จาก interpreter
    input_dtype = input_details[0]['dtype']
    input_index = input_details[0]['index']
    output_index = output_details[0]['index']

    # เตรียมข้อมูลให้ตรงกับชนิดที่โมเดลต้องการ (uint8 หรือ float32)
    if input_dtype == np.uint8:
        # ถ้าโมเดล quantized รับ uint8, แปลงจาก [-1,1] -> [0,255] (ประมาณ)
        # วิธีแปลงนี้ขึ้นกับวิธีแปลงที่ใช้ตอน convert tflite; ปรับได้ถ้าต้องการ
        input_data = ((preprocessed_img + 1.0) * 127.5).astype(np.uint8)
    else:
        # default float32
        input_data = preprocessed_img.astype(np.float32)

    try:
        # ส่งข้อมูลเข้าโมเดล, รันโมเดล, ดึงผลลัพธ์ออกมา
        interpreter.set_tensor(input_index, input_data)
        interpreter.invoke()
        output_data = interpreter.get_tensor(output_index)  # shape (1, num_classes)
        
        # ลดมิติ output ให้เหลือแค่ 1D (เช่น [0.1, 0.7, 0.2])
        probs = np.squeeze(output_data)
        
        # ถ้าผลรวมของ probs ไม่ใกล้ 1 (ยังไม่ softmax) ให้ทำ softmax เพื่อ normalize
        if probs.ndim == 1 and not (0.99 <= probs.sum() <= 1.01):
            e = np.exp(probs - np.max(probs))
            probs = e / e.sum()
        
        # หา index ของ class ที่มีค่าความมั่นใจสูงสุด (ช่วงอายุที่โมเดลทำนาย)
        age_idx = int(np.argmax(probs))

        # คืนค่า index ของช่วงอายุ และ array ของความมั่นใจแต่ละ class
        return age_idx, probs
    except Exception as e:
        # ถ้าการ inference ผิดพลาด ให้คืน None
        print("TFLite inference error:", e)
        return None, None

# =========================
# Endpoint
# =========================
# รับไฟล์รูปหลายรูป ผ่าน API, ตรวจจับสัตว์ด้วย YOLO, ตัดภาพ, ทำนายอายุ, และคืนผลลัพธ์เป็น JSON
@app.post("/analyze")
async def analyze_images(files: list[UploadFile] = File(...)):
    """
    รับไฟล์รูปหลายรูป, ทำการตรวจจับด้วย YOLO แล้วประเมินอายุด้วย TFLite model
    คืน JSON ที่มี path ของรูปผลลัพธ์ในเซิร์ฟเวอร์ และรายละเอียด detections
    """
    all_results = [] # สร้างลิสต์สำหรับเก็บผลลัพธ์ของแต่ละไฟล์

    # เริ่มการวิเคราะห์: โปรแกรมจะเริ่มทำงานกับรูปภาพทีละรูปที่ส่งมา
    for file in files:

        # สร้างชื่อไฟล์ใหม่แบบสุ่มและบันทึกไฟล์ลงโฟลเดอร์ชั่วคราว
        file_id = str(uuid.uuid4())
        filename = file.filename
        file_path = os.path.join(UPLOAD_FOLDER, f"{file_id}_{filename}")

        # เขียนข้อมูลไฟล์ที่อัพโหลดลงดิสก์
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        # YOLO ตรวจจับ
        try:
            # ส่งรูปที่บันทึกไว้ให้ YOLO เพื่อตรวจจับและระบุตำแหน่ง/ชนิดของสัตว์
            yolo_out = yolo_model(file_path)[0]  # ผลของ ultralytics
        except Exception as e:
            # ถ้า YOLO ตรวจจับผิดพลาด ให้บันทึก error แล้วข้ามไฟล์นี้
            all_results.append({
                "original_file": filename,
                "error": f"YOLO inference error: {str(e)}"
            })
            continue

        # เตรียมลิสต์สำหรับเก็บข้อมูลการตรวจจับและภาพที่ถูก crop
        detections = []
        cropped_animals = []

        # อ่านภาพต้นฉบับ: โหลดรูปภาพกลับมาเพื่อเตรียมพร้อมสำหรับการตัดภาพตามผลตรวจจับ
        img_cv_full = cv2.imread(file_path)
        if img_cv_full is None:
            all_results.append({
                "original_file": filename,
                "error": "ไม่สามารถอ่านไฟล์ภาพได้"
            })
            continue
        h_full, w_full = img_cv_full.shape[:2]

        # ตัดรูปเฉพาะตัวสัตว์: วนลูปดูว่า YOLO ตรวจพบสัตว์กี่ตัว แล้วใช้พิกัดที่ตรวจพบ ตัดภาพ เฉพาะส่วนที่เป็นตัวสัตว์ออกมา
        for det in yolo_out.boxes:
            try:
                # ดึงค่าพิกัด, ความมั่นใจ, คลาส และ label ของสัตว์แต่ละตัว
                x1, y1, x2, y2 = det.xyxy[0].tolist()
                conf = float(det.conf[0])
                cls = int(det.cls[0])
                label = yolo_model.names[cls] if hasattr(yolo_model, "names") else str(cls)
                
                # ปรับพิกัดให้อยู่ในขอบเขตภาพ
                x1i, y1i = max(0, int(x1)), max(0, int(y1))
                x2i, y2i = min(w_full-1, int(x2)), min(h_full-1, int(y2))

                # เก็บข้อมูลการตรวจจับแต่ละตัว
                detections.append({
                    "label": label,
                    "confidence": conf,
                    "bbox": [x1i, y1i, x2i, y2i]
                })

                # ตัดภาพเฉพาะส่วนที่เป็นสัตว์แต่ละตัว
                if x2i > x1i and y2i > y1i:
                    crop_img = img_cv_full[y1i:y2i, x1i:x2i]
                else:
                    crop_img = None
                cropped_animals.append(crop_img)
            except Exception as e:
                print("Error parsing detection:", e)
                continue

        # ถ้าไม่พบสัตว์เลย ให้บันทึกข้อความและลบไฟล์
        if not detections:
            all_results.append({
                "original_file": filename,
                "message": "ไม่พบสัตว์ในภาพ (หลัง parse)"
            })
            if os.path.exists(file_path):
                os.remove(file_path)
            continue

        # ประเมินอายุสัตว์แต่ละตัวด้วยโมเดล TFLite และเก็บผลลัพธ์
        age_results = []
        for crop in cropped_animals:
            if crop is None or crop.size == 0:
                age_results.append(None)
                continue
            pre = preprocess_for_age(crop)  # float32 [-1,1]
            # นำภาพที่ตัดแล้วมาประมวลผลและส่งให้โมเดลเพื่อทำนายช่วงวัย
            age_idx, probs = tflite_predict_age(
                age_interpreter,  # โมเดล TFLite สำหรับทำนายอายุ
                age_input_details, # รายละเอียด input
                age_output_details, # รายละเอียด output
                pre # ภาพที่เตรียมไว้แล้ว
            )
            if age_idx is None or probs is None:
                age_results.append(None)
            else:
                age_results.append({
                    "age_range": age_labels[age_idx] if age_idx < len(age_labels) else f"idx_{age_idx}",
                    "confidence": float(probs[age_idx]) if len(probs) > age_idx else float(np.max(probs)),
                })

        # จัด JSON ผลลัพธ์
        result = {
            "original_file": file.filename,
            "detections": []
        }

        # สร้าง dictionary สำหรับแต่ละ detection (สัตว์แต่ละตัว) 
        # โดยใส่ label, confidence, bbox
        for i, det in enumerate(detections):
            entry = {
                "label": det["label"],
                "confidence": det["confidence"],
                "bbox": det["bbox"]
            }

            # ถ้ามีผลลัพธ์การทำนายอายุสำหรับตัวนี้ ให้ดึงช่วงอายุและความมั่นใจ
            if i < len(age_results) and age_results[i] is not None:
                predicted_age = age_results[i]["age_range"]
                predicted_conf = age_results[i]["confidence"]

                # ปรับอายุให้ตรงประเภทสัตว์จาก YOLO โดยใช้ mapping
                # ตรวจสอบว่า label เป็นหมาหรือแมว แล้วปรับช่วงอายุให้ตรงกับชนิดสัตว์ (ถ้า label กับ age ไม่ตรงกัน)
                if "dog" in det["label"].lower():
                    entry["animalType"] = "dog"
                    if predicted_age in age_mapping and predicted_age.startswith("cat_"):
                        predicted_age = age_mapping[predicted_age]
                elif "cat" in det["label"].lower():
                    entry["animalType"] = "cat"
                    if predicted_age in age_mapping and predicted_age.startswith("dog_"):
                        predicted_age = age_mapping[predicted_age]

                # เพิ่มข้อมูลช่วงอายุและความมั่นใจเข้าไปใน entry
                entry.update({
                    "age_range": predicted_age,
                    "age_confidence": predicted_conf,
                })
            else:
                # ถ้าไม่มีผลลัพธ์อายุ ให้ใส่ None
                entry.update({
                    "age_range": None,
                    "age_confidence": None,
                })

                # ถ้า label ลงท้ายด้วย _cat หรือ _dog ให้ระบุชนิดสัตว์
                if det["label"].endswith("_cat"):
                    entry["animalType"] = "cat"
                elif det["label"].endswith("_dog"):
                    entry["animalType"] = "dog"

            # เพิ่ม entry นี้เข้าไปในลิสต์ detections ของผลลัพธ์ไฟล์นี้
            result["detections"].append(entry)

        # รวบรวมผลลัพธ์: จัดเก็บข้อมูลทั้งหมด 
        # (ชื่อไฟล์, ชนิดสัตว์, พิกัด, ช่วงอายุ, ความมั่นใจ) เข้าเป็นชุดข้อมูลสำหรับรูปนั้นๆ
        all_results.append(result)

        # ลบไฟล์ input ชั่วคราว
        if os.path.exists(file_path):
            os.remove(file_path)

    # ส่งผลลัพธ์กลับ: ส่งชุดข้อมูลสรุปผลการวิเคราะห์ทั้งหมดกลับไปยังผู้ใช้ในรูปแบบ JSON
    return JSONResponse(content={"results": all_results})

"""
{
  "results": [
    {
      "original_file": "my_cat_photo.jpg",
      "detections": [
        {
          "label": "british_shorthair_cat",
          "confidence": 0.987,
          "bbox": [150, 80, 500, 420], 
          "animalType": "cat",
          "age_range": "cat_kitten",
          "age_confidence": 0.915
        }
      ]
    }
  ]
}
"""