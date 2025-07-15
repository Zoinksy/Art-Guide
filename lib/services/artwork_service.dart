import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:image/image.dart' as img;
import 'wikipedia_service.dart';

class ArtworkDetails {
  final String title;
  final String description;
  final String artist;
  final String year;
  final String style;
  final String location;
  final String imageUrl;

  ArtworkDetails({
    required this.title,
    required this.description,
    required this.artist,
    required this.year,
    required this.style,
    required this.location,
    required this.imageUrl,
  });

  factory ArtworkDetails.fromMap(Map<String, dynamic> map) {
    return ArtworkDetails(
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      artist: map['artist'] ?? '',
      year: map['year'] ?? '',
      style: map['style'] ?? '',
      location: map['location'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
    );
  }
}

class ArtworkService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final WikipediaService _wikipediaService = WikipediaService();

  Future<void> saveArtworkDetails({
    required String artworkName,
    required double confidence,
    required File imageFile,
    required Map<String, dynamic>? modelDetails,
  }) async {
    try {
      print('DEBUG: saveArtworkDetails - începe upload imagine');
      
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      String imageUrl = ''; // Declare imageUrl variable

      // Rotate image 90 degrees before upload
      print('DEBUG: Rotating image 90 degrees');
      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);
      if (image != null) {
        final rotatedImage = img.copyRotate(image, angle: 90);
        final rotatedBytes = img.encodeJpg(rotatedImage, quality: 90);
        
        // Create temporary file with rotated image
        final tempDir = await Directory.systemTemp.createTemp('rotated_image');
        final rotatedFile = File('${tempDir.path}/rotated_${path.basename(imageFile.path)}');
        await rotatedFile.writeAsBytes(rotatedBytes);
        
        // Upload rotated image to Firebase Storage
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = '${user.uid}_$timestamp${path.extension(imageFile.path)}';
        final storageRef = _storage.ref().child('artwork_images/$fileName');
        
        print('DEBUG: Upload la Firebase Storage: $fileName');
        await storageRef.putFile(rotatedFile);
        imageUrl = await storageRef.getDownloadURL();
        print('DEBUG: Imagine rotată uploadată, URL: $imageUrl');
        
        // Clean up temporary file
        await rotatedFile.delete();
        await tempDir.delete();
      } else {
        // Fallback to original image if rotation fails
        print('DEBUG: Rotation failed, using original image');
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = '${user.uid}_$timestamp${path.extension(imageFile.path)}';
        final storageRef = _storage.ref().child('artwork_images/$fileName');
        
        print('DEBUG: Upload la Firebase Storage: $fileName');
        await storageRef.putFile(imageFile);
        imageUrl = await storageRef.getDownloadURL();
        print('DEBUG: Imagine uploadată, URL: $imageUrl');
      }

      // Get Wikipedia details
      print('DEBUG: Începe fetch Wikipedia');
      final wikiDetails = await _wikipediaService.getArtworkDetails(artworkName);
      print('DEBUG: Wikipedia details: $wikiDetails');

      // Combine model details with Wikipedia details
      final details = {
        ...?modelDetails,
        ...wikiDetails,
      };
      print('DEBUG: Detalii combinate: $details');

      // Save to Firestore
      print('DEBUG: Salvare în Firestore');
      await _firestore.collection('recognition_results').add({
        'userId': user.uid,
        'artworkName': artworkName,
        'confidence': confidence,
        'imageUrl': imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'details': details,
      });
      print('DEBUG: Salvare Firestore completă pentru: $artworkName');
    } catch (e) {
      print('ERROR: Error saving artwork details: $e');
      rethrow;
    }
  }

  Future<void> deleteArtwork(String documentId, String? imageUrl) async {
    try {
      // Delete from Firestore
      await _firestore.collection('recognition_results').doc(documentId).delete();

      // Delete image from Storage if URL exists
      if (imageUrl != null) {
        try {
          final ref = _storage.refFromURL(imageUrl);
          await ref.delete();
        } catch (e) {
          print('Error deleting image from storage: $e');
        }
      }
    } catch (e) {
      print('Error deleting artwork: $e');
      rethrow;
    }
  }

  // Metodă pentru a popula baza de date cu detaliile operelor
  Future<void> populateArtworkDetails() async {
    final artworks = {
      'American Gothic': {
        'title': 'American Gothic',
        'description': 'O pictură iconică care înfățișează un fermier și fiica sa în fața unei case cu stil gotic. Pictura este considerată o reprezentare a valorilor tradiționale americane și a vieții rurale din perioada Marii Crize.',
        'artist': 'Grant Wood',
        'year': '1930',
        'style': 'Regionalism',
        'location': 'Art Institute of Chicago',
        'imageUrl': 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/4c/Grant_Wood_-_American_Gothic_-_Google_Art_Project.jpg/800px-Grant_Wood_-_American_Gothic_-_Google_Art_Project.jpg',
      },
      'Cafe Terrace at Night': {
        'title': 'Cafe Terrace at Night',
        'description': 'O scenă nocturnă vibrantă a unui cafenea din Arles, Franța. Van Gogh a capturat atmosfera caldă și intimă a serii, folosind culori vii și tușe expresive.',
        'artist': 'Vincent van Gogh',
        'year': '1888',
        'style': 'Post-impresionism',
        'location': 'Kröller-Müller Museum, Otterlo',
        'imageUrl': 'https://upload.wikimedia.org/wikipedia/commons/thumb/7/7d/Vincent_van_Gogh_-_Cafe_Terrace_at_Night_%28Yorck%29.jpg/800px-Vincent_van_Gogh_-_Cafe_Terrace_at_Night_%28Yorck%29.jpg',
      },
      'Guernica': {
        'title': 'Guernica',
        'description': 'O pictură puternică care denunță atrocitățile războiului civil spaniol. Picasso a creat o compoziție complexă și emoționantă care transmite suferința și teroarea conflictului.',
        'artist': 'Pablo Picasso',
        'year': '1937',
        'style': 'Cubism',
        'location': 'Museo Reina Sofía, Madrid',
        'imageUrl': 'https://upload.wikimedia.org/wikipedia/en/thumb/7/74/PicassoGuernica.jpg/800px-PicassoGuernica.jpg',
      },
      'Impression Sunrise': {
        'title': 'Impression Sunrise',
        'description': 'Considerată opera care a dat numele mișcării impresioniste, această pictură captează o scenă de dimineață în portul Le Havre, cu o atmosferă de ceață și lumină difuză.',
        'artist': 'Claude Monet',
        'year': '1872',
        'style': 'Impresionism',
        'location': 'Musée Marmottan Monet, Paris',
        'imageUrl': 'https://upload.wikimedia.org/wikipedia/commons/thumb/5/59/Monet_-_Impression%2C_Sunrise.jpg/800px-Monet_-_Impression%2C_Sunrise.jpg',
      },
      'Las Meninas': {
        'title': 'Las Meninas',
        'description': 'O pictură complexă care prezintă familia regală spaniolă și servitorii lor. Velázquez s-a inclus și pe el în pictură, creând o compoziție ingenioasă despre natura artei și percepției.',
        'artist': 'Diego Velázquez',
        'year': '1656',
        'style': 'Baroc',
        'location': 'Museo del Prado, Madrid',
        'imageUrl': 'https://upload.wikimedia.org/wikipedia/commons/thumb/3/31/Las_Meninas%2C_by_Diego_Vel%C3%A1zquez%2C_from_Prado_in_Google_Earth.jpg/800px-Las_Meninas%2C_by_Diego_Vel%C3%A1zquez%2C_from_Prado_in_Google_Earth.jpg',
      },
      'Liberty Leading the People': {
        'title': 'Liberty Leading the People',
        'description': 'O reprezentare puternică a Revoluției din Iulie 1830 din Franța. Pictura simbolizează lupta pentru libertate și drepturi civile, cu figura alegorică a Libertății conducând poporul.',
        'artist': 'Eugène Delacroix',
        'year': '1830',
        'style': 'Romantism',
        'location': 'Louvre Museum, Paris',
        'imageUrl': 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a5/Eug%C3%A8ne_Delacroix_-_La_libert%C3%A9_guidant_le_peuple.jpg/800px-Eug%C3%A8ne_Delacroix_-_La_libert%C3%A9_guidant_le_peuple.jpg',
      },
      'Napoleon Crossing the Alps': {
        'title': 'Napoleon Crossing the Alps',
        'description': 'O reprezentare dramatică a lui Napoleon Bonaparte conducând trupele sale prin Alpi. Pictura transmite puterea și determinarea liderului francez.',
        'artist': 'Jacques-Louis David',
        'year': '1801',
        'style': 'Neoclasicism',
        'location': 'Château de Malmaison',
        'imageUrl': 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/2a/Jacques-Louis_David_-_Bonaparte_franchissant_le_Grand_Saint-Bernard%2C_20_mai_1800_-_Google_Art_Project.jpg/800px-Jacques-Louis_David_-_Bonaparte_franchissant_le_Grand_Saint-Bernard%2C_20_mai_1800_-_Google_Art_Project.jpg',
      },
      'Nighthawks': {
        'title': 'Nighthawks',
        'description': 'O scenă nocturnă a unui bar din oraș, capturând singurătatea și izolarea vieții urbane moderne. Pictura este cunoscută pentru lumina dramatică și atmosfera melancolică.',
        'artist': 'Edward Hopper',
        'year': '1942',
        'style': 'Realism',
        'location': 'Art Institute of Chicago',
        'imageUrl': 'https://upload.wikimedia.org/wikipedia/commons/thumb/7/78/Nighthawks_by_Edward_Hopper_1942.jpg/800px-Nighthawks_by_Edward_Hopper_1942.jpg',
      },
      'Starry Night': {
        'title': 'Starry Night',
        'description': 'Una dintre cele mai cunoscute picturi ale lui Van Gogh, care înfățișează o noapte cu cer învârtit și stele strălucitoare. Pictura reflectă starea emoțională intensă a artistului.',
        'artist': 'Vincent van Gogh',
        'year': '1889',
        'style': 'Post-impresionism',
        'location': 'Museum of Modern Art, New York',
        'imageUrl': 'https://upload.wikimedia.org/wikipedia/commons/thumb/e/ea/Van_Gogh_-_Starry_Night_-_Google_Art_Project.jpg/800px-Van_Gogh_-_Starry_Night_-_Google_Art_Project.jpg',
      },
      'The Birth of Venus': {
        'title': 'The Birth of Venus',
        'description': 'O reprezentare a nașterii zeiței Venus din spuma mării. Pictura este considerată una dintre cele mai frumoase opere ale Renașterii italiene.',
        'artist': 'Sandro Botticelli',
        'year': '1485',
        'style': 'Renaștere',
        'location': 'Uffizi Gallery, Florence',
        'imageUrl': 'https://upload.wikimedia.org/wikipedia/commons/thumb/0/0b/Sandro_Botticelli_-_La_nascita_di_Venere_-_Google_Art_Project_-_edited.jpg/800px-Sandro_Botticelli_-_La_nascita_di_Venere_-_Google_Art_Project_-_edited.jpg',
      },
      'The Creation of Adam': {
        'title': 'The Creation of Adam',
        'description': 'O scenă din Capela Sixtină care înfățișează momentul creării lui Adam de către Dumnezeu. Pictura este cunoscută pentru compoziția sa puternică și semnificația sa religioasă.',
        'artist': 'Michelangelo',
        'year': '1512',
        'style': 'Renaștere',
        'location': 'Sistine Chapel, Vatican',
        'imageUrl': 'https://upload.wikimedia.org/wikipedia/commons/thumb/5/5b/Michelangelo_-_Creation_of_Adam_%28cropped%29.jpg/800px-Michelangelo_-_Creation_of_Adam_%28cropped%29.jpg',
      },
      'The Great Wave off Kanagawa': {
        'title': 'The Great Wave off Kanagawa',
        'description': 'O gravură japoneză care înfățișează un val masiv amenințând bărcile de pescuit. Opera este considerată una dintre cele mai cunoscute gravuri japoneze.',
        'artist': 'Katsushika Hokusai',
        'year': '1831',
        'style': 'Ukiyo-e',
        'location': 'Metropolitan Museum of Art, New York',
        'imageUrl': 'https://upload.wikimedia.org/wikipedia/commons/thumb/0/0a/The_Great_Wave_off_Kanagawa.jpg/800px-The_Great_Wave_off_Kanagawa.jpg',
      },
      'The Kiss': {
        'title': 'The Kiss',
        'description': 'O sculptură care înfățișează o pereche îmbrățișată, simbolizând iubirea și pasiunea. Opera este considerată una dintre cele mai romantice sculpturi ale secolului XX.',
        'artist': 'Auguste Rodin',
        'year': '1889',
        'style': 'Impresionism',
        'location': 'Musée Rodin, Paris',
        'imageUrl': 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/4f/The_Kiss_-_Rodin_-_Mus%C3%A9e_Rodin_-_Paris_2011.jpg/800px-The_Kiss_-_Rodin_-_Mus%C3%A9e_Rodin_-_Paris_2011.jpg',
      },
      'The Last Supper': {
        'title': 'The Last Supper',
        'description': 'O pictură murală care înfățișează ultima cină a lui Iisus cu apostolii săi. Opera este cunoscută pentru compoziția sa complexă și semnificația sa religioasă.',
        'artist': 'Leonardo da Vinci',
        'year': '1498',
        'style': 'Renaștere',
        'location': 'Santa Maria delle Grazie, Milan',
        'imageUrl': 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/48/The_Last_Supper_-_Leonardo_Da_Vinci_-_High_Resolution_32x16.jpg/800px-The_Last_Supper_-_Leonardo_Da_Vinci_-_High_Resolution_32x16.jpg',
      },
      'The Night Watch': {
        'title': 'The Night Watch',
        'description': 'O pictură de grup care înfățișează o companie de gărzi civile. Opera este cunoscută pentru compoziția sa dinamică și utilizarea dramatică a luminii.',
        'artist': 'Rembrandt van Rijn',
        'year': '1642',
        'style': 'Baroc',
        'location': 'Rijksmuseum, Amsterdam',
        'imageUrl': 'https://upload.wikimedia.org/wikipedia/commons/thumb/5/59/Rembrandt_-_The_Night_Watch_-_Google_Art_Project.jpg/800px-Rembrandt_-_The_Night_Watch_-_Google_Art_Project.jpg',
      },
      'The Persistence of Memory': {
        'title': 'The Persistence of Memory',
        'description': 'O pictură surrealistă care înfățișează ceasuri topite într-un peisaj oniric. Opera explorează conceptul timpului și realității.',
        'artist': 'Salvador Dalí',
        'year': '1931',
        'style': 'Surrealism',
        'location': 'Museum of Modern Art, New York',
        'imageUrl': 'https://upload.wikimedia.org/wikipedia/en/thumb/d/dd/The_Persistence_of_Memory.jpg/800px-The_Persistence_of_Memory.jpg',
      },
      'The Scream': {
        'title': 'The Scream',
        'description': 'O pictură expresionistă care înfățișează o figură care țipă într-un peisaj distorsionat. Opera transmite anxietatea și agitația modernă.',
        'artist': 'Edvard Munch',
        'year': '1893',
        'style': 'Expresionism',
        'location': 'National Gallery, Oslo',
        'imageUrl': 'https://upload.wikimedia.org/wikipedia/commons/thumb/f/f4/The_Scream.jpg/800px-The_Scream.jpg',
      },
      'Water Lilies': {
        'title': 'Water Lilies',
        'description': 'O serie de picturi care înfățișează nenufarele din grădina lui Monet. Operele sunt cunoscute pentru studiul luminii și culorilor în natură.',
        'artist': 'Claude Monet',
        'year': '1919',
        'style': 'Impresionism',
        'location': 'Musée de l\'Orangerie, Paris',
        'imageUrl': 'https://upload.wikimedia.org/wikipedia/commons/thumb/8/8d/Claude_Monet_-_Water_Lilies_-_Google_Art_Project.jpg/800px-Claude_Monet_-_Water_Lilies_-_Google_Art_Project.jpg',
      },
      'Whistler\'s Mother': {
        'title': 'Whistler\'s Mother',
        'description': 'O pictură care înfățișează mama artistului într-o poziție solemnă. Opera este cunoscută pentru simplitatea și demnitatea sa.',
        'artist': 'James McNeill Whistler',
        'year': '1871',
        'style': 'Realism',
        'location': 'Musée d\'Orsay, Paris',
        'imageUrl': 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/1b/Whistlers_Mother_high_res.jpg/800px-Whistlers_Mother_high_res.jpg',
      },
      'Girl with A Pearl Earring': {
        'title': 'Girl with A Pearl Earring',
        'description': 'O pictură care înfățișează o tânără cu o perlă la ureche. Opera este cunoscută pentru misterul și frumusețea sa atemporală.',
        'artist': 'Johannes Vermeer',
        'year': '1665',
        'style': 'Baroc',
        'location': 'Mauritshuis, The Hague',
        'imageUrl': 'https://upload.wikimedia.org/wikipedia/commons/thumb/0/0f/1665_Girl_with_a_Pearl_Earring.jpg/800px-1665_Girl_with_a_Pearl_Earring.jpg',
      },
    };

    // Adăugăm fiecare operă în Firestore
    for (final entry in artworks.entries) {
      await _firestore.collection('artwork_details').doc(entry.key).set(entry.value);
    }
  }

  // Metodă publică pentru a obține detalii Wikipedia
  Future<Map<String, dynamic>> getWikipediaDetails(String artworkName) {
    return _wikipediaService.getArtworkDetails(artworkName);
  }
} 