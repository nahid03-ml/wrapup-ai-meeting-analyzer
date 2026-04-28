import '../data/live_event.dart';

class LiveTranscriptLine {
  const LiveTranscriptLine({
    required this.text,
    required this.speaker,
    required this.isFinal,
    required this.confidence,
    required this.createdAt,
  });

  final String text;
  final int? speaker;
  final bool isFinal;
  final double confidence;
  final DateTime createdAt;
}

List<LiveTranscriptLine> mergeLiveTranscriptEvent({
  required List<LiveTranscriptLine> lines,
  required LiveTranscriptEvent event,
  DateTime? createdAt,
}) {
  final text = event.text.trim();
  final next = List<LiveTranscriptLine>.of(lines);
  final lastIsInterim = next.isNotEmpty && !next.last.isFinal;

  if (event.isFinal) {
    if (lastIsInterim) {
      next.removeLast();
    }
    if (text.isEmpty) {
      return List.unmodifiable(next);
    }
    next.add(
      LiveTranscriptLine(
        text: text,
        speaker: event.speaker,
        isFinal: true,
        confidence: event.confidence,
        createdAt: createdAt ?? DateTime.now(),
      ),
    );
    return List.unmodifiable(next);
  }

  if (text.isEmpty) {
    if (lastIsInterim) {
      next.removeLast();
    }
    return List.unmodifiable(next);
  }

  final line = LiveTranscriptLine(
    text: text,
    speaker: event.speaker,
    isFinal: false,
    confidence: event.confidence,
    createdAt: createdAt ?? DateTime.now(),
  );

  if (lastIsInterim) {
    next[next.length - 1] = line;
  } else {
    next.add(line);
  }
  return List.unmodifiable(next);
}
