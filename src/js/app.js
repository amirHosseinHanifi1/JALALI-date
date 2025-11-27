import jalaali from 'jalaali-js';

// المنت‌ها
const calendarDays = document.getElementById("calendarDays");
const currentMonthYear = document.getElementById("currentMonthYear");

// تاریخ امروز
const today = new Date();
const jToday = jalaali.toJalaali(today.getFullYear(), today.getMonth()+1, today.getDate());

// نمایش ماه و سال شمسی
currentMonthYear.textContent = `${jToday.jy} / ${jToday.jm}`;

// تعداد روزهای ماه
const daysInMonth = jalaali.jalaaliMonthLength(jToday.jy, jToday.jm);

// پیدا کردن روز شروع ماه (شنبه = 0)
const firstDay = jalaali.toGregorian(jToday.jy, jToday.jm, 1);
const weekday = new Date(firstDay.gy, firstDay.gm-1, firstDay.gd).getDay(); 

// پر کردن خانه‌های خالی قبل از شروع ماه
for (let i=0; i<weekday; i++){
  const emptyDiv = document.createElement("div");
  calendarDays.appendChild(emptyDiv);
}

// پر کردن روزهای ماه
for (let i=1; i<=daysInMonth; i++){
  const dayDiv = document.createElement("div");
  dayDiv.className = "p-3 rounded hover:bg-indigo-100 cursor-pointer transition text-center";
  dayDiv.textContent = i;
  calendarDays.appendChild(dayDiv);
}
