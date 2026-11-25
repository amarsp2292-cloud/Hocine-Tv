import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

const appName = 'Hocine Tv';

void main() => runApp(const HocineApp());

class HocineApp extends StatelessWidget {
  const HocineApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: appName,
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true).copyWith(
          scaffoldBackgroundColor: const Color(0xFF070A1F),
          colorScheme: ColorScheme.dark(primary: Colors.blueAccent),
        ),
        home: const Splash(),
      );
}

class Xtream {
  final String server, user, pass;
  Xtream(this.server, this.user, this.pass);

  String get _api => '$server/player_api.php?username=$user&password=$pass';

  Future<dynamic> _get(String extra) async {
    final r = await http.get(Uri.parse('$_api$extra')).timeout(const Duration(seconds: 20));
    if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
    return jsonDecode(utf8.decode(r.bodyBytes));
  }

  Future<Map> login() async {
    final d = await _get('');
    if (d is! Map || d['user_info'] == null || d['user_info']['auth'].toString() != '1') {
      throw Exception('بيانات الدخول غير صحيحة');
    }
    return d['user_info'];
  }

  Future<List> categories(String type) async => await _get('&action=get_${type}_categories') as List;
  Future<List> streams(String type, String cat) async =>
      await _get('&action=get_${type}_streams&category_id=$cat') as List;
  Future<List> series(String cat) async => await _get('&action=get_series&category_id=$cat') as List;
  Future<Map> seriesInfo(String id) async => await _get('&action=get_series_info&series_id=$id') as Map;

  String liveUrl(dynamic id) => '$server/live/$user/$pass/$id.m3u8';
  String movieUrl(dynamic id, String ext) => '$server/movie/$user/$pass/$id.$ext';
  String episodeUrl(dynamic id, String ext) => '$server/series/$user/$pass/$id.$ext';
}

class Splash extends StatefulWidget {
  const Splash({super.key});
  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> {
  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final p = await SharedPreferences.getInstance();
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    final s = p.getString('server'), u = p.getString('user'), pw = p.getString('pass');
    Widget next = const LoginScreen();
    if (s != null && u != null && pw != null) {
      next = HomeScreen(api: Xtream(s, u, pw), info: const {});
    }
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => next));
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.live_tv, size: 90, color: Colors.blueAccent),
            SizedBox(height: 16),
            Text(appName, style: TextStyle(fontSize: 38, fontWeight: FontWeight.bold)),
          ]),
        ),
      );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final server = TextEditingController(text: 'http://');
  final user = TextEditingController();
  final pass = TextEditingController();
  bool loading = false;
  String? error;

  Future<void> _login() async {
    setState(() { loading = true; error = null; });
    var s = server.text.trim();
    while (s.endsWith('/')) { s = s.substring(0, s.length - 1); }
    final api = Xtream(s, user.text.trim(), pass.text.trim());
    try {
      final info = await api.login();
      final p = await SharedPreferences.getInstance();
      await p.setString('server', s);
      await p.setString('user', api.user);
      await p.setString('pass', api.pass);
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen(api: api, info: info)));
    } catch (e) {
      setState(() => error = 'فشل الدخول: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Widget _field(TextEditingController c, String label, {bool obscure = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          obscureText: obscure,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(children: [
                const Text(appName, style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                _field(server, 'رابط السيرفر (http://host:port)'),
                _field(user, 'اسم المستخدم'),
                _field(pass, 'كلمة المرور', obscure: true),
                if (error != null) Text(error!, style: const TextStyle(color: Colors.redAccent)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: loading ? null : _login,
                    child: loading ? const CircularProgressIndicator() : const Text('دخول'),
                  ),
                ),
              ]),
            ),
          ),
        ),
      );
}

class HomeScreen extends StatelessWidget {
  final Xtream api;
  final Map info;
  const HomeScreen({super.key, required this.api, required this.info});

  Widget _tile(BuildContext c, String title, IconData icon, List<Color> colors, String type) => Expanded(
        child: InkWell(
          onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => CategoriesScreen(api: api, type: type, title: title))),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(colors: colors),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 56),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text(appName, style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                final p = await SharedPreferences.getInstance();
                await p.clear();
                if (context.mounted) {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                }
              },
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(children: [
            _tile(context, 'TV EN DIRECT', Icons.live_tv, [Colors.teal, Colors.indigo], 'live'),
            Expanded(
              child: Row(children: [
                _tile(context, 'FILMS', Icons.play_circle, [Colors.pink, Colors.orange], 'vod'),
                _tile(context, 'SERIES', Icons.movie, [Colors.purple, Colors.blue], 'series'),
              ]),
            ),
          ]),
        ),
      );
}

class CategoriesScreen extends StatelessWidget {
  final Xtream api;
  final String type, title;
  const CategoriesScreen({super.key, required this.api, required this.type, required this.title});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: FutureBuilder<List>(
          future: api.categories(type),
          builder: (c, s) {
            if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (s.hasError) return Center(child: Text('خطأ: ${s.error}'));
            final cats = s.data!;
            return ListView.builder(
              itemCount: cats.length,
              itemBuilder: (_, i) => ListTile(
                title: Text(cats[i]['category_name'].toString()),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ItemsScreen(api: api, type: type, catId: cats[i]['category_id'].toString(), title: cats[i]['category_name'].toString()),
                  ),
                ),
              ),
            );
          },
        ),
      );
}

class ItemsScreen extends StatefulWidget {
  final Xtream api;
  final String type, catId, title;
  const ItemsScreen({super.key, required this.api, required this.type, required this.catId, required this.title});
  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  late Future<List> future;
  String q = '';

  @override
  void initState() {
    super.initState();
    future = widget.type == 'series' ? widget.api.series(widget.catId) : widget.api.streams(widget.type, widget.catId);
  }

  void _open(Map it) {
    final api = widget.api;
    if (widget.type == 'series') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => SeriesScreen(api: api, id: it['series_id'].toString(), name: it['name'].toString())));
      return;
    }
    final url = widget.type == 'live'
        ? api.liveUrl(it['stream_id'])
        : api.movieUrl(it['stream_id'], (it['container_extension'] ?? 'mp4').toString());
    Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(url: url, title: it['name'].toString())));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'بحث', border: OutlineInputBorder()),
              onChanged: (v) => setState(() => q = v.toLowerCase()),
            ),
          ),
          Expanded(
            child: FutureBuilder<List>(
              future: future,
              builder: (c, s) {
                if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
                if (s.hasError) return Center(child: Text('خطأ: ${s.error}'));
                final items = s.data!.where((e) => e['name'].toString().toLowerCase().contains(q)).toList();
                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final it = items[i] as Map;
                    final icon = (it['stream_icon'] ?? it['cover'] ?? '').toString();
                    return ListTile(
                      leading: icon.isEmpty
                          ? const Icon(Icons.tv)
                          : Image.network(icon, width: 48, errorBuilder: (_, __, ___) => const Icon(Icons.tv)),
                      title: Text(it['name'].toString()),
                      onTap: () => _open(it),
                    );
                  },
                );
              },
            ),
          ),
        ]),
      );
}

class SeriesScreen extends StatelessWidget {
  final Xtream api;
  final String id, name;
  const SeriesScreen({super.key, required this.api, required this.id, required this.name});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(name)),
        body: FutureBuilder<Map>(
          future: api.seriesInfo(id),
          builder: (c, s) {
            if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (s.hasError) return Center(child: Text('خطأ: ${s.error}'));
            final eps = s.data!['episodes'];
            final widgets = <Widget>[];
            if (eps is Map) {
              eps.forEach((season, list) {
                widgets.add(Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('الموسم $season', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ));
                for (final e in list) {
                  widgets.add(ListTile(
                    title: Text('${e['episode_num']}. ${e['title']}'),
                    leading: const Icon(Icons.play_arrow),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlayerScreen(
                          url: api.episodeUrl(e['id'], (e['container_extension'] ?? 'mp4').toString()),
                          title: e['title'].toString(),
                        ),
                      ),
                    ),
                  ));
                }
              });
            }
            return ListView(children: widgets);
          },
        ),
      );
}

class PlayerScreen extends StatefulWidget {
  final String url, title;
  const PlayerScreen({super.key, required this.url, required this.title});
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late VideoPlayerController ctrl;
  bool ready = false;
  String? error;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        setState(() => ready = true);
        ctrl.play();
      }).catchError((e) => setState(() => error = e.toString()));
  }

  @override
  void dispose() {
    ctrl.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(title: Text(widget.title), backgroundColor: Colors.black54),
        body: Center(
          child: error != null
              ? Text('تعذر التشغيل\n$error', textAlign: TextAlign.center)
              : !ready
                  ? const CircularProgressIndicator()
                  : GestureDetector(
                      onTap: () => setState(() => ctrl.value.isPlaying ? ctrl.pause() : ctrl.play()),
                      child: AspectRatio(aspectRatio: ctrl.value.aspectRatio, child: VideoPlayer(ctrl)),
                    ),
        ),
      );
}
