import 'package:flutter/material.dart';
import 'database.dart';
import 'models.dart';

const _navy = Color(0xFF071E26);
const _navy2 = Color(0xFF0D303A);
const _gold = Color(0xFFF2C14E);
const _bg = Color(0xFFF5F7F8);

class PremiumDashboardPage extends StatefulWidget {
  const PremiumDashboardPage({super.key, required this.user});
  final AppUser user;

  @override
  State<PremiumDashboardPage> createState() => _PremiumDashboardPageState();
}

class _PremiumDashboardPageState extends State<PremiumDashboardPage> {
  late Future<_DashboardData> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _future = _load();

  Future<_DashboardData> _load() async {
    final db = AppDatabase.instance;
    final companyId = widget.user.isAdmin ? null : widget.user.companyId;
    final stats = await db.getStats(companyId: companyId);
    final inventories = await db.getInventories(companyId: companyId);
    final companies = await db.getCompanies(onlyCompanyId: companyId);
    final warehouses = <_WarehouseTotal>[];
    double grandTotal = 0;
    double totalQty = 0;
    for (final company in companies) {
      final ws = await db.getWarehouses(companyId: company.id);
      for (final w in ws) {
        final balances = await db.getStockBalances(w.id);
        final amount = balances.fold<double>(0, (s, b) => s + b.totalAmount);
        final qty = balances.fold<double>(0, (s, b) => s + b.quantity);
        grandTotal += amount;
        totalQty += qty;
        warehouses.add(_WarehouseTotal(w.name, amount, qty));
      }
    }
    warehouses.sort((a, b) => b.amount.compareTo(a.amount));
    final pending = await db.pendingSyncCount();
    return _DashboardData(stats, inventories.take(5).toList(), warehouses, grandTotal, totalQty, pending);
  }

  String _money(double v) {
    final s = v.toStringAsFixed(2);
    final parts = s.split('.');
    final chars = parts[0].split('').reversed.toList();
    final out = <String>[];
    for (var i = 0; i < chars.length; i++) {
      if (i > 0 && i % 3 == 0) out.add(',');
      out.add(chars[i]);
    }
    return '${out.reversed.join()}.${parts[1]} ₼';
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _bg,
      child: FutureBuilder<_DashboardData>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: _gold));
          final d = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async { setState(_reload); await _future; },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_navy, _navy2]),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: _navy.withValues(alpha: .18), blurRadius: 24, offset: const Offset(0, 10))],
                  ),
                  child: const Row(children: [
                    CircleAvatar(radius: 25, backgroundColor: _gold, child: Icon(Icons.inventory_2_rounded, color: _navy, size: 29)),
                    SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Muno Inventory', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24)),
                      SizedBox(height: 3),
                      Text('Biznesiniz nəzarətinizdə', style: TextStyle(color: Color(0xFFB8C9CE), fontSize: 14)),
                    ])),
                  ]),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(builder: (context, c) {
                  final w = c.maxWidth > 700 ? (c.maxWidth - 36) / 4 : (c.maxWidth - 12) / 2;
                  return Wrap(spacing: 12, runSpacing: 12, children: [
                    _Metric(width: w, icon: Icons.apartment_rounded, label: 'Müəssisələr', value: '${d.stats.companies}', tint: const Color(0xFFFFF7E2), iconColor: const Color(0xFFA87800)),
                    _Metric(width: w, icon: Icons.warehouse_rounded, label: 'Anbarlar', value: '${d.stats.warehouses}', tint: const Color(0xFFEAF3FF), iconColor: const Color(0xFF1769AA)),
                    _Metric(width: w, icon: Icons.inventory_2_rounded, label: 'Məhsullar', value: '${d.stats.products}', tint: const Color(0xFFEAF8F0), iconColor: const Color(0xFF14804A)),
                    _Metric(width: w, icon: Icons.fact_check_rounded, label: 'Aktiv sayımlar', value: '${d.stats.openInventories}', tint: const Color(0xFFFFEEEE), iconColor: const Color(0xFFB42318)),
                  ]);
                }),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(color: _navy, borderRadius: BorderRadius.circular(24)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('ÜMUMİ ANBAR QALIĞI', style: TextStyle(color: Color(0xFFAFC1C6), fontWeight: FontWeight.w700, letterSpacing: .8, fontSize: 12)),
                    const SizedBox(height: 8),
                    Text(_money(d.grandTotal), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 34)),
                    const SizedBox(height: 20),
                    Row(children: [
                      Expanded(child: _DarkMini(icon: Icons.widgets_rounded, label: 'Ümumi məhsul', value: '${d.stats.products}')),
                      const SizedBox(width: 10),
                      Expanded(child: _DarkMini(icon: Icons.scale_rounded, label: 'Qalıq miqdarı', value: d.totalQty.toStringAsFixed(1))),
                    ]),
                  ]),
                ),
                const SizedBox(height: 18),
                const _Title('Anbarlar üzrə qalıq'),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFE7ECEE))),
                  child: d.warehouses.isEmpty
                    ? const Padding(padding: EdgeInsets.all(14), child: Text('Anbar qalığı yüklənməyib.'))
                    : Column(children: d.warehouses.take(6).map((w) {
                        final ratio = d.grandTotal <= 0 ? 0.0 : (w.amount / d.grandTotal).clamp(0.0, 1.0);
                        return Padding(padding: const EdgeInsets.symmetric(vertical: 9), child: Row(children: [
                          const CircleAvatar(radius: 19, backgroundColor: Color(0xFFEAF3FF), child: Icon(Icons.warehouse_outlined, size: 19, color: Color(0xFF1769AA))),
                          const SizedBox(width: 11),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [Expanded(child: Text(w.name, style: const TextStyle(fontWeight: FontWeight.w700))), Text(_money(w.amount), style: const TextStyle(fontWeight: FontWeight.w800))]),
                            const SizedBox(height: 7),
                            ClipRRect(borderRadius: BorderRadius.circular(9), child: LinearProgressIndicator(value: ratio, minHeight: 7, backgroundColor: const Color(0xFFEDF1F2), valueColor: const AlwaysStoppedAnimation(_gold))),
                          ])),
                        ]));
                      }).toList()),
                ),
                const SizedBox(height: 18),
                const _Title('Son inventarizasiyalar'),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFE7ECEE))),
                  child: d.recent.isEmpty ? const Padding(padding: EdgeInsets.all(20), child: Text('Hələ inventarizasiya yoxdur.')) : Column(
                    children: d.recent.map((e) => ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                      leading: CircleAvatar(backgroundColor: e.isClosed ? const Color(0xFFE7F7EE) : const Color(0xFFFFF4E5), child: Icon(e.isClosed ? Icons.check_rounded : Icons.schedule_rounded, color: e.isClosed ? const Color(0xFF16834B) : const Color(0xFFC77800))),
                      title: Text(e.warehouseName ?? 'Anbar', style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text('${e.inventoryDate} · ${e.responsible}'),
                      trailing: Text(e.isClosed ? 'Tamamlandı' : 'Davam edir', style: TextStyle(fontWeight: FontWeight.w700, color: e.isClosed ? const Color(0xFF16834B) : const Color(0xFFC77800))),
                    )).toList(),
                  ),
                ),
                if (d.pending > 0) ...[
                  const SizedBox(height: 14),
                  Row(children: [const Icon(Icons.cloud_off_rounded, size: 18, color: Color(0xFF6B7B80)), const SizedBox(width: 7), Text('${d.pending} dəyişiklik lokal sinxronizasiya növbəsindədir.', style: const TextStyle(color: Color(0xFF6B7B80)))])
                ]
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.width, required this.icon, required this.label, required this.value, required this.tint, required this.iconColor});
  final double width; final IconData icon; final String label; final String value; final Color tint; final Color iconColor;
  @override Widget build(BuildContext context) => Container(width: width, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(20), border: Border.all(color: iconColor.withValues(alpha: .12))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: iconColor, size: 25), const SizedBox(height: 13), Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)), const SizedBox(height: 4), Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 27, color: _navy))]));
}
class _DarkMini extends StatelessWidget { const _DarkMini({required this.icon, required this.label, required this.value}); final IconData icon; final String label; final String value; @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .07), borderRadius: BorderRadius.circular(15)), child: Row(children: [Icon(icon, color: _gold), const SizedBox(width: 9), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Color(0xFFAFC1C6), fontSize: 11)), Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17))]))])); }
class _Title extends StatelessWidget { const _Title(this.text); final String text; @override Widget build(BuildContext context) => Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _navy)); }
class _WarehouseTotal { const _WarehouseTotal(this.name, this.amount, this.qty); final String name; final double amount; final double qty; }
class _DashboardData { const _DashboardData(this.stats, this.recent, this.warehouses, this.grandTotal, this.totalQty, this.pending); final DashboardStats stats; final List<InventoryHeader> recent; final List<_WarehouseTotal> warehouses; final double grandTotal; final double totalQty; final int pending; }
