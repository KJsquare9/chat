// import 'package:flutter/material.dart';

class NewsService {
  List<Map<String, dynamic>> getNews() {
    return [
      {
        'category': 'Technology',
        'description': 'Apple unveils new iPhone with AI features.',
        'source': 'The Verge',
        'time': '6h ago',
        'iconColor': 0xFF00FF00,
        'url': 'https://www.theverge.com'
      },
      {
        'category': 'Health',
        'description': 'Study finds exercise may reduce dementia risk.',
        'source': 'Reuters',
        'time': '8h ago',
        'iconColor': 0xFF800080,
        'url': 'https://www.reuters.com'
      },
      {
        'category': 'Business',
        'description': 'Tesla announces new gigafactory in Austin with 5,000 new jobs.',
        'source': 'CNBC',
        'time': '12h ago',
        'iconColor': 0xFF0000FF,
        'url': 'https://www.cnbc.com'
      },
      {
        'category': 'Sports',
        'description': 'Lakers win championship in dramatic Game 7 overtime thriller.',
        'source': 'ESPN',
        'time': '14h ago',
        'iconColor': 0xFFFF0000,
        'url': 'https://www.espn.com'
      },
      {
        'category': 'World',
        'description': 'Russian warship: Moskva sinks in Black Sea.',
        'source': 'BBC News',
        'time': '4h ago',
        'iconColor': 0xFFFF0000,
        'url': 'https://www.bbc.com'
      },
      {
        'category': 'Money',
        'description': 'Wind power produced more electricity than coal and nuclear.',
        'source': 'USA Today',
        'time': '4h ago',
        'iconColor': 0xFF0000FF,
        'url': 'https://www.usatoday.com'
      }
    ];
  }
}
