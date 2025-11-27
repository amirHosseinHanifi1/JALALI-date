export function jalaliToGregorian(jy, jm, jd) {
  jy += 1595;
  var days =
    -355668 +
    365 * jy +
    ~~(jy / 33) * 8 +
    ~~(((jy % 33) + 3) / 4) +
    jd +
    (jm < 7 ? jm * 31 : (jm - 6) * 30 + 186);

  var gYear = 400 * ~~(days / 146097);
  days %= 146097;

  if (days > 36524) {
    gYear += 100 * ~~(--days / 36524);
    days %= 36524;

    if (days >= 365) days++;
  }

  gYear += 4 * ~~(days / 1461);
  days %= 1461;

  if (days > 365) {
    gYear += ~~((days - 1) / 365);
    days = (days - 1) % 365;
  }

  var sal_a = [
    0,
    31,
    (gYear % 4 === 0 && gYear % 100 !== 0) || gYear % 400 === 0 ? 29 : 28,
    31,
    30,
    31,
    30,
    31,
    31,
    30,
    31,
    30,
    31,
  ];
  var gm = 0;
  for (gm = 0; gm < 13; gm++) {
    if (days < sal_a[gm]) break;
    days -= sal_a[gm];
  }
  return { gy: gYear, gm: gm, gd: days + 1 };
}

export function getJalaliMonthLength(year, month) {
  if (month <= 6) return 31;
  if (month <= 11) return 30;
  return year % 4 === 3 ? 30 : 29;
}
