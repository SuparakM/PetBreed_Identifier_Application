class BreedAgeMapper {
  // -----------------------
  // Breed Mapping
  // -----------------------
  // ประกาศพจนานุกรม (Map): ชื่อ breedMapping เป็นแบบ static final (ใช้ร่วมกันและเปลี่ยนแปลงไม่ได้) 
  // ใช้เก็บคู่ของ 'ชื่อหลังบ้าน' กับ 'ชื่อแสดงผล'
  static final Map<String, String> breedMapping = {
    "poodle_dog": "poodle",
    "american_shorthair_cat": "american shorthair",
    "bombay_cat": "bombay",
    "calico_cat": "calico",
    "chihuahua_dog": "chihuahua",
    "corgi_dog": "corgi",
    "domestic_long_hair_cat": "domestic long hair",
    "domestic_short_hair_cat": "domestic shorthair",
    "french_bulldog_dog": "french bulldog",
    "golden_retriever_dog": "golden retriever",
    "labrador_retriever_dog": "labrador retriever",
    "maine_coon_cat": "maine coon",
    "manx_cat": "manx",
    "persian_cat": "persian",
    "pomeranian_dog": "pomeranian",
    "pug_dog": "pug",
    "russian_blue_cat": "russian blue",
    "shih_tzu_dog": "shih tzu",
    "siamese_cat": "siamese",
    "siberian_husky_dog": "siberian husky"
  };

  // -----------------------
  // Age Mapping
  // -----------------------
  // ประกาศพจนานุกรม (Map): ชื่อ ageMapping สำหรับแปลงชื่อช่วงอายุ
  static final Map<String, String> ageMapping = {
    // Backend → JSON
    'cat_adult': 'adult',
    'cat_kitten': 'kitten',
    'cat_senior': 'senior',
    'cat_young': 'young',
    'dog_adult': 'adult',
    'dog_puppy': 'puppy',
    'dog_senior': 'senior',
    'dog_young': 'young'
  };

  // -----------------------
  // Helper Functions
  // -----------------------

  /// คืนชื่อสายพันธุ์ตาม JSON
  /// ใช้สำหรับแปลงชื่อสายพันธุ์จากรูปแบบ backend เป็นรูปแบบที่ต้องการ
  static String mapBreed(String backendBreed) {
    return breedMapping[backendBreed] ?? backendBreed;
  }

  /// คืนช่วงอายุตาม JSON
  /// ใช้สำหรับแปลงชื่อช่วงอายุจากรูปแบบ backend เป็นรูปแบบที่ต้องการ
  static String mapAge(String backendAge) {
    return ageMapping[backendAge] ?? backendAge;
  }
}