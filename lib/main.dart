import 'package:firebase_ui_oauth_google/firebase_ui_oauth_google.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
import 'package:flutter/cupertino.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseUIAuth.configureProviders([
    EmailAuthProvider(),
    GoogleProvider(clientId: 'YOUR_GOOGLE_CLIENT_ID'),
  ]);

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Firebase UI Auth',
      theme: ThemeData(
        scaffoldBackgroundColor : const Color.fromRGBO(241, 229, 209, 1), // Change primary color
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => AuthGate(),
        '/profile': (context) => ProfileScreen(),
        '/verify-email': (context) => VerifyEmailScreen(),
        '/todo-list': (context) => TodoListScreen(),
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SignInScreen(
            actions: [
              AuthStateChangeAction<SignedIn>((context, state) {
                if (!state.user!.emailVerified) {
                  Navigator.pushNamed(context, '/verify-email');
                } else {
                  Navigator.pushReplacementNamed(context, '/todo-list');
                }
              }),
            ],
          );
        }
        return TodoListScreen();
      },
    );
  }
}

class TodoListScreen extends StatefulWidget {
  @override
  _TodoListScreenState createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  final TextEditingController _taskController = TextEditingController();
  final List<String> _categories = [
    'work',
    'home',
    'sport',
    'finance',
    'school',
    'shopping',
    'family',
    'health',
    'hobby',
    'other',
  ];
  String _selectedCategory = 'work'; // Default category

  Map<String, IconData> _categoryIcons = {
    'work': CupertinoIcons.briefcase,
    'home': CupertinoIcons.home,
    'sport': CupertinoIcons.sportscourt,
    'finance': CupertinoIcons.money_dollar,
    'school': CupertinoIcons.book,
    'shopping': CupertinoIcons.shopping_cart,
    'family': CupertinoIcons.group,
    'health': CupertinoIcons.heart_circle,
    'hobby': CupertinoIcons.music_note,
    'other': CupertinoIcons.line_horizontal_3_decrease_circle,
  };

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('To-Do List'),
        actions: [
          IconButton(
            icon: Icon(Icons.person),
            onPressed: () {
              Navigator.pushNamed(context, '/profile');
            },
          ),
        ],
      ),
      body: Container(
        color: Color.fromRGBO(241, 229, 209, 1), // Background color
        child: StreamBuilder(
          stream: FirebaseFirestore.instance
              .collection('tasks')
              .where('userId', isEqualTo: user?.uid)
              .snapshots(),
          builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
            if (!snapshot.hasData) {
              return Center(child: CircularProgressIndicator());
            }

            final tasks =
                snapshot.data!.docs.where((doc) => !doc['isDone']).toList();
            final finishedTasks =
                snapshot.data!.docs.where((doc) => doc['isDone']).toList();

            return ListView(
              children: [
                ...tasks.map((doc) => _buildTaskItem(doc)),
                if (finishedTasks.isNotEmpty) _buildFinishedHeader(),
                ...finishedTasks.map((doc) => _buildTaskItem(doc)),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTask,
        backgroundColor: Color.fromRGBO(134, 112, 112, 1), // Add task button color
        child: Icon(Icons.add),
      ),
    );
  }

  Widget _buildTaskItem(DocumentSnapshot doc) {
    bool isDone = doc['isDone'];
    String category = doc['category'];

    return Dismissible(
      key: Key(doc.id),
      direction: DismissDirection.startToEnd,
      onDismissed: (direction) {
        FirebaseFirestore.instance.collection('tasks').doc(doc.id).delete();
      },
      background: Container(
        color: Colors.red, // Background color for dismiss
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: Icon(
              Icons.delete,
              color: Colors.white,
            ),
          ),
        ),
      ),
      child: Card(
        elevation: 3,
        color: Color.fromARGB(255, 255, 255, 255), // Task card background color
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
          side: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        child: ListTile(
          leading: Icon(
            _categoryIcons[category],
            size: 32,
            color: Color.fromRGBO(219, 181, 181, 1), // Category icon color
          ),
          title: Text(
            doc['task'],
            style: TextStyle(
              decoration: isDone ? TextDecoration.lineThrough : null,
              color: isDone ? Colors.grey : Colors.black,
            ),
          ),
          trailing: Checkbox(
            value: isDone,
            onChanged: (bool? value) {
              FirebaseFirestore.instance.collection('tasks').doc(doc.id).update({
                'isDone': value,
              });
              if (value == true) {
                _incrementCompletedTasksCount(FirebaseAuth.instance.currentUser!.uid);
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFinishedHeader() {
    return Container(
      padding: EdgeInsets.all(16.0),
      color: Color.fromRGBO(228, 208, 208, 1), // Finished header background color
      child: Text('Finished',
          style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold)),
    );
  }

  void _addTask() {
    String? selectedCategory = _selectedCategory;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Add Task'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _taskController,
                    decoration: InputDecoration(labelText: 'Task'),
                  ),
                  DropdownButton<String>(
                    value: selectedCategory,
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedCategory = newValue;
                      });
                    },
                    items: _categories.map((String category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Row(
                          children: [
                            Icon(
                              _categoryIcons[category],
                              size: 24,
                              color: const Color.fromRGBO(219, 181, 181, 1), // Category icon color
                            ),
                            SizedBox(width: 8),
                            Text(category),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    if (_taskController.text.isNotEmpty &&
                        selectedCategory != null) {
                      FirebaseFirestore.instance.collection('tasks').add({
                        'userId': FirebaseAuth.instance.currentUser!.uid,
                        'task': _taskController.text,
                        'category': selectedCategory!,
                        'isDone': false,
                      });
                      _taskController.clear();
                      Navigator.of(context).pop();
                    }
                  },
                  child: Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _incrementCompletedTasksCount(String uid) async {
    final userDoc = FirebaseFirestore.instance.collection('users').doc(uid);
    await userDoc.set({
      'completedTasksCount': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }
}

class VerifyEmailScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Verify Email'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Please verify your email address.'),
            ElevatedButton(
              onPressed: () async {
                await FirebaseAuth.instance.currentUser?.sendEmailVerification();
              },
              child: Text('Resend Verification Email'),
            ),
            ElevatedButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.pushReplacementNamed(context, '/');
              },
              child: Text('Sign Out'),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Logged in as:',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              user?.email ?? 'No email',
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                _showChangePasswordDialog(context);
              },
              child: Text('Change Password'),
            ),
            SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.pushReplacementNamed(context, '/');
              },
              child: Text('Sign Out'),
            ),
            SizedBox(height: 20),
            _buildCompletedTasksCard(context, user?.uid),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedTasksCard(BuildContext context, String? uid) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return CircularProgressIndicator();
        }

        final int completedTasksCount = snapshot.data!['completedTasksCount'] ?? 0;

        return Card(
          elevation: 3,
          margin: EdgeInsets.symmetric(horizontal: 16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'You already completed:',
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                    color: Color.fromARGB(255, 150, 96, 169), // Completed tasks text color
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '$completedTasksCount tasks',
                  style: TextStyle(
                    fontSize: 16.0,
                    color: Colors.black,
                  ),
                ),
                Text(
                  'Good Job!',
                  style: TextStyle(
                    fontSize: 16.0,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final TextEditingController _passwordController = TextEditingController();
    final TextEditingController _confirmPasswordController = TextEditingController();
    final _formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Change Password'),
          content: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(labelText: 'New Password'),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your new password';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: InputDecoration(labelText: 'Confirm New Password'),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your new password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  try {
                    await FirebaseAuth.instance.currentUser?.updatePassword(_passwordController.text);
                    Navigator.of(context).pop();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Failed to change password: $e'),
                    ));
                  }
                }
              },
              child: Text('Change'),
            ),
          ],
        );
      },
    );
  }
}
