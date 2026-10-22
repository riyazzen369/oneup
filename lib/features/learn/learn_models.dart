import '../../core/theme/app_colors.dart';

class Book {
  Book.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        title = j['title'] as String,
        short = j['short'] as String,
        author = j['author'] as String,
        year = j['year'] as int,
        publisher = j['publisher'] as String,
        isbn = j['isbn'] as String?,
        note = j['note'] as String?,
        verify = j['verify'] as bool? ?? false;
  final String id, title, short, author, publisher;
  final int year;
  final String? isbn, note;
  final bool verify;
}

class Lesson {
  Lesson.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        bookId = j['book'] as String,
        title = j['title'] as String,
        dimensions = [for (final d in j['dimensions'] as List) WellnessDimension.values.byName(d as String)],
        idea = j['idea'] as String,
        cards = List<String>.from(j['cards'] as List),
        tryThis = j['tryThis'] as String,
        sensitive = j['sensitive'] as bool? ?? false,
        body = j['body'] == null ? null : LessonBody.fromJson(j['body'] as Map<String, dynamic>);
  final String id, bookId, title, idea, tryThis;
  final LessonBody? body;

  /// All readable words (body + Try this), or the short cards when there is no body.
  int get wordCount => _words([...?body?.allText, if (body == null) ...cards, tryThis]);

  /// Estimated minutes at ~200 words per minute (at least 1).
  int get readingMinutes => (wordCount / 200).ceil().clamp(1, 99);
  final List<WellnessDimension> dimensions;
  final List<String> cards;
  final bool sensitive;
}

int _words(Iterable<String> parts) => parts.fold(0, (n, p) => n + RegExp(r'\S+').allMatches(p).length);

class LessonSection {
  const LessonSection(this.heading, this.paragraphs);
  final String heading;
  final List<String> paragraphs;
}

/// Book-style long read: intro, titled sections, worked example, takeaways, reflection questions.
class LessonBody {
  LessonBody.fromJson(Map<String, dynamic> j)
      : intro = j['intro'] as String,
        sections = [
          for (final s in j['sections'] as List)
            LessonSection((s as List)[0] as String, [for (final p in (s[1] as String).split('\n\n')) p.trim()]),
        ],
        exampleTitle = (j['example'] as Map)['title'] as String,
        example = (j['example'] as Map)['text'] as String,
        takeaways = List<String>.from(j['takeaways'] as List),
        reflect = List<String>.from(j['reflect'] as List);
  final String intro, exampleTitle, example;
  final List<LessonSection> sections;
  final List<String> takeaways, reflect;

  Iterable<String> get allText sync* {
    yield intro;
    for (final s in sections) {
      yield s.heading;
      yield* s.paragraphs;
    }
    yield exampleTitle;
    yield example;
    yield* takeaways;
    yield* reflect;
  }
}

class LearnLibrary {
  LearnLibrary.fromJson(Map<String, dynamic> j)
      : disclaimer = j['disclaimer'] as String,
        sensitiveNote = j['sensitiveNote'] as String,
        financialNote = j['financialNote'] as String? ?? 'Not financial advice.',
        books = [for (final b in j['books'] as List) Book.fromJson(b as Map<String, dynamic>)],
        lessons = [for (final l in j['lessons'] as List) Lesson.fromJson(l as Map<String, dynamic>)];
  final String disclaimer, sensitiveNote, financialNote;
  final List<Book> books;
  final List<Lesson> lessons;
  Book book(String id) => books.firstWhere((b) => b.id == id);
  Lesson? lesson(String id) => lessons.where((l) => l.id == id).firstOrNull;

  /// The lesson after [id] in library order (wraps around), or null if unknown.
  Lesson? next(String id) {
    final i = lessons.indexWhere((l) => l.id == id);
    return i < 0 || lessons.length < 2 ? null : lessons[(i + 1) % lessons.length];
  }

  List<Lesson> filter({WellnessDimension? dim, String? bookId}) => [
        for (final l in lessons)
          if ((dim == null || l.dimensions.contains(dim)) && (bookId == null || l.bookId == bookId)) l,
      ];

  /// Up to [n] not-yet-completed lessons for the focus dimensions, in focus order.
  List<Lesson> recommended(List<WellnessDimension> focus, Set<String> done, {int n = 3}) {
    final out = <Lesson>[];
    for (final d in focus) {
      for (final l in lessons) {
        if (out.length >= n) return out;
        if (l.dimensions.contains(d) && !done.contains(l.id) && !out.contains(l)) {
          out.add(l);
          break;
        }
      }
    }
    for (final l in lessons) {
      if (out.length >= n) break;
      if (focus.any(l.dimensions.contains) && !done.contains(l.id) && !out.contains(l)) out.add(l);
    }
    return out;
  }

  /// (completed, total) per dimension.
  Map<WellnessDimension, (int, int)> progress(Set<String> done) => {
        for (final d in WellnessDimension.values)
          d: (
            lessons.where((l) => l.dimensions.contains(d) && done.contains(l.id)).length,
            lessons.where((l) => l.dimensions.contains(d)).length,
          ),
      };
}
