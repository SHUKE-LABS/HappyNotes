class PublicNote {
  final int id;
  final String content;
  final int createdAt;
  final bool isMarkdown;

  const PublicNote({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.isMarkdown,
  });

  factory PublicNote.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final content = json['content'];
    final createdAt = json['createdAt'];
    final isMarkdown = json['isMarkdown'];

    if (id is! int ||
        content is! String ||
        createdAt is! int ||
        isMarkdown is! bool) {
      throw const FormatException('Invalid public note response');
    }

    return PublicNote(
      id: id,
      content: content,
      createdAt: createdAt,
      isMarkdown: isMarkdown,
    );
  }
}
