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
in-app purchase `com.perezari.shifty.pro.lifetime`, a non-consumable at ₪24.90. (The first,
`com.perezari.shifty.pro`, was created as a consumable by mistake, and so was never kept as owned; App Store
Connect can't change a product's type, nor give its ID again.)

## App privacy

**Privacy Policy URL:** `https://perezari.github.io/shifty-app/privacy.html` (the public repository
`Perezari/shifty-app` on GitHub Pages, as Forge's and Sogia's; Settings links to it too).

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

**Support URL:** `https://perezari.github.io/shifty-app/`

**Copyright:**

```
2026 Ari Perez
```

**Screenshots:** from the "Shifty · screenshots" workflow on Codemagic, 1206 by 2622, App Store
Connect's first iPhone slot, in their numbered order (the first run, 30 October 2026). The app is for the
iPhone alone, so there are no iPad screenshots. The same run's `iap-pro.png`, Pro's sheet, is the in-app
purchase's review screenshot (the purchase's page, Review Information).

**App Review notes** (App Review asked for them on 2 November 2026, with a screen recording; the same
text is the reply to its message and the Notes field of App Review Information, under that field's 4000
characters):

```
1. Screen recording: attached, made on an iPhone with the latest iOS. It begins at the app's launch and shows a shift from its start to its end, its Live Activity, the net pay and each tab. The app has no account, login or user-generated content. The iPhone's Apple ID bought Shifty Pro in TestFlight, so the recording shows Pro as active (its card in Settings: "Shifty Pro, פעיל. תודה!") and its features in use. Pro's purchase sheet is the in-app purchase's review screenshot.

2. Purpose and audience: Shifty is a Hebrew app for hourly and shift workers in Israel, at any employer; it is not a business's internal app. It records the hours worked and shows the wage they earn. A shift is started and ended with a tap, and the app computes the regular hours, overtime at 125% and 150%, Shabbat and holiday hours, night hours and travel, as Israeli payslips do, and adds them up by pay period. Workers see what they have earned before the payslip comes, and check the payslip against it.

3. Setup and main features: no account, login, setup or sample files. The app opens with an hourly wage of ₪50, changed on the workplace's page in Settings. The tabs, right to left:
- Now (עכשיו): "התחל משמרת" starts a shift; the dial shows the time worked and the pay rising each second; "הפסקה" takes a break; holding "סיום משמרת" until the button fills ends the shift. A long press on start or break, or a tap on end, sets it some minutes earlier or at another time.
- Shifts (משמרות): the pay period's shifts and totals. Tap a shift to edit it, swipe to delete it, long press for its menu; the plus adds a shift, or a day off on a long press.
- Calendar (לוח): the period's days, each filled by its hours; tap a day for its shifts.
- Settings (הגדרות): the workplaces (מקומות עבודה), each with its pay (by the hour or monthly), pay period, hours, overtime, vacation, pension and travel; then holidays, notifications, the lock and a backup to a file.
Permissions, all optional and asked only when a feature needs them: notifications (the day's hours done, a break reminder, the period's summary); location, When In Use then Always, only for a workplace's reminder (on arriving and on leaving, a notification asks whether to start or end the shift; the location never leaves the device); Face ID for the lock.

4. External services: none: no server, account, analytics, advertising or AI. Only Apple's: StoreKit for the in-app purchase, iCloud key-value storage to sync the user's own devices, Live Activities and widgets, App Intents for Siri, the Control Center and the Action button, region monitoring and local notifications.

5. Regional differences: none. The app is offered in Israel only, in Hebrew, and its holidays, overtime rules and tax estimate are Israel's.

6. Regulated industry or third-party material: neither. The app computes the user's own wage from the hours they record; it moves no money and gives no financial advice, and it shows the net pay as an estimate.

7. In-App Purchase: one non-consumable, "Shifty Pro" (com.perezari.shifty.pro.lifetime), paid once. It opens the net pay estimate, the vacation and sick-day balances, the bonus and recuperation pay cards, more workplaces, the Live Activity and widgets, Siri and the Control Center, iCloud sync and the location reminder; everything else is free. To reach it: the Shifty Pro card at the top of Settings (הגדרות), anything marked Pro there (such as "הוספת מקום עבודה"), or the net pay line marked Pro on the Now tab. Its sheet has the price, the buy button and "שחזור רכישה" (Restore Purchase), also on the Settings card. Without it, the widgets show a lock and Siri answers that the action is in Shifty Pro.
```

## Version 1.2

Submitted from App Store Connect as a new version of the same app: the description, keywords, screenshots,
App Review notes and the in-app purchase carry over from 1.1 and stay as they are; the build is the newest
1.2 in TestFlight (its number is the UTC time it was built, `%y%j%H%M`, so the highest is the latest).
1.1's train is closed since its approval, which is why the app's version is 1.2.

**What's New in This Version** (4000 at most; what was built after 1.1's build, 263051228):

```
• מחקת משמרת בטעות? אחרי כל מחיקה מופיע "ביטול", ומה שנמחק ב־30 הימים האחרונים נמצא בהגדרות › נמחקו לאחרונה.
• הגדרה ראשונה: מקום העבודה, השכר והשעות כבר בפתיחה הראשונה.
• ימי מילואים, ותאריך עברי לצד הלועזי (בהגדרות › תצוגה).
• לחיצה ארוכה על האייקון במסך הבית: התחלת משמרת או סיומה, הוספת משמרת ויום חופש.
• בפירוט של יום מחליקים ליום הקודם וליום הבא, ואת שעת ההתחלה אפשר לגרור על השעון.
• תקופת עבודה עם יום אחרון: השכר נספר רק בתוכה.
• משמרת לילה של 7 שעות לפי החוק, למי שמפעיל אותה בדף מקום העבודה.
• שליחת משוב ישר מההגדרות.
• Shifty Pro: דף "סיום העבודה" עם פיצויים, הודעה מוקדמת, פדיון חופשה ודמי הבראה; אייקונים לבחירה; ותזכורת המיקום מציעה להתחיל בשעת ההגעה ולסיים בשעת היציאה.
• לחיצה ארוכה ברשימות כבר לא מפריעה לגלילה ולמחיקה בהחלקה.
```
