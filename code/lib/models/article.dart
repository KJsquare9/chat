class Article {
  final String title;
  final String description;
  final String link;

  Article({required this.title, required this.description, required this.link});

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      title: json['title'] ?? 'N/A',
      description: json['description'] ?? 'N/A',
      link: json['link'] ?? 'N/A',
    );
  }
}
