import { getSeasonColor, } from "./SeasonTheme.js";
import { getJalaliMonthLength } from "../../js/jalali.js";

export function renderCalendar() {
  const today = new Date();
  let jy = 1403;   // به‌طور پیش‌فرض
  let jm = 11;

  const monthNames = [
    "فروردین","اردیبهشت","خرداد",
    "تیر","مرداد","شهریور",
    "مهر","آبان","آذر",
    "دی","بهمن","اسفند"
  ];

  document.getElementById("calendarTitle").innerText =
    `${monthNames[jm - 1]} ${jy}`;

  const daysInMonth = getJalaliMonthLength(jy, jm);

  let grid = `
      <div class="grid grid-cols-2 sm:grid-cols-4 md:grid-cols-7 gap-2 text-center font-medium">
        <div>شنبه</div>
        <div>یکشنبه</div>
        <div>دوشنبه</div>
        <div>سه‌شنبه</div>
        <div>چهارشنبه</div>
        <div>پنجشنبه</div>
        <div>جمعه</div>
      </div>
  `;

  grid += `<div class="grid grid-cols-2 sm:grid-cols-4 md:grid-cols-7 gap-3 mt-4">`;

  const seasonColor = getSeasonColor(jm);

  for (let d = 1; d <= daysInMonth; d++) {
    const isToday = (d === 5);

    grid += `
      <div 
        class="p-4 rounded-xl border 
        ${seasonColor}
        ${isToday ? "bg-white shadow-xl border-4 scale-105" : ""} 
        transition hover:shadow-lg hover:scale-105 cursor-pointer select-none">
        ${d}
      </div>
    `;
  }

  grid += `</div>`;

  document.getElementById("calendarGrid").innerHTML = grid;
}
