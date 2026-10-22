/// App-side crisis keyword layer (spec: "Do not rely on the prompt alone").
/// English + basic romanised Hindi and Tamil. Deliberately over-inclusive: a false
/// positive shows a helpline card; a false negative could miss someone in danger.
/// [VERIFY] keyword list with clinical / language reviewers before launch.
enum CrisisCategory { selfHarm, harmOthers, abuseDanger, psychosisLike, medicalEmergency }

class CrisisResult {
  const CrisisResult(this.category, this.matched);
  final CrisisCategory category;
  final String matched;
}

const _keywords = <CrisisCategory, List<String>>{
  CrisisCategory.selfHarm: [
    // en
    'suicide', 'suicidal', 'kill myself', 'killing myself', 'end my life', 'ending my life', 'end it all',
    'dont want to live', 'do not want to live', 'dont want to be alive', 'want to die', 'wish i was dead',
    'wish i were dead', 'better off dead', 'no reason to live', 'nothing to live for', 'take my own life',
    'self harm', 'selfharm', 'hurt myself', 'hurting myself', 'cut myself', 'cutting myself', 'overdose',
    // hi (romanised)
    'khudkushi', 'aatmhatya', 'atmahatya', 'mar jaana chahta', 'mar jana chahta', 'mar jaana chahti', 'mar jana chahti',
    'marna chahta', 'marna chahti', 'jeena nahi chahta', 'jeena nahi chahti', 'jeene ka mann nahi', 'zindagi khatam',
    'khud ko nuksan', 'apne aap ko nuksan', 'apne aap ko maar',
    // ta (romanised)
    'thatkolai', 'thatkolai', 'thatkollai', 'tharkolai', 'saaga poren', 'saaga porean', 'saaganum', 'sethuduren',
    'vazha pidikkala', 'vaazha pidikkala', 'uyir vida', 'ennai naane kaayapaduthi',
  ],
  CrisisCategory.harmOthers: [
    'kill someone',
    'kill him',
    'kill her',
    'kill them',
    'hurt someone',
    'harm someone',
    'hurt others',
    'usko maar dunga',
    'maar daalunga',
    'kolai panna',
  ],
  CrisisCategory.abuseDanger: [
    'being abused',
    'abusing me',
    'hits me',
    'beats me',
    'beating me',
    'i am in danger',
    'im in danger',
    'not safe at home',
    'someone is hurting me',
    'mujhe maarta',
    'mujhe maarti',
    'adikkiraar',
    'adikkiraanga',
  ],
  CrisisCategory.psychosisLike: [
    'hearing voices',
    'hear voices',
    'voices telling me',
    'voices in my head',
    'awaazein sunai',
  ],
  CrisisCategory.medicalEmergency: [
    'chest pain',
    'cant breathe',
    'cannot breathe',
    'can not breathe',
    'fainted',
    'passing out',
    'took too many pills',
    'seene mein dard',
    'saans nahi',
    'nenju vali',
    'moochu vida mudiyala',
  ],
};

String normaliseForSafety(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r"[’'`]"), '')
    .replaceAll(RegExp(r'[^a-z0-9\u0900-\u097F\u0B80-\u0BFF ]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

CrisisResult? detectCrisis(String text) {
  final n = ' ${normaliseForSafety(text)} ';
  for (final e in _keywords.entries) {
    for (final k in e.value) {
      if (n.contains(' $k ') || n.contains(' $k')) return CrisisResult(e.key, k);
    }
  }
  return null;
}
