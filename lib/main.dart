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

enum _View {
  students,
  sections,
  days,
}
int toint(_View v) {
  switch (v) {
  case _View.students: return 0;
  case _View.sections: return 1;
  case _View.days: return 2;
  }
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  _View _view = _View.students;
  List<String> _students = [];
  List<String> _sections = [];
  List<Map> _days = [];

  @override
  void initState() {
    super.initState();
    debugPrint("I am in initState");
    _readState().then((Map state) {
      setState(() {
        _counter = state['counter'];
        _students = state['students'];
        _sections = state['sections'];
        _days = state['days'];
      });
    });
  }

  Future<File> _getLocalFile() async {
    // get the path to the document directory.
    String dir = (await PathProvider.getApplicationDocumentsDirectory()).path;
    return new File('$dir/student-pairs.json');
  }

  Future<Map> _readState() async {
    try {
      File file = await _getLocalFile();
      // read the variable as a string from the file.
      String contents = await file.readAsString();
      print('reading $file contents are $contents');
      return JSON.decode(contents);
    } on FileSystemException {
      return {'counter': 0,
          'students': [],
          'sections': [],
          'days': []};
    }
  }
  Future<Null> _writeState() async {
    // write the variable as a string to the file
    _students.sort();
    await (await _getLocalFile()).writeAsString(JSON.encode({
        'counter': _counter,
            'students': _students,
            'sections': _sections,
            'days': _days,
            }));
    Map test = await _readState();
    debugPrint('my file is $test');
  }

  Future<Null> _incrementCounter() async {
    debugPrint("I am in _incrementCounter");
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
    await _writeState();
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
    await _writeState();
  }

  Future<Null> add() async {
    switch (_view) {
    case _View.students:
      var x = await textInputDialog(context,
                            'Add student',
                            );
      if (x == null) {
        return;
      }
      setState(() {
          // This call to setState tells the Flutter framework that
          // something has changed in this State, which causes it to rerun
          // the build method below so that the display can reflect the
          // updated values. If we changed _counter without calling
          // setState(), then the build method would not be called again,
          // and so nothing would appear to happen.
          _students.add(x);
        });
      // write the variable as a string to the file
      await _writeState();
      debugPrint(' got student string "$x"');
      break;
    case _View.sections:
      var x = await textInputDialog(context, 'Add section');
      if (x == null) {
        return;
      }
      setState(() {
          _sections.add(x);
        });
      await _writeState();
      debugPrint('added section "$x"');
      break;
    case _View.days:
      var x = await textInputDialog(context, 'Add date');
      if (x == null) {
        return;
      }
      setState(() {
          _days.add({'date': x});
        });
      await _writeState();
      debugPrint('added day "$x"');
      break;
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    switch (_view) {
    case _View.students:
      List<Widget> ch = _students.map((s) =>
                                      new Padding(child: new Row(children: <Widget>[new Text(s),
                                                                                    new FlatButton(child: new Icon(Icons.delete),
                                                                                                   onPressed: () async {
                                                                                                     var ok = await confirmDialog(context, 'Really delete student $s?', 'DELETE');
                                                                                                     if (ok != null && ok) {
                                                                                                       setState(() {
                                                                                                           _students.remove(s);
                                                                                                         });
                                                                                                       _writeState();
                                                                                                     }
                                                                                                   },)],
                                                                 mainAxisSize: MainAxisSize.max,
                                                                 mainAxisAlignment: MainAxisAlignment.spaceBetween),
                                                  padding: const EdgeInsets.all(12.0),)
                                      ).toList();
      body = new Block(children: ch);
      break;
    case _View.sections:
      List<Widget> ch = _sections.map((s) =>
                                      new Padding(child: new Row(children: <Widget>[new Text(s),
                                                                                    new FlatButton(child: new Icon(Icons.delete),
                                                                                                   onPressed: () async {
                                                                                                     var ok = await confirmDialog(context, 'Really delete section $s?', 'DELETE');
                                                                                                     if (ok != null && ok) {
                                                                                                       setState(() {
                                                                                                           _sections.remove(s);
                                                                                                         });
                                                                                                       _writeState();
                                                                                                     }
                                                                                                   },)],
                                                                 mainAxisSize: MainAxisSize.max,
                                                                 mainAxisAlignment: MainAxisAlignment.spaceBetween),
                                                  padding: const EdgeInsets.all(12.0),)
                                      ).toList();
      body = new Block(children: ch);
      break;
    case _View.days:
      List<Widget> ch = _days.map((d) =>
                                      new Padding(child: new Row(children: <Widget>[new Text(d['date']),
                                                                                    new FlatButton(child: new Icon(Icons.delete),
                                                                                                   onPressed: () async {
                                                                                                     var ok = await confirmDialog(context, "Really delete day ${d['date']}}?", 'DELETE');
                                                                                                     if (ok != null && ok) {
                                                                                                       setState(() {
                                                                                                           _days.remove(d);
                                                                                                         });
                                                                                                       _writeState();
                                                                                                     }
                                                                                                   },)],
                                                                 mainAxisSize: MainAxisSize.max,
                                                                 mainAxisAlignment: MainAxisAlignment.spaceBetween),
                                                  padding: const EdgeInsets.all(12.0),)
                                      ).toList();
      body = new Block(children: ch);
      break;
    default:
      body = new Center(child: new Text('ERROR $_view'));
      break;
    }
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
              icon: new Icon(Icons.people),
              title: new Text("Students"),
            ),
            new DestinationLabel(
              icon: new Icon(Icons.assignment),
              title: new Text("Sections"),
            ),
            new DestinationLabel(
              icon: new Icon(Icons.schedule),
              title: new Text("Days"),
            ),
            new DestinationLabel(
              icon: new Icon(Icons.restaurant),
              title: new Text("Days"),
            ),
        ],
      currentIndex: toint(_view),
      onTap: (int index) {
        setState(() {
            switch (index) {
              case 0:
                _view = _View.students;
                break;
              case 1:
                _view = _View.sections;
                break;
              case 2:
              case 3:
                _view = _View.days;
              }
          });
      },
      ),
      floatingActionButton: new FloatingActionButton(
        onPressed: add,
        tooltip: 'Increment',
        child: new Icon(Icons.add),
      ), // This trailing comma tells the Dart formatter to use
      // a style that looks nicer for build methods.
    );
  }
}

Future<String> textInputDialog(BuildContext context, String title) async {
  InputValue myinput = new InputValue(text: '');
  String foo;
  return showDialog(context: context,
                    child: new AlertDialog(title: new Text(title),
                                           content: new Input(value: myinput,
                                                              onChanged: (InputValue newval) {
                                                                foo = newval.text;
                                                              },
                                                              onSubmitted: (InputValue newval) {
                                                                Navigator.pop(context, newval.text);
                                                              }),
                                           actions: <Widget>[
                                                        new FlatButton(
                                                                       child: new Text('CANCEL'),
                                                                       onPressed: () {
                                                                         Navigator.pop(context, null);
                                                                       }
                                                                       ),
                                                        new FlatButton(
                                                                       child: new Text('ADD'),
                                                                       onPressed: () {
                                                                         Navigator.pop(context, foo);
                                                                       }
                                                                       ),
                                                        ]),
                    );
}

Future<bool> confirmDialog(BuildContext context, String title, String action) async {
  return showDialog(context: context,
                    child: new AlertDialog(title: new Text(title),
                                           actions: <Widget>[
                                                        new FlatButton(
                                                                       child: new Text('CANCEL'),
                                                                       onPressed: () {
                                                                         Navigator.pop(context, false);
                                                                       }
                                                                       ),
                                                        new FlatButton(
                                                                       child: new Text(action),
                                                                       onPressed: () {
                                                                         Navigator.pop(context, true);
                                                                       }
                                                                       ),
                                                        ]),
                    );
}
