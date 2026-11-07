import 'package:flutter/material.dart';
import 'package:happy_notes/app_config.dart';
import 'package:happy_notes/screens/search/search_results_page.dart';
import 'package:happy_notes/screens/memories/memories_on_day.dart';
import 'package:happy_notes/screens/components/create_note_fab.dart';

class SearchTab extends StatefulWidget {
  const SearchTab({super.key});

  @override
  State<SearchTab> createState() => SearchTabState();
}

class SearchTabState extends State<SearchTab> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _performSearch() {
    final query = _controller.text.trim();
    if (query.isEmpty) return;

    // Try date parsing first
    final dateString = _normalizeDateString(query);
    if (dateString != null) {
      try {
        final date = DateTime.parse(dateString);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => MemoriesOnDay(date: date)),
        );
        return;
      } catch (_) {}
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchResultsPage(query: query),
      ),
    );
  }

  String? _normalizeDateString(String input) {
    final monthNames = {
      'jan': '01',
      'feb': '02',
      'mar': '03',
      'apr': '04',
      'may': '05',
      'jun': '06',
      'jul': '07',
      'aug': '08',
      'sep': '09',
      'oct': '10',
      'nov': '11',
      'dec': '12'
    };

    final monthNamePattern = RegExp(
      r'^(\d{4})-(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)-(\d{2})$',
      caseSensitive: false,
    );
    final monthMatch = monthNamePattern.firstMatch(input);
    if (monthMatch != null) {
      final year = monthMatch.group(1);
      final month = monthNames[monthMatch.group(2)?.toLowerCase()];
      final day = monthMatch.group(3);
      return '$year-$month-$day';
    }

    final numericPattern =
        RegExp(r'^(\d{4})-(0?[1-9]|1[0-2])-(0?[1-9]|[12]\d|3[01])$');
    final numericMatch = numericPattern.firstMatch(input);
    if (numericMatch != null) {
      final year = numericMatch.group(1);
      final month = numericMatch.group(2)!.padLeft(2, '0');
      final day = numericMatch.group(3)!.padLeft(2, '0');
      return '$year-$month-$day';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              key: const ValueKey<String>('e2e-search-entry'),
              controller: _controller,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: 'Enter keyword or date',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _controller.clear(),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _performSearch(),
            ),
            const SizedBox(height: 24),
            const Opacity(
              opacity: 0.6,
              child: Column(
                children: [
                  Icon(Icons.search, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    'Search your notes by keyword or date',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Date formats: 2024-01-15, 2024-Jan-15',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: CreateNoteFAB(
        isPrivate: AppConfig.privateNoteOnlyIsEnabled,
        heroTag: 'fab_search_tab',
      ),
    );
  }
}
