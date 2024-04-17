import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:flutter/services.dart' show rootBundle;
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:printing/printing.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ezprints and Google Drive Files',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String phoneNumber = '';
  String? printerStatus = '';
  List<drive.File>? fileList;

  Future<Uint8List?> loadPdfFromDrive(String filename) async {
    final credentialsJson = await rootBundle.loadString('assets/apikeys.json');
    final credentials = auth.ServiceAccountCredentials.fromJson(credentialsJson);
    final scopes = [drive.DriveApi.driveFileScope];
    final accessCredentials = await auth.obtainAccessCredentialsViaServiceAccount(credentials, scopes, http.Client());
    final authClient = auth.authenticatedClient(http.Client(), accessCredentials);
    final driveApi = drive.DriveApi(authClient);

    final fileListResponse = await driveApi.files.list(
      q: "name = '$filename'",
    );

    if (fileListResponse.files != null && fileListResponse.files!.isNotEmpty) {
      final fileId = fileListResponse.files![0].id!;
      return printFile(fileId);
    } else {
      print('File not found on Google Drive');
      return null;
    }
  }

  Future<Uint8List> printFile(String fileId) async {
    try {
      final pdfUrl = 'https://drive.google.com/uc?id=$fileId';
      final response = await http.get(Uri.parse(pdfUrl));
      return response.bodyBytes.buffer.asUint8List();
    } catch (e) {
      print('Error loading PDF: $e');
      throw Exception('Failed to load PDF');
    }
  }

  Future<String> getFileId(String fileName) async {
    final serviceAccountCredentials = rootBundle.loadString('assets/apikeys.json');
    final credentials = auth.ServiceAccountCredentials.fromJson(serviceAccountCredentials);
    final scopes = [drive.DriveApi.driveScope];
    final client = await auth.clientViaServiceAccount(credentials, scopes);
    final driveApi = drive.DriveApi(client);

    try {
      final response = await driveApi.files.list(q: "name = '$fileName'");
      final files = response.files;
      if (files != null && files.isNotEmpty) {
        final fileId = files.first.id;
        print('File ID for "$fileName": $fileId');
        return fileId!;
      } else {
        print('File with name "$fileName" not found.');
        throw Exception('File not found');
      }
    } finally {
      client.close();
    }
  }

  void checkPhoneNumber(String phoneNumber) async {
    var db = await mongo.Db.create("mongodb+srv://abel:abel@cluster0.iqgx2js.mongodb.net/ezprints?retryWrites=true&w=majority&appName=Cluster0");
    await db.open();
    var collection = db.collection(phoneNumber);

    final count = await collection.count();

    if (count == 0) {
      setState(() {
        printerStatus = 'User not found';
      });
    } else {
      setState(() {
        printerStatus = 'Collection found';
      });

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CollectionScreen(collection: collection),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Ezprints',
          style: GoogleFonts.reemKufiFun(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () {
              setState(() {
                printerStatus = null;
              });
            },
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 50.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            TextField(
              decoration: InputDecoration(
                hintText: 'Enter your phone number',
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                phoneNumber = value;
              },
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                checkPhoneNumber(phoneNumber);
              },
              child: Text('Login'),
            ),
            SizedBox(height: 20),
            Text(printerStatus ?? ''),
          ],
        ),
      ),
    );
  }
}

class CollectionScreen extends StatefulWidget {
  final mongo.DbCollection collection;

  const CollectionScreen({Key? key, required this.collection}) : super(key: key);

  @override
  _CollectionScreenState createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  late Timer _timer;
  late Future<List<dynamic>> _futureData;

  @override
  void initState() {
    super.initState();
    _futureData = _fetchData();
    _timer = Timer.periodic(Duration(seconds: 5), (Timer t) => _refreshData());
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<List<dynamic>> _fetchData() async {
    final data = await widget.collection.find().toList();
    return data;
  }

  Future<void> _refreshData() async {
    setState(() {
      _futureData = _fetchData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Files available to print:',
          style: GoogleFonts.reemKufiFun(),
        ),
        automaticallyImplyLeading: false, // Removes the back button
        actions: [
          IconButton(
            icon: Icon(Icons.exit_to_app_rounded),
            onPressed: () {
              // Navigate back to the first screen
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder(
              future: _futureData,
              builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                List<dynamic> data = snapshot.data ?? [];

                return ListView.builder(
                  itemCount: data.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(data[index]['name'] ?? ''),
                    );
                  },
                );
              },
            ),
          ),
          // Button to trigger printing
          // ElevatedButton(
          //   onPressed: () async {
          //     var data = await widget.collection.find().toList();
          //     var filenamesFromDatabase = data.map((e) => e['name']).toList();

          //     List<Uint8List> pdfs = [];
          //     for (var filename in filenamesFromDatabase) {
          //       var pdf = await _MyHomePageState().loadPdfFromDrive(filename);
          //       if (pdf != null) {
          //         pdfs.add(pdf);
          //       }
          //     }

          //     for (var pdf in pdfs) {
          //       await Printing.layoutPdf(onLayout: (_) => pdf);
          //     }
          //   },
          //   child: Text('Print'),
          // ),
//           ElevatedButton(
//             onPressed: () async {
//               var data = await widget.collection.find().toList();
//               var filenamesFromDatabase = data.map((e) => e['name']).toList();

//               List<Uint8List> pdfs = [];
//               List<String> filenamesToDelete = []; // List to store filenames to delete

//               for (var filename in filenamesFromDatabase) {
//                 var pdf = await _MyHomePageState().loadPdfFromDrive(filename);
//                 if (pdf != null) {
//                   pdfs.add(pdf);
//                   filenamesToDelete.add(filename); // Add filename to the list
//                 }
//               }

//               // Delete filenames from the collection
//               for (var filename in filenamesToDelete) {
//                 await widget.collection.remove({'name': filename});
//               }

//               for (var pdf in pdfs) {
//                 await Printing.layoutPdf(onLayout: (_) => pdf);
//               }

//               // Refresh data to reflect changes after deletion
//               _refreshData();
//             },
//             child: Text('Print'),
//           ),

//         ],
//       ),
//     );
//   }
// }
            Padding(
            padding: const EdgeInsets.only(bottom: 40.0),
            child: ElevatedButton(
              onPressed: () async {
              var data = await widget.collection.find().toList();
              var filenamesFromDatabase = data.map((e) => e['name']).toList();

              List<Uint8List> pdfs = [];
              List<String> filenamesToDelete = []; // List to store filenames to delete

              for (var filename in filenamesFromDatabase) {
                var pdf = await _MyHomePageState().loadPdfFromDrive(filename);
                if (pdf != null) {
                  pdfs.add(pdf);
                  filenamesToDelete.add(filename); // Add filename to the list
                }
              }

              // Delete filenames from the collection
              for (var filename in filenamesToDelete) {
                await widget.collection.remove({'name': filename});
              }

              for (var pdf in pdfs) {
                await Printing.layoutPdf(onLayout: (_) => pdf);
              }

              // Refresh data to reflect changes after deletion
              _refreshData();
            },
              child: Text('Print'),
            ),
          ),
        ],
      ),
    );
  }
}
