import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart'; // for File operations

const double INFINITY = 1.0 / 0.0;
const double NEGATIVE_INFINITY = INFINITY * -1;

int argmax(List<dynamic> X) {
  int idx = 0;
  int l = X.length;
  for (int i = 0; i < l; i++) {
    idx = X[i] > X[idx] ? i : idx;
  }
  return idx;
}

class StandardScaler {
  List<double> mean;
  List<double> scale;

  StandardScaler({required this.mean, required this.scale});

  // Scale a batch of input data
  List<List<double>> transformBatch(List<List<double>> inputs) {
    return inputs.map((input) {
      List<double> scaled = [];
      for (int i = 0; i < input.length; i++) {
        scaled.add((input[i] - mean[i]) / scale[i]);
      }
      return scaled;
    }).toList();
  }
}

class DecisionTreeClassifier {
  List<int> childrenLeft;
  List<int> childrenRight;
  List<double> threshold;
  List<int> features;
  List<List<dynamic>> values;
  List<int> classes;

  /// To manually instantiate the DecisionTreeClassifier. The parameters
  /// are lifted directly from scikit-learn.
  /// See the attributes here:
  /// https://scikit-learn.org/stable/modules/generated/sklearn.tree.DecisionTreeClassifier.html
  DecisionTreeClassifier(this.childrenLeft, this.childrenRight, this.threshold,
      this.features, this.values, this.classes);

  factory DecisionTreeClassifier.fromMap(Map params) {
    return DecisionTreeClassifier(
        List<int>.from(params["children_left"]),
        List<int>.from(params["children_right"]),
        List<double>.from(params["threshold"]),
        List<int>.from(params["feature"]),
        List<List<dynamic>>.from(params["value"]),
        List<int>.from(params["classes_"] ?? []));
  }

  int predict(List<double> X) {
    return _predict(X);
  }

  int _predict(List<double> X, [int? node]) {
    node ??= 0;
    if (childrenLeft[node]!=-1) {
      if (X[features[node]] <= threshold[node])
        return _predict(X, childrenLeft[node]);
      return _predict(X, childrenRight[node]);
    }
    return classes[argmax(List<double>.from(values[node].first))];
  }
}

/// An implementation of sklearn.ensemble.RandomForestClassifier
/// ---------------
///
/// https://scikit-learn.org/stable/modules/generated/sklearn.ensemble.RandomForestClassifier.html
class RandomForestClassifier {
  List<int> classes;
  List<DecisionTreeClassifier> _dtrees = [];
  List<dynamic> dtrees;

  /// To manually instantiate the RandomForestClassifier. The parameters
  /// are lifted directly from scikit-learn.
  /// See the attributes here:
  /// https://scikit-learn.org/stable/modules/generated/sklearn.ensemble.RandomForestClassifier.html
  RandomForestClassifier(this.classes, this.dtrees) {
    initDtrees(dtrees);
  }

  /// Override from Classifier.
  factory RandomForestClassifier.fromMap(Map<String, dynamic> params) {
    return RandomForestClassifier(
        List<int>.from(params["classes_"]), params["dtrees"]);
  }

  /// Initializes the decision [trees] within the forest.
  /// Each of those instantiates a DecisionTreeClassifier.
  void initDtrees(List<dynamic> trees) {
    if (_dtrees.length > 0) return null;
    for (int i = 0; i < trees.length; i++) {
      trees[i]["classes_"] = classes;
      _dtrees.add(DecisionTreeClassifier.fromMap(trees[i]));
    }
  }

  int predict(List<double> X) {
    var cls = List<dynamic>.filled(_dtrees[0].classes.length, 0);
    _dtrees.asMap().forEach((i, v) => cls[_dtrees[i].predict(X)]++);
    return classes[argmax(cls)];
  }
}

Future<Map<String, dynamic>> runRandomForestModel(
    List<List<dynamic>> inputBatch) async {
  String jsonFilePath = 'assets/Mode_classifier.json';
  final String jsonString =
      await rootBundle.loadString('assets/Mode_classifier.json');
  Map<String, dynamic> modelData = json.decode(jsonString);
  List<String> stringsToCheck = [
    '(2)ny',
    '(3)kr',
    '(4)tg',
    '(6)hg',
    '(7)ku',
    '(8)xh',
    '(9)sh',
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
  List<int> selectedIndices = [];
  if (inputBatch.isNotEmpty) {
    List<dynamic> headerRow = inputBatch[0];
    selectedIndices =
        stringsToCheck.map((col) => headerRow.indexOf(col)).toList();
  }

  List<List<double>> filteredData = inputBatch.skip(1).map((row) {
    return selectedIndices.map((index) {
      return double.tryParse(row[index].toString()) ?? 0.0;
    }).toList();
  }).toList();

  StandardScaler scaler = StandardScaler(
    mean: List<double>.from(modelData['scaler']['mean']),
    scale: List<double>.from(modelData['scaler']['scale']),
  );

  List<List<double>> scaledBatch = scaler.transformBatch(filteredData);

  RandomForestClassifier rf =
      RandomForestClassifier.fromMap(modelData["random_forest"]);

  // Then, make predictions with the RandomForest for the entire batch
  List<int> predictions = [];
  for (var input in scaledBatch) {
    int v = rf.predict(input);
    predictions.add(v);
  }

  // Create three lists to store rows corresponding to each class.
  List<List<dynamic>> class0Rows = [stringsToCheck];
  List<List<dynamic>> class1Rows = [stringsToCheck];
  List<List<dynamic>> class2Rows = [stringsToCheck];

// Separate the rows based on their corresponding class labels.
  for (int i = 0; i < filteredData.length; i++) {
    if (predictions[i] == 0) {
      class0Rows.add(filteredData[i]);
    } else if (predictions[i] == 1) {
      class1Rows.add(filteredData[i]);
    } else if (predictions[i] == 2) {
      class2Rows.add(filteredData[i]);
    }
  }

// Now, class0Rows, class1Rows, and class2Rows contain rows of their respective classes, plus the header row.
  List<int> class0 = await runMode(class0Rows, 'cruise');
  List<int> class1 = await runMode(class1Rows, 'idle');
  List<int> class2 = await runMode(class2Rows, 'takeoff');

  // Calculate the count of 1s in each class and the size of each class.
  int countClass0 = countOnes(class0);
  int countClass1 = countOnes(class1);
  int countClass2 = countOnes(class2);

  int sizeClass0 = class0.length;
  int sizeClass1 = class1.length;
  int sizeClass2 = class2.length;

  // Calculate percentages for each class.
  double percentageClass0 = calculatePercentage(countClass0, sizeClass0);
  double percentageClass1 = calculatePercentage(countClass1, sizeClass1);
  double percentageClass2 = calculatePercentage(countClass2, sizeClass2);
  print(percentageClass0);

// Calculate the combined average percentage.
  double averagePercentage =
      (percentageClass0 + percentageClass1 + percentageClass2) / 3;

// Create a map to hold the percentages for each class and the combined average.
  Map<String, dynamic> classSummary = {
    'cruise': {
      'healthy': percentageClass0,
      'totalSize': sizeClass0,
    },
    'idle': {
      'healthy': percentageClass1,
      'totalSize': sizeClass1,
    },
    'takeoff': {
      'healthy': percentageClass2,
      'totalSize': sizeClass2,
    },
    'averagePercentage': averagePercentage,
    'overallStatus': averagePercentage >= 50 ? "Healthy" : "Unhealthy"
  };

  return classSummary;
}

Future<List<int>> runMode(
    List<List<dynamic>> inputBatch, String jsontring) async {
  // print(inputBatch);
  // Load the model JSON from the specified file path
  final String jsonString =
      await rootBundle.loadString('assets/$jsontring.json');
  // Decode the JSON string into a Map.
  Map<String, dynamic> modelData = json.decode(jsonString);
  // final fuk = await jsonString.readAsString();
  // Map<String, dynamic> modelData = json.decode(fuk);
  List<String> stringsToCheck = [
    '(4)tg',
    '(6)hg',
    '(7)ku',
    '(8)xh',
    '(9)sh',
    '(12)db',
    '(13)nl',
    '(14)pb',
    '(17)tgd2',
    '(21)xk',
    '(22)xosh',
    '(23)tgd1',
    '(24)xb',
    '(29)np',
    '(31)v',
    '(32)h',
    '(45)nb'
  ];
  List<int> selectedIndices = [];
  if (inputBatch.isNotEmpty) {
    List<dynamic> headerRow = inputBatch[0];
    selectedIndices =
        stringsToCheck.map((col) => headerRow.indexOf(col)).toList();
  }

  List<List<double>> filteredData = inputBatch.skip(1).map((row) {
    // Extract the relevant columns from each row using selected indices.
    return selectedIndices.map((index) {
      // Convert the value to double, or use a default value (like 0.0) if it cannot be converted.
      return double.tryParse(row[index].toString()) ?? 0.0;
    }).toList();
  }).toList();

  // Initialize StandardScaler
  StandardScaler scaler = StandardScaler(
    mean: List<double>.from(modelData['scaler']['mean']),
    scale: List<double>.from(modelData['scaler']['scale']),
  );

  // First, scale the batch of inputs
  List<List<double>> scaledBatch = scaler.transformBatch(filteredData);

  RandomForestClassifier rf =
      RandomForestClassifier.fromMap(modelData["random_forest"]);
  print(-44);

  // Then, make predictions with the RandomForest for the entire batch
  List<int> predictions = [];
  for (var input in scaledBatch) {
    int v = rf.predict(input);
    predictions.add(v);
  }

  return predictions;
}

int countOnes(List<int> classList) {
  return classList.where((element) => element == 1).length;
}

// Function to calculate the percentage of 1s in a list.
double calculatePercentage(int countOfOnes, int totalSize) {
  return (totalSize == 0) ? 0 : (countOfOnes / totalSize) * 100;
}
