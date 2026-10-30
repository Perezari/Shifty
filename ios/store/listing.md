# Shifty on the App Store: the listing

The texts of the app's page in App Store Connect, in Hebrew, each within its field's limit. The facts
in them are the app's own (README, ios/Shifty): change them here first when the app changes.

## App Information

**Name** (30 characters at most; the app record's name, already reserved):

```
Shifty - משמרות ושכר
```

**Subtitle** (30 at most):

```
שעון נוכחות ושעות נוספות
```

**Primary language:** Hebrew.

**Category:** Productivity (פרודוקטיביות) first, Finance (פיננסים) second.

**Content rights:** no third-party content.

**Age rating:** nothing in any of the questions: 4+.

## Pricing and availability

Free, in Israel only: its holidays, overtime rules and tax estimate are Israel's. Shifty Pro is the
in-app purchase `com.perezari.shifty.pro`, a non-consumable at ₪24.90.

## App privacy

**Privacy Policy URL:** `https://perezari.github.io/shifty-app/privacy.html` (the site to come, as
Forge's and Sogia's).

**Data collection:** none ("No, we do not collect data from this app"). The shifts and settings stay on
the iPhone and in the user's own iCloud; the workplace's place stays on the iPhone, watched by iOS;
there are no accounts, analytics, ads or servers.

## Version 1.0

**Promotional text** (170 at most; changes without a review):

```
לוחצים כשנכנסים לעבודה, ורואים את השכר עולה בכל שנייה. שעות נוספות, שבתות, חגים ושעות לילה מחושבים לבד, וכל תקופת השכר מסוכמת בשבילך.
```

**Description** (4000 at most):

```
Shifty מראה כמה הרווחת, בזמן אמת. לוחצים כשנכנסים לעבודה ולוחצים כשיוצאים, והשעות, השעות הנוספות והשכר מחושבים לבד.

• משמרת רצה: שעון עם הזמן שעבר והשכר שעולה בכל שנייה, הפסקות, ודגל שמראה מתי תשלים את שעות היום.
• שכחת ללחוץ? לחיצה ארוכה על הכפתור מתחילה או מסיימת משמרת לפני כמה דקות, או בשעה שתבחר.
• שעות נוספות של 125% ו-150%, שבתות וחגים, שעות לילה ודמי נסיעה, לפי ההגדרות שלך.
• חגי ישראל מזוהים לבד, וגם ערבי חג עם יום עבודה מקוצר.
• המשמרות של כל תקופת שכר: שעות, שעות חוסר, מספר משמרות וסך הכול, מכל יום בחודש שתבחר.
• לוח חודשי שמראה במבט אחד אילו ימים השלמת ואילו לא.
• ימי חופש ומחלה בתשלום, והוספת משמרת שנשכחה.
• התראות כשמשלימים את היום, תזכורת להפסקה אחרי 6 שעות, וסיכום בסוף כל תקופה.
• נעילה עם Face ID, מצב כהה וגיבוי לקובץ.

הכול נשמר באייפון שלך: בלי חשבון, בלי פרסומות ובלי מעקב.

Shifty Pro: תשלום אחד, בלי מנוי, ושלך לתמיד.
• נטו משוער: מס הכנסה עם נקודות הזיכוי, ביטוח לאומי, מס בריאות ופנסיה.
• יתרות של ימי חופש ומחלה.
• המשמרת על מסך הנעילה, ב-Dynamic Island ובווידג׳טים.
• Siri, מרכז הבקרה וכפתור הפעולה: מתחילים ומסיימים משמרת בלי לפתוח את האפליקציה.
• סנכרון ב-iCloud בין המכשירים שלך.
• תזכורת לפי מיקום, כשמגיעים לעבודה וכשיוצאים ממנה.
```

**Keywords** (100 at most, the name's and subtitle's words left out, as Apple indexes them anyway):

```
מחשבון,משמרת,דיווח,תלוש,נטו,ברוטו,עבודה,שעתי,חופשה,מחלה,שבת,חג,לילה,נסיעות,shift,overtime,wage
```

**Support URL:** `https://perezari.github.io/shifty-app/` (the site to come).

**Copyright:**

```
2026 Ari Perez
```

**Screenshots:** from the "Shifty · screenshots" workflow on Codemagic, 1206 by 2622, App Store
Connect's first iPhone slot, in their numbered order (the first run, 30 October 2026). The app is for the
iPhone alone, so there are no iPad screenshots.

**App Review notes** (the answers App Review asked of Sogia, given before it asks; item 7 to be checked
against the app once Shifty Pro is built):

```
1. Purpose and audience: Shifty is a Hebrew app for hourly and shift workers in Israel, to record their working hours and see the wage they earn. A shift is started and ended with a tap; the app computes the regular hours, overtime at 125% and 150%, Shabbat and holiday hours, night hours and travel pay, as Israeli payslips do, and adds them up by pay period. Israel's holidays are found by the app itself.

2. Setup and main features: no account, login or setup. The hourly wage and the hours of each day are set in Settings. The tabs:
- Now (עכשיו): start a shift, take a break, end it; the dial shows the time worked and the pay rising each second. A long press on these buttons starts or ends a shift a few minutes ago, or at another time.
- Shifts (משמרות): the pay period's shifts and totals. Tap a shift to edit it, swipe to delete it, long press for its menu; the plus adds a shift, or a paid day off on a long press.
- Calendar (לוח): the period's days, each filled by its hours; tap a day for its shifts.
- Settings (הגדרות): the wage and the workplace, each day's hours, overtime, holidays, night hours, notifications, the lock and the backup.

3. Permissions, all optional and asked only when the user turns on what needs them:
- Location (When In Use, then Always): only for the reminder in Settings, "כשמגיעים לעבודה ויוצאים ממנה". The user saves the workplace's place; iOS region monitoring then wakes the app on arriving and on leaving, and a notification asks whether to start or end the shift, with buttons that do it. It needs Always because the user is rarely in the app when arriving at work or leaving it. The location never leaves the device.
- Notifications: the day's hours completed, a break reminder after six hours, a pay period's summary, and the location reminder.
- Face ID: the optional lock in Settings.

4. External services: none: no server, account, analytics, advertising or AI. Apple services only: StoreKit for the in-app purchase, iCloud key-value storage to keep the shifts the same on the user's own devices, Live Activities and widgets, App Intents for Siri, the Control Center and the Action button, and local notifications.

5. Regional differences: the app is in Hebrew and offered in Israel only; its holidays, overtime rules and tax estimate are Israel's.

6. Third-party material: none. This is not a regulated industry; the net pay is shown as an estimate.

7. In-App Purchase: one non-consumable, "Shifty Pro" (com.perezari.shifty.pro), paid once. It opens the net pay estimate, the vacation and sick-day balances, the Live Activity and widgets, Siri and the Control Center, iCloud sync and the location reminder; everything else is free. To reach it: the Shifty Pro card at the top of Settings, or any row marked Pro. Its screen shows the price, the buy button and "שחזור רכישה" (restore purchase).
```
