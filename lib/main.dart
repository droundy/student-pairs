import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(new MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'Student Pairs',
      theme: new ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see
        // the application has a blue toolbar. Then, without quitting
        // the app, try changing the primarySwatch below to Colors.green
        // and press "r" in the console where you ran "flutter run".
        // We call this a "hot reload". Notice that the counter didn't
        // reset back to zero -- the application is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: new MyHomePage(title: 'Student Pairs'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful,
  // meaning that it has a State object (defined below) that contains
  // fields that affect how it looks.

  // This class is the configuration for the state. It holds the
  // values (in this case the title) provided by the parent (in this
  // case the App widget) and used by the build method of the State.
  // Fields in a Widget subclass are always marked "final".

  final String title;

  @override
  _MyHomePageState createState() => new _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  int _view = 0;

  @override
  void initState() {
    super.initState();
    _readCounter().then((int value) {
      setState(() {
        _counter = value;
      });
    });
  }

  Future<File> _getLocalFile() async {
    // get the path to the document directory.
    String dir = (await PathProvider.getApplicationDocumentsDirectory()).path;
    return new File('$dir/counter.txt');
  }

  Future<int> _readCounter() async {
    try {
      File file = await _getLocalFile();
      // read the variable as a string from the file.
      String contents = await file.readAsString();
      // return int.parse(contents);
      return JSON.decode(contents)[0];
    } on FileSystemException {
      return 0;
    }
  }

  Future<Null> _incrementCounter() async {
    setState(() {
      // This call to setState tells the Flutter framework that
      // something has changed in this State, which causes it to rerun
      // the build method below so that the display can reflect the
      // updated values. If we changed _counter without calling
      // setState(), then the build method would not be called again,
      // and so nothing would appear to happen.
      _counter++;
    });
    // write the variable as a string to the file
    await (await _getLocalFile()).writeAsString(JSON.encode([_counter]));
  }

  Future<Null> _decrementCounter() async {
    setState(() {
      // This call to setState tells the Flutter framework that
      // something has changed in this State, which causes it to rerun
      // the build method below so that the display can reflect the
      // updated values. If we changed _counter without calling
      // setState(), then the build method would not be called again,
      // and so nothing would appear to happen.
      _counter--;
    });
    // write the variable as a string to the file
    await (await _getLocalFile()).writeAsString(JSON.encode([_counter]));
  }

  @override
  Widget build(BuildContext context) {
    Widget body = new Center(child: new Column(
        children: [
          new Text(
            'Button tapped $_counter time${ _counter == 1 ? '' : 's' }.',
          ),
          new Text('View $_view'),
        ],
      ));
    Widget studentview = new Center(child: new Column(
        children: [
          new Text(
            'Students tapped $_counter time${ _counter == 1 ? '' : 's' }.',
          ),
          new Text('View $_view'),
        ],
      ));
    return new Scaffold(
      appBar: new AppBar(
        // Here we take the value from the MyHomePage object that
        // was created by the App.build method, and use it to set
        // our appbar title.
        title: new Text(config.title),
        actions: [
            new Center(child: new FlatButton(
            child: new Icon(Icons.arrow_back),
            onPressed: _decrementCounter)),
            new Center(child: new FlatButton(
            child: new Icon(Icons.arrow_forward),
            onPressed: _incrementCounter)),
        ],
      ),
      body: body,
      bottomNavigationBar: new BottomNavigationBar(
      labels: [
            new DestinationLabel(
              icon: new Icon(Icons.arrow_back),
              title: new Text("Students"),
            ),
            new DestinationLabel(
              icon: new Icon(Icons.arrow_forward),
              title: new Text("Sections"),
            ),
            new DestinationLabel(
              icon: new Icon(Icons.arrow_forward),
              title: new Text("Days"),
            ),
            new DestinationLabel(
              icon: new Icon(Icons.arrow_forward),
              title: new Text("Days"),
            ),
        ],
      currentIndex: _view,
      onTap: (int index) {
        setState(() {
          _view = index;
        });
       },
      ),
      floatingActionButton: new FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: new Icon(Icons.add),
      ), // This trailing comma tells the Dart formatter to use
      // a style that looks nicer for build methods.
    );
  }
}
