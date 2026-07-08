> تمت هذه الترجمة بواسطة Claude. إذا كانت لديك اقتراحات للتحسين، يرجى فتح PR.

<h1 align="center">bmux</h1>
<p align="center">تطبيق طرفية لنظام macOS مبني على Ghostty مع علامات تبويب عمودية وإشعارات لوكلاء البرمجة بالذكاء الاصطناعي</p>

<p align="center">
  <a href="https://github.com/manaflow-ai/bmux/releases/latest/download/bmux-macos.dmg">
    <img src="../assets/macos-badge.png" alt="تحميل bmux لنظام macOS" width="180" />
  </a>
</p>

<p align="center">
  <a href="../../README.md">English</a> | <a href="README.ja.md">日本語</a> | <a href="README.vi.md">Tiếng Việt</a> | <a href="README.zh-CN.md">简体中文</a> | <a href="README.zh-TW.md">繁體中文</a> | <a href="README.ko.md">한국어</a> | <a href="README.de.md">Deutsch</a> | <a href="README.es.md">Español</a> | <a href="README.fr.md">Français</a> | <a href="README.it.md">Italiano</a> | <a href="README.da.md">Dansk</a> | <a href="README.pl.md">Polski</a> | <a href="README.ru.md">Русский</a> | <a href="README.bs.md">Bosanski</a> | العربية | <a href="README.no.md">Norsk</a> | <a href="README.pt-BR.md">Português (Brasil)</a> | <a href="README.th.md">ไทย</a> | <a href="README.tr.md">Türkçe</a> | <a href="README.km.md">ភាសាខ្មែរ</a> | <a href="README.uk.md">Українська</a>
</p>

<p align="center">
  <a href="https://x.com/manaflowai"><img src="https://img.shields.io/badge/@manaflow-555?logo=x" alt="X / Twitter" /></a>
  <a href="https://discord.gg/xsgFEVrWCZ"><img src="https://img.shields.io/badge/Discord-555?logo=discord" alt="Discord" /></a>
  <a href="https://github.com/manaflow-ai/bmux"><img src="https://img.shields.io/github/stars/manaflow-ai/bmux?style=flat&logo=github&label=stars&color=4c71f2" alt="GitHub stars" /></a>
</p>

<p align="center">
  <img src="../assets/main-first-image.png" alt="لقطة شاشة bmux" width="900" />
</p>

<p align="center">
  <a href="https://www.youtube.com/watch?v=i-WxO5YUTOs">▶ فيديو توضيحي</a> · <a href="https://bmux.com/blog/zen-of-bmux">فلسفة bmux</a>
</p>

## الميزات

<table>
<tr>
<td width="40%" valign="middle">
<h3>حلقات الإشعارات</h3>
تحصل الأجزاء على حلقة زرقاء وتضيء علامات التبويب عندما يحتاج وكلاء البرمجة انتباهك
</td>
<td width="60%">
<img src="../assets/notification-rings.png" alt="حلقات الإشعارات" width="100%" />
</td>
</tr>
<tr>
<td width="40%" valign="middle">
<h3>لوحة الإشعارات</h3>
عرض جميع الإشعارات المعلقة في مكان واحد، والانتقال إلى أحدث إشعار غير مقروء
</td>
<td width="60%">
<img src="../assets/sidebar-notification-badge.png" alt="شارة إشعارات الشريط الجانبي" width="100%" />
</td>
</tr>
<tr>
<td width="40%" valign="middle">
<h3>متصفح مدمج</h3>
قسّم متصفحًا بجانب الطرفية مع API قابل للبرمجة مأخوذ من <a href="https://github.com/vercel-labs/agent-browser">agent-browser</a>
</td>
<td width="60%">
<img src="../assets/built-in-browser.png" alt="المتصفح المدمج" width="100%" />
</td>
</tr>
<tr>
<td width="40%" valign="middle">
<h3>علامات تبويب عمودية + أفقية</h3>
يعرض الشريط الجانبي فرع git وحالة/رقم طلب السحب المرتبط ومجلد العمل والمنافذ المستمعة وآخر نص إشعار. تقسيم أفقي وعمودي.
</td>
<td width="60%">
<img src="../assets/vertical-horizontal-tabs-and-splits.png" alt="علامات تبويب عمودية وأجزاء مقسمة" width="100%" />
</td>
</tr>
<tr>
<td width="40%" valign="middle">
<h3>SSH</h3>
<code>bmux ssh user@remote</code> ينشئ مساحة عمل لجهاز بعيد. تُوجَّه أجزاء المتصفح عبر الشبكة البعيدة بحيث يعمل localhost مباشرة. اسحب صورة إلى جلسة بعيدة لرفعها عبر scp.
</td>
<td width="60%">
<img src="../assets/ssh.png" alt="bmux SSH" width="100%" />
</td>
</tr>
<tr>
<td width="40%" valign="middle">
<h3>Claude Code Teams</h3>
<code>bmux claude-teams</code> يشغّل وضع الفريق في Claude Code بأمر واحد. يظهر أعضاء الفريق كأقسام أصلية مع بيانات وصفية في الشريط الجانبي وإشعارات. لا حاجة لـ tmux.
</td>
<td width="60%">
<img src="../assets/claude-code-teams.png" alt="Claude Code Teams" width="100%" />
</td>
</tr>
</table>

- **استيراد المتصفح** — استيراد ملفات تعريف الارتباط والسجل والجلسات من Chrome وFirefox وArc وأكثر من 20 متصفحًا آخر حتى تبدأ أجزاء المتصفح مع تسجيل الدخول
- **أوامر مخصصة** — حدد إجراءات خاصة بالمشروع في [`bmux.json`](https://bmux.com/docs/custom-commands) يتم تشغيلها من لوحة الأوامر
- **قابل للبرمجة** — CLI وsocket API لإنشاء مساحات العمل وتقسيم الأجزاء وإرسال ضغطات المفاتيح وأتمتة المتصفح
- **تطبيق macOS أصلي** — مبني بـ Swift وAppKit، وليس Electron. بدء تشغيل سريع واستهلاك ذاكرة منخفض.
- **متوافق مع Ghostty** — يقرأ إعداداتك الحالية من `~/.config/ghostty/config` للسمات والخطوط والألوان
- **تسريع GPU** — مدعوم بـ libghostty لعرض سلس
- **اختصارات لوحة المفاتيح** — [اختصارات شاملة](https://bmux.com/docs/keyboard-shortcuts) لمساحات العمل والتقسيمات والمتصفح والمزيد
- **مفتوح المصدر** — مجاني ومرخّص بموجب GPL

## التثبيت

### DMG (مستحسن)

<a href="https://github.com/manaflow-ai/bmux/releases/latest/download/bmux-macos.dmg">
  <img src="../assets/macos-badge.png" alt="تحميل bmux لنظام macOS" width="180" />
</a>

افتح ملف `.dmg` واسحب bmux إلى مجلد التطبيقات. يتم تحديث bmux تلقائيًا عبر Sparkle، لذا تحتاج للتحميل مرة واحدة فقط.

### Homebrew

```bash
brew tap manaflow-ai/bmux
brew install --cask bmux
```

للتحديث لاحقًا:

```bash
brew upgrade --cask bmux
```

عند التشغيل الأول، قد يطلب منك macOS تأكيد فتح تطبيق من مطور معروف. انقر **فتح** للمتابعة.

## لماذا bmux؟

أقوم بتشغيل الكثير من جلسات Claude Code وCodex بالتوازي. كنت أستخدم Ghostty مع مجموعة من الأجزاء المقسمة، وأعتمد على إشعارات macOS الأصلية لمعرفة متى يحتاجني وكيل ما. لكن نص إشعار Claude Code يكون دائمًا مجرد "Claude is waiting for your input" بدون أي سياق، ومع فتح عدد كافٍ من علامات التبويب لم أعد قادرًا حتى على قراءة العناوين.

جربت بعض منظمات البرمجة لكن معظمها كانت تطبيقات Electron/Tauri وأداؤها كان يزعجني. كما أنني أفضل الطرفية لأن منظمات GUI تحبسك في سير عملها. لذا بنيت bmux كتطبيق macOS أصلي بـ Swift/AppKit. يستخدم libghostty لعرض الطرفية ويقرأ إعدادات Ghostty الحالية للسمات والخطوط والألوان.

الإضافات الرئيسية هي الشريط الجانبي ونظام الإشعارات. يحتوي الشريط الجانبي على علامات تبويب عمودية تعرض فرع git وحالة/رقم طلب السحب المرتبط ومجلد العمل والمنافذ المستمعة وآخر نص إشعار لكل مساحة عمل. يلتقط نظام الإشعارات تسلسلات الطرفية (OSC 9/99/777) ولديه CLI (`bmux notify`) يمكنك ربطه بخطافات الوكلاء لـ Claude Code وOpenCode وغيرها. عندما ينتظر وكيل ما، يحصل جزؤه على حلقة زرقاء وتضيء علامة التبويب في الشريط الجانبي، حتى أتمكن من معرفة أيها يحتاجني عبر الأقسام وعلامات التبويب. Cmd+Shift+U ينتقل إلى أحدث إشعار غير مقروء.

المتصفح المدمج لديه API قابل للبرمجة مأخوذ من [agent-browser](https://github.com/vercel-labs/agent-browser). يمكن للوكلاء التقاط شجرة إمكانية الوصول والحصول على مراجع العناصر والنقر وملء النماذج وتنفيذ JS. يمكنك تقسيم جزء متصفح بجانب الطرفية وجعل Claude Code يتفاعل مع خادم التطوير مباشرة.

كل شيء قابل للبرمجة عبر CLI وsocket API — إنشاء مساحات العمل/علامات التبويب، تقسيم الأجزاء، إرسال ضغطات المفاتيح، فتح عناوين URL في المتصفح.

## فلسفة bmux

bmux لا يفرض على المطورين طريقة استخدام أدواتهم. إنه طرفية ومتصفح مع واجهة سطر أوامر، والباقي متروك لك.

bmux هو لبنة أساسية وليس حلًا جاهزًا. يمنحك طرفية ومتصفحًا وإشعارات ومساحات عمل وأقسامًا وعلامات تبويب وواجهة سطر أوامر للتحكم في كل ذلك. bmux لا يجبرك على طريقة محددة لاستخدام وكلاء البرمجة. ما تبنيه باستخدام هذه اللبنات الأساسية هو ملكك.

أفضل المطورين دائمًا ما بنوا أدواتهم الخاصة. لم يكتشف أحد بعد أفضل طريقة للعمل مع الوكلاء، والفرق التي تبني منتجات مغلقة لم تكتشفها أيضًا بالتأكيد. المطورون الأقرب لقواعد بياناتهم الخاصة سيكتشفونها أولًا.

أعطِ مليون مطور لبنات أساسية قابلة للتركيب وسيجدون بشكل جماعي أكثر سير العمل كفاءة أسرع مما يمكن لأي فريق منتج تصميمه من الأعلى إلى الأسفل.

## التوثيق

لمزيد من المعلومات حول كيفية إعداد bmux، [توجه إلى وثائقنا](https://bmux.com/docs/getting-started?utm_source=readme).

## اختصارات لوحة المفاتيح

### مساحات العمل

| الاختصار | الإجراء |
|----------|--------|
| ⌘ N | مساحة عمل جديدة |
| ⌘ 1–8 | الانتقال إلى مساحة العمل 1–8 |
| ⌘ 9 | الانتقال إلى آخر مساحة عمل |
| ⌃ ⌘ ] | مساحة العمل التالية |
| ⌃ ⌘ [ | مساحة العمل السابقة |
| ⌘ ⇧ W | إغلاق مساحة العمل |
| ⌘ ⇧ R | إعادة تسمية مساحة العمل |
| ⌥ ⌘ E | تحرير وصف مساحة العمل |
| ⌘ B | تبديل الشريط الجانبي |
| ⌥ ⌘ B | تبديل الشريط الجانبي الأيمن |
| ⌘ ⇧ E | تبديل التركيز على الشريط الجانبي الأيمن |

### الأسطح

| الاختصار | الإجراء |
|----------|--------|
| ⌘ T | سطح جديد |
| ⌘ ⇧ ] | السطح التالي |
| ⌘ ⇧ [ | السطح السابق |
| ⌃ Tab | السطح التالي |
| ⌃ ⇧ Tab | السطح السابق |
| ⌃ 1–8 | الانتقال إلى السطح 1–8 |
| ⌃ 9 | الانتقال إلى آخر سطح |
| ⌘ W | إغلاق السطح |

### الأجزاء المقسمة

| الاختصار | الإجراء |
|----------|--------|
| ⌘ D | تقسيم لليمين |
| ⌘ ⇧ D | تقسيم للأسفل |
| ⌥ ⌘ ← → ↑ ↓ | التركيز على الجزء حسب الاتجاه |
| ⌘ ⇧ H | وميض الجزء المركّز عليه |

### المتصفح

اختصارات أدوات المطور في المتصفح تتبع إعدادات Safari الافتراضية ويمكن تخصيصها في `الإعدادات ← اختصارات لوحة المفاتيح`.
اختصارات التنقل في لوحة الأوامر، بما في ذلك ⌃ P، قابلة للتخصيص أيضًا ويمكن مسحها بحيث تصل ضغطة المفتاح إلى الطرفية النشطة.

| الاختصار | الإجراء |
|----------|--------|
| ⌘ ⇧ L | فتح المتصفح في قسم |
| ⌘ L | التركيز على شريط العنوان |
| ⌘ [ | للخلف |
| ⌘ ] | للأمام |
| ⌘ R | إعادة تحميل الصفحة |
| ⌥ ⌘ I | تبديل أدوات المطور (إعداد Safari الافتراضي) |
| ⌥ ⌘ C | عرض وحدة تحكم JavaScript (إعداد Safari الافتراضي) |

### الإشعارات

| الاختصار | الإجراء |
|----------|--------|
| ⌘ I | عرض لوحة الإشعارات |
| ⌘ ⇧ U | الانتقال إلى أحدث إشعار غير مقروء |
| ⌥ ⌘ U | تبديل حالة العنصر الحالي بين مقروء وغير مقروء |
| ⌃ ⌘ U | تعيين العنصر الحالي كأقدم غير مقروء والانتقال إلى أحدث إشعار غير مقروء تالٍ |

### البحث

| الاختصار | الإجراء |
|----------|--------|
| ⌘ F | بحث |
| ⌘ ⇧ F | البحث في المجلد |
| ⌘ G / ⌥ ⌘ G | البحث التالي / السابق |
| ⌥ ⌘ ⇧ F | إخفاء شريط البحث |
| ⌘ E | استخدام التحديد للبحث |

### الطرفية

| الاختصار | الإجراء |
|----------|--------|
| ⌘ K | مسح سجل التمرير |
| ⌘ C | نسخ (مع التحديد) |
| ⌘ V | لصق |
| ⌘ + / ⌘ - | تكبير / تصغير حجم الخط |
| ⌘ 0 | إعادة تعيين حجم الخط |

### النافذة

| الاختصار | الإجراء |
|----------|--------|
| ⌘ ⇧ N | نافذة جديدة |
| ⌘ ⇧ O | إعادة فتح الجلسة السابقة |
| ⌘ , | الإعدادات |
| ⌘ ⇧ , | إعادة تحميل الإعدادات |
| ⌘ Q | إنهاء |

## الإصدارات الليلية

[تحميل bmux NIGHTLY](https://github.com/manaflow-ai/bmux/releases/download/nightly/bmux-nightly-macos.dmg)

bmux NIGHTLY هو تطبيق منفصل بمعرّف حزمة خاص به، لذا يعمل بجانب الإصدار المستقر. يُبنى تلقائيًا من أحدث commit على فرع `main` ويتم تحديثه تلقائيًا عبر Sparkle الخاص به.

أبلغ عن أخطاء الإصدارات الليلية على [GitHub Issues](https://github.com/manaflow-ai/bmux/issues) أو في [#nightly-bugs على Discord](https://discord.gg/xsgFEVrWCZ).

## استعادة الجلسة

عند إغلاق bmux، يتم حفظ الجلسة الحالية. عند إعادة التشغيل، يستعيد bmux الحالة التي يملكها التطبيق:
- تخطيط النوافذ/مساحات العمل/الأجزاء
- مجلدات العمل
- سجل تمرير الطرفية (أفضل جهد)
- عنوان URL للمتصفح وسجل التنقل

لا ينشئ bmux نقاط تحقق لأي حالة عملية حية عشوائية. يعاد فتح tmux وvim وshell وتطبيقات الطرفية غير المدعومة كطرفيات عادية.

يمكن استئناف جلسات الوكلاء المدعومة عندما تحفظ hooks معرف جلسة أصليًا. ثبّت hooks بعد تثبيت agent CLI حتى يكون ملفه التنفيذي على `PATH`:

```bash
bmux hooks setup
bmux hooks setup codex
bmux hooks setup --agent opencode
```

يثبّت `bmux hooks setup` الوكلاء المدعومين الذين يعثر عليهم ويطبع ملخصًا للوكلاء المتخطَّين. تشمل تكاملات الاستئناف المدعومة Claude Code وCodex وGrok وOpenCode وPi وAmp وCursor CLI وGemini وRovo Dev وCopilot وCodeBuddy وFactory وQoder. يتعامل مع Claude Code غلاف bmux الخاص بـ Claude عند تفعيل تكامل Claude في الإعدادات.

يمكن للمستخدمين المتقدمين والتكاملات ربط أمر استئناف مخصص بسطح الطرفية الحالي. هذا مفيد للأدوات التي تملك حالة دائمة خاصة بها، مثل جلسات tmux أو واجهات agent CLI مخصصة:

```bash
bmux surface resume set --kind tmux --checkpoint work --shell "tmux attach -t work"
bmux surface resume show --json
bmux surface resume clear --checkpoint work
```

يبقى هذا الربط مرتبطًا بسطح bmux. تُحفظ الارتباطات التي ينشئها CLI العام أو socket للفحص والاستئناف اليدوي ما لم توافق على بادئة أمر موقّعة للاستئناف التلقائي. كما تُربط البادئات المعتمدة بمجلد العمل وقيم البيئة المحددة عند توفرها. راجع أو حرّر الموافقات في **الإعدادات > الطرفية > أوامر الاستئناف**. لا يشغّل bmux تلقائيًا إلا ارتباطات الاستئناف التي يضع عليها علامة موثوقة، مثل ارتباطات tmux المكتشفة من العمليات الحية أو البادئات المعتمدة من المستخدم. تُسقط مفاتيح البيئة الحساسة مثل الرموز وكلمات المرور والأسرار ومفاتيح API قبل حفظ ربط الاستئناف.

لإبقاء طرفيات الوكلاء المستعادة خاملة بدلًا من تشغيل أوامر الاستئناف تلقائيًا، أوقف **الإعدادات > الطرفية > استئناف جلسات الوكلاء عند إعادة الفتح** أو عيّن هذا في `~/.config/bmux/bmux.json`:

```json
{
  "terminal": {
    "autoResumeAgentSessions": false
  }
}
```

هذا يعطّل فقط أوامر استئناف الوكلاء التلقائية. لا يزال bmux يستعيد التخطيط المحفوظ ومجلدات العمل وسجل التمرير وسجل المتصفح.

إذا احتجت إلى إعادة تطبيق آخر لقطة محفوظة يدويًا، استخدم:
- `File > Reopen Previous Session`
- `⌘ ⇧ O`
- `bmux restore-session`

في الخلفية، يكتب bmux لقطة مُصدَّرة تحت `~/Library/Application Support/bmux/` وتكتب hooks الوكلاء تعيينات الجلسات تحت `~/.bmuxterm/`. عند الاستعادة، يعيد bmux بناء التخطيط أولًا، ثم يشغّل أمر الاستئناف الأصلي للوكيل المدعوم عند تفعيل الاستئناف التلقائي للوكلاء.

اقرأ الدليل الكامل على <https://bmux.com/docs/session-restore>.

## الأسئلة الشائعة

### ما علاقة bmux بـ Ghostty؟

bmux ليس نسخة معدّلة (fork) من Ghostty. إنه يستخدم [libghostty](https://github.com/ghostty-org/ghostty) كمكتبة لعرض الطرفية، بنفس الطريقة التي تستخدم بها التطبيقات WebKit لعروض الويب. Ghostty هو طرفية مستقلة؛ أما bmux فهو تطبيق مختلف مبني فوق محرك العرض الخاص به.

### ما المنصات التي يدعمها؟

macOS فقط، في الوقت الحالي. bmux تطبيق أصلي مبني بـ Swift وAppKit.

### هل يوجد تطبيق iOS؟

نعم، في مرحلة تجريبية. اقرن iPhone بجهاز Mac من نافذة Mobile Connect واتصل بطرفياتك من هاتفك، مع إمكانية اختيارية لإعادة توجيه إشعارات الطرفية. يُطرح على TestFlight باسم bmux BETA. راجع [وثائق iOS](https://bmux.com/docs/ios).

### ما وكلاء البرمجة الذين يعمل معهم bmux؟

جميعهم. bmux طرفية، لذا فإن أي وكيل يعمل في الطرفية يعمل بشكل مباشر: Claude Code وCodex وOpenCode وGemini CLI وKiro وAider وGoose وAmp وCline وCursor Agent، وأي شيء آخر يمكنك تشغيله من سطر الأوامر.

### هل يستطيع bmux تنسيق عدة وكلاء ووكلاء فرعيين؟

نعم. عندما يولّد وكيل وكلاء فرعيين أو زملاء فريق، يحوّلهم bmux إلى أجزاء وتقسيمات أصلية بدلًا من عمليات خلفية مخفية. وهو يدعم [Claude Code teams](https://bmux.com/docs/agent-integrations/claude-code-teams) وتنسيق متعدد النماذج عبر [oh-my-opencode](https://bmux.com/docs/agent-integrations/oh-my-opencode)، بحيث يكون كل وكيل في التشغيل مرئيًا وقابلًا للتحكم.

### هل يمكنني استخدام bmux مع الأجهزة البعيدة؟

نعم. افتح مساحات العمل عبر SSH واتصل بجلسات tmux البعيدة، حتى يتمكن الوكلاء من العمل على مضيف بعيد بينما تتحكم بهم من bmux. راجع [SSH والوصول البعيد](https://bmux.com/docs/ssh).

### كيف تعمل الإشعارات؟

عندما تحتاج عملية ما إلى الانتباه، يعرض bmux حلقات إشعارات حول الأجزاء وشارات غير مقروءة في الشريط الجانبي ونافذة منبثقة للإشعارات وإشعارًا على سطح مكتب macOS. تظهر هذه تلقائيًا عبر تسلسلات الهروب القياسية للطرفية (OSC 9/99/777)، أو يمكنك تشغيلها باستخدام [bmux CLI](https://bmux.com/docs/notifications#cli-usage) و[خطافات الوكلاء](https://bmux.com/docs/notifications#integration-examples). أي وكيل يدعم hooks أو OSC يعمل، بما في ذلك Claude Code وCodex وOpenCode وpi.

### هل bmux قابل للبرمجة؟

نعم. كل إجراء متاح عبر bmux CLI وعبر مقبس Unix: إنشاء مساحات العمل، فتح الأجزاء المقسمة، إرسال المدخلات، قراءة محتويات الشاشة، التقاط لقطات الشاشة، وقيادة المتصفح المدمج. راجع [مرجع CLI](https://bmux.com/docs/api) ووثائق [أتمتة المتصفح](https://bmux.com/docs/browser-automation).

### ماذا يمكن للمتصفح المدمج أن يفعل؟

يستطيع bmux تقسيم جزء متصفح حقيقي بجانب الطرفية، وهو قابل للبرمجة بالكامل: التنقل والتقاط لقطة DOM والنقر والكتابة وتنفيذ JavaScript وقراءة نشاط وحدة التحكم والشبكة عبر نفس socket API. يستخدمه الوكلاء للتحقق من تغييرات الويب الخاصة بهم دون مغادرة bmux. راجع [أتمتة المتصفح](https://bmux.com/docs/browser-automation).

### هل يملك bmux مهارات (skills)؟

نعم. المهارات هي سير عمل قابل لإعادة الاستخدام يمكنك منحه لأي وكيل يعمل في bmux، لأمور مثل التحكم عبر CLI وأتمتة مساحات العمل والإعدادات وأسطح المتصفح. تصفّح المجموعة المفتوحة على [bmux-skills](https://github.com/manaflow-ai/bmux-skills)، أو اقرأ [وثائق المهارات](https://bmux.com/docs/skills).

### هل يمكنني تخصيص اختصارات لوحة المفاتيح؟

تُقرأ اختصارات الطرفية من ملف إعداد Ghostty (`~/.config/ghostty/config`). أما الاختصارات الخاصة بـ bmux (مساحات العمل والتقسيمات والمتصفح والإشعارات) فيمكن تخصيصها في الإعدادات. راجع [الاختصارات الافتراضية](https://bmux.com/docs/keyboard-shortcuts) للحصول على قائمة كاملة.

### هل يمكنني تخصيص bmux؟

نعم. يستخدم عرض الطرفية إعداد Ghostty الخاص بك، لذا تنتقل السمات والخطوط والألوان والمؤشر مباشرة. تتحكم إعدادات bmux الخاصة في `~/.config/bmux/bmux.json` بالشريط الجانبي وشريط علامات التبويب والأجزاء المقسمة والسلوك، وكل [اختصار لوحة مفاتيح](https://bmux.com/docs/keyboard-shortcuts) قابل للتحرير. راجع [الإعداد](https://bmux.com/docs/configuration).

### هل تُحفظ جلساتي؟

نعم. يستعيد bmux نوافذك ومساحات عملك وأجزاءك ومجلدات العمل وسجل التمرير عند إعادة التشغيل، وتبقى الحالة بعد إعادة تشغيل الكمبيوتر بالكامل، وليس فقط عند إغلاق التطبيق. كما تعود جلسات الوكلاء مثل Claude Code وCodex وOpenCode. راجع [استعادة الجلسة](https://bmux.com/docs/session-restore).

### كيف يقارَن بـ tmux؟

tmux هو مُضاعِف طرفية يعمل داخل أي طرفية. أما bmux فهو تطبيق macOS أصلي بواجهة رسومية: علامات تبويب عمودية وأجزاء مقسمة ومتصفح مدمج وsocket API، كلها مبنية بالداخل، بدون ملفات إعداد أو مفاتيح بادئة. ومع ذلك، يستخدم كثير من الناس bmux مع SSH وtmux معًا بسعادة، ويمكن لـ bmux الاتصال بجلسات tmux البعيدة الخاصة بك بشكل أصلي ([تجريبي](https://bmux.com/docs/remote-tmux)).

### هل bmux مجاني؟

نعم، bmux مجاني الاستخدام. الكود المصدري متاح على [GitHub](https://github.com/manaflow-ai/bmux).

### كيف يمكنني دعم bmux؟

bmux مجاني ومفتوح المصدر، وسيظل كذلك دائمًا. إذا كنت ترغب في دعم التطوير والحصول على وصول مبكر لما هو قادم، بما في ذلك bmux AI وتطبيق iOS وCloud VMs، فاطّلع على [bmux Founders Edition](https://github.com/manaflow-ai/bmux#founders-edition).

### لدي طلب ميزة أو وجدت خطأ؟

نريد أن نسمعه. افتح [issue](https://github.com/manaflow-ai/bmux/issues) أو [pull request](https://github.com/manaflow-ai/bmux/pulls) على GitHub، أو [راسلنا عبر البريد الإلكتروني](mailto:founders@manaflow.com?subject=bmux%20feature%20request).

## تاريخ النجوم

<a href="https://star-history.com/#manaflow-ai/bmux&Date">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=manaflow-ai/bmux&type=Date&theme=dark" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=manaflow-ai/bmux&type=Date" />
   <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=manaflow-ai/bmux&type=Date" width="600" />
 </picture>
</a>

## المساهمة

طرق للمشاركة:

- تابعنا على X للتحديثات [@manaflowai](https://x.com/manaflowai)، [@lawrencecchen](https://x.com/lawrencecchen)، و[@austinywang](https://x.com/austinywang)
- انضم إلى المحادثة على [Discord](https://discord.gg/xsgFEVrWCZ)
- أنشئ وشارك في [قضايا GitHub](https://github.com/manaflow-ai/bmux/issues) و[المناقشات](https://github.com/manaflow-ai/bmux/discussions)
- أخبرنا بما تبنيه باستخدام bmux

## المجتمع

- [Discord](https://discord.gg/xsgFEVrWCZ)
- [GitHub](https://github.com/manaflow-ai/bmux)
- [X / Twitter](https://twitter.com/manaflowai)
- [YouTube](https://www.youtube.com/channel/UCAa89_j-TWkrXfk9A3CbASw)
- [LinkedIn](https://www.linkedin.com/company/manaflow-ai/)
- [Reddit](https://www.reddit.com/r/bmux/)

<p>
  <strong>WeChat:</strong> امسح رمز QR للانضمام إلى المجتمع.<br />
  <img src="./docs/assets/wechat-community-qr.jpg" alt="رمز QR على WeChat للانضمام إلى مجتمع bmux" width="240" />
</p>

## إصدار المؤسسين

bmux مجاني ومفتوح المصدر وسيظل كذلك دائمًا. إذا كنت ترغب في دعم التطوير والحصول على وصول مبكر لما هو قادم:

**[احصل على إصدار المؤسسين](https://buy.stripe.com/3cI00j2Ld0it5OU33r5EY0q)**

- **أولوية لطلبات الميزات/إصلاح الأخطاء**
- **وصول مبكر: ذكاء اصطناعي لـ bmux يمنحك سياقًا عن كل مساحة عمل وعلامة تبويب ولوحة**
- **وصول مبكر: تطبيق iOS مع مزامنة الطرفيات بين سطح المكتب والهاتف**
- **وصول مبكر: أجهزة افتراضية سحابية**
- **وصول مبكر: وضع الصوت**
- **iMessage/WhatsApp الشخصي الخاص بي**

## الرخصة

bmux مفتوح المصدر بموجب [GPL-3.0-or-later](LICENSE).

إذا لم تستطع مؤسستك الامتثال لـ GPL، فهناك ترخيص تجاري متاح. تواصل مع [founders@manaflow.com](mailto:founders@manaflow.com) للتفاصيل.
