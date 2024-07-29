import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:typed_data';
import 'dart:html' as html;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CSV Upload Model',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
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
  bool _fileUploaded = false;
  bool _isUploading = false;
  String? _csvFileName;
  Uint8List? _pdfBytes;
  List<String> _history = []; // List to track history

  Future<void> _pickFile() async {
    setState(() {
      _isUploading = true;
    });

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result != null) {
      setState(() {
        _csvFileName = result.files.single.name;
      });

      Fluttertoast.showToast(
        msg: "File uploaded successfully",
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );

      // Simulate delay for processing
      await Future.delayed(Duration(seconds: 2));

      setState(() {
        _fileUploaded = true;

        // Add to history
        _history.add('File: $_csvFileName, Report: ${_csvFileName!.replaceAll(RegExp(r'\.csv$'), '_report.pdf')}');
      });
    }

    setState(() {
      _isUploading = false;
    });
  }

  Future<void> _generatePdf() async {
    if (_csvFileName == null) return;

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Text(
              "Sample Report\n\nThis is a demo PDF report.",
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          );
        },
      ),
    );

    // Convert PDF to bytes
    final pdfBytes = await pdf.save();

    setState(() {
      _pdfBytes = pdfBytes;
    });

    // Extract file name without extension
    final pdfFileName = _csvFileName!.replaceAll(RegExp(r'\.csv$'), '_report.pdf');

    // Trigger download
    final blob = html.Blob([pdfBytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', pdfFileName)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("CSV Upload ML Model"),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        elevation: 10,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue, Colors.purple],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.home, color: Colors.white),
            onPressed: () {
              // Navigate to Home
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => MyHomePage()),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.history, color: Colors.white),
            onPressed: () {
              // Show History
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => HistoryScreen(history: _history),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.info_outline, color: Colors.white),
            onPressed: () {
              // Information action
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              ElevatedButton(
                onPressed: _pickFile,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  backgroundColor: Colors.deepOrange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 10,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.upload_file, size: 24),
                    SizedBox(width: 10),
                    Text(
                      "Upload CSV File",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              if (_isUploading)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(
                    color: Colors.deepOrange,
                  ),
                ),
              if (_fileUploaded)
                Column(
                  children: [
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _generatePdf,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                        backgroundColor: Colors.teal,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 10,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.picture_as_pdf, size: 24),
                          SizedBox(width: 10),
                          Text(
                            "Download Report (PDF)",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class HistoryScreen extends StatelessWidget {
  final List<String> history;

  HistoryScreen({required this.history});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("History"),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        elevation: 10,
      ),
      body: ListView.builder(
        itemCount: history.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(history[index]),
          );
        },
      ),
    );
  }
}
