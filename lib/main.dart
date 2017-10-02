/* Student Pairs
   Copyright (C) 2017 David Roundy

   This program is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public License as
   published by the Free Software Foundation; either version 2 of the
   License, or (at your option) any later version.

   This program is distributed in the hope that it will be useful, but
   WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
   02110-1301 USA */

import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import 'package:share/share.dart';

final GoogleSignIn _googleSignIn = new GoogleSignIn();
final FirebaseAuth _auth = FirebaseAuth.instance;
final _random = new Random(); // generates a new Random object

void main() {
  // the following logs us in.
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
    case _View.students:
      return 0;
    case _View.sections:
      return 1;
    case _View.teams:
      return 2;
    case _View.days:
      return 3;
  }
}

final Widget authorizedUserIcon = new Icon(Icons.face);
final Widget courseIcon = new Icon(Icons.local_florist);
final Widget scrambleIcon = new Icon(Icons.shuffle);
final Widget studentIcon = new Icon(Icons.person);
final Widget sectionIcon = new Icon(Icons.assignment);
final Widget teamIcon = new Icon(Icons.people);
final Widget dayIcon = new Icon(Icons.schedule);
final Widget deleteIcon = new Icon(Icons.delete);
final Widget editIcon = new Icon(Icons.edit);

class _MyHomePageState extends State<MyHomePage> {
  _View _view = _View.students;
  List<String> _authorized_users = [];
  List<String> _students = [];
  List<String> _sections = [];
  List<String> _teams = [];
  List<Map> _days = [];
  int _currentDate = 0;
  FirebaseUser _user = null;
  DatabaseReference _courseNameRef = null;
  StreamSubscription<Event> _courseNameSubscription;
  String _courseName;

  DatabaseReference _courseRef = null;
  StreamSubscription<Event> _courseSubscription;

  Future<FirebaseUser> _signInWithGoogle() async {
    _user = await _auth.currentUser();
    if (_user == null) {
      final GoogleSignInAccount googleUser = await _googleSignIn.signIn();
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      _user = await _auth.signInWithGoogle(
          accessToken: googleAuth.accessToken, idToken: googleAuth.idToken);
      assert(_user.email != null);
      assert(_user.displayName != null);
      assert(_user.uid != null);
      assert(!_user.isAnonymous);
      assert(await _user.getToken() != null);
    }
    final user_ref =
        FirebaseDatabase.instance.reference().child('users').child(_user.uid);
    user_ref.child('displayname').set(_user.displayName);
    user_ref.child('email').set(_user.email);
    print('userid for ${_user.displayName} is ${_user.uid}');
    _courseNameRef = user_ref.child('coursename');
    _courseNameRef.keepSynced(true);
    _courseNameSubscription = _courseNameRef.onValue.listen((Event event) {
      setState(() {
        _courseName = event.snapshot.value;
        print('coursename is now $_courseName');
        if (_courseName == null) {
          _courseRef = null;
          _courseSubscription = null;
          _authorized_users = [];
          _students = [];
          _sections = [];
          _teams = [];
          _days = [];
        } else {
          _courseRef = FirebaseDatabase.instance
              .reference()
              .child('courses')
              .child(_courseName);
          _courseRef.child('currentDate').once().then((snap) {
                setState(() {
                  // We initialize the _currentDate to the last saved value, but
                  // after that we do not *read* the _currentDate from the
                  // server.  This preserves the date across reboots, but does
                  // not let someone else (e.g. the TA) reset our current date
                  // while we are entering data.
                  _currentDate = snap.value ?? -1;
                });
              });
          _courseSubscription = _courseRef.onValue.listen((Event event) {
            // print('course changed? to ${event.snapshot.value}');
            if (event.snapshot.value == null) {
              Map authmap = {};
              _authorized_users.forEach((u) {
                authmap[u] = true;
              });
              _courseRef.set({
                'currentDate': _currentDate,
                'students': _students,
                'sections': _sections,
                'teams': _teams,
                'days': _days,
                'authorized_users': authmap,
              });
            } else {
              setState(() {
                _authorized_users = [];
                (event.snapshot.value['authorized_users'] ?? {})
                    .forEach((u, x) {
                  _authorized_users.add(u);
                });
                if (!_authorized_users.contains(_user.uid)) {
                  _authorized_users.add(_user.uid);
                }
                _students = (event.snapshot.value['students'] ?? [])
                    .toList(growable: true);
                _sections = (event.snapshot.value['sections'] ?? [])
                    .toList(growable: true);
                _teams = (event.snapshot.value['teams'] ?? [])
                    .toList(growable: true);
                _days =
                    (event.snapshot.value['days'] ?? []).toList(growable: true);
              });
            }
          });
          _courseRef.keepSynced(true);
        }
      });
    });
    return _user;
  }

  @override
  void initState() {
    super.initState();
    FirebaseDatabase.instance.setPersistenceEnabled(true);
    _signInWithGoogle();
  }

  Future<Null> _writeState(void setit()) async {
    setState(setit);
    // write the variable as a string to the file
    _students.sort();
    if (_courseRef != null && _students.length > 0) {
      Map authmap = {};
      _authorized_users.forEach((u) {
        authmap[u] = true;
      });
      _courseRef.set({
        'currentDate': _currentDate,
        'students': _students,
        'sections': _sections,
        'teams': _teams,
        'days': _days,
        'authorized_users': authmap,
      });
    }
  }

  String _jsonState() {
    _students.sort();
    return JSON.encode({
      'currentDate': _currentDate,
      'students': _students,
      'sections': _sections,
      'teams': _teams,
      'days': _days,
    });
  }

  Future<Null> scramble() async {
    String answer = await optionsDialog(
        context, 'Scramble which students?', ['ALL', 'UNASSIGNED']);
    if (answer == null) {
      return;
    }
    await _writeState(() {
      if (answer == 'ALL') {
        _students.forEach((s) {
          _todayStudent(s).remove('team');
        });
      }
      _sections.forEach((section) {
        _fixUpSection(section);
      });
    });
  }

  Future<Null> add() async {
    switch (_view) {
      case _View.students:
        var x = await textInputDialog(context, 'Add student');
        print('Added student "$x"');
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

  Map _lookupDay(String day) {
    for (int i = 0; i < _days.length; i++) {
      if (_days[i].contains('date') && _days[i]['date'] == day) {
        return _days[i];
      }
    }
  }

  Map _todayStudent(String student, [Map day]) {
    if (day == null) day = _today();
    if (day == null) return {};
    if (day is! Map || !day.containsKey('students')) {
      day['students'] = {};
    }
    Map students = day['students'];
    if (!students.containsKey(student)) {
      students[student] = {};
    }
    return students[student];
  }

  String _todayStudentSection(String student, [Map today]) {
    today = _todayStudent(student, today);
    if (today != null && today.containsKey('section')) {
      return today['section'];
    }
    Map d = _studentDefault(student);
    if (d.containsKey('section')) return d['section'];
    return '-';
  }

  String _todayStudentTeam(String student, [Map today]) {
    today = _todayStudent(student, today);
    if (today != null && today.containsKey('team')) {
      return today['team'];
    }
    Map d = _studentDefault(student);
    if (d.containsKey('team')) return d['team'];
    return '-';
  }

  String _findPartner(String student, [Map day]) {
    if (day == null) day = _today();
    String team = _todayStudentTeam(student, day);
    String section = _todayStudentSection(student, day);

    for (int i = 0; i < _students.length; i++) {
      String s = _students[i];
      if (s != student &&
          _todayStudentSection(s, day) == section &&
          _todayStudentTeam(s, day) == team) return s;
    }
  }

  List<String> _teamsAvailable() {
    List<String> teams = [];
    _teams.forEach((t) {
      teams.add(t);
    });
    for (int i = 0; i < _students.length; i++) {
      String s = _students[i];
      String t = _todayStudentTeam(s);
      teams.remove(t);
    }
    return teams;
  }

  Map _teamsForSection(String section) {
    Map teams = {};
    if (section == null) {
      _teams.forEach((t) {
        teams[t] = [];
      });
      _students.forEach((s) {
        String t = _todayStudentTeam(s);
        teams.remove(t);
      });
      return teams;
    }
    for (int i = 0; i < _students.length; i++) {
      String s = _students[i];
      if (_todayStudentSection(s) == section) {
        String t = _todayStudentTeam(s);
        if (_teams.contains(t)) {
          if (teams.containsKey(t)) {
            teams[t].add(s);
          } else {
            teams[t] = [s];
          }
        }
      }
    }
    return teams;
  }

  List<String> _possiblePartnersForStudent(String student, [Map day]) {
    if (day == null) day = _today();
    if (day == null) return [];
    String section = _todayStudentSection(student);
    if (!_sections.contains(section)) return Set();
    List<String> partners = new List.from(
        _students.where((s) => _todayStudentSection(s) == section));
    partners.remove(student);

    // remove students who already have partners
    for (String p in new List.from(partners)) {
      if (_teams.contains(_todayStudentTeam(p, day))) partners.remove(p);
    }
    String current = _findPartner(student, day);
    if (current != null) partners.add(current);
    for (Map past in _days.skip(1)) {
      if (past == day) return partners;
      String p = _findPartner(student, past);
      if (p != null) partners.remove(p);
    }
  }

  void _fixUpSection(String section) {
    Map teams = _teamsForSection(section);
    List<String> students = new List.from(
        _students.where((s) => _todayStudentSection(s) == section));
    List<String> students_handled = new List.from([]);
    List<String> students_remaining = new List.from(students);
    teams.forEach((t, stu) {
      for (String s in stu) {
        students_handled.add(s);
        students_remaining.remove(s);
      }
    });
    List<String> teamsavailable = _teamsAvailable();
    teamsavailable.forEach((t) {
      if (students_remaining.length > 0) {
        List<String> ss = new List.from(_lastWeekStudentInTeam(t)
            .where((s) => students_remaining.contains(s)));
        List<String> sss = new List.from(
            ss.where((s) => !_previousWeekStudentInTeam(t).contains(s)));
        if (sss.length > 0) {
          ss = sss;
        }
        if (ss.length > 0) {
          String s = ss[_random.nextInt(ss.length)];
          _todayStudent(s)['team'] = t;
          students_handled.add(s);
          students_remaining.remove(s);
        }
      }
    });
    teams = _teamsForSection(section);
    teams.forEach((t, stu) {
      if (stu.length == 1) {
        List<String> parts = new List.from(_possiblePartnersForStudent(stu[0])
            .where((s) => students_remaining.contains(s)));
        print('possible partners for ${stu[0]}: $parts');
        if (parts.length > 0) {
          String p = parts[_random.nextInt(parts.length)];
          _todayStudent(p)['team'] = t;
          students_remaining.remove(p);
          students_handled.add(p);
        }
      }
    });
    teamsavailable = _teamsAvailable();
    teamsavailable.forEach((t) {
      if (students_remaining.length > 0) {
        String s =
            students_remaining[_random.nextInt(students_remaining.length)];
        _todayStudent(s)['team'] = t;
        students_handled.add(s);
        students_remaining.remove(s);
        List<String> parts = _possiblePartnersForStudent(s);
        if (parts.length > 0) {
          String p = parts[_random.nextInt(parts.length)];
          _todayStudent(p)['team'] = t;
          students_remaining.remove(p);
          students_handled.add(p);
        }
      }
    });
  }

  void _fixUpSectionErrors(String section) {
    Map teams = _teamsForSection(section);
    teams.forEach((t, stu) {
      for (String s in _students) {
        if (_todayStudentTeam(s) == t && _todayStudentSection(s) != section) {
          _todayStudent(s).remove('team');
        }
      }
      while (stu.length > 2) {
        _todayStudent(stu[0]).remove('team');
        stu.removeAt(0);
      }
    });
  }

  Widget _sectionMenuForStudent(String s) {
    List<String> section_options = new List.from(_sections)..add('absent');
    return alternativesMenu(section_options, _todayStudentSection(s), (n) {
      _writeState(() {
        _todayStudent(s)['section'] = n;
      });
    });
  }

  Widget _teamMenuForStudent(String s) {
    List<String> team_options = new List.from(_teamsAvailable())..add('-');
    String section = _todayStudentSection(s);
    _teamsForSection(section).forEach((t, stu) {
      if (stu.length < 2 || stu.contains(s)) {
        team_options.add(t);
      }
    });
    team_options.sort();
    String current = _todayStudentTeam(s);
    if (team_options.length == 0) return new Text('');
    List<PopupMenuItem> pmis = [];
    team_options.forEach((i) {
      pmis.add(new PopupMenuItem<String>(value: i, child: _teamLabel(i, s)));
    });
    Widget cw = menuIcon;
    if (current != '-' && current != null) {
      cw = _teamLabel(current, s);
    }
    return new PopupMenuButton<String>(
        child: cw,
        itemBuilder: (BuildContext context) => pmis,
        onSelected: (n) {
          _writeState(() {
            _todayStudent(s)['team'] = n;
          });
        });
  }

  List<String> _lastWeekStudentInTeam(String team) {
    int last_week = _currentDate - 1;
    if (last_week >= 0) {
      return new List.from(_students
          .where((s) => _todayStudentTeam(s, _days[last_week]) == team));
    }
    return [];
  }

  List<String> _previousWeekStudentInTeam(String team) {
    int last_week = _currentDate - 2;
    if (last_week >= 0) {
      return new List.from(_students
          .where((s) => _todayStudentTeam(s, _days[last_week]) == team));
    }
    return [];
  }

  List<Widget> _studentMenusForTeam(
      String section, String team, List<String> currentStudents) {
    List<String> possibleStudents = new List.from(_students
        .where((s) => _todayStudentSection(s) == section || section == null));
    for (String p in new List.from(possibleStudents)) {
      String pteam = _todayStudentTeam(p);
      if (pteam != team && _teams.contains(pteam)) possibleStudents.remove(p);
    }

    List<String> allow_removal(List<String> o) {
      return new List.from(o)..add('remove');
    }

    set_student([String other]) {
      Future<Null> setter(String newstudent) async {
        await _writeState(() {
          for (String x in _students) {
            if (_todayStudentTeam(x) == team) {
              _todayStudent(x).remove('team');
            }
          }
          _todayStudent(newstudent)['team'] = team;
          if (other != null) _todayStudent(other)['team'] = team;
        });
      }

      return setter;
    }

    if (currentStudents.length == 0) {
      return [
        _studentsMenu(possibleStudents, '-', team, set_student()),
        new Text('')
      ];
    }
    List<String> student_options =
        new List.from(_possiblePartnersForStudent(currentStudents[0]));
    if (currentStudents.length == 1) {
      String s = currentStudents[0];
      return [
        _studentsMenu(allow_removal(possibleStudents), s, team, set_student()),
        _studentsMenu(student_options, null, team, set_student(s)),
      ];
    }
    return [
      _studentsMenu(
          allow_removal(_possiblePartnersForStudent(currentStudents[1])),
          currentStudents[0],
          team,
          set_student(currentStudents[1])),
      _studentsMenu(
          allow_removal(_possiblePartnersForStudent(currentStudents[0])),
          currentStudents[1],
          team,
          set_student(currentStudents[0])),
    ];
  }

  Widget _studentTable(List<String> students_to_list) {
    List<DataColumn> columns = <DataColumn>[
      new DataColumn(label: studentIcon),
      new DataColumn(label: sectionIcon),
      new DataColumn(label: teamIcon),
    ];
    List<DataRow> rows = [];
    for (int i = 0; i < students_to_list.length; i++) {
      String s = students_to_list[i];
      String s_section = _todayStudentSection(s);
      String s_team = _todayStudentTeam(s);
      rows.add(new DataRow(cells: <DataCell>[
        new DataCell(_studentLabel(s)),
        new DataCell(_sectionMenuForStudent(s)),
        new DataCell(_teamMenuForStudent(s)),
      ]));
    }
    return new DataTable(columns: columns, rows: rows);
  }

  Widget _teamTable(String section) {
    List<DataColumn> columns = <DataColumn>[
      new DataColumn(label: teamIcon),
      new DataColumn(label: new Icon(Icons.person)),
      new DataColumn(label: new Icon(Icons.person)),
    ];
    List<DataRow> rows = [];
    Map teams_map = _teamsForSection(section);
    List<String> teams = new List.from(teams_map.keys);
    teams.sort();
    teams.forEach((team) {
      List<String> students = teams_map[team];
      List<Widget> student_menus =
          _studentMenusForTeam(section, team, students);
      rows.add(new DataRow(cells: <DataCell>[
        new DataCell(new Text(team)),
        new DataCell(student_menus[0]),
        new DataCell(student_menus[1]),
      ]));
    });
    return new DataTable(columns: columns, rows: rows);
  }

  Widget _studentLabel(String student, [String team]) {
    if (team == null) {
      team = _todayStudentTeam(student);
    }
    if (team == '-') {
      return new Text(student);
    }
    String yesterday_team = null;
    String previous_team = null;
    if (_currentDate - 1 >= 0) {
      yesterday_team = _todayStudentTeam(student, _days[_currentDate - 1]);
      if (_currentDate - 2 >= 0) {
        previous_team = _todayStudentTeam(student, _days[_currentDate - 2]);
      }
    }
    if (team == yesterday_team) {
      if (team == previous_team) {
        return new Text(student,
            style: new TextStyle(
                fontWeight: FontWeight.bold, fontStyle: FontStyle.italic));
      }
      return new Text(student,
          style: new TextStyle(fontWeight: FontWeight.bold));
    }
    if (team == previous_team) {
      return new Text(student,
          style: new TextStyle(fontStyle: FontStyle.italic));
    }
    return new Text(student);
  }

  Widget _teamLabel(String team, [String student]) {
    if (student == null) {
      return new Text(team);
    }
    String yesterday_team = null;
    String previous_team = null;
    if (_currentDate - 1 >= 0) {
      yesterday_team = _todayStudentTeam(student, _days[_currentDate - 1]);
      if (_currentDate - 2 >= 0) {
        previous_team = _todayStudentTeam(student, _days[_currentDate - 2]);
      }
    }
    if (team == yesterday_team) {
      if (team == previous_team) {
        return new Text(team,
            style: new TextStyle(
                fontWeight: FontWeight.bold, fontStyle: FontStyle.italic));
      }
      return new Text(team, style: new TextStyle(fontWeight: FontWeight.bold));
    }
    if (team == previous_team) {
      return new Text(team, style: new TextStyle(fontStyle: FontStyle.italic));
    }
    return new Text(team);
  }

  Widget _studentsMenu(List<String> items, String current, String team,
      void onchange(String newval)) {
    if (items.length == 0) return new Text('');
    List<PopupMenuItem> pmis = [];
    items.forEach((i) {
      pmis.add(
          new PopupMenuItem<String>(value: i, child: _studentLabel(i, team)));
    });
    Widget cw = menuIcon;
    if (current != '-' && current != null) {
      cw = _studentLabel(current, team);
    }
    return new PopupMenuButton<String>(
        child: cw,
        itemBuilder: (BuildContext context) => pmis,
        onSelected: onchange);
  }

  @override
  Widget build(BuildContext context) {
    if (_courseName == null && _courseNameRef != null) {
      print('coursename is unknown?!');
      textInputDialog(context, 'What is the course name?').then((cn) {
        print('cn is now $cn');
        _courseNameRef.set(cn);
      });
    }
    Widget body;
    if (_amViewingDate()) {
      for (String section in _sections) {
        _fixUpSectionErrors(section);
      }
      // This is where we edit the plan for a given class day
      switch (_view) {
        case _View.students:
          body = new ListView(children: <Widget>[_studentTable(_students)]);
          break;
        case _View.sections:
          List<Widget> tables = [];
          for (int i = 0; i < _sections.length; i++) {
            List students_section = new List.from(_students
                .where((s) => _todayStudentSection(s) == _sections[i]));
            if (students_section.length > 0) {
              tables.add(_studentTable(students_section));
            }
          }
          List students_absent = new List.from(
              _students.where((s) => _todayStudentSection(s) == 'absent'));
          if (students_absent.length > 0) {
            tables.add(_studentTable(students_absent));
          }
          List students_unassigned = new List.from(
              _students.where((s) => _todayStudentSection(s) == '-'));
          if (students_unassigned.length > 0) {
            tables.add(_studentTable(students_unassigned));
          }
          body = new ListView(children: tables);
          break;
        case _View.teams:
          List<Widget> tables = [];
          for (int i = 0; i < _sections.length; i++) {
            tables.add(new Center(child: new Text(_sections[i])));
            tables.add(_teamTable(_sections[i]));
          }
          tables.add(new Center(child: new Text('unused')));
          tables.add(_teamTable(null));
          body = new ListView(children: tables);
          break;
        case _View.days:
          List<Widget> ch = [];
          for (int i = 0; i < _days.length; i++) {
            Widget w = new Padding(
              child: new Row(
                  children: <Widget>[
                    new FlatButton(
                        child: new Text(_days[i]['date']),
                        onPressed: () {
                          _writeState(() {
                            _currentDate = i;
                          });
                        })
                  ],
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween),
              padding: const EdgeInsets.all(12.0),
            );
            ch.add(w);
          }
          body = new ListView(children: ch);
          break;
      }
    } else {
      // Here is where we edit the possibilities
      switch (_view) {
        case _View.students:
          List<Widget> ch = _students
              .map((s) => new Padding(
                    child: new Row(
                        children: <Widget>[
                          _studentLabel(s),
                          deleteButton('student $s', () {
                            _students.remove(s);
                          }),
                        ],
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween),
                    padding: const EdgeInsets.all(12.0),
                  ))
              .toList();
          body = new ListView(children: ch);
          break;
        case _View.sections:
          List<Widget> ch = _sections
              .map((s) => new Padding(
                    child: new Row(
                        children: <Widget>[
                          new Text(s),
                          new FlatButton(
                            child: deleteIcon,
                            onPressed: () async {
                              var ok = await confirmDialog(context,
                                  'Really delete section $s?', 'DELETE');
                              if (ok != null && ok) {
                                _writeState(() {
                                  _sections.remove(s);
                                });
                              }
                            },
                          )
                        ],
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween),
                    padding: const EdgeInsets.all(12.0),
                  ))
              .toList();
          body = new ListView(children: ch);
          break;
        case _View.days:
          List<Widget> ch = [];
          for (int i = 0; i < _days.length; i++) {
            Widget w = new Padding(
              child: new Row(
                  children: <Widget>[
                    new FlatButton(
                        child: new Text(_days[i]['date']),
                        onPressed: () {
                          _writeState(() {
                            _currentDate = i;
                          });
                        }),
                    new FlatButton(
                      child: deleteIcon,
                      onPressed: () async {
                        var ok = await confirmDialog(context,
                            "Really delete day ${_days[i]['date']}?", 'DELETE');
                        if (ok != null && ok) {
                          _writeState(() {
                            _days.removeAt(i);
                          });
                        }
                      },
                    )
                  ],
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween),
              padding: const EdgeInsets.all(12.0),
            );
            ch.add(w);
          }
          body = new ListView(children: ch);
          break;
        case _View.teams:
          List<Widget> ch = [];
          for (int i = 0; i < _teams.length; i++) {
            String team = _teams[i];
            Widget w = new Padding(
              child: new Row(
                  children: <Widget>[
                    new Text(team),
                    new FlatButton(
                      child: deleteIcon,
                      onPressed: () async {
                        var ok = await confirmDialog(
                            context, "Really delete team $team?", 'DELETE');
                        if (ok != null && ok) {
                          _writeState(() {
                            _teams.removeAt(i);
                          });
                        }
                      },
                    )
                  ],
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween),
              padding: const EdgeInsets.all(12.0),
            );
            ch.add(w);
          }
          body = new ListView(children: ch);
          break;
      }
    }

    String courseNameButton = 'Select course';
    if (_courseName != null) {
      courseNameButton = _courseName;
    }

    String current_day_text = 'manage';
    if (_amViewingDate()) {
      current_day_text = _days[_currentDate]['date'];
    }
    Icon floatingActionIcon = new Icon(Icons.add);
    var floatingActionOnPressed = add;
    if (current_day_text != 'manage' && _view != _View.days) {
      floatingActionIcon = scrambleIcon;
      floatingActionOnPressed = scramble;
    }
    List<String> day_options = new List.from(_days.map((d) => d['date']))
      ..insert(0, 'manage');
    return new Scaffold(
      appBar: new AppBar(
        title: new FlatButton(
            child: new Text(courseNameButton),
            onPressed: () {
              textInputDialog(context, 'What is the course name?').then((cn) {
                if (cn != null) {
                  _courseNameRef.set(cn);
                }
              });
            }),
        // title: alternativesMenu(day_options, current_day_text,
        //     (String s) async {
        //       await _writeState(() { _currentDate = day_options.indexOf(s) - 1; });
        //     }),
        // title: new Text(title),
        actions: [
          new FlatButton(
              child: authorizedUserIcon,
              onPressed: () async {
                DataSnapshot users = await FirebaseDatabase.instance
                    .reference()
                    .child('users')
                    .once();
                List<Map> all_users = [];
                List<Map> auth_users = [];
                users.value.forEach((u, data) {
                  if (_authorized_users.contains(u)) {
                    auth_users.add({
                      'uid': u,
                      'name': data['displayname'],
                      'email': data['email']
                    });
                  } else {
                    all_users.add({
                      'uid': u,
                      'name': data['displayname'],
                      'email': data['email']
                    });
                  }
                });
                String uid = await promptUserDialog(
                    context, '$_courseName users', auth_users, all_users);
                if (uid != null) {
                  _writeState(() {
                    _authorized_users.add(uid);
                  });
                }
              }),
          new Center(
              // widthFactor: 1.2,
              child: alternativesMenu(day_options, current_day_text,
                  (String s) async {
            await _writeState(() {
              _currentDate = day_options.indexOf(s) - 1;
            });
          })),
          new FlatButton(
              child: new Icon(Icons.share),
              onPressed: () {
                share(_jsonState());
              }),
        ],
      ),
      body: body,
      bottomNavigationBar: new BottomNavigationBar(
        items: [
          new BottomNavigationBarItem(
            icon: studentIcon,
            title: new Text("Students"),
          ),
          new BottomNavigationBarItem(
              icon: sectionIcon, title: new Text("Sections")),
          new BottomNavigationBarItem(
            icon: teamIcon,
            title: new Text("Teams"),
          ),
          new BottomNavigationBarItem(
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
        onPressed: floatingActionOnPressed,
        tooltip: 'Increment',
        child: floatingActionIcon,
      ), // This trailing comma tells the Dart formatter to use
      // a style that looks nicer for build methods.
    );
  }

  Widget deleteButton(String item, void handleDelete()) {
    return new FlatButton(
      child: deleteIcon,
      onPressed: () async {
        var ok = await confirmDialog(context, "Really delete $item?", 'DELETE');
        if (ok != null && ok) {
          await _writeState(() {
            handleDelete();
          });
        }
      },
    );
  }
  Widget editButton(String item, void rename(String)) {
    return new FlatButton(
      child: editIcon,
      onPressed: () async {
        String newname = await textInputDialog(context, "Rename $item to:", 'RENAME');
        if (newname != null) {
          await _writeState(() {
            rename(newname);
          });
        }
      },
    );
  }
}

Future<String> textInputDialog(BuildContext context, String title) async {
  String foo;
  return showDialog(
    context: context,
    child: new AlertDialog(
        title: new Text(title),
        content: new TextField(
            autofocus: true,
            onChanged: (String newval) {
              foo = newval;
            },
            onSubmitted: (String newval) {
              Navigator.pop(context, newval);
            }),
        actions: <Widget>[
          new FlatButton(
              child: new Text('CANCEL'),
              onPressed: () {
                Navigator.pop(context, null);
              }),
          new FlatButton(
              child: new Text('ADD'),
              onPressed: () {
                Navigator.pop(context, foo);
              }),
        ]),
  );
}

Future<bool> confirmDialog(
    BuildContext context, String title, String action) async {
  return showDialog(
    context: context,
    child: new AlertDialog(title: new Text(title), actions: <Widget>[
      new FlatButton(
          child: new Text('CANCEL'),
          onPressed: () {
            Navigator.pop(context, false);
          }),
      new FlatButton(
          child: new Text(action),
          onPressed: () {
            Navigator.pop(context, true);
          }),
    ]),
  );
}

Future<String> optionsDialog(
    BuildContext context, String title, List<String> actions) async {
  var buttons = <Widget>[
    new FlatButton(
        child: new Text('CANCEL'),
        onPressed: () {
          Navigator.pop(context, null);
        })
  ];
  for (int i = 0; i < actions.length; i++) {
    buttons.add(new FlatButton(
        child: new Text(actions[i]),
        onPressed: () {
          Navigator.pop(context, actions[i]);
        }));
  }
  return showDialog(
      context: context,
      child: new AlertDialog(title: new Text(title), actions: buttons));
}

Future<String> promptUserDialog(
    BuildContext context, String title, List<Map> auth, List<Map> users) async {
  var buttons = <Widget>[
    new Text(
      'Currently authorized users',
      textAlign: TextAlign.center,
      style: new TextStyle(fontWeight: FontWeight.bold),
    )
  ];
  auth.forEach((u) {
    buttons.add(new Text("${u['name']} <${u['email']}>"));
  });
  if (users.length > 0) {
    buttons.add(new Text(
      'Authorize new user',
      textAlign: TextAlign.center,
      style: new TextStyle(fontWeight: FontWeight.bold),
    ));
  }
  users.forEach((u) {
    buttons.add(new SimpleDialogOption(
        child: new Text("${u['name']} <${u['email']}>"),
        onPressed: () {
          Navigator.pop(context, u['uid']);
        }));
  });
  return showDialog(
      context: context,
      child: new SimpleDialog(title: new Text(title), children: buttons));
}

final menuIcon = new Icon(Icons.more_vert);

Widget alternativesMenu(
    List<String> items, String current, void onchange(String newval)) {
  if (items.length == 0) return new Text('');
  List<PopupMenuItem> pmis = [];
  for (int i = 0; i < items.length; i++) {
    pmis.add(
        new PopupMenuItem<String>(value: items[i], child: new Text(items[i])));
  }
  Widget cw = menuIcon;
  if (current != '-' && current != null) {
    cw = new Text(current);
  }
  return new PopupMenuButton<String>(
    child: cw,
    itemBuilder: (BuildContext context) => pmis,
    onSelected: onchange,
  );
}

Widget boldedItalicText(String text, List<String> bolded, List<String> italic) {
  bool isbold = bolded.contains(text);
  bool isit = italic.contains(text);
  if (isbold && isit) {
    return new Text(text,
        style: new TextStyle(
            fontWeight: FontWeight.bold, fontStyle: FontStyle.italic));
  } else if (isbold) {
    return new Text(text, style: new TextStyle(fontWeight: FontWeight.bold));
  } else if (isit) {
    return new Text(text, style: new TextStyle(fontStyle: FontStyle.italic));
  } else {
    return new Text(text);
  }
}
