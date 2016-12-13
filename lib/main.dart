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
  teams,
}
int toint(_View v) {
  switch (v) {
  case _View.students: return 0;
  case _View.sections: return 1;
  case _View.teams: return 2;
  case _View.days: return 3;
  }
}

final Widget studentIcon = new Icon(Icons.people);
final Widget sectionIcon = new Icon(Icons.assignment);
final Widget teamIcon = new Icon(Icons.restaurant);
final Widget dayIcon = new Icon(Icons.schedule);
final Widget deleteIcon = new Icon(Icons.delete);

class _MyHomePageState extends State<MyHomePage> {
  _View _view = _View.students;
  List<String> _students = [];
  List<String> _sections = [];
  List<String> _teams = [];
  List<Map> _days = [];
  int _currentDate = 0;

  @override
  void initState() {
    super.initState();
    _readState().then((Map state) {
      setState(() {
        _students = state['students'];
        _sections = state['sections'];
        _days = state['days'];
        if (state.containsKey('teams')) {
          _teams = state['teams'];
        }
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
      return {
      'currentDate': -1,
          'students': [],
          'sections': [],
          'days': []};
    }
  }
  Future<Null> _writeState(void setit()) async {
    setState(setit);
    // write the variable as a string to the file
    _students.sort();
    await (await _getLocalFile()).writeAsString(JSON.encode({
            'currentDate': _currentDate,
            'students': _students,
            'sections': _sections,
            'teams': _teams,
            'days': _days,
            }));
    Map test = await _readState();
    debugPrint('my file is $test');
  }

  _currentDateSetter(int value) {
    Future<Null> setter() async {
      await _writeState(() {
          _currentDate = value;
        });
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
      await _writeState(() {
          _students.add(x);
        });
      break;
    case _View.sections:
      var x = await textInputDialog(context, 'Add section');
      if (x == null) {
        return;
      }
      await _writeState(() {
          _sections.add(x);
        });
      break;
    case _View.teams:
      var x = await textInputDialog(context, 'Add team');
      if (x == null) {
        return;
      }
      await _writeState(() {
          _teams.add(x);
        });
      break;
    case _View.days:
      var x = await textInputDialog(context, 'Add date');
      if (x == null) {
        return;
      }
      await _writeState(() {
          _days.add({'date': x});
        });
      break;
    }
  }
  bool _amViewingDate() {
    return _currentDate >= 0 && _currentDate < _days.length;
  }
  Map _today() {
    if (_amViewingDate()) {
      return _days[_currentDate];
    }
    return null;
  }
  Map _defaults() {
    if (_days.length == 0) {
      _days.add({'date': 'default'});
    }
    if (_days[0]['date'] != 'default') {
      _days.insert(0, {'date': 'default'});
    }
    return _days[0];
  }
  Map _studentDefault(String student) {
    Map d = _defaults();
    if (!d.containsKey('students')) {
      d['students'] = {};
    }
    d = d['students'];
    if (!d.containsKey(student)) {
      d[student] = {};
    }
    return d[student];
  }
  Map _todayStudent(String student) {
    Map today = _today();
    if (today == null) return null;
    if (!today.containsKey('students')) {
      today['students'] = {};
    }
    Map students = today['students'];
    if (!students.containsKey(student)) {
      students[student] = {};
    }
    return students[student];
  }

  String _todayStudentSection(String student) {
    Map today = _todayStudent(student);
    if (today != null && today.containsKey('section')) {
      return today['section'];
    }
    Map d = _studentDefault(student);
    if (d.containsKey('section')) return d['section'];
    return '-';
  }

  String _todayStudentTeam(String student) {
    Map today = _todayStudent(student);
    if (today != null && today.containsKey('team')) {
      return today['team'];
    }
    Map d = _studentDefault(student);
    if (d.containsKey('team')) return d['team'];
    return '-';
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_amViewingDate()) {
      // This is where we edit the plan for a given class day
      switch (_view) {
      case _View.students:
        List<String> section_options = new List.from(_sections)..add('absent');
        List<String> team_options = new List.from(_teams)..add('unknown');
        List<DataColumn> columns = <DataColumn>[new DataColumn(label: studentIcon),
                                                new DataColumn(label: sectionIcon),
                                                new DataColumn(label: teamIcon),
                                                ];
        List<DataRow> rows = [];
        for (int i=0; i<_students.length; i++) {
          String s = _students[i];
          Map today = _todayStudent(s);
          String s_section = _todayStudentSection(s);
          String s_team = _todayStudentTeam(s);
          rows.add(new DataRow(cells: <DataCell>[new DataCell(new Text(s)),
                                                 new DataCell(alternativesMenu(section_options, s_section, (n) {
                                                       _writeState (() {
                                                           today['section'] = n;
                                                           debugPrint('wrote section $s as $n');
                                                         });
                                                     })),
                                                 new DataCell(alternativesMenu(team_options, s_team, (n) {
                                                       _writeState (() {
                                                           today['team'] = n;
                                                         });
                                                     })),
                                                 ]));
        }
        body = new Block(children: <Widget>[new DataTable(columns: columns,
                                                          rows: rows)]);
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
      case _View.teams:
        List<Widget> ch = _teams.map((s) =>
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
                                                                                      deleteButton('student $s', () {
                                                                                          _students.remove(s);
                                                                                        }),
                                                                                      ],
                                                                   mainAxisSize: MainAxisSize.max,
                                                                   mainAxisAlignment: MainAxisAlignment.spaceBetween),
                                                    padding: const EdgeInsets.all(12.0),)
                                        ).toList();
        body = new Block(children: ch);
        break;
      case _View.sections:
        List<Widget> ch = _sections.map((s) =>
                                        new Padding(child: new Row(children: <Widget>[new Text(s),
                                                                                      new FlatButton(child: deleteIcon,
                                                                                                     onPressed: () async {
                                                                                                       var ok = await confirmDialog(context, 'Really delete section $s?', 'DELETE');
                                                                                                       if (ok != null && ok) {
                                                                                                         _writeState(() {
                                                                                                             _sections.remove(s);
                                                                                                           });
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
                                                                   new FlatButton(child: deleteIcon,
                                                                                  onPressed: () async {
                                                                                    var ok = await confirmDialog(context, "Really delete day ${_days[i]['date']}?", 'DELETE');
                                                                                    if (ok != null && ok) {
                                                                                      _writeState(() {
                                                                                          _days.removeAt(i);
                                                                                        });
                                                                                    }
                                                                                  },)],
                                                mainAxisSize: MainAxisSize.max,
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween),
                                 padding: const EdgeInsets.all(12.0),);
          ch.add(w);
        }
        body = new Block(children: ch);
        break;
      case _View.teams:
        List<Widget> ch = [];
        for (int i=0; i<_teams.length; i++) {
          String team = _teams[i];
          Widget w = new Padding(child: new Row(children: <Widget>[new Text(team),
                                                                   new FlatButton(child: deleteIcon,
                                                                                  onPressed: () async {
                                                                                    var ok = await confirmDialog(context, "Really delete team $team?", 'DELETE');
                                                                                    if (ok != null && ok) {
                                                                                      _writeState(() {
                                                                                          _teams.removeAt(i);
                                                                                        });
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
              icon: studentIcon,
              title: new Text("Students"),
            ),
            new DestinationLabel(
              icon: sectionIcon,
              title: new Text("Sections"),
            ),
            new DestinationLabel(
              icon: new Icon(Icons.restaurant),
              title: new Text("Teams"),
            ),
            new DestinationLabel(
              icon: dayIcon,
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
                _view = _View.teams;
                break;
              case 3:
                _view = _View.days;
                break;
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


  Widget deleteButton(String item, void handleDelete()) {
    return new FlatButton(child: deleteIcon,
                          onPressed: () async {
                            var ok = await confirmDialog(context, "Really delete $item?", 'DELETE');
                            if (ok != null && ok) {
                              await _writeState(() {
                                  handleDelete();
                                });
                            }
                          },);
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

Widget alternativesMenu(List<String> items, String current, void onchange(String newval)) {
  List<PopupMenuItem> pmis = [];
  for (int i=0;i<items.length;i++) {
    pmis.add(new PopupMenuItem<String>(value: items[i],
                                       child: new Text(items[i])));
  }
  Widget cw = new Text(current);
  if (current == '-') {
    cw = new Icon(Icons.more_vert);
  }
  return new PopupMenuButton<String>(child: cw,
                                     itemBuilder: (BuildContext context) => pmis,
                                     onSelected: onchange,
                                     );
}
