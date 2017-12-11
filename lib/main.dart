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

import 'dart:async';
import 'dart:convert';
import 'dart:math';
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
  return 0;
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
  List<String> _authorizedUsers = [];
  List<String> _students = [];
  List<String> _sections = [];
  List<String> _teams = [];
  List<Map> _days = [];
  int _currentDate = 0;
  FirebaseUser _user;
  DatabaseReference _courseNameRef;
  String _courseName;

  DatabaseReference _courseRef;

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
    }
    final DatabaseReference userRef =
        FirebaseDatabase.instance.reference().child('users').child(_user.uid);
    userRef.child('displayname').set(_user.displayName);
    userRef.child('email').set(_user.email);
    print('userid for ${_user.displayName} is ${_user.uid}');
    _courseNameRef = userRef.child('coursename');
    _courseNameRef.keepSynced(true);
    _courseNameRef.onValue.listen((Event event) {
      setState(() {
        _courseName = event.snapshot.value;
        print('coursename is now $_courseName');
        // null out contents to avoid copying over items from one course to
        // another.
        _authorizedUsers = [];
        _students = [];
        _sections = [];
        _teams = [];
        _days = [];
        if (_courseName == null) {
          _courseRef = null;
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
          _courseRef.onValue.listen((Event event) {
            // print('course changed? to ${event.snapshot.value}');
            if (event.snapshot.value == null) {
              Map authmap = {};
              _authorizedUsers.forEach((u) {
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
                _authorizedUsers = [];
                (event.snapshot.value['authorized_users'] ?? {})
                    .forEach((u, x) {
                  _authorizedUsers.add(u);
                });
                if (!_authorizedUsers.contains(_user.uid)) {
                  _authorizedUsers.add(_user.uid);
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
      _authorizedUsers.forEach((u) {
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
    return null;
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
    if (!_sections.contains(section)) return [];
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
    return [];
  }

  void _fixUpSection(String section) {
    Map teams = _teamsForSection(section);
    List<String> students = new List.from(
        _students.where((s) => _todayStudentSection(s) == section));
    List<String> studentsHandled = new List.from([]);
    List<String> studentsRemaining = new List.from(students);
    teams.forEach((t, stu) {
      for (String s in stu) {
        studentsHandled.add(s);
        studentsRemaining.remove(s);
      }
    });
    List<String> teamsavailable = _teamsAvailable();
    teamsavailable.forEach((t) {
      if (studentsRemaining.length > 0) {
        List<String> ss = new List.from(_lastWeekStudentInTeam(t)
            .where((s) => studentsRemaining.contains(s)));
        List<String> sss = new List.from(
            ss.where((s) => !_previousWeekStudentInTeam(t).contains(s)));
        if (sss.length > 0) {
          ss = sss;
        }
        if (ss.length > 0) {
          String s = ss[_random.nextInt(ss.length)];
          _todayStudent(s)['team'] = t;
          studentsHandled.add(s);
          studentsRemaining.remove(s);
        }
      }
    });
    teams = _teamsForSection(section);
    teams.forEach((t, stu) {
      if (stu.length == 1) {
        List<String> parts = new List.from(_possiblePartnersForStudent(stu[0])
            .where((s) => studentsRemaining.contains(s)));
        print('possible partners for ${stu[0]}: $parts');
        if (parts.length > 0) {
          String p = parts[_random.nextInt(parts.length)];
          _todayStudent(p)['team'] = t;
          studentsRemaining.remove(p);
          studentsHandled.add(p);
        }
      }
    });
    teamsavailable = _teamsAvailable();
    teamsavailable.forEach((t) {
      if (studentsRemaining.length > 0) {
        String s = studentsRemaining[_random.nextInt(studentsRemaining.length)];
        _todayStudent(s)['team'] = t;
        studentsHandled.add(s);
        studentsRemaining.remove(s);
        List<String> parts = _possiblePartnersForStudent(s);
        if (parts.length > 0) {
          String p = parts[_random.nextInt(parts.length)];
          _todayStudent(p)['team'] = t;
          studentsRemaining.remove(p);
          studentsHandled.add(p);
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

  void _renameTeam(String oldname, String newname) {
    _writeState(() {
      int i = _teams.indexOf(oldname);
      _teams[i] = newname;
      _days.forEach((d) {
        if (d.containsKey('students')) {
          d['students'].forEach((String k, Map s) {
            if (s.containsKey('team') && s['team'] == oldname) {
              s['team'] = newname;
            }
          });
        }
      });
    });
  }

  void _renameStudent(String oldname, String newname) {
    _writeState(() {
      int i = _students.indexOf(oldname);
      _students[i] = newname;
      _days.forEach((d) {
        if (d.containsKey('students')) {
          if (d['students'].containsKey(oldname)) {
            final Map v = d['students'][oldname];
            d['students'].remove(oldname);
            d['students'][newname] = v;
          }
        }
      });
    });
  }

  void _renameDay(String oldname, String newname) {
    _writeState(() {
      _days.forEach((d) {
        if (d['date'] == oldname) {
          d['date'] = newname;
        }
      });
    });
  }

  void _renameSection(String oldname, String newname) {
    _writeState(() {
      int i = _sections.indexOf(oldname);
      _sections[i] = newname;
      _days.forEach((d) {
        if (d.containsKey('students')) {
          d['students'].forEach((String k, Map s) {
            if (s.containsKey('section') && s['section'] == oldname) {
              s['section'] = newname;
            }
          });
        }
      });
    });
  }

  Widget _sectionMenuForStudent(String s) {
    List<String> sectionOptions = new List.from(_sections)..add('absent');
    return alternativesMenu(sectionOptions, _todayStudentSection(s), (n) {
      _writeState(() {
        _todayStudent(s)['section'] = n;
      });
    });
  }

  Widget _teamMenuForStudent(String s) {
    List<String> teamOptions = new List.from(_teamsAvailable())..add('-');
    String section = _todayStudentSection(s);
    _teamsForSection(section).forEach((t, stu) {
      if (stu.length < 2 || stu.contains(s)) {
        teamOptions.add(t);
      }
    });
    teamOptions.sort();
    String current = _todayStudentTeam(s);
    if (teamOptions.length == 0) return new Text('');
    List<PopupMenuItem<String>> pmis = [];
    teamOptions.forEach((i) {
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
            Map todays = _todayStudent(s);
            todays['team'] = n;
            Map d = _studentDefault(s);
            if (n == '-' && d['section'] == todays['section']) {
              // This unsets the section, if it is equal to the default section
              // for this student.  This is intended to undo the below.
              todays.remove('section');
              todays.remove('team');
            } else if (!todays.containsKey('section')) {
              // The following sets the section to its default value if it is
              // not yet defined for this day.  This ensures that if the default
              // is later changed, it won't retroactively change days that have
              // already passed.  Note: this does mean that there is potential
              // harm in "planning ahead", since it inhibits the effects of
              // changing the default section.
              if (d.containsKey('section')) todays['section'] = d['section'];
            }
          });
        });
  }

  List<String> _lastWeekStudentInTeam(String team) {
    int lastWeek = _currentDate - 1;
    if (lastWeek >= 0) {
      return new List.from(_students
          .where((s) => _todayStudentTeam(s, _days[lastWeek]) == team));
    }
    return [];
  }

  List<String> _previousWeekStudentInTeam(String team) {
    int lastWeek = _currentDate - 2;
    if (lastWeek >= 0) {
      return new List.from(_students
          .where((s) => _todayStudentTeam(s, _days[lastWeek]) == team));
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

    List<String> allowRemoval(List<String> o) {
      return new List.from(o)..add('remove');
    }

    setStudent([String other]) {
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
        _studentsMenu(possibleStudents, '-', team, setStudent()),
        new Text('')
      ];
    }
    List<String> studentOptions =
        new List.from(_possiblePartnersForStudent(currentStudents[0]));
    if (currentStudents.length == 1) {
      String s = currentStudents[0];
      return [
        _studentsMenu(allowRemoval(possibleStudents), s, team, setStudent()),
        _studentsMenu(studentOptions, null, team, setStudent(s)),
      ];
    }
    return [
      _studentsMenu(
          allowRemoval(_possiblePartnersForStudent(currentStudents[1])),
          currentStudents[0],
          team,
          setStudent(currentStudents[1])),
      _studentsMenu(
          allowRemoval(_possiblePartnersForStudent(currentStudents[0])),
          currentStudents[1],
          team,
          setStudent(currentStudents[0])),
    ];
  }

  Widget _studentTable(List<String> studentsToList) {
    List<DataColumn> columns = <DataColumn>[
      new DataColumn(label: studentIcon),
      new DataColumn(label: sectionIcon),
      new DataColumn(label: teamIcon),
    ];
    List<DataRow> rows = [];
    for (int i = 0; i < studentsToList.length; i++) {
      String s = studentsToList[i];
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
    Map teamsMap = _teamsForSection(section);
    List<String> teams = new List.from(teamsMap.keys);
    teams.sort();
    teams.forEach((team) {
      List<String> students = teamsMap[team];
      List<Widget> studentMenus = _studentMenusForTeam(section, team, students);
      rows.add(new DataRow(cells: <DataCell>[
        new DataCell(new Text(team)),
        new DataCell(studentMenus[0]),
        new DataCell(studentMenus[1]),
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
    String yesterdayTeam;
    String previousTeam;
    if (_currentDate - 1 >= 0) {
      yesterdayTeam = _todayStudentTeam(student, _days[_currentDate - 1]);
      if (_currentDate - 2 >= 0) {
        previousTeam = _todayStudentTeam(student, _days[_currentDate - 2]);
      }
    }
    if (team == yesterdayTeam) {
      if (team == previousTeam) {
        return new Text(student,
            style: new TextStyle(
                fontWeight: FontWeight.bold, fontStyle: FontStyle.italic));
      }
      return new Text(student,
          style: new TextStyle(fontWeight: FontWeight.bold));
    }
    if (team == previousTeam) {
      return new Text(student,
          style: new TextStyle(fontStyle: FontStyle.italic));
    }
    return new Text(student);
  }

  Widget _teamLabel(String team, [String student]) {
    if (student == null) {
      return new Text(team);
    }
    String yesterdayTeam;
    String previousTeam;
    if (_currentDate - 1 >= 0) {
      yesterdayTeam = _todayStudentTeam(student, _days[_currentDate - 1]);
      if (_currentDate - 2 >= 0) {
        previousTeam = _todayStudentTeam(student, _days[_currentDate - 2]);
      }
    }
    if (team == yesterdayTeam) {
      if (team == previousTeam) {
        return new Text(team,
            style: new TextStyle(
                fontWeight: FontWeight.bold, fontStyle: FontStyle.italic));
      }
      return new Text(team, style: new TextStyle(fontWeight: FontWeight.bold));
    }
    if (team == previousTeam) {
      return new Text(team, style: new TextStyle(fontStyle: FontStyle.italic));
    }
    return new Text(team);
  }

  Widget _studentsMenu(List<String> items, String current, String team,
      void onchange(String newval)) {
    if (items.length == 0) return new Text('');
    List<PopupMenuItem<String>> pmis = [];
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
            List studentsSection = new List.from(_students
                .where((s) => _todayStudentSection(s) == _sections[i]));
            if (studentsSection.length > 0) {
              tables.add(_studentTable(studentsSection));
            }
          }
          List studentsAbsent = new List.from(
              _students.where((s) => _todayStudentSection(s) == 'absent'));
          if (studentsAbsent.length > 0) {
            tables.add(_studentTable(studentsAbsent));
          }
          List studentsUnassigned = new List.from(
              _students.where((s) => _todayStudentSection(s) == '-'));
          if (studentsUnassigned.length > 0) {
            tables.add(_studentTable(studentsUnassigned));
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
                          new Expanded(child: _studentLabel(s)),
                          editButton('student $s', (String newval) {
                            _renameStudent(s, newval);
                          }),
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
                          new Expanded(child: new Text(s)),
                          editButton('section $s', (String newval) {
                            _renameSection(s, newval);
                          }),
                          deleteButton('section $s', () {
                            _sections.remove(s);
                          }),
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
                    editButton('day ${_days[i]['date']}', (String newval) {
                      _renameDay(_days[i]['date'], newval);
                    }),
                    deleteButton('day ${_days[i]['date']}', () {
                      _days.removeAt(i);
                    }),
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
                    new Expanded(child: new Text(team)),
                    editButton('team $team', (String newval) {
                      _renameTeam(team, newval);
                    }),
                    deleteButton('Really delete team $team?', () {
                      _writeState(() {
                        _teams.removeAt(i);
                      });
                    }),
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

    String currentDayText = 'manage';
    if (_amViewingDate()) {
      currentDayText = _days[_currentDate]['date'];
    }
    Icon floatingActionIcon = new Icon(Icons.add);
    var floatingActionOnPressed = add;
    if (currentDayText != 'manage' && _view != _View.days) {
      floatingActionIcon = scrambleIcon;
      floatingActionOnPressed = scramble;
    }
    List<String> dayOptions = new List.from(_days.map((d) => d['date']))
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
        // title: alternativesMenu(dayOptions, currentDayText,
        //     (String s) async {
        //       await _writeState(() { _currentDate = dayOptions.indexOf(s) - 1; });
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
                List<Map> allUsers = [];
                List<Map> authUsers = [];
                users.value.forEach((u, data) {
                  if (_authorizedUsers.contains(u)) {
                    authUsers.add({
                      'uid': u,
                      'name': data['displayname'],
                      'email': data['email']
                    });
                  } else {
                    allUsers.add({
                      'uid': u,
                      'name': data['displayname'],
                      'email': data['email']
                    });
                  }
                });
                String uid = await promptUserDialog(
                    context, '$_courseName users', authUsers, allUsers);
                if (uid != null) {
                  _writeState(() {
                    _authorizedUsers.add(uid);
                  });
                }
              }),
          new Center(
              // widthFactor: 1.2,
              child: alternativesMenu(dayOptions, currentDayText,
                  (String s) async {
            await _writeState(() {
              _currentDate = dayOptions.indexOf(s) - 1;
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
            backgroundColor: Colors.blue,
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

  Widget editButton(String item, void rename(String newvalue)) {
    return new FlatButton(
      child: editIcon,
      onPressed: () async {
        String newname = await textInputDialog(context, "Rename $item to:",
            confirm: 'RENAME');
        if (newname != null) {
          await _writeState(() {
            rename(newname);
          });
        }
      },
    );
  }
}

Future<String> textInputDialog(BuildContext context, String title,
    {String confirm = 'ADD'}) async {
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
              child: new Text(confirm),
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
  List<PopupMenuItem<String>> pmis = [];
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
