
enum StyleType {
  bold,
  italic,
  underline,
  header1,
  header2,
}

class FormattingSpan {
  int start;
  int end;
  final StyleType type;

  FormattingSpan(this.start, this.end, this.type);

  FormattingSpan copyWith({int? start, int? end, StyleType? type}) {
    return FormattingSpan(
      start ?? this.start,
      end ?? this.end,
      type ?? this.type,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'start': start,
      'end': end,
      'type': type.index,
    };
  }

  factory FormattingSpan.fromJson(Map<String, dynamic> json) {
    return FormattingSpan(
      json['start'],
      json['end'],
      StyleType.values[json['type']],
    );
  }
}
