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

final _logoBytes = base64Decode(kLogoB64);

class Logo extends StatelessWidget {
  final double size;
  const Logo({super.key, this.size = 24});
  @override
  Widget build(BuildContext context) =>
      Image.memory(_logoBytes, height: size * 2.5, gaplessPlayback: true);
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
            colors: [Color(0xFF03041A), Color(0xFF060826), Color(0xFF0B0A3A)],
          ),
        ),
        child: CustomPaint(
          painter: WavesPainter(),
          child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Column(children: [
              // ── top bar
              SizedBox(
                height: 64,
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
      ),
    );
  }
}

class WavesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rect = Rect.fromLTWH(0, 0, w, h);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0.2, 1.15),
          radius: 0.9,
          colors: [Color(0x662B1BFF), Color(0x00000000)],
        ).createShader(rect),
    );
    void wave(double y0, double y1, double y2, Color c, double sw) {
      final p = Path()
        ..moveTo(0, h * y0)
        ..cubicTo(w * 0.3, h * y1, w * 0.6, h * y2, w, h * (y0 - 0.08));
      canvas.drawPath(
          p,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = sw * 4
            ..color = c.withAlpha(70)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
      canvas.drawPath(
          p,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = sw
            ..color = c);
    }

    wave(0.90, 0.80, 1.02, const Color(0xFF3D6BFF), 2);
    wave(0.93, 0.84, 1.05, const Color(0xFF9B3DFF), 2.5);
    wave(0.97, 0.90, 1.08, const Color(0xFFFF3DCB), 1.5);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
  int stage = 0; // 0 = قائمة الباقات، 1 = قنوات الباقة
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
      setState(() { cats = c; loading = false; });
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

  void _openCat(int i) {
    catIdx = i;
    stage = 1;
    q = '';
    chans = [];
    _loadCat();
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

  Widget _catPanel() {
    if (err != null && cats.isEmpty) {
      return Center(
        child: TextButton.icon(
            onPressed: () { setState(() => err = null); _init(); },
            icon: const Icon(Icons.refresh),
            label: Text('خطأ - إعادة المحاولة\n$err', textAlign: TextAlign.center)),
      );
    }
    if (cats.isEmpty) return const Center(child: CircularProgressIndicator());
    final list = q.isEmpty
        ? cats
        : cats.where((e) => e['category_name'].toString().toLowerCase().contains(q)).toList();
    return Column(children: [
      Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(colors: [Color(0xFF5B21D6), Color(0xFF7B2FF7)]),
        ),
        child: Text('Live TV  •  ${cats.length}',
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
      ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.only(top: 6),
          itemExtent: 56,
          itemCount: list.length,
          itemBuilder: (_, i) {
            final cat = list[i];
            return InkWell(
              onTap: () => _openCat(cats.indexOf(cat)),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 2),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                    color: Colors.white12, borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  const Icon(Icons.folder_rounded, color: Color(0xFFB794FF)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(cat['category_name'].toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 18)),
                  ),
                  const Icon(Icons.chevron_right),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
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
          : (selected == null
              ? const Opacity(opacity: 0.35, child: Logo(size: 30))
              : const CircularProgressIndicator()),
    );
  }

  Widget _topBar() => SizedBox(
        height: 46,
        child: Row(children: [
          IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (stage == 1) {
                  setState(() { stage = 0; q = ''; });
                } else {
                  Navigator.pop(context);
                }
              }),
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
    return PopScope(
      canPop: stage == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && stage == 1) setState(() { stage = 0; q = ''; });
      },
      child: Scaffold(
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
                    child: stage == 0
                        ? _catPanel()
                        : Column(children: [
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
    ));
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
  bool showUi = true;
  int mode = 0; // 0 = ajuster, 1 = remplir (يقص الأطراف), 2 = étirer (تمديد)
  Timer? hideT;

  static const _modeNames = ['Ajuster', 'Remplir', 'Étirer'];

  @override
  void initState() {
    super.initState();
    ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => ready = true);
        ctrl.play();
        _autoHide();
      }).catchError((e) {
        if (mounted) setState(() => error = e.toString());
      });
  }

  @override
  void dispose() {
    hideT?.cancel();
    ctrl.dispose();
    super.dispose();
  }

  void _autoHide() {
    hideT?.cancel();
    hideT = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => showUi = false);
    });
  }

  void _toggleUi() {
    if (showUi) {
      hideT?.cancel();
      setState(() => showUi = false);
    } else {
      setState(() => showUi = true);
      _autoHide();
    }
  }

  Widget _video() {
    final s = ctrl.value.size;
    switch (mode) {
      case 1:
        return SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(width: s.width, height: s.height, child: VideoPlayer(ctrl)),
          ),
        );
      case 2:
        return SizedBox.expand(child: VideoPlayer(ctrl));
      default:
        return Center(
          child: AspectRatio(aspectRatio: ctrl.value.aspectRatio, child: VideoPlayer(ctrl)),
        );
    }
  }

  Widget _overlay() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 12, 24),
            child: Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
              Expanded(
                child: Text(widget.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20)),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() => mode = (mode + 1) % 3);
                  _autoHide();
                },
                icon: const Icon(Icons.aspect_ratio, color: Colors.white),
                label: Text(_modeNames[mode], style: const TextStyle(color: Colors.white, fontSize: 16)),
              ),
              IconButton(
                icon: Icon(ctrl.value.isPlaying ? Icons.pause : Icons.play_arrow, size: 30),
                onPressed: () {
                  setState(() => ctrl.value.isPlaying ? ctrl.pause() : ctrl.play());
                  _autoHide();
                },
              ),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        body: error != null
            ? Center(child: Text('تعذر التشغيل\n$error', textAlign: TextAlign.center))
            : !ready
                ? const Center(child: CircularProgressIndicator())
                : GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _toggleUi,
                    child: Stack(children: [
                      Positioned.fill(child: _video()),
                      if (showUi) Positioned(top: 0, left: 0, right: 0, child: _overlay()),
                    ]),
                  ),
      );
}

// شعار التطبيق (PNG مُشفّر)
const kLogoB64 =
    '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';
