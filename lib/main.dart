import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

const appName = 'Hocine Tv';
const kBg = Color(0xFF070A1F);
const kPurple = Color(0xFF7B2FF7);
const kPurpleDark = Color(0xFF4A1FB8);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(
      [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const HocineApp());
}

class HocineApp extends StatelessWidget {
  const HocineApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: appName,
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true).copyWith(
          scaffoldBackgroundColor: kBg,
          colorScheme: const ColorScheme.dark(primary: kPurple),
        ),
        home: const Splash(),
      );
}

// ───────────────────────── Helpers ─────────────────────────

const _months = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
];
const _monthsShort = [
  'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
  'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'
];

String two(int n) => n.toString().padLeft(2, '0');
String hhmm(DateTime d) => '${two(d.hour)}:${two(d.minute)}';

String agoText(int? ms) {
  if (ms == null) return 'never';
  final d = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms));
  if (d.inMinutes < 1) return 'just now';
  if (d.inHours < 1) return '${d.inMinutes} minutes ago';
  if (d.inDays < 1) return '${d.inHours} hours ago';
  return '${d.inDays} days ago';
}

String expText(Map info) {
  final v = int.tryParse((info['exp_date'] ?? '').toString());
  if (v == null) return 'Illimité';
  final d = DateTime.fromMillisecondsSinceEpoch(v * 1000);
  return '${_months[d.month - 1]} ${d.day}, ${d.year}';
}

void soon(BuildContext c) => ScaffoldMessenger.of(c)
    .showSnackBar(const SnackBar(content: Text('قريباً')));

Future<void> logout(BuildContext c) async {
  final p = await SharedPreferences.getInstance();
  await p.clear();
  if (c.mounted) {
    Navigator.pushAndRemoveUntil(
        c, MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }
}

// ───────────────────────── API ─────────────────────────

class Xtream {
  final String server, user, pass;
  Xtream(this.server, this.user, this.pass);

  final Map<String, dynamic> _cache = {};

  String get _api => '$server/player_api.php?username=$user&password=$pass';

  Future<dynamic> _get(String extra, {bool cache = true}) async {
    if (cache && _cache.containsKey(extra)) return _cache[extra];
    final r = await http
        .get(Uri.parse('$_api$extra'))
        .timeout(const Duration(seconds: 30));
    if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
    final d = jsonDecode(utf8.decode(r.bodyBytes));
    if (cache) _cache[extra] = d;
    return d;
  }

  void clearCache([String? type]) {
    if (type == null) {
      _cache.clear();
    } else {
      _cache.removeWhere((k, _) => k.contains('_$type'));
    }
  }

  Future<Map> login() async {
    final d = await _get('', cache: false);
    if (d is! Map || d['user_info'] == null || d['user_info']['auth'].toString() != '1') {
      throw Exception('بيانات الدخول غير صحيحة');
    }
    return d['user_info'];
  }

  Future<List> categories(String type) async =>
      await _get('&action=get_${type}_categories') as List;

  /// cat فارغ = كل القنوات / الأفلام
  Future<List> streams(String type, String cat) async => await _get(
      '&action=get_${type}_streams${cat.isEmpty ? '' : '&category_id=$cat'}') as List;

  Future<List> series(String cat) async =>
      await _get('&action=get_series&category_id=$cat') as List;
  Future<Map> seriesInfo(String id) async =>
      await _get('&action=get_series_info&series_id=$id') as Map;

  String liveUrl(dynamic id) => '$server/live/$user/$pass/$id.m3u8';
  String movieUrl(dynamic id, String ext) => '$server/movie/$user/$pass/$id.$ext';
  String episodeUrl(dynamic id, String ext) => '$server/series/$user/$pass/$id.$ext';
}

// ───────────────────────── Shared widgets ─────────────────────────

class Logo extends StatelessWidget {
  final double size;
  const Logo({super.key, this.size = 24});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.satellite_alt, color: Colors.amber, size: size + 4),
        const SizedBox(width: 6),
        Text.rich(TextSpan(children: [
          TextSpan(
              text: 'Hocine ',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: size)),
          TextSpan(
              text: 'tv',
              style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w900, fontSize: size)),
        ])),
      ]);
}

class ClockText extends StatefulWidget {
  final bool longDate;
  const ClockText({super.key, this.longDate = false});
  @override
  State<ClockText> createState() => _ClockTextState();
}

class _ClockTextState extends State<ClockText> {
  DateTime now = DateTime.now();
  Timer? t;

  @override
  void initState() {
    super.initState();
    t = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() => now = DateTime.now());
    });
  }

  @override
  void dispose() {
    t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.longDate ? _months[now.month - 1] : _monthsShort[now.month - 1];
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(hhmm(now), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(width: 14),
      Text('$m ${now.day},${now.year}',
          style: const TextStyle(fontSize: 16, color: Colors.white70)),
    ]);
  }
}

class SettingsMenu extends StatelessWidget {
  const SettingsMenu({super.key});
  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
        icon: const Icon(Icons.settings, size: 28),
        onSelected: (v) {
          if (v == 'logout') logout(context);
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'logout', child: Text('Se déconnecter')),
        ],
      );
}

// ───────────────────────── Splash / Login ─────────────────────────

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
      final api = Xtream(s, u, pw);
      Map info = {};
      try {
        info = await api.login().timeout(const Duration(seconds: 15));
      } catch (_) {}
      next = HomeScreen(api: api, info: info);
    }
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => next));
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Logo(size: 44)),
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
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => HomeScreen(api: api, info: info)));
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
                const Logo(size: 34),
                const SizedBox(height: 20),
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

// ───────────────────────── Home ─────────────────────────

class HomeScreen extends StatefulWidget {
  final Xtream api;
  final Map info;
  const HomeScreen({super.key, required this.api, required this.info});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Map<String, int> upd = {};
  final Set<String> busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final k in ['live', 'vod', 'series']) {
      var v = p.getInt('upd_$k');
      if (v == null) {
        v = now;
        await p.setInt('upd_$k', now);
      }
      upd[k] = v;
    }
    if (mounted) setState(() {});
  }

  Future<void> _refresh(String type) async {
    setState(() => busy.add(type));
    try {
      widget.api.clearCache(type);
      await widget.api.categories(type);
      final p = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      await p.setInt('upd_$type', now);
      if (mounted) setState(() => upd[type] = now);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    } finally {
      if (mounted) setState(() => busy.remove(type));
    }
  }

  void _open(String type) {
    final api = widget.api;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => type == 'live'
            ? LiveScreen(api: api)
            : CategoriesScreen(api: api, type: type, title: type == 'vod' ? 'FILMS' : 'SERIES'),
      ),
    );
  }

  void _account() {
    final i = widget.info;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text((i['username'] ?? widget.api.user).toString()),
        content: Text('Statut: ${i['status'] ?? '-'}\n'
            'Expiration: ${expText(i)}\n'
            'Connexions max: ${i['max_connections'] ?? '-'}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 720;
    final who = (widget.info['username'] ?? widget.api.user).toString();
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF04061A), Color(0xFF0A0B3A), Color(0xFF2A0F80)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(children: [
              // ── top bar
              SizedBox(
                height: 48,
                child: Row(children: [
                  const Logo(size: 24),
                  const SizedBox(width: 24),
                  const ClockText(),
                  const Spacer(),
                  InkWell(
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => SearchScreen(api: widget.api))),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(children: [
                        const Icon(Icons.search, size: 28),
                        if (wide) const SizedBox(width: 8),
                        if (wide) const Text('Main Recherche', style: TextStyle(fontSize: 17)),
                      ]),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.notifications, size: 26), onPressed: () => soon(context)),
                  IconButton(icon: const Icon(Icons.person, size: 26), onPressed: _account),
                  const SettingsMenu(),
                ]),
              ),
              const SizedBox(height: 8),
              // ── cards
              Expanded(
                child: Row(children: [
                  Expanded(
                    flex: 5,
                    child: BigCard(
                      title: 'TV EN DIRECT',
                      icon: Icons.live_tv_rounded,
                      colors: const [Color(0xFF14D8FF), Color(0xFF0B52FF), Color(0xFF1A0FA8)],
                      updated: agoText(upd['live']),
                      busy: busy.contains('live'),
                      onTap: () => _open('live'),
                      onRefresh: () => _refresh('live'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 9,
                    child: Column(children: [
                      Expanded(
                        flex: 5,
                        child: Row(children: [
                          Expanded(
                            child: BigCard(
                              title: 'FILMS',
                              icon: Icons.local_movies_rounded,
                              colors: const [Color(0xFFFF2D55), Color(0xFFFF6A00), Color(0xFFFFC400)],
                              updated: agoText(upd['vod']),
                              busy: busy.contains('vod'),
                              onTap: () => _open('vod'),
                              onRefresh: () => _refresh('vod'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: BigCard(
                              title: 'SERIES',
                              icon: Icons.movie_creation_rounded,
                              colors: const [Color(0xFFB000FF), Color(0xFF7A2BF0), Color(0xFF5B7CFF)],
                              updated: agoText(upd['series']),
                              busy: busy.contains('series'),
                              onTap: () => _open('series'),
                              onRefresh: () => _refresh('series'),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        flex: 2,
                        child: Row(children: [
                          Expanded(
                            child: SmallTile(
                              label: 'LIVE AVEC EPG',
                              icon: Icons.live_tv,
                              colors: const [Color(0xFF16B8A6), Color(0xFF1AA37A)],
                              onTap: () => _open('live'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SmallTile(
                              label: 'MULTI-ÉCRANS',
                              icon: Icons.grid_view_rounded,
                              colors: const [Color(0xFF12B866), Color(0xFF0FA94F)],
                              onTap: () => soon(context),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SmallTile(
                              label: 'RATTRAPER',
                              icon: Icons.history_rounded,
                              colors: const [Color(0xFF13C26B), Color(0xFF0DE06A)],
                              onTap: () => soon(context),
                            ),
                          ),
                        ]),
                      ),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 8),
              // ── footer
              SizedBox(
                height: 36,
                child: Row(children: [
                  Expanded(
                    child: Row(children: [
                      const Icon(Icons.calendar_month, size: 26),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text('Expiration : ${expText(widget.info)}',
                            overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16)),
                      ),
                    ]),
                  ),
                  Expanded(
                    child: Center(
                      child: InkWell(
                        onTap: () => soon(context),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.shopping_cart_outlined, size: 26),
                          SizedBox(width: 10),
                          Text('Buy Premium Version', style: TextStyle(fontSize: 16)),
                        ]),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text.rich(
                        TextSpan(children: [
                          const TextSpan(text: 'Connecté : '),
                          TextSpan(text: who, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ]),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class BigCard extends StatelessWidget {
  final String title, updated;
  final IconData icon;
  final List<Color> colors;
  final bool busy;
  final VoidCallback onTap, onRefresh;
  const BigCard({
    super.key,
    required this.title,
    required this.icon,
    required this.colors,
    required this.updated,
    required this.onTap,
    required this.onRefresh,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
            ),
            child: Column(children: [
              Expanded(
                child: InkWell(
                  onTap: onTap,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(icon, size: 84, color: Colors.white),
                          const SizedBox(height: 6),
                          Text(title,
                              style: const TextStyle(
                                  fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white)),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                color: Colors.black26,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(children: [
                  Expanded(
                    child: Text('Dernière mise à jour: $updated',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: busy ? null : onRefresh,
                    child: Container(
                      width: 36,
                      height: 30,
                      decoration:
                          BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                      child: busy
                          ? const Padding(
                              padding: EdgeInsets.all(6),
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.sync, color: Colors.black87, size: 22),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      );
}

class SmallTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;
  const SmallTile(
      {super.key, required this.label, required this.icon, required this.colors, required this.onTap});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.centerLeft, end: Alignment.centerRight, colors: colors)),
            child: InkWell(
              onTap: onTap,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(icon, size: 34, color: Colors.white),
                      const SizedBox(width: 10),
                      Text(label,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

// ───────────────────────── Live TV (قائمة + معاينة) ─────────────────────────

class LiveScreen extends StatefulWidget {
  final Xtream api;
  const LiveScreen({super.key, required this.api});
  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  List cats = [];
  int catIdx = 0;
  List chans = [];
  Map? selected;
  bool loading = true;
  String? err;
  String q = '';

  VideoPlayerController? ctrl;
  bool ready = false;
  bool playError = false;
  int _token = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _token++;
    ctrl?.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final c = await widget.api.categories('live');
      if (!mounted) return;
      cats = [
        {'category_id': '', 'category_name': 'Toutes les chaînes'},
        ...c,
      ];
      await _loadCat();
    } catch (e) {
      if (mounted) setState(() { err = e.toString(); loading = false; });
    }
  }

  Future<void> _loadCat() async {
    setState(() { loading = true; err = null; });
    try {
      final id = cats[catIdx]['category_id'].toString();
      final l = await widget.api.streams('live', id);
      if (!mounted) return;
      setState(() { chans = l; loading = false; });
      if (ctrl == null && l.isNotEmpty) _play(l.first as Map);
    } catch (e) {
      if (mounted) setState(() { err = e.toString(); loading = false; });
    }
  }

  void _changeCat(int d) {
    if (cats.isEmpty) return;
    catIdx = (catIdx + d + cats.length) % cats.length;
    _loadCat();
  }

  Future<void> _play(Map ch) async {
    final my = ++_token;
    final old = ctrl;
    setState(() { selected = ch; ctrl = null; ready = false; playError = false; });
    old?.dispose();
    final c = VideoPlayerController.networkUrl(Uri.parse(widget.api.liveUrl(ch['stream_id'])));
    ctrl = c;
    try {
      await c.initialize();
      if (!mounted || my != _token) return;
      await c.play();
      setState(() => ready = true);
    } catch (_) {
      if (mounted && my == _token) setState(() => playError = true);
    }
  }

  Future<void> _fullscreen() async {
    final ch = selected;
    if (ch == null) return;
    ctrl?.pause();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
            url: widget.api.liveUrl(ch['stream_id']), title: ch['name'].toString()),
      ),
    );
    if (mounted) ctrl?.play();
  }

  void _search() {
    final tc = TextEditingController(text: q);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        content: TextField(
          controller: tc,
          autofocus: true,
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Recherche'),
          onSubmitted: (v) {
            setState(() => q = v.toLowerCase());
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => q = '');
              Navigator.pop(context);
            },
            child: const Text('Effacer'),
          ),
          TextButton(
            onPressed: () {
              setState(() => q = tc.text.toLowerCase());
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _video() {
    final c = ctrl;
    if (ready && c != null && c.value.isInitialized) {
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: c.value.size.width,
            height: c.value.size.height,
            child: VideoPlayer(c),
          ),
        ),
      );
    }
    return Container(
      color: Colors.black,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 120),
      child: playError
          ? const Text('تعذر التشغيل', style: TextStyle(color: Colors.white54))
          : (selected == null ? null : const CircularProgressIndicator()),
    );
  }

  Widget _topBar() => SizedBox(
        height: 46,
        child: Row(children: [
          IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
          const Logo(size: 20),
          const SizedBox(width: 16),
          const ClockText(longDate: true),
          const Spacer(),
          IconButton(icon: const Icon(Icons.search, size: 28), onPressed: _search),
          const SettingsMenu(),
        ]),
      );

  Widget _catHeader() {
    final name = cats.isEmpty ? '...' : cats[catIdx]['category_name'].toString();
    return Container(
      height: 46,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(colors: [Color(0xFF5B21D6), Color(0xFF7B2FF7)]),
      ),
      child: Row(children: [
        IconButton(icon: const Icon(Icons.chevron_left, size: 30), onPressed: () => _changeCat(-1)),
        Expanded(
          child: Text(name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
        ),
        IconButton(icon: const Icon(Icons.chevron_right, size: 30), onPressed: () => _changeCat(1)),
      ]),
    );
  }

  Widget _signal() => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final h in [6.0, 11.0, 16.0, 21.0])
            Container(
              width: 5,
              height: h,
              margin: const EdgeInsets.only(left: 2),
              decoration: BoxDecoration(
                  color: const Color(0xFF2EE04A), borderRadius: BorderRadius.circular(1.5)),
            ),
        ],
      );

  Widget _row(List list, int i) {
    final ch = list[i] as Map;
    final isSel = selected != null && selected!['stream_id'].toString() == ch['stream_id'].toString();
    final icon = (ch['stream_icon'] ?? '').toString();
    return InkWell(
      onTap: () => isSel ? _fullscreen() : _play(ch),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isSel ? null : Colors.white12,
          gradient: isSel
              ? const LinearGradient(colors: [Color(0xFF7B2FF7), Color(0xFF4A1FB8)])
              : null,
          borderRadius: BorderRadius.circular(14),
          border: isSel ? Border.all(color: Colors.white, width: 1.5) : null,
        ),
        child: Row(children: [
          SizedBox(
            width: 44,
            child: Text((i + 1).toString().padLeft(3, '0'),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          ),
          SizedBox(
            width: 62,
            height: 40,
            child: icon.isEmpty
                ? const Icon(Icons.tv, color: Colors.white54)
                : Image.network(icon,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(Icons.tv, color: Colors.white54)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(ch['name'].toString(),
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18)),
          ),
          isSel ? const Icon(Icons.play_arrow, size: 30) : _signal(),
        ]),
      ),
    );
  }

  Widget _list() {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (err != null) {
      return Center(
        child: TextButton.icon(
            onPressed: cats.isEmpty ? _init : _loadCat,
            icon: const Icon(Icons.refresh),
            label: Text('خطأ - إعادة المحاولة\n$err', textAlign: TextAlign.center)),
      );
    }
    final list = q.isEmpty
        ? chans
        : chans.where((e) => e['name'].toString().toLowerCase().contains(q)).toList();
    return ListView.builder(
      padding: const EdgeInsets.only(top: 6),
      itemExtent: 56,
      itemCount: list.length,
      itemBuilder: (_, i) => _row(list, i),
    );
  }

  Widget _liveBadge() => Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: selected == null
              ? const SizedBox()
              : Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                  const Text('LIVE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 2),
                  Container(
                    constraints: const BoxConstraints(maxWidth: 260),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration:
                        BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                    child: Text(selected!['name'].toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Color(0xFF4A1FB8), fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                ]),
        ),
      );

  Widget _tabs() => SizedBox(
        height: 46,
        child: Row(children: [
          Expanded(flex: 4, child: _tab('Live TV', Icons.live_tv, true, () {})),
          const SizedBox(width: 10),
          Expanded(
              flex: 4,
              child: _tab('Films', Icons.local_movies, false, () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => CategoriesScreen(api: widget.api, type: 'vod', title: 'FILMS'))))),
          const SizedBox(width: 10),
          Expanded(
              flex: 4,
              child: _tab('Séries', Icons.movie_creation, false, () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          CategoriesScreen(api: widget.api, type: 'series', title: 'SERIES'))))),
          const SizedBox(width: 10),
          Expanded(flex: 5, child: _tab('Multi-Écrans', Icons.grid_view_rounded, false, () => soon(context))),
          const SizedBox(width: 10),
          Expanded(flex: 5, child: _tab('Rattraper', Icons.history_rounded, false, () => soon(context))),
        ]),
      );

  Widget _tab(String label, IconData icon, bool on, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: on ? null : Colors.white12,
            gradient: on ? const LinearGradient(colors: [Color(0xFF5B21D6), Color(0xFF8A3DFF)]) : null,
            border: on ? Border.all(color: const Color(0xFFB794FF), width: 2) : null,
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 24),
                const SizedBox(width: 8),
                Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
              ]),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Positioned.fill(child: GestureDetector(onTap: _fullscreen, child: _video())),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xF2120A3A), Color(0xB3120A3A), Color(0x00120A3A)],
                  stops: [0, 0.45, 0.75],
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Column(children: [
              _topBar(),
              const SizedBox(height: 4),
              Expanded(
                child: Row(children: [
                  SizedBox(
                    width: w * 0.46,
                    child: Column(children: [
                      _catHeader(),
                      Expanded(child: _list()),
                    ]),
                  ),
                  Expanded(child: _liveBadge()),
                ]),
              ),
              const SizedBox(height: 6),
              _tabs(),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ───────────────────────── بحث عام ─────────────────────────

class SearchScreen extends StatefulWidget {
  final Xtream api;
  const SearchScreen({super.key, required this.api});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  List<Map> all = [];
  bool loading = true;
  String? err;
  String q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([widget.api.streams('live', ''), widget.api.streams('vod', '')]);
      final out = <Map>[];
      for (var t = 0; t < 2; t++) {
        for (final e in r[t]) {
          out.add({...(e as Map), '_t': t == 0 ? 'live' : 'vod'});
        }
      }
      if (mounted) setState(() { all = out; loading = false; });
    } catch (e) {
      if (mounted) setState(() { err = e.toString(); loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final res = q.length < 2
        ? <Map>[]
        : all.where((e) => e['name'].toString().toLowerCase().contains(q)).take(100).toList();
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Main Recherche', border: InputBorder.none),
          onChanged: (v) => setState(() => q = v.toLowerCase().trim()),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : err != null
              ? Center(child: Text('خطأ: $err'))
              : ListView.builder(
                  itemCount: res.length,
                  itemBuilder: (_, i) {
                    final it = res[i];
                    final live = it['_t'] == 'live';
                    return ListTile(
                      leading: Icon(live ? Icons.live_tv : Icons.movie),
                      title: Text(it['name'].toString()),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PlayerScreen(
                            url: live
                                ? widget.api.liveUrl(it['stream_id'])
                                : widget.api.movieUrl(
                                    it['stream_id'], (it['container_extension'] ?? 'mp4').toString()),
                            title: it['name'].toString(),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

// ───────────────────────── الأفلام / المسلسلات ─────────────────────────

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
                    builder: (_) => ItemsScreen(
                        api: api,
                        type: type,
                        catId: cats[i]['category_id'].toString(),
                        title: cats[i]['category_name'].toString()),
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
    future = widget.type == 'series'
        ? widget.api.series(widget.catId)
        : widget.api.streams(widget.type, widget.catId);
  }

  void _open(Map it) {
    final api = widget.api;
    if (widget.type == 'series') {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => SeriesScreen(api: api, id: it['series_id'].toString(), name: it['name'].toString())));
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
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search), hintText: 'بحث', border: OutlineInputBorder()),
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

// ───────────────────────── المشغل ─────────────────────────

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
    ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => ready = true);
        ctrl.play();
      }).catchError((e) {
        if (mounted) setState(() => error = e.toString());
      });
  }

  @override
  void dispose() {
    ctrl.dispose();
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
