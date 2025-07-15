import 'dart:convert';
import 'package:http/http.dart' as http;

class WikipediaService {
  static const String _baseUrl = 'https://en.wikipedia.org/w/api.php';
  
  Future<Map<String, dynamic>> getArtworkDetails(String artworkName) async {
    try {
      // First, search for the artwork to get the page ID
      final searchResponse = await http.get(Uri.parse(
        '$_baseUrl?action=query&list=search&srsearch=$artworkName&format=json'
      ));

      if (searchResponse.statusCode != 200) {
        throw Exception('Failed to search Wikipedia');
      }

      final searchData = json.decode(searchResponse.body);
      final searchResults = searchData['query']['search'] as List;
      
      if (searchResults.isEmpty) {
        return {};
      }

      // Get the first result's page ID
      final pageId = searchResults[0]['pageid'];

      // Now get the full page content
      final contentResponse = await http.get(Uri.parse(
        '$_baseUrl?action=query&pageids=$pageId&prop=extracts|pageimages&exintro=1&explaintext=1&pithumbsize=500&format=json'
      ));

      if (contentResponse.statusCode != 200) {
        throw Exception('Failed to get Wikipedia content');
      }

      final contentData = json.decode(contentResponse.body);
      final pages = contentData['query']['pages'];
      final page = pages[pageId.toString()];

      // Extract relevant information
      final extract = page['extract'] as String? ?? '';
      final thumbnail = page['thumbnail']?['source'] as String?;

      // Parse the extract to find key information
      final details = _parseExtract(extract);
      if (thumbnail != null) {
        details['imageUrl'] = thumbnail;
      }

      return details;
    } catch (e) {
      print('Error fetching Wikipedia data: $e');
      return {};
    }
  }

  Map<String, dynamic> _parseExtract(String extract) {
    final details = <String, dynamic>{};
    
    // Try to find artist
    final artistMatch = RegExp(r'(?:by|created by|painted by|artist:)\s+([^\n\.;,]+)', caseSensitive: false)
        .firstMatch(extract);
    if (artistMatch != null) {
      details['artist'] = artistMatch.group(1)?.trim();
    }

    // Try to find year
    final yearMatch = RegExp(r'(?:painted|created|completed) in (\d{4})', caseSensitive: false)
        .firstMatch(extract);
    if (yearMatch != null) {
      details['year'] = yearMatch.group(1);
    }

    // Try to find style
    final styleMatch = RegExp(r'(?:style|movement):\s+([^\.]+)', caseSensitive: false)
        .firstMatch(extract);
    if (styleMatch != null) {
      details['style'] = styleMatch.group(1)?.trim();
    }

    // Try to find location
    final locationMatch = RegExp(r'(?:located in|housed in|exhibited at)\s+([^\.]+)', caseSensitive: false)
        .firstMatch(extract);
    if (locationMatch != null) {
      details['location'] = locationMatch.group(1)?.trim();
    }

    // Use the first paragraph as description
    final paragraphs = extract.split('\n\n');
    if (paragraphs.isNotEmpty) {
      details['description'] = paragraphs[0].trim();
    }

    return details;
  }
} 