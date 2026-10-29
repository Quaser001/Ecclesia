// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appName => 'CalFit';

  @override
  String get tryAgain => 'फिर से कोशिश करें';

  @override
  String get cancel => 'रद्द करें';

  @override
  String get save => 'सेव करें';

  @override
  String get done => 'हो गया';

  @override
  String get edit => 'बदलें';

  @override
  String get add => 'जोड़ें';

  @override
  String get close => 'बंद करें';

  @override
  String get back => 'वापस';

  @override
  String get seeAll => 'सभी देखें';

  @override
  String get saved => 'सेव हो गया';

  @override
  String get notSet => 'नहीं भरा';

  @override
  String get unknownBrand => 'ब्रांड पता नहीं';

  @override
  String get unnamedProduct => 'बिना नाम का प्रोडक्ट';

  @override
  String get scanAProduct => 'प्रोडक्ट स्कैन करें';

  @override
  String get navHome => 'होम';

  @override
  String get navHistory => 'इतिहास';

  @override
  String get navInsights => 'इनसाइट्स';

  @override
  String get navProfile => 'प्रोफ़ाइल';

  @override
  String get timeJustNow => 'अभी';

  @override
  String timeMinutes(int n) {
    return '$n मि.';
  }

  @override
  String timeHours(int n) {
    return '$n घं.';
  }

  @override
  String timeDays(int n) {
    return '$n दिन';
  }

  @override
  String get today => 'आज';

  @override
  String get yesterday => 'कल';

  @override
  String get errorNetwork =>
      'CalFit सर्वर तक नहीं पहुँच पा रहे। इंटरनेट जाँचें और फिर कोशिश करें।';

  @override
  String get errorTimeout => 'बहुत समय लग गया। कृपया फिर कोशिश करें।';

  @override
  String get errorServer =>
      'CalFit सर्वर में अभी दिक्कत है। थोड़ी देर बाद कोशिश करें।';

  @override
  String get errorNotFound => 'यह नहीं मिला।';

  @override
  String get errorUnauthorized =>
      'आपका सेशन रीफ़्रेश करना होगा। कृपया फिर कोशिश करें।';

  @override
  String get errorScanLimit =>
      'आज की स्कैन सीमा पूरी हो गई। यह आधी रात (UTC) को रीसेट होगी।';

  @override
  String get errorProfileReset =>
      'आपका साइन-इन रीसेट हो गया है, इसलिए आपकी स्वास्थ्य प्रोफ़ाइल अब हमारे सर्वर पर नहीं है। स्कैन करने से पहले कृपया प्रोफ़ाइल में इसे फिर से भरें।';

  @override
  String get errorPrescriptionLimit =>
      'आज की प्रिस्क्रिप्शन सीमा पूरी हो गई है। कृपया कल फिर कोशिश करें।';

  @override
  String get errorGeneric => 'कुछ गड़बड़ हो गई। कृपया फिर कोशिश करें।';

  @override
  String get errorImageOpen => 'यह फ़ोटो नहीं खुल सकी। कृपया दूसरी चुनें।';

  @override
  String get greetingStillUp => 'अभी तक जाग रहे हैं';

  @override
  String get greetingMorning => 'सुप्रभात';

  @override
  String get greetingAfternoon => 'नमस्कार';

  @override
  String get greetingEvening => 'शुभ संध्या';

  @override
  String get greetingNight => 'शुभ रात्रि';

  @override
  String get homeTitleNoName => 'आइए अपना खाना जाँचें';

  @override
  String get homeErrorTitle => 'डैशबोर्ड लोड नहीं हो सका';

  @override
  String latestScan(String when) {
    return 'आख़िरी स्कैन · $when';
  }

  @override
  String get firstScanTitle => 'अपना पहला प्रोडक्ट स्कैन करें';

  @override
  String get firstScanBody =>
      'किसी भी पैक्ड खाने के पीछे की फ़ोटो लें। हम लेबल पढ़कर बताएँगे कि यह आपकी प्रोफ़ाइल के लिए कितना सही है।';

  @override
  String get personaliseTitle => 'स्कोर को अपने हिसाब से बनाएँ';

  @override
  String get personaliseBody => 'अपनी बीमारियाँ, एलर्जी और लक्ष्य जोड़ें।';

  @override
  String get statScans => 'स्कैन';

  @override
  String get statAverage => 'औसत';

  @override
  String get statBest => 'सबसे अच्छा';

  @override
  String get scoringForYou => 'आपके लिए स्कोरिंग';

  @override
  String get scoringEmpty =>
      'अभी कुछ नहीं जोड़ा, इसलिए स्कोर सामान्य सलाह पर हैं।';

  @override
  String get scoredForTitle => 'किसके लिए स्कोर किया गया';

  @override
  String get scoredForNote =>
      'स्कैन करते समय की आपकी प्रोफ़ाइल। बाद में प्रोफ़ाइल बदलने से यह रेटिंग नहीं बदलती।';

  @override
  String get scoredForNone =>
      'कोई एलर्जी, बीमारी, आहार या लक्ष्य नहीं चुना गया था।';

  @override
  String get switchProfile => 'प्रोफ़ाइल बदलें';

  @override
  String get profilesTitle => 'इस फ़ोन पर प्रोफ़ाइल';

  @override
  String get profileMe => 'मैं';

  @override
  String get addFamilyMember => 'परिवार का सदस्य जोड़ें';

  @override
  String get memberNameLabel => 'उनका नाम';

  @override
  String get familyAdultsNote =>
      'वयस्कों (18+) के लिए। हर व्यक्ति की बीमारियाँ, एलर्जी, स्कैन और इतिहास अलग रखे जाते हैं।';

  @override
  String allergyChip(String name) {
    return '$name से एलर्जी';
  }

  @override
  String get recentScans => 'हाल के स्कैन';

  @override
  String get switchToLight => 'लाइट मोड पर जाएँ';

  @override
  String get switchToDark => 'डार्क मोड पर जाएँ';

  @override
  String get historyTitle => 'इतिहास';

  @override
  String get historyErrorTitle => 'इतिहास लोड नहीं हो सका';

  @override
  String get historyEmptyTitle => 'अभी यहाँ कुछ नहीं';

  @override
  String get historyEmptyBody =>
      'आप जो भी स्कैन करेंगे, वह स्कोर के साथ यहाँ दिखेगा, ताकि आप कभी भी देख सकें।';

  @override
  String get insightsTitle => 'इनसाइट्स';

  @override
  String get insightsErrorTitle => 'इनसाइट्स लोड नहीं हो सके';

  @override
  String get insightsEmptyTitle => 'आपके ट्रेंड यहाँ दिखेंगे';

  @override
  String get insightsEmptyBody =>
      'कुछ प्रोडक्ट स्कैन करें, फिर आपको औसत स्कोर, सबसे ज़्यादा पकड़ी गई बातें और आपकी अच्छी पसंद दिखेंगी।';

  @override
  String get averageScore => 'औसत स्कोर';

  @override
  String scanCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count स्कैन',
      one: '1 स्कैन',
    );
    return '$_temp0';
  }

  @override
  String get weekByWeek => 'हफ़्ते दर हफ़्ते';

  @override
  String get weekByWeekBody => 'हर हफ़्ते स्कैन किए गए प्रोडक्ट का औसत स्कोर';

  @override
  String weekNoScans(String date) {
    return '$date का हफ़्ता: कोई स्कैन नहीं';
  }

  @override
  String weekSummary(String date, String score, int count) {
    return '$date का हफ़्ता: $count स्कैन से औसत $score';
  }

  @override
  String get flaggedMost => 'सबसे ज़्यादा पकड़ी गई बातें';

  @override
  String get flaggedMostBody => 'आपके स्कैन में मिली समस्याएँ';

  @override
  String countOfTotal(int count, int total) {
    return '$total में से $count';
  }

  @override
  String get bestPicks => 'आपकी अच्छी पसंद';

  @override
  String get secondLook => 'दोबारा देखने लायक';

  @override
  String get secondLookBody => 'जिनका स्कोर आपकी प्रोफ़ाइल के लिए कम रहा';

  @override
  String basedOnScans(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'आपके पिछले $count स्कैन पर आधारित।',
      one: 'आपके आख़िरी स्कैन पर आधारित।',
    );
    return '$_temp0';
  }

  @override
  String get yourGoals => 'आपके लक्ष्य';

  @override
  String get yourGoalsBody => 'आपके स्कैन आपके लक्ष्यों से कितना मेल खाते हैं';

  @override
  String goalFits(int fits, int checked) {
    return '$checked में से $fits स्कैन इस लक्ष्य के अनुकूल';
  }

  @override
  String get goalNoData =>
      'अभी तक इस लक्ष्य के लिए ज़रूरी जानकारी वाला कोई स्कैन नहीं।';

  @override
  String get goalNotTracked =>
      'अभी ट्रैक नहीं होता। इस लक्ष्य के लिए CalFit में कोई नियम नहीं है।';

  @override
  String goalMainIssue(String issue) {
    return 'सबसे आम समस्या: $issue';
  }

  @override
  String goalChecks(String basis) {
    return 'जाँच: $basis';
  }

  @override
  String get addGoalsPrompt =>
      'प्रोफ़ाइल में लक्ष्य जोड़ें, ताकि देख सकें कि आपके स्कैन उनसे कितना मेल खाते हैं।';

  @override
  String toTargetLose(String kg) {
    return 'लक्ष्य वज़न से $kg kg ज़्यादा';
  }

  @override
  String toTargetGain(String kg) {
    return 'लक्ष्य वज़न से $kg kg कम';
  }

  @override
  String get atTarget => 'आप अपने लक्ष्य वज़न पर हैं';

  @override
  String get goal_weight_loss => 'वज़न घटाना';

  @override
  String get goal_muscle_gain => 'मसल बढ़ाना';

  @override
  String get goal_maintain_weight => 'वज़न बनाए रखना';

  @override
  String get goal_improve_energy => 'ज़्यादा ऊर्जा';

  @override
  String get goal_improve_digestion => 'बेहतर पाचन';

  @override
  String get goal_reduce_inflammation => 'कम सूजन';

  @override
  String get goal_manage_blood_sugar => 'ब्लड शुगर नियंत्रण';

  @override
  String get goal_heart_health => 'दिल की सेहत';

  @override
  String get condition_diabetes_type_1 => 'टाइप 1 डायबिटीज़';

  @override
  String get condition_diabetes_type_2 => 'टाइप 2 डायबिटीज़';

  @override
  String get condition_prediabetes => 'प्रीडायबिटीज़';

  @override
  String get condition_hypertension => 'हाई ब्लड प्रेशर';

  @override
  String get condition_high_cholesterol => 'हाई कोलेस्ट्रॉल';

  @override
  String get condition_celiac_disease => 'सीलिएक रोग';

  @override
  String get condition_ibs => 'IBS';

  @override
  String get condition_kidney_disease => 'किडनी रोग';

  @override
  String get condition_heart_disease => 'हृदय रोग';

  @override
  String get condition_obesity => 'मोटापा';

  @override
  String get condition_lactose_intolerance => 'लैक्टोज़ इनटॉलरेंस';

  @override
  String get condition_anaemia => 'एनीमिया';

  @override
  String get diet_vegetarian => 'शाकाहारी';

  @override
  String get diet_vegan => 'वीगन';

  @override
  String get diet_gluten_free => 'ग्लूटेन-फ़्री';

  @override
  String get diet_dairy_free => 'डेयरी-फ़्री';

  @override
  String get diet_halal => 'हलाल';

  @override
  String get diet_kosher => 'कोशर';

  @override
  String get diet_low_carb => 'लो कार्ब';

  @override
  String get diet_keto => 'कीटो';

  @override
  String get diet_paleo => 'पैलियो';

  @override
  String get suitabilityExcellent => 'बहुत अच्छा मेल';

  @override
  String get suitabilityGood => 'अच्छा मेल';

  @override
  String get suitabilityFair => 'ठीक-ठाक मेल';

  @override
  String get suitabilityPoor => 'कमज़ोर मेल';

  @override
  String get suitabilityNotSuitable => 'अनुकूल नहीं';

  @override
  String get suitabilityUnknown => 'पता नहीं';

  @override
  String get profileTitle => 'प्रोफ़ाइल';

  @override
  String get settingsTooltip => 'सेटिंग्स';

  @override
  String get profileErrorTitle => 'प्रोफ़ाइल लोड नहीं हो सकी';

  @override
  String get addYourName => 'अपना नाम जोड़ें';

  @override
  String get introduceYourself => 'अपना परिचय देने के लिए पेंसिल पर टैप करें';

  @override
  String get signedInAnonymously => 'इस डिवाइस पर बिना नाम के साइन इन';

  @override
  String get editName => 'नाम बदलें';

  @override
  String get profileSetup => 'प्रोफ़ाइल सेटअप';

  @override
  String filledOf(int filled, int total) {
    return '$total में से $filled';
  }

  @override
  String get moreAccurate =>
      'आप जितना ज़्यादा जोड़ेंगे, स्कोर उतने सटीक होंगे।';

  @override
  String get sectionGoals => 'लक्ष्य';

  @override
  String get goalsCaption => 'आप किस चीज़ के लिए मेहनत कर रहे हैं?';

  @override
  String get sectionConditions => 'बीमारियाँ';

  @override
  String get conditionsCaption =>
      'इन्हें बढ़ाने वाले प्रोडक्ट का स्कोर हम घटा देते हैं।';

  @override
  String get sectionDiet => 'डाइट';

  @override
  String get dietCaption => 'इन्हें तोड़ने वाले प्रोडक्ट हम चिह्नित करते हैं।';

  @override
  String get sectionAllergies => 'एलर्जी';

  @override
  String get allergiesCaption =>
      'इनमें से कुछ भी सामग्री में हो तो हम चेतावनी देते हैं।';

  @override
  String get yourName => 'आपका नाम';

  @override
  String get nameHint => 'हम आपको क्या बुलाएँ?';

  @override
  String get allergiesHint => 'जैसे मूँगफली, सोया';

  @override
  String get noAllergies => 'कोई एलर्जी नहीं जोड़ी।';

  @override
  String get addAllergy => 'एलर्जी जोड़ें';

  @override
  String get takePhoto => 'फ़ोटो लें';

  @override
  String get chooseFromGallery => 'गैलरी से चुनें';

  @override
  String get bodyTitle => 'शरीर';

  @override
  String get bodyCaption =>
      'वैकल्पिक। BMI और आपके लक्ष्यों को ट्रैक करने के लिए।';

  @override
  String get addBodyDetails => 'लंबाई, वज़न और भी जोड़ें';

  @override
  String get bodyEditTitle => 'शरीर की जानकारी';

  @override
  String get height => 'लंबाई';

  @override
  String get weight => 'वज़न';

  @override
  String get targetWeight => 'लक्ष्य वज़न';

  @override
  String get bmi => 'BMI';

  @override
  String get age => 'उम्र';

  @override
  String get birthYear => 'जन्म वर्ष';

  @override
  String get sex => 'लिंग';

  @override
  String get sexFemale => 'महिला';

  @override
  String get sexMale => 'पुरुष';

  @override
  String get sexOther => 'अन्य';

  @override
  String get activityLevel => 'सक्रियता स्तर';

  @override
  String get activity_sedentary => 'कम सक्रिय';

  @override
  String get activity_sedentary_hint => 'बैठकर काम, बहुत कम व्यायाम';

  @override
  String get activity_light => 'थोड़ा सक्रिय';

  @override
  String get activity_light_hint => 'हफ़्ते में 1–3 दिन हल्का व्यायाम';

  @override
  String get activity_moderate => 'मध्यम सक्रिय';

  @override
  String get activity_moderate_hint => 'हफ़्ते में 3–5 दिन व्यायाम';

  @override
  String get activity_active => 'सक्रिय';

  @override
  String get activity_active_hint => 'हफ़्ते में 6–7 दिन कड़ा व्यायाम';

  @override
  String get activity_very_active => 'बहुत सक्रिय';

  @override
  String get activity_very_active_hint => 'शारीरिक काम और ट्रेनिंग';

  @override
  String get unitCm => 'cm';

  @override
  String get unitKg => 'kg';

  @override
  String ageYears(int age) {
    return '$age वर्ष';
  }

  @override
  String get bmiUnderweight => 'कम वज़न';

  @override
  String get bmiNormal => 'स्वस्थ सीमा';

  @override
  String get bmiOverweight => 'ज़्यादा वज़न';

  @override
  String get bmiObese => 'मोटापा';

  @override
  String get bmiNote =>
      'भारतीयों के लिए BMI सीमा: 18.5–22.9 स्वस्थ, 23–24.9 ज़्यादा वज़न, 25+ मोटापा।';

  @override
  String get bmiNeedsBoth => 'BMI देखने के लिए लंबाई और वज़न जोड़ें।';

  @override
  String invalidRange(String min, String max) {
    return '$min से $max के बीच कोई संख्या लिखें';
  }

  @override
  String get clearValue => 'हटाएँ';

  @override
  String get prescription => 'प्रिस्क्रिप्शन';

  @override
  String get prescriptionReading => 'आपका प्रिस्क्रिप्शन पढ़ रहे हैं…';

  @override
  String get prescriptionBody =>
      'स्कैन करें, हम बीमारियाँ और एलर्जी सुझाएँगे। कुछ भी सेव करने से पहले आप पुष्टि करेंगे।';

  @override
  String get prescriptionConsentTitle => 'प्रिस्क्रिप्शन पढ़ें?';

  @override
  String get prescriptionConsentGemini =>
      'आपकी फ़ोटो पढ़ने के लिए Google Gemini को भेजी जाती है।';

  @override
  String get prescriptionConsentNoSave =>
      'CalFit फ़ोटो या उससे पढ़ी गई जानकारी सेव नहीं करता।';

  @override
  String get prescriptionConsentSuggestOnly =>
      'हम सिर्फ़ बीमारियाँ और एलर्जी सुझाते हैं। जब तक आप टिक करके पुष्टि न करें, कुछ नहीं जुड़ता।';

  @override
  String get prescriptionConsentNotAdvice =>
      'यह मेडिकल सलाह नहीं है। हर सुझाव जाँचें।';

  @override
  String get agreeAndContinue => 'सहमत हूँ, आगे बढ़ें';

  @override
  String get reviewTitle => 'जाँचें';

  @override
  String get selectWhatToAdd => 'क्या जोड़ना है चुनें';

  @override
  String addSelected(int count) {
    return 'चुने हुए जोड़ें ($count)';
  }

  @override
  String get nothingToAdd => 'इस फ़ोटो से जोड़ने लायक कुछ नहीं मिला।';

  @override
  String get tickWhatApplies =>
      'जो आप पर लागू हो उसे टिक करें। पुष्टि तक कुछ नहीं जुड़ता।';

  @override
  String inferredFromMedicine(String medicine) {
    return 'दवा ($medicine) से अनुमान। जाँचें कि यह आप पर लागू होता है।';
  }

  @override
  String get statedOnPrescription => 'प्रिस्क्रिप्शन में लिखा है';

  @override
  String get readNotAdded => 'पढ़ा गया पर जोड़ा नहीं';

  @override
  String get newScan => 'नया स्कैन';

  @override
  String get scanHeadline => 'पैक के पीछे की फ़ोटो लें';

  @override
  String get scanBody =>
      'सामग्री और पोषण तालिका फ़्रेम में रखें। हम इसे आपकी बीमारियों, एलर्जी और लक्ष्यों से मिलाकर देखेंगे।';

  @override
  String get tapToTakePhoto => 'फ़ोटो लेने के लिए टैप करें';

  @override
  String get orPickFromGallery => 'या अपनी गैलरी से चुनें';

  @override
  String get camera => 'कैमरा';

  @override
  String get gallery => 'गैलरी';

  @override
  String get checkThisProduct => 'यह प्रोडक्ट जाँचें';

  @override
  String get removePhoto => 'फ़ोटो हटाएँ';

  @override
  String get tipsTitle => 'सबसे अच्छे नतीजे के लिए';

  @override
  String get tipBackOfPack =>
      'आगे की फ़ोटो चलेगी; पीछे की फ़ोटो से पूरी जाँच होती है';

  @override
  String get tipLight => 'अच्छी रोशनी, प्लास्टिक पर चमक न हो';

  @override
  String get tipFillFrame => 'सामग्री और पोषण तालिका से फ़्रेम भरें';

  @override
  String get stepReadingLabel => 'लेबल पढ़ रहे हैं';

  @override
  String get stepCheckingProfile => 'आपकी प्रोफ़ाइल देख रहे हैं';

  @override
  String get stepWeighing => 'नतीजे परख रहे हैं';

  @override
  String get stepAlternatives => 'विकल्प ढूँढ रहे हैं';

  @override
  String get scanResultTitle => 'स्कैन का नतीजा';

  @override
  String get scanDetailsTitle => 'स्कैन की जानकारी';

  @override
  String get couldntOpenScan => 'यह स्कैन नहीं खुल सका';

  @override
  String get cantReadLabel => 'यह लेबल पढ़ा नहीं जा सका';

  @override
  String get cantReadLabelBody =>
      'फ़ोटो धुंधली थी या लेबल फ़्रेम से बाहर था। पैक के पीछे की साफ़ और पास से ली गई फ़ोटो आम तौर पर काम करती है।';

  @override
  String get tryAnotherPhoto => 'दूसरी फ़ोटो आज़माएँ';

  @override
  String scannedWhen(String when) {
    return 'स्कैन किया $when';
  }

  @override
  String get outOf10 => '10 में से';

  @override
  String scoreOutOf10(String score) {
    return 'स्कोर 10 में से $score';
  }

  @override
  String whatWeFound(int count) {
    return 'हमें क्या मिला ($count)';
  }

  @override
  String get severityAvoid => 'बचें';

  @override
  String get severityCaution => 'सावधान';

  @override
  String get severityHeadsUp => 'ध्यान दें';

  @override
  String get severityGoodToKnow => 'जानने लायक';

  @override
  String pointsLost(String points) {
    return '−$points अंक';
  }

  @override
  String get onTheLabel => 'लेबल पर';

  @override
  String get perServingNote => 'प्रति सर्विंग। डैश का मतलब लेबल पर नहीं था।';

  @override
  String get nutrientCalories => 'कैलोरी';

  @override
  String get nutrientTotalFat => 'कुल फ़ैट';

  @override
  String get nutrientSaturatedFat => 'सैचुरेटेड फ़ैट';

  @override
  String get nutrientSodium => 'सोडियम';

  @override
  String get nutrientCarbs => 'कुल कार्ब्स';

  @override
  String get nutrientSugars => 'शुगर';

  @override
  String get nutrientProtein => 'प्रोटीन';

  @override
  String get ingredients => 'सामग्री';

  @override
  String get tryInstead => 'इसके बजाय आज़माएँ';

  @override
  String get tryInsteadBody =>
      'उसी कैटेगरी के असली प्रोडक्ट जो आपके लिए बेहतर हैं';

  @override
  String get inOurDatabase => 'हमारे डेटाबेस में';

  @override
  String get noAlternative => 'इसके लिए कोई बेहतर विकल्प सुझाने को नहीं है।';

  @override
  String get serverTextNote => 'स्कैन की जानकारी अभी अंग्रेज़ी में है।';

  @override
  String get disclaimerShort =>
      'CalFit लेबल पढ़ता है; यह मेडिकल सलाह नहीं है। निदान या इलाज के लिए डॉक्टर या डाइटीशियन से पूछें।';

  @override
  String get disclaimerTitle => 'शुरू करने से पहले एक बात';

  @override
  String get disclaimerBody =>
      'CalFit प्रोडक्ट का लेबल स्कैन करके बताता है कि वह आपकी प्रोफ़ाइल के लिए कितना सही है। यह डॉक्टर या डाइटीशियन की जगह नहीं ले सकता और इसे खाने की हर चीज़ का पता नहीं होता।\n\nअगर आपको एलर्जी है तो पैक ख़ुद ज़रूर पढ़ें, और किसी स्कैन की वजह से डाइट बदलने से पहले अपने डॉक्टर से पूछें।';

  @override
  String get gotIt => 'समझ गया';

  @override
  String get settingsTitle => 'सेटिंग्स';

  @override
  String get appearance => 'दिखावट';

  @override
  String get theme => 'थीम';

  @override
  String get themeSystem => 'फ़ोन जैसा';

  @override
  String get themeLight => 'लाइट';

  @override
  String get themeDark => 'डार्क';

  @override
  String get textSize => 'अक्षरों का आकार';

  @override
  String get textSizeSmall => 'छोटा';

  @override
  String get textSizeDefault => 'सामान्य';

  @override
  String get textSizeLarge => 'बड़ा';

  @override
  String get textSizeExtraLarge => 'बहुत बड़ा';

  @override
  String get textSizePreview =>
      'मसाला नूडल्स · प्रति 100 g में 1,172 mg सोडियम';

  @override
  String get language => 'भाषा';

  @override
  String get languagePhone => 'फ़ोन जैसी';

  @override
  String get translationNote =>
      'अनुवाद की जाँच मूल भाषी कर रहे हैं; कुछ शब्द बदल सकते हैं।';

  @override
  String get privacyAndData => 'गोपनीयता और डेटा';

  @override
  String get privacyPolicy => 'गोपनीयता नीति';

  @override
  String get deleteMyData => 'मेरा डेटा मिटाएँ';

  @override
  String get deleteMyDataBody =>
      'CalFit के सर्वर से आपकी प्रोफ़ाइल, स्कैन और फ़ोटो हटा देता है।';

  @override
  String get adultsOnlyBirthYear => 'CalFit वयस्कों (18+) के लिए है।';

  @override
  String get rxConsentSetting => 'पर्चा पढ़ना';

  @override
  String get rxConsentSettingOn =>
      'चालू। आपके चुने पर्चे की फ़ोटो पढ़ने के लिए भेजी जाती है। अपनी सहमति वापस लेने के लिए बंद करें।';

  @override
  String get rxConsentSettingOff => 'बंद। पर्चे से कुछ भी नहीं भेजा जाता।';

  @override
  String get rxConsentWithdrawn =>
      'सहमति वापस ली गई। पर्चे की फ़ोटो नहीं भेजी जाएगी।';

  @override
  String get consentTitle => 'शुरू करने से पहले';

  @override
  String get consentIntro =>
      'CalFit आपकी दी हुई स्वास्थ्य जानकारी का उपयोग करता है। कृपया पढ़ें कि हम क्या लेते हैं और क्यों, फिर सहमति दें।';

  @override
  String get consentWhatTitle => 'हम क्या लेते हैं, और क्यों';

  @override
  String get consentItemProfile =>
      'आपकी स्वास्थ्य प्रोफ़ाइल: बीमारियाँ, एलर्जी, आहार, लक्ष्य, और वैकल्पिक शारीरिक जानकारी (लंबाई, वज़न, जन्म वर्ष, लिंग, सक्रियता)। हर उत्पाद को आपके लिए आँकने के लिए।';

  @override
  String get consentItemScans =>
      'आपके स्कैन किए लेबल की फ़ोटो, और उनके नतीजे। लेबल पढ़ने, स्कोर देने और आपका इतिहास रखने के लिए।';

  @override
  String get consentItemToken =>
      'इस फ़ोन के लिए एक साइन-इन कोड। कोई नाम, ईमेल या फ़ोन नंबर नहीं। आपका डेटा बाकी सबसे अलग रखने और रोज़ की स्कैन सीमा लागू करने के लिए।';

  @override
  String get consentSharedTitle => 'और कौन इसे संभालता है';

  @override
  String get consentShared =>
      'Google Gemini लेबल की फ़ोटो पढ़ता है और व्याख्या लिखता है। उसे उत्पाद के निष्कर्ष मिलते हैं, आपकी प्रोफ़ाइल नहीं। आपका डेटा सिंगापुर में Supabase के पास रखा जाता है। कुछ भी बेचा या विज्ञापन के लिए इस्तेमाल नहीं किया जाता।';

  @override
  String get consentChoicesTitle => 'आपके विकल्प';

  @override
  String get consentChoices =>
      'आप कभी भी अपनी प्रोफ़ाइल बदल सकते हैं या कोई स्कैन हटा सकते हैं। सेटिंग्स → मेरा डेटा हटाएँ सब कुछ मिटा देता है और यह सहमति वापस ले लेता है। आप हमें लिख भी सकते हैं, या भारत के डेटा संरक्षण बोर्ड से शिकायत कर सकते हैं।';

  @override
  String get consentReadPolicy => 'पूरी गोपनीयता नीति पढ़ें';

  @override
  String get consentAdult => 'मेरी उम्र 18 वर्ष या उससे अधिक है';

  @override
  String get consentAgree => 'मैं सहमत हूँ';

  @override
  String get consentDeclineNote =>
      'अगर आप सहमत नहीं हैं, तो ऐप बंद कर दें। कोई स्वास्थ्य जानकारी नहीं भेजी गई है।';

  @override
  String get errorConsentRequired => 'कृपया पहले गोपनीयता सूचना से सहमति दें।';

  @override
  String get errorAppOutdated =>
      'CalFit का यह संस्करण पुराना है। जारी रखने के लिए इसे अपडेट करें।';

  @override
  String get deleteConfirmTitle => 'अपना सारा डेटा मिटाएँ?';

  @override
  String get deleteConfirmBody =>
      'आपकी प्रोफ़ाइल, हर स्कैन और हर फ़ोटो CalFit के सर्वर से हमेशा के लिए मिट जाएगी। इसे वापस नहीं लाया जा सकता।';

  @override
  String get deleteConfirmButton => 'सब मिटाएँ';

  @override
  String get dataDeleted => 'आपका डेटा मिटा दिया गया।';

  @override
  String get about => 'जानकारी';

  @override
  String version(String version) {
    return 'वर्शन $version';
  }

  @override
  String get dataSources => 'डेटा स्रोत';

  @override
  String get dataSourcesBody =>
      'प्रोडक्ट डेटा Open Food Facts (openfoodfacts.org) से, Open Database Licence के तहत। BMI सीमाएँ भारतीयों के लिए सहमत कट-ऑफ़ पर आधारित हैं।';

  @override
  String get notMedicalAdviceTitle => 'मेडिकल सलाह नहीं';

  @override
  String get viewPhoto => 'फ़ोटो देखें';

  @override
  String get onbWelcomeTitle => 'जानिए आपके खाने में क्या है';

  @override
  String get onbWelcomeBody =>
      'किसी भी पैक्ड खाने के पीछे की फ़ोटो लें। CalFit लेबल पढ़कर बताता है कि यह आपके लिए कितना सही है।';

  @override
  String get onbPointScan =>
      'भारतीय पैक के लिए: बिस्किट, नमकीन, नूडल्स, ड्रिंक्स और भी';

  @override
  String get onbPointPersonal =>
      'स्कोर आपकी बीमारियों, एलर्जी और लक्ष्यों के हिसाब से बदलते हैं';

  @override
  String get onbPointAlternatives =>
      'आपके लिए बेहतर, मिलते-जुलते असली प्रोडक्ट सुझाता है';

  @override
  String get onbChooseLanguage => 'अपनी भाषा चुनें';

  @override
  String get onbProfileTitle => 'अपने बारे में थोड़ा बताएँ';

  @override
  String get onbProfileBody =>
      'जो भी लागू हो चुनें। आप इसे कभी भी प्रोफ़ाइल में बदल सकते हैं।';

  @override
  String get onbAllergiesTitle => 'एलर्जी';

  @override
  String get onbConditionsTitle => 'स्वास्थ्य समस्याएँ';

  @override
  String get onbDietTitle => 'डाइट';

  @override
  String get onbSafetyTitle => 'एक ज़रूरी बात';

  @override
  String get onbGetStarted => 'शुरू करें';

  @override
  String get onbNext => 'आगे';

  @override
  String get onbSkip => 'छोड़ें';

  @override
  String onbStep(int current, int total) {
    return 'चरण $current / $total';
  }

  @override
  String get allergy_peanut => 'मूँगफली';

  @override
  String get allergy_milk => 'दूध';

  @override
  String get allergy_gluten => 'ग्लूटेन';

  @override
  String get allergy_soy => 'सोया';

  @override
  String get allergy_egg => 'अंडा';

  @override
  String get allergy_tree_nuts => 'मेवे';

  @override
  String get nutrientSalt => 'नमक';

  @override
  String get atAGlance => 'एक नज़र में';

  @override
  String get levelsPer100g =>
      'प्रति 100 ग्राम, मानक ट्रैफ़िक-लाइट पैमाने पर। सबके लिए एक जैसा।';

  @override
  String get levelsPer100ml =>
      'प्रति 100 मिली, मानक ट्रैफ़िक-लाइट पैमाने पर। सबके लिए एक जैसा।';

  @override
  String get levelLow => 'कम';

  @override
  String get levelMedium => 'मध्यम';

  @override
  String get levelHigh => 'ज़्यादा';

  @override
  String get feedbackQuestion => 'क्या यह नतीजा सही था?';

  @override
  String get feedbackWhy =>
      'आपके जवाब से हम जाँचते हैं कि CalFit कितना सटीक है।';

  @override
  String get feedbackYes => 'हाँ';

  @override
  String get feedbackNo => 'पूरी तरह नहीं';

  @override
  String get feedbackWhatWrong => 'क्या ग़लत था?';

  @override
  String get issueWrongProduct => 'ग़लत प्रोडक्ट';

  @override
  String get issueWrongNutrition => 'पोषण के आँकड़े';

  @override
  String get issueWrongIngredients => 'सामग्री';

  @override
  String get issueMissedAllergen => 'एलर्जन छूट गया';

  @override
  String get issueScoreUnfair => 'स्कोर ग़लत लगा';

  @override
  String get issueOther => 'कुछ और';

  @override
  String get feedbackSend => 'भेजें';

  @override
  String get feedbackThanks =>
      'धन्यवाद। इससे हमें बेहतर बनने में मदद मिलती है।';

  @override
  String get feedbackFailed =>
      'भेजा नहीं जा सका। कनेक्शन जाँचें और फिर कोशिश करें।';

  @override
  String get pickerConfirmTitle => 'क्या यही प्रोडक्ट है?';

  @override
  String get pickerChooseTitle => 'इनमें से कौन-सा है?';

  @override
  String pickerReadAs(String text) {
    return 'हमने पैक पर “$text” पढ़ा।';
  }

  @override
  String get pickerYes => 'हाँ, यही है';

  @override
  String get pickerNoRetake => 'नहीं, फिर से फ़ोटो लें';

  @override
  String get pickerNoneRetake => 'इनमें से कोई नहीं, फिर से लें';

  @override
  String get sourceOpenFoodFacts => 'Open Food Facts';

  @override
  String get sourceCalfitDb => 'CalFit डेटाबेस';

  @override
  String get retakeHint =>
      'प्रोडक्ट का नाम साफ़ दिखाते हुए फिर से फ़ोटो लें, या पैक के पीछे की फ़ोटो लें।';

  @override
  String identifiedAs(String name) {
    return 'पहचाना गया: $name';
  }

  @override
  String identifiedSource(String source) {
    return 'पोषण प्रति 100 ग्राम/मिली, स्रोत: $source';
  }

  @override
  String get notThisProduct => 'यह प्रोडक्ट नहीं है?';

  @override
  String get removeScanTitle => 'यह स्कैन हटाएँ?';

  @override
  String get removeScanBody =>
      'यह आपकी हिस्ट्री से हट जाएगा ताकि आप फिर से फ़ोटो ले सकें।';

  @override
  String get remove => 'हटाएँ';

  @override
  String get scanRemoved =>
      'स्कैन हटा दिया गया। फिर से कोशिश करने के लिए स्कैन दबाएँ।';

  @override
  String get couldntRemove => 'स्कैन नहीं हट सका। फिर कोशिश करें।';

  @override
  String get servingUnknownTitle => 'सर्विंग साइज़ पता नहीं';

  @override
  String get servingUnknownBody =>
      'इस लेबल के आँकड़ों से पता नहीं चलता कि वे प्रति 100 ग्राम/मिली हैं या प्रति सर्विंग। पैक देखें और सर्विंग साइज़ जोड़ें; अगली बार यह प्रोडक्ट स्कैन करने पर हम इसका इस्तेमाल करेंगे।';

  @override
  String get addServingSize => 'सर्विंग साइज़ जोड़ें';

  @override
  String get servingSheetTitle => 'सर्विंग साइज़';

  @override
  String get servingAmountLabel => 'एक सर्विंग (ग्राम या मिली)';

  @override
  String get servingAmountHelp => 'पैक पर “serving size” या नेट मात्रा देखें।';

  @override
  String get servingBasisLabel => 'लेबल पर आँकड़े हैं';

  @override
  String get basisPer100 => 'प्रति 100 ग्राम/मिली';

  @override
  String get basisPerServing => 'प्रति सर्विंग';

  @override
  String servingSaved(String amount) {
    return 'सेव हो गया: $amount ग्राम/मिली प्रति सर्विंग। अगली बार यह प्रोडक्ट स्कैन करने पर हम इसका इस्तेमाल करेंगे।';
  }

  @override
  String get servingSaveFailed =>
      'सेव नहीं हो सका। कनेक्शन जाँचें और फिर कोशिश करें।';

  @override
  String labelNotePer100(String source) {
    return 'प्रति 100 ग्राम/मिली, स्रोत: $source। डैश का मतलब है कि पता नहीं।';
  }

  @override
  String labelNoteYourServing(String amount) {
    return '$amount ग्राम/मिली की सर्विंग पर, आपका सेव किया सर्विंग साइज़।';
  }

  @override
  String get confirmingProduct => 'यह प्रोडक्ट जाँचा जा रहा है…';
}
