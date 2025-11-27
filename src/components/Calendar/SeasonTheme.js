export function getSeasonColor(month) {
  if (month >= 1 && month <= 3) return "bg-pink-100 border-pink-500 text-pink-700";        // بهار
  if (month >= 4 && month <= 6) return "bg-green-100 border-green-500 text-green-700";    // تابستان
  if (month >= 7 && month <= 9) return "bg-orange-100 border-orange-500 text-orange-700"; // پاییز
  return "bg-sky-100 border-sky-500 text-sky-700";                                        // زمستان
}
