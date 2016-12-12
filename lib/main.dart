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
  int _currentDate = 0;

  @override
  void initState() {
    super.initState();
    _readState().then((Map state) {
      setState(() {
        _counter = state['counter'];
        _students = state['students'];
        _sections = state['sections'];
        _days = state['days'];
        if (state.containsKey('currentDate')) {
          _currentDate = state['currentDate'];
        }
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
          'currentDate': -1,
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
            'currentDate': _currentDate,
            'students': _students,
            'sections': _sections,
            'days': _days,
            }));
    Map test = await _readState();
    debugPrint('my file is $test');
  }

  Future<Null> _incrementCounter() async {
    setState(() { _counter++; });
    await _writeState();
  }

  Future<Null> _decrementCounter() async {
    setState(() { _counter--; });
    await _writeState();
  }
  _currentDateSetter(int value) {
    Future<Null> setter() async {
      setState(() {
          _currentDate = value;
        });
      await _writeState();
    }
    return setter;
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
  bool _amViewingDate() {
    return _currentDate >= 0 && _currentDate < _days.length;
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_amViewingDate()) {
      // This is where we edit the plan for a given class day
      switch (_view) {
      case _View.students:
        List<Widget> ch = [];
        for (int i=0; i<_days.length; i++) {
          String s = _students[i];
          Widget w = new Padding(child: new Row(children: <Widget>[new Text(s),
                                                                   new PopupMenuButton(child: new Text('menu here'),
                                                                                       itemBuilder: (BuildContext context) =>
                                                                                       <PopupMenuItem>[new PopupMenuItem(value: 0,
                                                                                                                         child: new Text('hello')),
                                                                                                       new PopupMenuItem(value: 1,
                                                                                                                         child: new Text('goodbye')),]
                                                                                       )],
                                                mainAxisSize: MainAxisSize.max,
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween),
                                 padding: const EdgeInsets.all(12.0),);
          ch.add(w);
        }
        body = new Block(children: ch);
        break;
      case _View.sections:
        List<Widget> ch = _sections.map((s) =>
                                        new Padding(child: new Row(children: <Widget>[new Text(s)],
                                                                   mainAxisSize: MainAxisSize.max,
                                                                   mainAxisAlignment: MainAxisAlignment.spaceBetween),
                                                    padding: const EdgeInsets.all(12.0),)
                                        ).toList();
        body = new Block(children: ch);
        break;
      case _View.days:
        List<Widget> ch = [];
        for (int i=0; i<_days.length; i++) {
          Widget w = new Padding(child: new Row(children: <Widget>[new FlatButton(child: new Text(_days[i]['date']),
                                                                                  onPressed: _currentDateSetter(i))],
                                                mainAxisSize: MainAxisSize.max,
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween),
                                 padding: const EdgeInsets.all(12.0),);
          ch.add(w);
        }
        body = new Block(children: ch);
        break;
      }
    } else {
      // Here is where we edit the possibilities
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
        List<Widget> ch = [];
        for (int i=0; i<_days.length; i++) {
          Widget w = new Padding(child: new Row(children: <Widget>[new FlatButton(child: new Text(_days[i]['date']),
                                                                                  onPressed: _currentDateSetter(i)),
                                                                   new FlatButton(child: new Icon(Icons.delete),
                                                                                  onPressed: () async {
                                                                                    var ok = await confirmDialog(context, "Really delete day ${_days[i]['date']}}?", 'DELETE');
                                                                                    if (ok != null && ok) {
                                                                                      setState(() {
                                                                                          _days.removeAt(i);
                                                                                        });
                                                                                      _writeState();
                                                                                    }
                                                                                  },)],
                                                mainAxisSize: MainAxisSize.max,
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween),
                                 padding: const EdgeInsets.all(12.0),);
          ch.add(w);
        }
        body = new Block(children: ch);
        break;
      }
    }
    String title = config.title;
    if (_amViewingDate()) {
      title = _days[_currentDate]['date'];
    }
    return new Scaffold(
      appBar: new AppBar(
        // Here we take the value from the MyHomePage object that
        // was created by the App.build method, and use it to set
        // our appbar title.
        title: new Text(title),
        actions: [
            new Center(child: new FlatButton(
            child: new Icon(Icons.home),
            onPressed: _currentDateSetter(-1))),
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
