import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'database.dart';
import 'models.dart';
import 'services/excel_service.dart';

const _yellow = Color(0xFFFFCF4A);
const _dark = Color(0xFF3F3F3F);
const _page = Color(0xFFF7F5EC);
const _line = Color(0xFFE7E3D6);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDatabase.instance.database;
  runApp(const MunoInventoryApp());
}

class MunoInventoryApp extends StatefulWidget {
  const MunoInventoryApp({super.key});

  @override
  State<MunoInventoryApp> createState() => _MunoInventoryAppState();
}

class _MunoInventoryAppState extends State<MunoInventoryApp> {
  AppUser? _user;
  late Future<bool> _hasUsers;

  @override
  void initState() {
    super.initState();
    _hasUsers = AppDatabase.instance.hasUsers();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Muno Inventory',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _yellow, brightness: Brightness.light),
        scaffoldBackgroundColor: _page,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          isDense: true,
        ),
        dataTableTheme: const DataTableThemeData(
          headingRowColor: WidgetStatePropertyAll(Color(0xFFF0ECDD)),
          dividerThickness: 0.8,
          headingTextStyle: TextStyle(fontWeight: FontWeight.w700, color: _dark),
        ),
      ),
      home: FutureBuilder<bool>(
        future: _hasUsers,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (!snapshot.data!) {
            return SetupAdminScreen(
              onCreated: (user) => setState(() {
                _user = user;
                _hasUsers = Future.value(true);
              }),
            );
          }
          if (_user == null) {
            return LoginScreen(onLogin: (user) => setState(() => _user = user));
          }
          return AppShell(user: _user!, onLogout: () => setState(() => _user = null));
        },
      ),
    );
  }
}

class SetupAdminScreen extends StatefulWidget {
  const SetupAdminScreen({super.key, required this.onCreated});
  final ValueChanged<AppUser> onCreated;

  @override
  State<SetupAdminScreen> createState() => _SetupAdminScreenState();
}

class _SetupAdminScreenState extends State<SetupAdminScreen> {
  final _name = TextEditingController();
  final _username = TextEditingController(text: 'admin');
  final _password = TextEditingController();
  bool _busy = false;

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty || _username.text.trim().isEmpty || _password.text.length < 4) {
      _snack(context, 'Ad, istifadəçi adı və minimum 4 simvolluq şifrə daxil et.');
      return;
    }
    setState(() => _busy = true);
    try {
      final user = await AppDatabase.instance.createFirstAdmin(
        fullName: _name.text,
        username: _username.text,
        password: _password.text,
      );
      widget.onCreated(user);
    } catch (e) {
      if (mounted) _snack(context, 'Admin yaradıla bilmədi: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _BrandHeader(subtitle: 'İlk quraşdırma · Admin hesabı'),
                  const SizedBox(height: 24),
                  TextField(controller: _name, decoration: const InputDecoration(labelText: 'Ad və soyad')),
                  const SizedBox(height: 12),
                  TextField(controller: _username, decoration: const InputDecoration(labelText: 'İstifadəçi adı')),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Şifrə'),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: _dark, foregroundColor: Colors.white),
                    onPressed: _busy ? null : _submit,
                    icon: const Icon(Icons.admin_panel_settings_outlined),
                    label: Text(_busy ? 'Yaradılır...' : 'Admin yarat'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onLogin});
  final ValueChanged<AppUser> onLogin;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  Future<void> _login() async {
    setState(() => _busy = true);
    final user = await AppDatabase.instance.login(_username.text, _password.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (user == null) {
      _snack(context, 'İstifadəçi adı və ya şifrə yanlışdır.');
      return;
    }
    widget.onLogin(user);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          if (MediaQuery.sizeOf(context).width > 760)
            Expanded(
              child: Container(
                color: _yellow,
                padding: const EdgeInsets.all(48),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 72, color: _dark),
                    SizedBox(height: 24),
                    Text('Muno Inventory', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w800, color: _dark)),
                    SizedBox(height: 8),
                    Text('Sürətli, offline və nəzarətli inventarizasiya.', style: TextStyle(fontSize: 18, color: _dark)),
                  ],
                ),
              ),
            ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _BrandHeader(subtitle: 'Sistemə giriş'),
                      const SizedBox(height: 28),
                      TextField(controller: _username, decoration: const InputDecoration(labelText: 'İstifadəçi adı')),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _password,
                        obscureText: true,
                        onSubmitted: (_) => _login(),
                        decoration: const InputDecoration(labelText: 'Şifrə'),
                      ),
                      const SizedBox(height: 18),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: _dark, foregroundColor: Colors.white),
                        onPressed: _busy ? null : _login,
                        child: Text(_busy ? 'Giriş...' : 'Daxil ol'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.subtitle});
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Muno Inventory', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: _dark)),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(color: Colors.grey.shade600)),
      ],
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.user, required this.onLogout});
  final AppUser user;
  final VoidCallback onLogout;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _titles = ['İdarəetmə paneli', 'İnventarizasiya', 'Məhsullar', 'Anbarlar', 'Admin'];

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(user: widget.user),
      InventoriesPage(user: widget.user),
      ProductsPage(user: widget.user),
      WarehousesPage(user: widget.user),
      AdminPage(user: widget.user),
    ];
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _dark,
        foregroundColor: Colors.white,
        title: Text(_titles[_index], style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(child: Text(widget.user.fullName, style: const TextStyle(fontWeight: FontWeight.w600))),
          ),
          PopupMenuButton<String>(
            icon: const CircleAvatar(backgroundColor: _yellow, child: Icon(Icons.person_outline, color: _dark)),
            onSelected: (value) {
              if (value == 'logout') widget.onLogout();
            },
            itemBuilder: (_) => const [PopupMenuItem(value: 'logout', child: Text('Çıxış'))],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          if (wide)
            NavigationRail(
              backgroundColor: _yellow,
              selectedIndex: _index,
              labelType: NavigationRailLabelType.all,
              onDestinationSelected: (value) => setState(() => _index = value),
              selectedIconTheme: const IconThemeData(color: _dark),
              selectedLabelTextStyle: const TextStyle(fontWeight: FontWeight.w800, color: _dark),
              destinations: const [
                NavigationRailDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: Text('Əsas')),
                NavigationRailDestination(icon: Icon(Icons.fact_check_outlined), selectedIcon: Icon(Icons.fact_check), label: Text('İnventar')),
                NavigationRailDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: Text('Məhsul')),
                NavigationRailDestination(icon: Icon(Icons.warehouse_outlined), selectedIcon: Icon(Icons.warehouse), label: Text('Anbar')),
                NavigationRailDestination(icon: Icon(Icons.admin_panel_settings_outlined), selectedIcon: Icon(Icons.admin_panel_settings), label: Text('Admin')),
              ],
            ),
          Expanded(child: pages[_index]),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (value) => setState(() => _index = value),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Əsas'),
                NavigationDestination(icon: Icon(Icons.fact_check_outlined), selectedIcon: Icon(Icons.fact_check), label: 'Sayım'),
                NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Məhsul'),
                NavigationDestination(icon: Icon(Icons.warehouse_outlined), selectedIcon: Icon(Icons.warehouse), label: 'Anbar'),
                NavigationDestination(icon: Icon(Icons.admin_panel_settings_outlined), selectedIcon: Icon(Icons.admin_panel_settings), label: 'Admin'),
              ],
            ),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.user});
  final AppUser user;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<(DashboardStats, List<InventoryHeader>, int)> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final companyId = widget.user.isAdmin ? null : widget.user.companyId;
    _future = () async {
      final stats = await AppDatabase.instance.getStats(companyId: companyId);
      final inventories = await AppDatabase.instance.getInventories(companyId: companyId);
      final pending = await AppDatabase.instance.pendingSyncCount();
      return (stats, inventories.take(8).toList(), pending);
    }();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(DashboardStats, List<InventoryHeader>, int)>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final (stats, recent, pending) = snapshot.data!;
        return RefreshIndicator(
          onRefresh: () async {
            setState(_reload);
            await _future;
          },
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _StatCard(icon: Icons.business_outlined, label: 'Müəssisə', value: '${stats.companies}'),
                  _StatCard(icon: Icons.warehouse_outlined, label: 'Anbar', value: '${stats.warehouses}'),
                  _StatCard(icon: Icons.inventory_2_outlined, label: 'Məhsul', value: '${stats.products}'),
                  _StatCard(icon: Icons.pending_actions_outlined, label: 'Açıq sayım', value: '${stats.openInventories}'),
                ],
              ),
              const SizedBox(height: 20),
              Card(
                child: ListTile(
                  leading: const CircleAvatar(backgroundColor: _yellow, child: Icon(Icons.cloud_off_outlined, color: _dark)),
                  title: const Text('Offline-first rejim', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('$pending dəyişiklik lokal sinxronizasiya növbəsindədir. Muno365 API qoşulduqda server sync aktivləşəcək.'),
                ),
              ),
              const SizedBox(height: 20),
              _SectionTitle(title: 'Son inventarizasiyalar', icon: Icons.history),
              const SizedBox(height: 8),
              _TableCard(
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('#')),
                    DataColumn(label: Text('Tarix')),
                    DataColumn(label: Text('Müəssisə')),
                    DataColumn(label: Text('Anbar')),
                    DataColumn(label: Text('Məsul şəxs')),
                    DataColumn(label: Text('Status')),
                  ],
                  rows: recent
                      .map((e) => DataRow(cells: [
                            DataCell(Text('${e.id}')),
                            DataCell(Text(e.inventoryDate)),
                            DataCell(Text(e.companyName ?? '')),
                            DataCell(Text(e.warehouseName ?? '')),
                            DataCell(Text(e.responsible)),
                            DataCell(_StatusChip(closed: e.isClosed)),
                          ]))
                      .toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(backgroundColor: _yellow, child: Icon(icon, color: _dark)),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: _dark)),
                Text(label, style: TextStyle(color: Colors.grey.shade600)),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key, required this.user});
  final AppUser user;

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final _db = AppDatabase.instance;
  final _excel = ExcelService(AppDatabase.instance);
  final _search = TextEditingController();
  List<Company> _companies = [];
  List<Product> _products = [];
  int? _companyId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final companies = await _db.getCompanies(onlyCompanyId: widget.user.isAdmin ? null : widget.user.companyId);
    var companyId = _companyId;
    if (companies.isNotEmpty && !companies.any((e) => e.id == companyId)) companyId = companies.first.id;
    final products = companyId == null ? <Product>[] : await _db.getProducts(companyId: companyId);
    if (!mounted) return;
    setState(() {
      _companies = companies;
      _companyId = companyId;
      _products = products;
      _loading = false;
    });
  }

  Future<void> _addProduct() async {
    if (_companyId == null) {
      _snack(context, 'Əvvəl müəssisə yarat.');
      return;
    }
    final saved = await showDialog<bool>(context: context, builder: (_) => ProductDialog(companyId: _companyId!));
    if (saved == true) await _reload();
  }

  Future<void> _import() async {
    if (_companyId == null) return;
    final result = await _excel.importProducts(_companyId!);
    if (!mounted || result == null) return;
    await _showImportResult(context, 'Məhsul importu', result);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.text.trim().toLowerCase();
    final visible = q.isEmpty
        ? _products
        : _products.where((p) => '${p.code} ${p.name} ${p.barcode ?? ''} ${p.subcategory}'.toLowerCase().contains(q)).toList();
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _Toolbar(
            children: [
              SizedBox(
                width: 230,
                child: DropdownButtonFormField<int>(
                  value: _companyId,
                  decoration: const InputDecoration(labelText: 'Müəssisə'),
                  items: _companies.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                  onChanged: (value) async {
                    setState(() => _companyId = value);
                    await _reload();
                  },
                ),
              ),
              SizedBox(
                width: 280,
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Məhsul axtar'),
                ),
              ),
              OutlinedButton.icon(onPressed: _import, icon: const Icon(Icons.upload_file), label: const Text('Excel yüklə')),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: _dark, foregroundColor: Colors.white),
                onPressed: _addProduct,
                icon: const Icon(Icons.add),
                label: const Text('Məhsul yarat'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _TableCard(
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Kateqoriya')),
                        DataColumn(label: Text('Alt kateqoriya')),
                        DataColumn(label: Text('Kod')),
                        DataColumn(label: Text('Ad')),
                        DataColumn(label: Text('Barkod')),
                        DataColumn(label: Text('Ölçü vahidi')),
                        DataColumn(label: Text('Vahid qiyməti')),
                      ],
                      rows: visible
                          .map((p) => DataRow(cells: [
                                DataCell(Text(p.category)),
                                DataCell(Text(p.subcategory)),
                                DataCell(Text(p.code, style: const TextStyle(fontWeight: FontWeight.w700))),
                                DataCell(Text(p.name)),
                                DataCell(Text(p.barcode ?? '—')),
                                DataCell(Text(p.unit)),
                                DataCell(Text('${_num(p.unitPrice)} ₼')),
                              ]))
                          .toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class ProductDialog extends StatefulWidget {
  const ProductDialog({super.key, required this.companyId});
  final int companyId;

  @override
  State<ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<ProductDialog> {
  final _sub = TextEditingController();
  final _code = TextEditingController();
  final _barcode = TextEditingController();
  final _name = TextEditingController();
  final _price = TextEditingController();
  String _category = 'Mal';
  String _unit = 'ədəd';
  bool _busy = false;

  static const _units = ['ədəd', 'pors', 'kq', 'qr', 'litr', 'ml', 'qutu', 'paket', 'butulka', 'banka'];

  Future<void> _save() async {
    if (_code.text.trim().isEmpty || _name.text.trim().isEmpty) {
      _snack(context, 'Kod və məhsul adı məcburidir.');
      return;
    }
    setState(() => _busy = true);
    try {
      await AppDatabase.instance.upsertProduct(
        companyId: widget.companyId,
        category: _category,
        subcategory: _sub.text,
        code: _code.text,
        barcode: _barcode.text,
        name: _name.text,
        unit: _unit,
        unitPrice: _parse(_price.text),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _snack(context, 'Məhsul yaradıla bilmədi: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Yeni məhsul'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(labelText: 'Kateqoriya'),
                items: const ['Mal', 'Məhsul', 'Yarımfabrikat'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _category = v ?? 'Mal'),
              ),
              const SizedBox(height: 10),
              TextField(controller: _sub, decoration: const InputDecoration(labelText: 'Alt kateqoriya')),
              const SizedBox(height: 10),
              TextField(controller: _code, decoration: const InputDecoration(labelText: 'Kod')),
              const SizedBox(height: 10),
              TextField(controller: _barcode, decoration: const InputDecoration(labelText: 'Barkod (opsional)')),
              const SizedBox(height: 10),
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Məhsulun adı')),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _unit,
                decoration: const InputDecoration(labelText: 'Ölçü vahidi'),
                items: _units.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _unit = v ?? 'ədəd'),
              ),
              const SizedBox(height: 10),
              TextField(controller: _price, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Vahid qiyməti, ₼')),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Ləğv et')),
        FilledButton(onPressed: _busy ? null : _save, child: const Text('Yadda saxla')),
      ],
    );
  }
}

class WarehousesPage extends StatefulWidget {
  const WarehousesPage({super.key, required this.user});
  final AppUser user;

  @override
  State<WarehousesPage> createState() => _WarehousesPageState();
}

class _WarehousesPageState extends State<WarehousesPage> {
  List<Company> _companies = [];
  List<Warehouse> _warehouses = [];
  int? _companyId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final companies = await AppDatabase.instance.getCompanies(onlyCompanyId: widget.user.isAdmin ? null : widget.user.companyId);
    var selected = _companyId;
    if (companies.isNotEmpty && !companies.any((c) => c.id == selected)) selected = companies.first.id;
    final warehouses = selected == null ? <Warehouse>[] : await AppDatabase.instance.getWarehouses(companyId: selected);
    if (!mounted) return;
    setState(() {
      _companies = companies;
      _companyId = selected;
      _warehouses = warehouses;
      _loading = false;
    });
  }

  Future<void> _edit({Warehouse? warehouse}) async {
    if (_companyId == null) {
      _snack(context, 'Əvvəl müəssisə yarat.');
      return;
    }
    final controller = TextEditingController(text: warehouse?.name ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(warehouse == null ? 'Yeni anbar' : 'Anbarı redaktə et'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'Anbarın adı')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Ləğv et')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yadda saxla')),
        ],
      ),
    );
    if (ok != true || controller.text.trim().isEmpty) return;
    try {
      if (warehouse == null) {
        await AppDatabase.instance.createWarehouse(_companyId!, controller.text);
      } else {
        await AppDatabase.instance.updateWarehouse(warehouse.id, controller.text);
      }
      await _reload();
    } catch (e) {
      if (mounted) _snack(context, 'Anbar saxlanmadı: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final companyNames = {for (final c in _companies) c.id: c.name};
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _Toolbar(children: [
            SizedBox(
              width: 260,
              child: DropdownButtonFormField<int>(
                value: _companyId,
                decoration: const InputDecoration(labelText: 'Müəssisə'),
                items: _companies.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                onChanged: (v) async {
                  setState(() => _companyId = v);
                  await _reload();
                },
              ),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _dark, foregroundColor: Colors.white),
              onPressed: () => _edit(),
              icon: const Icon(Icons.add),
              label: const Text('Anbar yarat'),
            ),
          ]),
          const SizedBox(height: 14),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _TableCard(
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Müəssisə')),
                        DataColumn(label: Text('Anbar')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Əməliyyat')),
                      ],
                      rows: _warehouses
                          .map((w) => DataRow(cells: [
                                DataCell(Text(companyNames[w.companyId] ?? '')),
                                DataCell(Text(w.name, style: const TextStyle(fontWeight: FontWeight.w700))),
                                DataCell(Text(w.isActive ? 'Aktiv' : 'Deaktiv')),
                                DataCell(IconButton(tooltip: 'Redaktə et', icon: const Icon(Icons.edit_outlined), onPressed: () => _edit(warehouse: w))),
                              ]))
                          .toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class InventoriesPage extends StatefulWidget {
  const InventoriesPage({super.key, required this.user});
  final AppUser user;

  @override
  State<InventoriesPage> createState() => _InventoriesPageState();
}

class _InventoriesPageState extends State<InventoriesPage> {
  List<InventoryHeader> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final data = await AppDatabase.instance.getInventories(companyId: widget.user.isAdmin ? null : widget.user.companyId);
    if (!mounted) return;
    setState(() {
      _items = data;
      _loading = false;
    });
  }

  Future<void> _create() async {
    final id = await showDialog<int>(context: context, builder: (_) => NewInventoryDialog(user: widget.user));
    if (id == null || !mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => InventoryCountPage(inventoryId: id)));
    await _reload();
  }

  Future<void> _open(int id) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => InventoryCountPage(inventoryId: id)));
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _Toolbar(children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _dark, foregroundColor: Colors.white),
              onPressed: _create,
              icon: const Icon(Icons.add_task),
              label: const Text('İnventarizasiya aç'),
            ),
          ]),
          const SizedBox(height: 14),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _TableCard(
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('#')),
                        DataColumn(label: Text('Tarix')),
                        DataColumn(label: Text('Müəssisə')),
                        DataColumn(label: Text('Anbar')),
                        DataColumn(label: Text('Məsul şəxs')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Əməliyyat')),
                      ],
                      rows: _items
                          .map((e) => DataRow(cells: [
                                DataCell(Text('${e.id}')),
                                DataCell(Text(e.inventoryDate)),
                                DataCell(Text(e.companyName ?? '')),
                                DataCell(Text(e.warehouseName ?? '')),
                                DataCell(Text(e.responsible)),
                                DataCell(_StatusChip(closed: e.isClosed)),
                                DataCell(TextButton.icon(onPressed: () => _open(e.id), icon: const Icon(Icons.open_in_new), label: Text(e.isClosed ? 'Bax' : 'Davam et'))),
                              ]))
                          .toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class NewInventoryDialog extends StatefulWidget {
  const NewInventoryDialog({super.key, required this.user});
  final AppUser user;

  @override
  State<NewInventoryDialog> createState() => _NewInventoryDialogState();
}

class _NewInventoryDialogState extends State<NewInventoryDialog> {
  List<Company> _companies = [];
  List<Warehouse> _warehouses = [];
  int? _companyId;
  int? _warehouseId;
  final _responsible = TextEditingController();
  DateTime _date = DateTime.now();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final companies = await AppDatabase.instance.getCompanies(onlyCompanyId: widget.user.isAdmin ? null : widget.user.companyId);
    final companyId = companies.isEmpty ? null : companies.first.id;
    final warehouses = companyId == null ? <Warehouse>[] : await AppDatabase.instance.getWarehouses(companyId: companyId);
    if (!mounted) return;
    setState(() {
      _companies = companies;
      _companyId = companyId;
      _warehouses = warehouses;
      _warehouseId = warehouses.isEmpty ? null : warehouses.first.id;
      _responsible.text = widget.user.fullName;
      _loading = false;
    });
  }

  Future<void> _companyChanged(int? id) async {
    final warehouses = id == null ? <Warehouse>[] : await AppDatabase.instance.getWarehouses(companyId: id);
    if (!mounted) return;
    setState(() {
      _companyId = id;
      _warehouses = warehouses;
      _warehouseId = warehouses.isEmpty ? null : warehouses.first.id;
    });
  }

  Future<void> _create() async {
    if (_companyId == null || _warehouseId == null || _responsible.text.trim().isEmpty) {
      _snack(context, 'Müəssisə, anbar və məsul şəxs seçilməlidir.');
      return;
    }
    final products = await AppDatabase.instance.getProducts(companyId: _companyId);
    if (products.isEmpty) {
      if (mounted) _snack(context, 'Bu müəssisədə məhsul yoxdur. Əvvəl məhsulları yarat/yüklə.');
      return;
    }
    final id = await AppDatabase.instance.createInventory(
      companyId: _companyId!,
      warehouseId: _warehouseId!,
      inventoryDate: _date.toIso8601String().substring(0, 10),
      responsible: _responsible.text,
      createdBy: widget.user.id,
    );
    if (mounted) Navigator.pop(context, id);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Yeni inventarizasiya'),
      content: SizedBox(
        width: 520,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    value: _companyId,
                    decoration: const InputDecoration(labelText: 'Müəssisə'),
                    items: _companies.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name))).toList(),
                    onChanged: _companyChanged,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    value: _warehouseId,
                    decoration: const InputDecoration(labelText: 'Anbar'),
                    items: _warehouses.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name))).toList(),
                    onChanged: (v) => setState(() => _warehouseId = v),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: _responsible, decoration: const InputDecoration(labelText: 'Məsul şəxs')),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: const Text('Tarix'),
                    subtitle: Text(_date.toIso8601String().substring(0, 10)),
                    trailing: const Icon(Icons.edit_calendar_outlined),
                    onTap: () async {
                      final picked = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: _date);
                      if (picked != null && mounted) setState(() => _date = picked);
                    },
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Ləğv et')),
        FilledButton(onPressed: _loading ? null : _create, child: const Text('Aç')),
      ],
    );
  }
}

class InventoryCountPage extends StatefulWidget {
  const InventoryCountPage({super.key, required this.inventoryId});
  final int inventoryId;

  @override
  State<InventoryCountPage> createState() => _InventoryCountPageState();
}

class _InventoryCountPageState extends State<InventoryCountPage> {
  final _db = AppDatabase.instance;
  final _excel = ExcelService(AppDatabase.instance);
  final _search = TextEditingController();
  InventoryHeader? _header;
  List<InventoryLineView> _lines = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final header = await _db.getInventory(widget.inventoryId);
    final lines = await _db.getInventoryLines(widget.inventoryId);
    if (!mounted) return;
    setState(() {
      _header = header;
      _lines = lines;
      _loading = false;
    });
  }

  Future<void> _setQty(InventoryLineView line, double qty) async {
    await _db.updateActualQty(line.lineId, qty);
    await _reload();
  }

  Future<void> _scan() async {
    final code = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const BarcodeScannerPage()));
    if (code == null || !mounted) return;
    InventoryLineView? found;
    for (final line in _lines) {
      if (line.barcode == code || line.code == code) {
        found = line;
        break;
      }
    }
    if (found == null) {
      _snack(context, 'Barkod bu inventarizasiyada tapılmadı: $code');
      return;
    }
    _search.text = found.productName;
    setState(() {});
    await _editQty(found);
  }

  Future<void> _editQty(InventoryLineView line) async {
    final controller = TextEditingController(text: line.actualQty == null ? '' : _num(line.actualQty!));
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(line.productName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sistem qalığı: ${_num(line.systemQty)} ${line.unit}'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Faktiki sayım (${line.unit})'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Ləğv et')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yadda saxla')),
        ],
      ),
    );
    if (ok == true) await _setQty(line, _parse(controller.text));
  }

  Future<void> _close() async {
    final missing = await _db.getMissingCount(widget.inventoryId);
    if (!mounted) return;
    if (missing > 0) {
      _snack(context, '$missing məhsul üzrə faktiki sayım daxil edilməyib.');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('İnventarizasiyanı bağla?'),
        content: const Text('Bağlandıqdan sonra faktiki sayımlar redaktə edilə bilməyəcək.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Xeyr')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Bəli, bağla')),
        ],
      ),
    );
    if (ok != true) return;
    await _db.closeInventory(widget.inventoryId);
    await _reload();
  }

  Future<void> _export(bool xlsx) async {
    if (_header == null) return;
    try {
      if (xlsx) {
        await _excel.exportInventoryXlsx(_header!, _lines);
      } else {
        await _excel.exportInventoryCsv(_header!, _lines);
      }
    } catch (e) {
      if (mounted) _snack(context, 'Export alınmadı: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _header == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final q = _search.text.trim().toLowerCase();
    final visible = q.isEmpty
        ? _lines
        : _lines.where((e) => '${e.code} ${e.productName} ${e.barcode ?? ''} ${e.subcategory}'.toLowerCase().contains(q)).toList();
    final grouped = <String, Map<String, List<InventoryLineView>>>{};
    for (final line in visible) {
      grouped.putIfAbsent(line.category, () => {});
      grouped[line.category]!.putIfAbsent(line.subcategory.isEmpty ? 'Digər' : line.subcategory, () => []).add(line);
    }
    final positive = _lines.where((e) => (e.differenceAmount ?? 0) > 0).fold<double>(0, (a, e) => a + (e.differenceAmount ?? 0));
    final negative = _lines.where((e) => (e.differenceAmount ?? 0) < 0).fold<double>(0, (a, e) => a + (e.differenceAmount ?? 0));
    final counted = _lines.where((e) => e.actualQty != null).length;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _dark,
        foregroundColor: Colors.white,
        title: Text('İnventarizasiya #${_header!.id} · ${_header!.warehouseName ?? ''}'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) => _export(value == 'xlsx'),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'xlsx', child: Text('Excel çıxar')),
              PopupMenuItem(value: 'csv', child: Text('CSV çıxar')),
            ],
            icon: const Icon(Icons.download_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _InfoPill(icon: Icons.business_outlined, text: _header!.companyName ?? ''),
                _InfoPill(icon: Icons.calendar_today_outlined, text: _header!.inventoryDate),
                _InfoPill(icon: Icons.person_outline, text: _header!.responsible),
                _InfoPill(icon: Icons.checklist, text: '$counted / ${_lines.length} sayılıb'),
                _InfoPill(icon: Icons.arrow_upward, text: 'Artıq: ${_money(positive)}', color: Colors.green.shade700),
                _InfoPill(icon: Icons.arrow_downward, text: 'Əskik: ${_money(negative)}', color: Colors.red.shade700),
                _StatusChip(closed: _header!.isClosed),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: _Toolbar(children: [
              SizedBox(
                width: 330,
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Kod, barkod və ya məhsul axtar'),
                ),
              ),
              OutlinedButton.icon(onPressed: _header!.isClosed ? null : _scan, icon: const Icon(Icons.qr_code_scanner), label: const Text('Barkod scan')),
              if (!_header!.isClosed)
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: _dark, foregroundColor: Colors.white),
                  onPressed: _close,
                  icon: const Icon(Icons.task_alt),
                  label: const Text('İnventarizasiyanı bağla'),
                ),
            ]),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(14),
              children: grouped.entries.map((category) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  clipBehavior: Clip.antiAlias,
                  child: ExpansionTile(
                    initiallyExpanded: true,
                    backgroundColor: Colors.white,
                    collapsedBackgroundColor: Colors.white,
                    leading: const CircleAvatar(backgroundColor: _yellow, child: Icon(Icons.inventory_2_outlined, color: _dark)),
                    title: Text(category.key, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                    subtitle: Text('${category.value.values.fold<int>(0, (a, b) => a + b.length)} məhsul'),
                    children: category.value.entries.map((sub) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Text(sub.key, style: const TextStyle(fontWeight: FontWeight.w700, color: _dark)),
                            ),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('Kod')),
                                  DataColumn(label: Text('Məhsul')),
                                  DataColumn(label: Text('Vahid')),
                                  DataColumn(label: Text('Sistem qalığı')),
                                  DataColumn(label: Text('Faktiki sayım')),
                                  DataColumn(label: Text('Fərq')),
                                  DataColumn(label: Text('Vahid qiyməti')),
                                  DataColumn(label: Text('Fərqin ₼ məbləği')),
                                ],
                                rows: sub.value.map((line) {
                                  final diff = line.difference ?? 0;
                                  final diffColor = diff < 0 ? Colors.red.shade700 : diff > 0 ? Colors.green.shade700 : Colors.grey.shade700;
                                  return DataRow(cells: [
                                    DataCell(Text(line.code, style: const TextStyle(fontWeight: FontWeight.w700))),
                                    DataCell(SizedBox(width: 200, child: Text(line.productName))),
                                    DataCell(Text(line.unit)),
                                    DataCell(Text(_num(line.systemQty))),
                                    DataCell(
                                      _header!.isClosed
                                          ? Text(line.actualQty == null ? '—' : _num(line.actualQty!))
                                          : _QtyField(
                                              key: ValueKey('${line.lineId}-${line.actualQty}'),
                                              initialValue: line.actualQty,
                                              onSave: (value) => _setQty(line, value),
                                            ),
                                    ),
                                    DataCell(Text(line.difference == null ? '—' : _num(line.difference!), style: TextStyle(fontWeight: FontWeight.w700, color: diffColor))),
                                    DataCell(Text('${_num(line.unitPrice)} ₼')),
                                    DataCell(Text(line.differenceAmount == null ? '—' : _money(line.differenceAmount!), style: TextStyle(fontWeight: FontWeight.w700, color: diffColor))),
                                  ]);
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyField extends StatefulWidget {
  const _QtyField({super.key, required this.initialValue, required this.onSave});
  final double? initialValue;
  final ValueChanged<double> onSave;

  @override
  State<_QtyField> createState() => _QtyFieldState();
}

class _QtyFieldState extends State<_QtyField> {
  late final TextEditingController _controller;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue == null ? '' : _num(widget.initialValue!));
    _focus.addListener(() {
      if (!_focus.hasFocus && _controller.text.trim().isNotEmpty) widget.onSave(_parse(_controller.text));
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 105,
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.right,
        decoration: const InputDecoration(isDense: true, hintText: '0'),
        onSubmitted: (value) {
          if (value.trim().isNotEmpty) widget.onSave(_parse(value));
        },
      ),
    );
  }
}

class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({super.key});

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  bool _returned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: _dark, foregroundColor: Colors.white, title: const Text('Barkod scan')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (_returned || capture.barcodes.isEmpty) return;
              final value = capture.barcodes.first.rawValue;
              if (value == null || value.isEmpty) return;
              _returned = true;
              Navigator.pop(context, value);
            },
          ),
          Center(
            child: Container(
              width: 280,
              height: 170,
              decoration: BoxDecoration(border: Border.all(color: _yellow, width: 3), borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }
}

class AdminPage extends StatelessWidget {
  const AdminPage({super.key, required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    if (!user.isAdmin) {
      return const Center(child: Text('Bu bölmə yalnız Admin üçündür.'));
    }
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Material(
            color: Colors.white,
            child: const TabBar(
              labelColor: _dark,
              indicatorColor: _yellow,
              tabs: [
                Tab(icon: Icon(Icons.business_outlined), text: 'Müəssisələr'),
                Tab(icon: Icon(Icons.group_outlined), text: 'İstifadəçilər'),
                Tab(icon: Icon(Icons.upload_file_outlined), text: 'Son qalıq yüklə'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                const CompaniesAdminTab(),
                const UsersAdminTab(),
                StockImportTab(user: user),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CompaniesAdminTab extends StatefulWidget {
  const CompaniesAdminTab({super.key});

  @override
  State<CompaniesAdminTab> createState() => _CompaniesAdminTabState();
}

class _CompaniesAdminTabState extends State<CompaniesAdminTab> {
  List<Company> _items = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final items = await AppDatabase.instance.getCompanies();
    if (mounted) setState(() => _items = items);
  }

  Future<void> _edit([Company? company]) async {
    final controller = TextEditingController(text: company?.name ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(company == null ? 'Müəssisə yarat' : 'Müəssisəni redaktə et'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'Müəssisənin adı')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Ləğv et')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yadda saxla')),
        ],
      ),
    );
    if (ok != true || controller.text.trim().isEmpty) return;
    try {
      if (company == null) {
        await AppDatabase.instance.createCompany(controller.text);
      } else {
        await AppDatabase.instance.updateCompany(company.id, controller.text);
      }
      await _reload();
    } catch (e) {
      if (mounted) _snack(context, 'Müəssisə saxlanmadı: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _Toolbar(children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _dark, foregroundColor: Colors.white),
              onPressed: () => _edit(),
              icon: const Icon(Icons.add_business),
              label: const Text('Müəssisə yarat'),
            ),
          ]),
          const SizedBox(height: 14),
          Expanded(
            child: _TableCard(
              child: DataTable(
                columns: const [DataColumn(label: Text('#')), DataColumn(label: Text('Müəssisə')), DataColumn(label: Text('Əməliyyat'))],
                rows: _items
                    .map((c) => DataRow(cells: [
                          DataCell(Text('${c.id}')),
                          DataCell(Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700))),
                          DataCell(IconButton(onPressed: () => _edit(c), icon: const Icon(Icons.edit_outlined))),
                        ]))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class UsersAdminTab extends StatefulWidget {
  const UsersAdminTab({super.key});

  @override
  State<UsersAdminTab> createState() => _UsersAdminTabState();
}

class _UsersAdminTabState extends State<UsersAdminTab> {
  List<AppUser> _users = [];
  List<Company> _companies = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final users = await AppDatabase.instance.getUsers();
    final companies = await AppDatabase.instance.getCompanies();
    if (!mounted) return;
    setState(() {
      _users = users;
      _companies = companies;
    });
  }

  Future<void> _create() async {
    if (_companies.isEmpty) {
      _snack(context, 'Əvvəl ən azı bir müəssisə yarat.');
      return;
    }
    final ok = await showDialog<bool>(context: context, builder: (_) => UserDialog(companies: _companies));
    if (ok == true) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final companyNames = {for (final c in _companies) c.id: c.name};
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _Toolbar(children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _dark, foregroundColor: Colors.white),
              onPressed: _create,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('İstifadəçi yarat'),
            ),
          ]),
          const SizedBox(height: 14),
          Expanded(
            child: _TableCard(
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Ad və soyad')),
                  DataColumn(label: Text('İstifadəçi adı')),
                  DataColumn(label: Text('Rol')),
                  DataColumn(label: Text('Təhkim olunan müəssisə')),
                  DataColumn(label: Text('Status')),
                ],
                rows: _users
                    .map((u) => DataRow(cells: [
                          DataCell(Text(u.fullName, style: const TextStyle(fontWeight: FontWeight.w700))),
                          DataCell(Text(u.username)),
                          DataCell(Text(u.isAdmin ? 'Admin' : 'İstifadəçi')),
                          DataCell(Text(u.companyId == null ? 'Bütün müəssisələr' : companyNames[u.companyId] ?? '—')),
                          DataCell(Text(u.isActive ? 'Aktiv' : 'Deaktiv')),
                        ]))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class UserDialog extends StatefulWidget {
  const UserDialog({super.key, required this.companies});
  final List<Company> companies;

  @override
  State<UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends State<UserDialog> {
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  String _role = 'user';
  int? _companyId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _companyId = widget.companies.first.id;
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _username.text.trim().isEmpty || _password.text.length < 4) {
      _snack(context, 'Bütün məcburi sahələri doldur. Şifrə minimum 4 simvol olsun.');
      return;
    }
    if (_role == 'user' && _companyId == null) {
      _snack(context, 'İstifadəçi üçün müəssisə seç.');
      return;
    }
    setState(() => _busy = true);
    try {
      await AppDatabase.instance.createUser(
        fullName: _name.text,
        username: _username.text,
        password: _password.text,
        role: _role,
        companyId: _role == 'admin' ? null : _companyId,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _snack(context, 'İstifadəçi yaradıla bilmədi: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('İstifadəçi yarat'),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Ad və soyad')),
            const SizedBox(height: 10),
            TextField(controller: _username, decoration: const InputDecoration(labelText: 'İstifadəçi adı')),
            const SizedBox(height: 10),
            TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Şifrə')),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _role,
              decoration: const InputDecoration(labelText: 'Rol'),
              items: const [
                DropdownMenuItem(value: 'user', child: Text('İstifadəçi')),
                DropdownMenuItem(value: 'admin', child: Text('Admin')),
              ],
              onChanged: (v) => setState(() => _role = v ?? 'user'),
            ),
            const SizedBox(height: 10),
            if (_role == 'user')
              DropdownButtonFormField<int>(
                value: _companyId,
                decoration: const InputDecoration(labelText: 'Müəssisə təhkim et'),
                items: widget.companies.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name))).toList(),
                onChanged: (v) => setState(() => _companyId = v),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Ləğv et')),
        FilledButton(onPressed: _busy ? null : _save, child: const Text('Yarat')),
      ],
    );
  }
}

class StockImportTab extends StatefulWidget {
  const StockImportTab({super.key, required this.user});
  final AppUser user;

  @override
  State<StockImportTab> createState() => _StockImportTabState();
}

class _StockImportTabState extends State<StockImportTab> {
  final _excel = ExcelService(AppDatabase.instance);
  List<Company> _companies = [];
  List<Warehouse> _warehouses = [];
  List<StockBalanceView> _balances = [];
  int? _companyId;
  int? _warehouseId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final companies = await AppDatabase.instance.getCompanies();
    final companyId = companies.isEmpty ? null : companies.first.id;
    final warehouses = companyId == null ? <Warehouse>[] : await AppDatabase.instance.getWarehouses(companyId: companyId);
    final warehouseId = warehouses.isEmpty ? null : warehouses.first.id;
    final balances = warehouseId == null ? <StockBalanceView>[] : await AppDatabase.instance.getStockBalances(warehouseId);
    if (!mounted) return;
    setState(() {
      _companies = companies;
      _companyId = companyId;
      _warehouses = warehouses;
      _warehouseId = warehouseId;
      _balances = balances;
    });
  }

  Future<void> _companyChanged(int? value) async {
    final warehouses = value == null ? <Warehouse>[] : await AppDatabase.instance.getWarehouses(companyId: value);
    final warehouseId = warehouses.isEmpty ? null : warehouses.first.id;
    final balances = warehouseId == null ? <StockBalanceView>[] : await AppDatabase.instance.getStockBalances(warehouseId);
    if (!mounted) return;
    setState(() {
      _companyId = value;
      _warehouses = warehouses;
      _warehouseId = warehouseId;
      _balances = balances;
    });
  }

  Future<void> _warehouseChanged(int? value) async {
    final balances = value == null ? <StockBalanceView>[] : await AppDatabase.instance.getStockBalances(value);
    if (!mounted) return;
    setState(() {
      _warehouseId = value;
      _balances = balances;
    });
  }

  Future<void> _import() async {
    if (_companyId == null || _warehouseId == null) {
      _snack(context, 'Müəssisə və anbar seç.');
      return;
    }
    setState(() => _busy = true);
    final result = await _excel.importStockBalances(companyId: _companyId!, warehouseId: _warehouseId!);
    if (!mounted) return;
    setState(() => _busy = false);
    if (result == null) return;
    await _showImportResult(context, 'Son anbar qalığı', result);
    await _warehouseChanged(_warehouseId);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Son anbar qalığını yüklə', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                  const SizedBox(height: 6),
                  Text('Excel/CSV sütunları: Məhsulun adı, Ölçü vahidi, Son qalıq, Cəmi qalıq məbləği. Kod sütunu varsa daha dəqiq uyğunlaşdırılır.', style: TextStyle(color: Colors.grey.shade700)),
                  const SizedBox(height: 14),
                  _Toolbar(children: [
                    SizedBox(
                      width: 240,
                      child: DropdownButtonFormField<int>(
                        value: _companyId,
                        decoration: const InputDecoration(labelText: 'Müəssisə'),
                        items: _companies.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name))).toList(),
                        onChanged: _companyChanged,
                      ),
                    ),
                    SizedBox(
                      width: 240,
                      child: DropdownButtonFormField<int>(
                        value: _warehouseId,
                        decoration: const InputDecoration(labelText: 'Anbar'),
                        items: _warehouses.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name))).toList(),
                        onChanged: _warehouseChanged,
                      ),
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: _dark, foregroundColor: Colors.white),
                      onPressed: _busy ? null : _import,
                      icon: const Icon(Icons.upload_file),
                      label: Text(_busy ? 'Yüklənir...' : 'Excel/CSV seç'),
                    ),
                  ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: _TableCard(
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Kod')),
                  DataColumn(label: Text('Məhsul')),
                  DataColumn(label: Text('Vahid')),
                  DataColumn(label: Text('Son qalıq')),
                  DataColumn(label: Text('Cəmi qalıq məbləği')),
                  DataColumn(label: Text('Yenilənmə')),
                ],
                rows: _balances
                    .map((b) => DataRow(cells: [
                          DataCell(Text(b.code)),
                          DataCell(Text(b.productName, style: const TextStyle(fontWeight: FontWeight.w700))),
                          DataCell(Text(b.unit)),
                          DataCell(Text(_num(b.quantity))),
                          DataCell(Text(_money(b.totalAmount))),
                          DataCell(Text(b.updatedAt.replaceFirst('T', ' ').split('.').first)),
                        ]))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: children);
  }
}

class _TableCard extends StatelessWidget {
  const _TableCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Scrollbar(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(child: child),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(children: [Icon(icon, color: _dark), const SizedBox(width: 8), Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))]);
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.closed});
  final bool closed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: closed ? Colors.green.shade50 : Colors.orange.shade50, borderRadius: BorderRadius.circular(20)),
      child: Text(closed ? 'Bağlı' : 'Davam edir', style: TextStyle(fontWeight: FontWeight.w700, color: closed ? Colors.green.shade800 : Colors.orange.shade800)),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.text, this.color});
  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(color: _page, border: Border.all(color: _line), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 17, color: color ?? _dark), const SizedBox(width: 6), Text(text, style: TextStyle(fontWeight: FontWeight.w600, color: color ?? _dark))]),
    );
  }
}

Future<void> _showImportResult(BuildContext context, String title, ImportResult result) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Yükləndi: ${result.imported}', style: const TextStyle(fontWeight: FontWeight.w800)),
            Text('Keçildi: ${result.skipped}'),
            if (result.messages.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Qeydlər:', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView(shrinkWrap: true, children: result.messages.map((e) => Text('• $e')).toList()),
              ),
            ],
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Bağla'))],
    ),
  );
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

double _parse(String value) => double.tryParse(value.trim().replaceAll(',', '.')) ?? 0;

String _num(double value) {
  final fixed = value.toStringAsFixed(3);
  return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
}

String _money(double value) => '${value.toStringAsFixed(2)} ₼';
