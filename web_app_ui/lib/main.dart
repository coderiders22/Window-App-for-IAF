import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'non_web_util.dart' if (dart.library.html) 'web_util.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    return MaterialApp(
      title: 'IAF Aircraft Health Predictor',
      theme: ThemeData(
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.deepOrange)
            .copyWith(secondary: Colors.green, brightness: Brightness.light),
        scaffoldBackgroundColor: Colors.white,
        textTheme: TextTheme(bodyLarge: TextStyle(color: Colors.black)),
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin {
  bool _fileUploaded = false;
  String? _excelFileName;
  List<List<dynamic>> _excelData = [];
  List<Map<String, dynamic>> _aircraftData = [];
  List<String> _downloadHistory = [];
  List<String> _uploadHistory = [];
  bool _showResults = false;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )
      ..repeat(reverse: true);
    _animation =
        CurvedAnimation(parent: _animationController, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _downloadHistory = prefs.getStringList('downloadHistory') ?? [];
      _uploadHistory = prefs.getStringList('uploadHistory') ?? [];
    });
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('downloadHistory', _downloadHistory);
    await prefs.setStringList('uploadHistory', _uploadHistory);
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
    );

    if (result != null) {
      setState(() {
        _excelFileName = result.files.single.name;
        _showResults = false;
      });

      try {
        final excelBytes = result.files.single.bytes!;
        final excel = Excel.decodeBytes(excelBytes);
        final sheet = excel.tables[excel.tables.keys.first]!;

        _excelData = sheet.rows;
        _aircraftData = sheet.rows.skip(1).map((row) {
          return {
            'Aircraft Name': row[0]?.value?.toString() ?? '',
            'Status': row[1]?.value?.toString() ?? '',
          };
        }).toList();

        Fluttertoast.showToast(
          msg: "File uploaded successfully",
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );

        setState(() {
          _fileUploaded = true;
          _uploadHistory.add(
              '${DateTime.now().toIso8601String()}: $_excelFileName');
        });
        _saveHistory();
      } catch (e) {
        Fluttertoast.showToast(
          msg: "Error processing file: ${e.toString()}",
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    }
  }

  Future<void> _generateResults() async {
    if (_aircraftData.isEmpty) return;

    setState(() {
      _showResults = true;
    });

    final pdfFile = await _generateStyledPDF();
    if (pdfFile != null) {
      setState(() {
        _downloadHistory.add(
            '${DateTime.now().toIso8601String()}: ${pdfFile.path}');
      });
      _saveHistory();
      _showPDFSavedNotification(pdfFile.path);
    }
  }

  void _showPDFSavedNotification(String filePath) {
    Fluttertoast.showToast(
      msg: "PDF saved: $filePath",
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.green,
      textColor: Colors.white,
    );
  }

  Future<File?> _generateStyledPDF() async {
    final pdf = pw.Document();
    final fontData = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
    final ttf = pw.Font.ttf(fontData);

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Text('IAF Aircraft Health Report',
                    style: pw.TextStyle(
                        font: ttf, fontSize: 24, color: PdfColors.deepOrange)),
              ),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                context: context,
                data: [
                  ['Aircraft Name', 'Status'],
                  ..._aircraftData.map((aircraft) =>
                  [
                    aircraft['Aircraft Name'],
                    aircraft['Status']
                  ]),
                ],
                headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: pw.BoxDecoration(color: PdfColors.deepOrange),
                rowDecoration: pw.BoxDecoration(
                    border: pw.Border(
                        bottom: pw.BorderSide(color: PdfColors.grey300))
                ),
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.center
                },
              ),
            ],
          );
        },
      ),
    );

    try {
      final output = await getApplicationDocumentsDirectory();
      final file = File("${output.path}/iaf_aircraft_health_${DateTime
          .now()
          .millisecondsSinceEpoch}.pdf");
      await file.writeAsBytes(await pdf.save());
      return file;
    } catch (e) {
      print('Error saving PDF: $e');
      return null;
    }
  }

  Widget _buildExcelPreview() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columns: _excelData.first.map((header) => DataColumn(label: Text(
              header.toString(),
              style: TextStyle(fontWeight: FontWeight.bold)))).toList(),
          rows: _excelData.skip(1).map((row) {
            return DataRow(
              cells: row.map((cell) => DataCell(Text(cell?.toString() ?? '')))
                  .toList(),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildResults() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Text(
            "Aircraft Health Status:",
            style: TextStyle(fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.deepOrange),
          ),
          SizedBox(height: 20),
          ..._aircraftData.map((aircraft) {
            bool isHealthy = aircraft['Status'].toLowerCase() == 'healthy';
            return Card(
              elevation: 5,
              margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: ListTile(
                leading: Icon(
                  isHealthy ? Icons.check_circle : Icons.warning,
                  color: isHealthy ? Colors.green : Colors.red,
                  size: 40,
                ),
                title: Text(aircraft['Aircraft Name'],
                    style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  isHealthy ? 'Healthy' : 'Unhealthy',
                  style: TextStyle(
                    color: isHealthy ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                trailing: Icon(Icons.airplanemode_active, color: Colors.blue),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  void _showUploadHistory() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Upload History"),
          content: SingleChildScrollView(
            child: ListBody(
              children: _uploadHistory.isEmpty
                  ? [Text("No upload history available.")]
                  : _uploadHistory.map((history) => Text(history)).toList(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text("Close"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _refreshHome() {
    setState(() {
      _fileUploaded = false;
      _excelData.clear();
      _aircraftData.clear();
      _showResults = false;
      _excelFileName = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("IAF Aircraft Health Predictor"),
        centerTitle: true,
        backgroundColor: Colors.deepOrange,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.history),
            onPressed: _showUploadHistory,
            tooltip: "Upload History",
          ),
          IconButton(
            icon: Icon(Icons.home),
            onPressed: _refreshHome,
            tooltip: "Home",
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              'assets/images/iaf.jpg',
              fit: BoxFit.cover,
              // This will cover the entire background
              color: Colors.black.withOpacity(0.5),
              // Optional: add a dark overlay
              colorBlendMode: BlendMode.darken,
            ),
          ),
          // Foreground content
          Row(
            children: [
              Expanded(
                flex: 1, // Excel preview on left
                child: Container(
                  padding: EdgeInsets.all(8.0),
                  color: Colors.white.withOpacity(0.8),
                  // Slight transparency for better visibility
                  child: _fileUploaded ? _buildExcelPreview() : Center(
                      child: Text("Upload an Excel file",
                          style: TextStyle(fontSize: 16, color: Colors.grey))),
                ),
              ),
              VerticalDivider(width: 1, color: Colors.black12),
              Expanded(
                flex: 1, // Results on right
                child: Container(
                  padding: EdgeInsets.all(8.0),
                  color: Colors.white.withOpacity(0.8),
                  // Slight transparency for better visibility
                  child: _showResults ? _buildResults() : Center(child: Text(
                      "Results will appear here",
                      style: TextStyle(fontSize: 16, color: Colors.grey))),
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _fileUploaded ? _generateResults : _pickFile,
        label: Text(_fileUploaded ? "Generate Results" : "Upload Excel"),
        icon: _fileUploaded ? Icon(Icons.analytics) : Icon(Icons.upload_file),
        backgroundColor: Colors.deepOrange,
      ),
    );
  }
}