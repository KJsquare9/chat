// lib/widgets/news_item.dart
import 'package:flutter/material.dart';

class NewsItem extends StatelessWidget {
  final String category;
  final String description;
  final String source;
  final String time;
  final Color iconColor;
  final String url;
  final VoidCallback onReadMorePressed;

  const NewsItem({
    super.key,
    required this.category,
    required this.description,
    required this.source,
    required this.time,
    required this.iconColor,
    required this.url,
    required this.onReadMorePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                category,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                time,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Source: $source',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              ElevatedButton(
                onPressed: onReadMorePressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF093466),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Read More'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
