import 'package:flutter/material.dart';

class QuestionsScreen extends StatefulWidget {
  const QuestionsScreen({super.key});

  @override
  QuestionsScreenState createState() => QuestionsScreenState();
}

class QuestionsScreenState extends State<QuestionsScreen> {
  bool _isAnsweredExpanded = false;
  bool _isUnansweredExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Questions Overview'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xFFFF5002),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    'CONSTITUENCY: NAMPALLY',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'CANDIDATE NAME: JOHN DOE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            Expanded(
              child: ListView(
                children: [
                  Text(
                    'Answered (54)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  _buildQuestionCard(
                    'How long till the next elections?',
                    '3 months.',
                  ),
                  _buildQuestionCard(
                    'How old is the constitution?',
                    '3 months (approximately).',
                  ),
                  _buildQuestionCard(
                    'How many power-cuts can we expect?',
                    '2 per day.',
                  ),
                  if (_isAnsweredExpanded) ...[
                    _buildQuestionCard(
                      'How long till the next elections?',
                      '3 months.',
                    ),
                    _buildQuestionCard(
                      'How old is the constitution?',
                      '3 months (approximately).',
                    ),
                    _buildQuestionCard(
                      'How many power-cuts can we expect?',
                      '2 per day.',
                    ),
                  ],
                  Center(
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          _isAnsweredExpanded = !_isAnsweredExpanded;
                        });
                      },
                      child: Text(
                        _isAnsweredExpanded
                            ? 'See Less (Answered)'
                            : 'See More (Answered)',
                        style: TextStyle(color: Colors.blue),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Unanswered (18)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  _buildQuestionCard(
                    'When are the new roads going to be laid in the village?',
                    '',
                  ),
                  _buildQuestionCard(
                    'How long is it going to take to lay the roads?',
                    '',
                  ),
                  if (_isUnansweredExpanded) ...[
                    _buildQuestionCard(
                      'When are the new roads going to be laid in the village?',
                      '',
                    ),
                    _buildQuestionCard(
                      'How long is it going to take to lay the roads?',
                      '',
                    ),
                  ],
                  Center(
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          _isUnansweredExpanded = !_isUnansweredExpanded;
                        });
                      },
                      child: Text(
                        _isUnansweredExpanded
                            ? 'See Less (Unanswered)'
                            : 'See More (Unanswered)',
                        style: TextStyle(color: Colors.blue),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(String question, String answer) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 5),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(question, style: TextStyle(fontWeight: FontWeight.bold)),
            if (answer.isNotEmpty) ...[
              SizedBox(height: 5),
              Text(answer, style: TextStyle(color: Colors.grey)),
            ],
          ],
        ),
      ),
    );
  }
}
