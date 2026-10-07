class MathLessonData {
  final String id;
  final int grade;
  final String unit;
  final String title;
  final String overview;
  final List<String> objectives;
  final List<String> keyPoints;
  final List<String> formulas;
  final String exampleTitle;
  final List<String> exampleSteps;
  final List<String> checkpoints;
  final List<String> sourceUrls;

  const MathLessonData({
    required this.id,
    required this.grade,
    required this.unit,
    required this.title,
    required this.overview,
    required this.objectives,
    required this.keyPoints,
    required this.formulas,
    required this.exampleTitle,
    required this.exampleSteps,
    required this.checkpoints,
    this.sourceUrls = const [],
  });
}

class MathStudySection {
  final String title;
  final String explanation;
  final List<String> keyIdeas;
  final List<String> workedExample;

  const MathStudySection({
    required this.title,
    required this.explanation,
    this.keyIdeas = const [],
    this.workedExample = const [],
  });
}
