import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://vplkqirnxbroiictsaqv.supabase.co',
    anonKey: 'sb_publishable_pHe7h-OXspAJmJ-EqZioag_PMAEa9iC',
  );

  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Supabase Notes App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      home: const AuthGate(),
    );
  }
}

/// Show Snackbar easily
extension SnackBarExtension on BuildContext {
  void showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }
}

/// Decide login page or notes page
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = supabase.auth.currentSession;

        if (session == null) {
          return const AuthPage();
        }

        return const NotesPage();
      },
    );
  }
}

/// Login + Register Page
class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLogin = true;
  bool isLoading = false;

  Future<void> submit() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      context.showMessage('Email နဲ့ Password ဖြည့်ပါ။', isError: true);
      return;
    }

    if (password.length < 6) {
      context.showMessage('Password အနည်းဆုံး 6 လုံးဖြစ်ရမယ်။', isError: true);
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      if (isLogin) {
        await supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );

        if (mounted) {
          context.showMessage('Login အောင်မြင်ပါပြီ။');
        }
      } else {
        final response = await supabase.auth.signUp(
          email: email,
          password: password,
        );

        if (mounted) {
          if (response.session == null) {
            context.showMessage(
              'Account ဖန်တီးပြီးပါပြီ။ Email confirmation link ကို စစ်ပြီးနောက် Login ဝင်ပါ။',
            );
          } else {
            context.showMessage('Register အောင်မြင်ပါပြီ။');
          }
        }
      }
    } on AuthException catch (error) {
      if (mounted) {
        context.showMessage(error.message, isError: true);
      }
    } catch (error) {
      if (mounted) {
        context.showMessage('တစ်ခုခု မှားယွင်းနေပါတယ်။', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  blurRadius: 18,
                  color: Colors.black.withOpacity(0.08),
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.note_alt_rounded,
                  size: 60,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  isLogin ? 'Login' : 'Register',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),

                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : submit,
                    child: isLoading
                        ? const CircularProgressIndicator()
                        : Text(isLogin ? 'Login' : 'Register'),
                  ),
                ),
                const SizedBox(height: 14),

                TextButton(
                  onPressed: isLoading
                      ? null
                      : () {
                          setState(() {
                            isLogin = !isLogin;
                          });
                        },
                  child: Text(
                    isLogin
                        ? 'Account မရှိသေးဘူးလား? Register'
                        : 'Account ရှိပြီးသားလား? Login',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Notes Page
class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  List<Map<String, dynamic>> notes = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadNotes();
  }

  Future<void> loadNotes() async {
    setState(() {
      isLoading = true;
    });

    try {
      final data = await supabase
          .from('notes')
          .select()
          .order('created_at', ascending: false);

      notes = List<Map<String, dynamic>>.from(data);
    } catch (error) {
      if (mounted) {
        context.showMessage('Notes မဖတ်နိုင်ပါ။', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> addNote(String title, String content) async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      context.showMessage('Login ပြန်ဝင်ပါ။', isError: true);
      return;
    }

    try {
      await supabase.from('notes').insert({
        'user_id': user.id,
        'title': title,
        'content': content,
      });

      if (mounted) {
        context.showMessage('Note ထည့်ပြီးပါပြီ။');
      }

      await loadNotes();
    } catch (error) {
      if (mounted) {
        context.showMessage('Note မထည့်နိုင်ပါ။', isError: true);
      }
    }
  }

  Future<void> updateNote(int id, String title, String content) async {
    try {
      await supabase
          .from('notes')
          .update({
            'title': title,
            'content': content,
          })
          .eq('id', id);

      if (mounted) {
        context.showMessage('Note ပြင်ပြီးပါပြီ။');
      }

      await loadNotes();
    } catch (error) {
      if (mounted) {
        context.showMessage('Note မပြင်နိုင်ပါ။', isError: true);
      }
    }
  }

  Future<void> deleteNote(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Note'),
          content: const Text('ဒီ note ကို ဖျက်မှာ သေချာလား?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await supabase.from('notes').delete().eq('id', id);

      if (mounted) {
        context.showMessage('Note ဖျက်ပြီးပါပြီ။');
      }

      await loadNotes();
    } catch (error) {
      if (mounted) {
        context.showMessage('Note မဖျက်နိုင်ပါ။', isError: true);
      }
    }
  }

  Future<void> openNoteDialog({Map<String, dynamic>? note}) async {
    final titleController = TextEditingController(
      text: note == null ? '' : note['title'].toString(),
    );

    final contentController = TextEditingController(
      text: note == null ? '' : note['content'].toString(),
    );

    final isEdit = note != null;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(isEdit ? 'Edit Note' : 'Add Note'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: contentController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Content',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final title = titleController.text.trim();
                final content = contentController.text.trim();

                if (title.isEmpty) {
                  context.showMessage('Title ဖြည့်ပါ။', isError: true);
                  return;
                }

                Navigator.pop(dialogContext);

                if (isEdit) {
                  await updateNote(
                    note['id'] as int,
                    title,
                    content,
                  );
                } else {
                  await addNote(title, content);
                }
              },
              child: Text(isEdit ? 'Update' : 'Save'),
            ),
          ],
        );
      },
    );

    titleController.dispose();
    contentController.dispose();
  }

  Future<void> logout() async {
    await supabase.auth.signOut();

    if (mounted) {
      context.showMessage('Logout ပြီးပါပြီ။');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Notes'),
        actions: [
          IconButton(
            onPressed: loadNotes,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : notes.isEmpty
              ? const Center(
                  child: Text(
                    'Note မရှိသေးပါ။\nအောက်က + ကိုနှိပ်ပြီး ထည့်ပါ။',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: loadNotes,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: notes.length,
                    itemBuilder: (context, index) {
                      final note = notes[index];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 14),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          title: Text(
                            note['title'].toString(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              note['content'].toString(),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') {
                                openNoteDialog(note: note);
                              } else if (value == 'delete') {
                                deleteNote(note['id'] as int);
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => openNoteDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}