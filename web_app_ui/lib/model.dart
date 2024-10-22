import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart'; // for File operations

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

class DecisionTree {
  List<int> childrenLeft;
  List<int> childrenRight;
  List<int> feature;
  List<double> threshold;
  List<List<List<double>>> value;

  DecisionTree({
    required this.childrenLeft,
    required this.childrenRight,
    required this.feature,
    required this.threshold,
    required this.value,
  });

  // Predict for a single data point
  List<double> predict(List<double> inputs) {
    int node = 0;
    while (childrenLeft[node] != -1 && childrenRight[node] != -1) {
      if (inputs[feature[node]] <= threshold[node]) {
        node = childrenLeft[node];
      } else {
        node = childrenRight[node];
      }
    }
    return value[node].first;
  }
}

class RandomForest {
  List<DecisionTree> trees;
  List<int> classes;

  RandomForest({required this.trees, required this.classes});

  // Predict for a batch of inputs
  List<int> predictBatch(List<List<double>> inputs) {
    List<int> predictions = [];
    for (var input in inputs) {
      List<double> votes = List<double>.filled(classes.length, 0.0);

      for (var tree in trees) {
        List<double> prediction = tree.predict(input);
        for (int i = 0; i < prediction.length; i++) {
          votes[i] += prediction[i];
        }
      }

      // Return the class with the most votes for each input
      int bestClass = 0;
      double maxVotes = votes[0];
      for (int i = 1; i < votes.length; i++) {
        if (votes[i] > maxVotes) {
          maxVotes = votes[i];
          bestClass = i;
        }
      }
      predictions.add(classes[bestClass]);
    }
    return predictions;
  }
}

Future<Map<String, dynamic>> runRandomForestModel(List<List<dynamic>> inputBatch) async {
  // print(inputBatch);
  // Load the model JSON from the specified file path
  String jsonFilePath = 'assets/Mode_classifier.json';
  final String jsonString =
      await rootBundle.loadString('assets/Mode_classifier.json');
  // Decode the JSON string into a Map.
  Map<String, dynamic> modelData = json.decode(jsonString);
  // final fuk = await jsonString.readAsString();
  // Map<String, dynamic> modelData = json.decode(fuk);
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
  // print(inputBatch[0]);

  // Create a new list that contains only the selected columns for each row,
  // skipping the header row (starting from index 1).
  List<List<double>> filteredData = inputBatch.skip(1).map((row) {
    // Extract the relevant columns from each row using selected indices.
    return selectedIndices.map((index) {
      // Convert the value to double, or use a default value (like 0.0) if it cannot be converted.
      return double.tryParse(row[index].toString()) ?? 0.0;
    }).toList();
  }).toList();

  // print(filteredData);
  // print("ende");

  // Initialize StandardScaler
  StandardScaler scaler = StandardScaler(
    mean: List<double>.from(modelData['scaler']['mean']),
    scale: List<double>.from(modelData['scaler']['scale']),
  );

  // Initialize RandomForest
  List<DecisionTree> trees = [];
  for (var treeData in modelData['random_forest']['trees']) {
    trees.add(DecisionTree(
      childrenLeft: List<int>.from(treeData['children_left']),
      childrenRight: List<int>.from(treeData['children_right']),
      feature: List<int>.from(treeData['feature']),
      threshold: List<double>.from(treeData['threshold']),
      value: List<List<List<double>>>.from(treeData['value'].map((outer) =>
          List<List<double>>.from(
              outer.map((inner) => List<double>.from(inner))))),
    ));
  }
  List<String> classLabels = List<String>.from(
      modelData['random_forest']['classes'].map((c) => c.toString()));
  Map<String, int> classToNumber = {
    for (int i = 0; i < classLabels.length; i++) classLabels[i]: i
  };
  List<int> classes =
      classLabels.map((label) => classToNumber[label]!).toList();
  RandomForest rf = RandomForest(
    trees: trees,
    classes: classes,
  );

  // First, scale the batch of inputs
  List<List<double>> scaledBatch = scaler.transformBatch(filteredData);

  // // Then, make predictions with the RandomForest for the entire batch
  List<int> predictions = rf.predictBatch(scaledBatch);
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
    'overallStatus': averagePercentage>=50?"Healthy":"Unhealthy"
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
  // print(inputBatch[0]);

  // Create a new list that contains only the selected columns for each row,
  // skipping the header row (starting from index 1).
  List<List<double>> filteredData = inputBatch.skip(1).map((row) {
    // Extract the relevant columns from each row using selected indices.
    return selectedIndices.map((index) {
      // Convert the value to double, or use a default value (like 0.0) if it cannot be converted.
      return double.tryParse(row[index].toString()) ?? 0.0;
    }).toList();
  }).toList();

  // print(filteredData);
  // print("ende");

  // Initialize StandardScaler
  StandardScaler scaler = StandardScaler(
    mean: List<double>.from(modelData['scaler']['mean']),
    scale: List<double>.from(modelData['scaler']['scale']),
  );

  // Initialize RandomForest
  List<DecisionTree> trees = [];
  for (var treeData in modelData['random_forest']['trees']) {
    trees.add(DecisionTree(
      childrenLeft: List<int>.from(treeData['children_left']),
      childrenRight: List<int>.from(treeData['children_right']),
      feature: List<int>.from(treeData['feature']),
      threshold: List<double>.from(treeData['threshold']),
      value: List<List<List<double>>>.from(treeData['value'].map((outer) =>
          List<List<double>>.from(
              outer.map((inner) => List<double>.from(inner))))),
    ));
  }
  RandomForest rf = RandomForest(
    trees: trees,
    classes: List<int>.from(modelData['random_forest']['classes']
        .map((c) => c is int ? c : (c as double).toInt())),
  );

  // First, scale the batch of inputs
  List<List<double>> scaledBatch = scaler.transformBatch(filteredData);

  // // Then, make predictions with the RandomForest for the entire batch
  List<int> predictions = rf.predictBatch(scaledBatch);

  return predictions;
}

int countOnes(List<int> classList) {
  return classList.where((element) => element == 1).length;
}

// Function to calculate the percentage of 1s in a list.
double calculatePercentage(int countOfOnes, int totalSize) {
  return (totalSize == 0) ? 0 : (countOfOnes / totalSize) * 100;
}
