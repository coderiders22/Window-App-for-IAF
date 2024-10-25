import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_app_ui/model.dart';
import 'package:web_app_ui/utils.dart';
import 'non_web_util.dart' if (dart.library.html) 'web_util.dart';

void main() {
  runApp(MyApp());
}

class MyCustomScrollBehavior extends MaterialScrollBehavior {
  // Override behavior methods like buildOverscrollIndicator and buildScrollbar
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
      };
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    return MaterialApp(
      scrollBehavior: MyCustomScrollBehavior(),
      title: 'IAF Aircraft Health Predictor',
      theme: ThemeData(
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.deepOrange),
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

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  bool _fileUploaded = false;
  bool _loading = false;
  bool _toggle = false;
  String? _excelFileName;
  List<List<dynamic>> _excelData = [];
  List<List<dynamic>> _aircraftData = [];
  List<String> _downloadHistory = [];
  List<String> _uploadHistory = [];
  late Map<String, dynamic> _finalOutput;
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
    )..repeat(reverse: true);
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

  Future<void> _pickFile(BuildContext context) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
    );
    setState(() {
      _loading = true;
    });

    late Map<String, dynamic> predictions;

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
        _aircraftData = sheet.rows
            .skip(2)
            .map((row) {
              // Map each row to its values.
              List<dynamic> values =
                  row.map((r) => r?.value?.toString().trim() ?? '').toList() ??
                      [];

              // Remove empty strings or rows that are only whitespace.
              values.removeWhere((value) => value.isEmpty);

              // Return the values if they are not empty.
              return values.isEmpty ? null : values;
            })
            .whereType<List<dynamic>>()
            .toList();

        List<String> stringsToCheck = [
          '(2)ny',
          '(3)kr',
          '(4)tg',
          '(6)hg',
          '(7)ku',
          '(8)xh',
          '(9)sh',
          '(11)dk',
          '(12)db',
          '(13)nl',
          '(14)pb',
          '(16)nz',
          '(17)tgd2',
          '(21)xk',
          '(22)xosh',
          '(23)tgd1',
          '(24)xb',
          '(29)np',
          '(31)v',
          '(32)h',
          '(45)nb',
          '(63)u'
        ];

        bool allStringsPresent = false;

        if (_aircraftData.isNotEmpty) {
          List<dynamic> firstArray = _aircraftData[0];

          // Check if each string in 'stringsToCheck' exists in 'firstArray'.
          allStringsPresent =
              stringsToCheck.every((string) => firstArray.contains(string));
        }

        if (allStringsPresent) {
          List<int> selectedIndices = [];
          int nlIndex = -1;
          int npIndex = -1;
          if (_aircraftData.isNotEmpty) {
            List<dynamic> headerRow = _aircraftData[0];
            selectedIndices =
                stringsToCheck.map((col) => headerRow.indexOf(col)).toList();
          }
          // Find the indices for 'nl' and 'np'
          // Find the indices for 'nl' and 'np'
          nlIndex = stringsToCheck.indexOf('(13)nl');
          npIndex = stringsToCheck.indexOf('(29)np');

          int removedCount = 0;
          List<List<dynamic>> filteredData = _aircraftData.where((row) {
            // Check if all selected indices are valid for the current row
            if (!selectedIndices.every((index) => index < row.length)) {
              removedCount++; // Increment count for removed row
              return false; // Exclude this row
            }
            return true; // Include this row
          }).map((row) {
            // Map the valid rows to the selected indices
            return selectedIndices.map((index) => row[index]).toList();
          }).toList();
          List<List<dynamic>> validData = [];

          for (var row in filteredData) {
            bool isValidRow = true;
            // Check if values in 'nl' and 'np' columns meet the conditions
            var nlValue =
                double.tryParse(row[nlIndex].toString()) ?? double.nan;
            var npValue =
                double.tryParse(row[npIndex].toString()) ?? double.nan;

            if (nlValue > 150 ||
                nlValue < -0.5 ||
                npValue > 150 ||
                npValue < -0.5) {
              isValidRow = false;
              removedCount++;
              continue; // Skip this row
            }
            for (var value in row) {
              if (value == null ||
                  value.toString().trim().isEmpty ||
                  value.toString() == 'NaN') {
                isValidRow = false;
                removedCount++;
                break;
              }
            }
            if (isValidRow) {
              validData.add(row);
            }
          }

          predictions = await runRandomForestModel(validData);
          predictions["removedRows"] = removedCount;
          predictions["totalRows"] = validData.length - 1;
        } else {
          throw ErrorDescription("Wrong CSV Uploaded");
        }
        // Working in chroma and not windows need to work on that

        setState(() {
          _fileUploaded = true;
          _loading = false;
          _toggle = true;
          _uploadHistory
              .add('${DateTime.now().toIso8601String()}: $_excelFileName');
          _finalOutput = predictions;
        });
        showCustomPopup(context, true, 'CSV Parsed Successfully');

        _saveHistory();
      } catch (e) {
        setState(() {
          _fileUploaded = false;
          _loading = false;
          _toggle = false;
          _excelData.clear();
          _aircraftData.clear();
          _showResults = false;
          _excelFileName = null;
        });
        print("Error ${e.toString()}");
        showCustomPopup(context, false, 'Incomplete CSV Uploaded');
      }
    }
  }

  Future<void> _generateResults(BuildContext context) async {
    if (_finalOutput.isEmpty) return;

    setState(() {
      _showResults = true;
      _loading = true;
    });

    final pdfFile = await _generateStyledPDF();
    if (pdfFile != null) {
      setState(() {
        _downloadHistory
            .add('${DateTime.now().toIso8601String()}: ${pdfFile.path}');
      });
      _saveHistory();

      _showPDFSavedNotification(pdfFile.path);
    }
    setState(() {
      _loading = false;
      _toggle = false;
    });
  }

  void _showPDFSavedNotification(String filePath) {
    String message = kIsWeb ? "PDF Downloaded" : "PDF saved: $filePath";
    showCustomPopup(context, true, message);
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
              pw.TableHelper.fromTextArray(
                context: context,
                headers: ['Mode', 'Healthy', 'Total Size'],
                data: [
                  [
                    'Cruise',
                    _finalOutput['cruise']['healthy'],
                    _finalOutput['cruise']['totalSize']
                  ],
                  [
                    'Idle',
                    _finalOutput['idle']['healthy'],
                    _finalOutput['idle']['totalSize']
                  ],
                  [
                    'Takeoff',
                    _finalOutput['takeoff']['healthy'],
                    _finalOutput['takeoff']['totalSize']
                  ],
                ],
                headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: pw.BoxDecoration(color: PdfColors.deepOrange),
                rowDecoration: pw.BoxDecoration(
                    border: pw.Border(
                        bottom: pw.BorderSide(color: PdfColors.grey300))),
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.center,
                  2: pw.Alignment.center,
                },
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Total Rows: ${_finalOutput['totalRows']}',
                style: pw.TextStyle(font: ttf, fontSize: 12),
              ),
              pw.Text(
                'Removed Rows: ${_finalOutput['removedRows']}',
                style: pw.TextStyle(font: ttf, fontSize: 12),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Average Healthy Percentage: ${_finalOutput['averagePercentage']}%',
                style: pw.TextStyle(font: ttf, fontSize: 12),
              ),
              pw.Text(
                'Overall Status: ${_finalOutput['overallStatus']}',
                style: pw.TextStyle(
                    font: ttf,
                    fontSize: 12,
                    color: _finalOutput['overallStatus'] == 'Healthy'
                        ? PdfColors.green
                        : PdfColors.red),
              ),
            ],
          );
        },
      ),
    );

    // Save the PDF file to a location
    try {
      if (kIsWeb) {
        // Save the PDF to bytes
        final pdfBytes = await pdf.save();
        downloadPdf(pdfBytes, "aircraft_health_report.pdf");
        return null;
      }
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/aircraft_health_report.pdf');
      return file.writeAsBytes(await pdf.save());
    } catch (e) {
      print("Error PDF ${e}");
      showCustomPopup(context, false, e.toString());
      return null;
    }
  }

  Widget _buildExcelPreview() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: DataTable(
          columns: _aircraftData.first
              .map((header) => DataColumn(
                  label: Text(header.toString(),
                      style: TextStyle(fontWeight: FontWeight.bold))))
              .toList(),
          rows: List<DataRow>.generate(
            (_aircraftData.length - 1).clamp(0, 50), // Skip header
            (index) {
              var row = _aircraftData[index + 1]; // Adjust index
              return DataRow(
                cells: row
                    .map((cell) => DataCell(Text(cell?.toString() ?? '')))
                    .toList(),
              );
            },
          ),
        ),
      ),
    );
  }

  // Helper to build a row in the table
  TableRow _buildTableRow(String phase, double healthy, double total) {
    return TableRow(children: [
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(phase, style: TextStyle(color: Colors.black)),
      ),
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(healthy.toString(), style: TextStyle(color: Colors.black)),
      ),
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(total.toString(), style: TextStyle(color: Colors.black)),
      ),
    ]);
  }

  // Helper to build a row displaying status
  Widget _buildStatusRow(String label, double value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Text(
            "$label ",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Text(
            value.toString(),
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            "Aircraft Health Status:",
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.deepOrange),
          ),
        ),

        SizedBox(height: 20),

        // Table for Cruise, Idle, and Takeoff
        Card(
          margin: EdgeInsets.symmetric(horizontal: 16),
          elevation: 5,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Table(
              columnWidths: {
                0: FlexColumnWidth(1),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1),
              },
              border: TableBorder.all(color: Colors.black),
              children: [
                // Table Header
                TableRow(children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      "Mode",
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      "Healthy",
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      "Total",
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ),
                ]),

                // Cruise Data
                _buildTableRow("Cruise", _finalOutput['cruise']['healthy'],
                    _finalOutput['cruise']['totalSize']),

                // Idle Data
                _buildTableRow("Idle", _finalOutput['idle']['healthy'],
                    _finalOutput['idle']['totalSize']),

                // Takeoff Data
                _buildTableRow("Takeoff", _finalOutput['takeoff']['healthy'],
                    _finalOutput['takeoff']['totalSize']),
              ],
            ),
          ),
        ),

        SizedBox(height: 20),

        // Total Rows, Removed Rows, and Overall Status
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Total Rows
              _buildStatusRow("Total Rows:", _finalOutput['totalRows']),

              // Removed Rows
              _buildStatusRow("Removed Rows:", _finalOutput['removedRows']),

              // Overall Status
              Row(
                children: [
                  Text(
                    "Overall Status: ",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    _finalOutput['overallStatus'],
                    style: TextStyle(
                      color: _finalOutput['overallStatus'] == 'Healthy'
                          ? Colors.green
                          : Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
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
                  child: _fileUploaded
                      ? _buildExcelPreview()
                      : Center(
                          child: Text("Upload an Excel file",
                              style:
                                  TextStyle(fontSize: 16, color: Colors.grey))),
                ),
              ),
              VerticalDivider(width: 1, color: Colors.black12),
              Expanded(
                flex: 1, // Results on right
                child: Container(
                  padding: EdgeInsets.all(8.0),
                  color: Colors.white.withOpacity(0.8),
                  // Slight transparency for better visibility
                  child: _showResults
                      ? _buildResults()
                      : Center(
                          child: Text("Results will appear here",
                              style:
                                  TextStyle(fontSize: 16, color: Colors.grey))),
                ),
              ),
            ],
          ),
        ],
      ),
      // floatingActionButton: FloatingActionButton.extended(
      //   onPressed: _toggle ? _generateResults : _pickFile,
      //   label: Text(_toggle ? "Generate Results" : "Upload Excel"),
      //   icon: _fileUploaded ? Icon(Icons.analytics) : Icon(Icons.upload_file),
      //   backgroundColor: Colors.deepOrange,
      // ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading
            ? null // Disable the button when loading
            : () async {
                if (_toggle) {
                  await _generateResults(context); // Your generate logic
                } else {
                  await _pickFile(context); // Your file picking logic
                }
              },
        label: _loading
            ? Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.0,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(
                      width: 8), // Add some spacing between the loader and text
                  Text("Loading..."),
                ],
              )
            : Text(_toggle ? "Generate Results" : "Upload Excel"),
        icon: _loading
            ? null
            : _fileUploaded
                ? Icon(Icons.analytics)
                : Icon(Icons.upload_file),
        backgroundColor: _loading
            ? Colors.grey
            : Colors.deepOrange, // Optional: Change color when loading
      ),
    );
  }
}
