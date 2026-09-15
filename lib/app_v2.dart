import 'package:flutter/material.dart';
import 'database.dart';
import 'models.dart';

const _navy = Color(0xFF071D26);
const _gold = Color(0xFFF4C451);
const _bg = Color(0xFFF4F6F7);

String _n(num v) => v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(2);

class InventoriesV2Page extends StatefulWidget {
  const InventoriesV2Page({super.key, required this.user});
  final AppUser user;
  @override
  State<InventoriesV2Page> createState() => _InventoriesV2PageState();
}

class _InventoriesV2PageState extends State<InventoriesV2Page> {
  List<InventoryHeader> items = [];
  bool loading = true;

  @override
  void initState() { super.initState(); reload(); }

  Future<void> reload() async {
    final db = await AppDatabase.instance.database;
    final where = widget.user.isAdmin ? '' : 'WHERE i.created_by = ?';
    final args = widget.user.isAdmin ? <Object?>[] : <Object?>[widget.user.id];
    final rows = await db.rawQuery('''
      SELECT i.*, c.name company_name, w.name warehouse_name
      FROM inventories i JOIN companies c ON c.id=i.company_id
      JOIN warehouses w ON w.id=i.warehouse_id
      $where ORDER BY i.inventory_date DESC, i.id DESC
    ''', args);
    if (!mounted) return;
    setState(() { items = rows.map(InventoryHeader.fromMap).toList(); loading = false; });
  }

  Future<void> createInventory() async {
    final id = await showDialog<int>(context: context, builder: (_) => _NewInventoryV2(user: widget.user));
    if (id == null || !mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => InventoryCountV2Page(inventoryId: id, user: widget.user)));
    reload();
  }

  Future<void> openInventory(InventoryHeader h) async {
    if (!widget.user.isAdmin && h.createdBy != widget.user.id) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => InventoryCountV2Page(inventoryId: h.id, user: widget.user)));
    reload();
  }

  Future<void> deleteInventory(InventoryHeader h) async {
    if (!widget.user.isAdmin) return;
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Sənədi sil?'),
      content: Text('İnventarizasiya #${h.id} tam silinəcək.'),
      actions: [TextButton(onPressed: ()=>Navigator.pop(context,false), child: const Text('Xeyr')), FilledButton(onPressed: ()=>Navigator.pop(context,true), child: const Text('Sil'))],
    ));
    if (ok != true) return;
    final db = await AppDatabase.instance.database;
    await db.delete('inventories', where:'id=?', whereArgs:[h.id]);
    reload();
  }

  @override
  Widget build(BuildContext context) {
    return Container(color: _bg, padding: const EdgeInsets.all(14), child: Column(children:[
      Row(children:[
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
          const Text('İnventarizasiya', style: TextStyle(fontSize:22,fontWeight:FontWeight.w800,color:_navy)),
          Text(widget.user.isAdmin ? 'Bütün sənədlər' : 'Yalnız sizin yaratdığınız sənədlər', style: const TextStyle(color:Colors.black54)),
        ])),
        FilledButton.icon(style:FilledButton.styleFrom(backgroundColor:_navy,foregroundColor:Colors.white), onPressed:createInventory, icon:const Icon(Icons.add), label:const Text('Yeni sayım')),
      ]),
      const SizedBox(height:12),
      Expanded(child: loading ? const Center(child:CircularProgressIndicator()) : ListView.separated(
        itemCount: items.length, separatorBuilder:(_,__)=>const SizedBox(height:8), itemBuilder:(context,i){
          final h=items[i];
          return Card(elevation:0, child: ListTile(
            dense:true,
            leading: CircleAvatar(backgroundColor:_gold, foregroundColor:_navy, child:Text('${i+1}',style:const TextStyle(fontWeight:FontWeight.w800))),
            title: Text('${h.warehouseName ?? ''} · ${h.inventoryDate}',style:const TextStyle(fontWeight:FontWeight.w700)),
            subtitle: Text('${h.companyName ?? ''}  •  ${h.responsible}  •  ${h.isClosed ? 'Bağlı' : 'Açıq'}'),
            trailing: Row(mainAxisSize:MainAxisSize.min,children:[
              IconButton(icon:const Icon(Icons.chevron_right),onPressed:()=>openInventory(h)),
              if(widget.user.isAdmin) IconButton(tooltip:'Sənədi sil',icon:const Icon(Icons.delete_outline,color:Colors.red),onPressed:()=>deleteInventory(h)),
            ]),
            onTap:()=>openInventory(h),
          ));
        },
      )),
    ]));
  }
}

class _NewInventoryV2 extends StatefulWidget {
  const _NewInventoryV2({required this.user});
  final AppUser user;
  @override State<_NewInventoryV2> createState()=>_NewInventoryV2State();
}
class _NewInventoryV2State extends State<_NewInventoryV2>{
  List<Company> companies=[]; List<Warehouse> warehouses=[]; int? companyId; int? warehouseId; DateTime date=DateTime.now(); bool loading=true;
  final responsible=TextEditingController();
  @override void initState(){super.initState();init();}
  Future<void> init() async{
    companies=await AppDatabase.instance.getCompanies(onlyCompanyId:widget.user.isAdmin?null:widget.user.companyId);
    companyId=companies.isEmpty?null:companies.first.id;
    warehouses=companyId==null?[]:await AppDatabase.instance.getWarehouses(companyId:companyId);
    warehouseId=warehouses.isEmpty?null:warehouses.first.id; responsible.text=widget.user.fullName;
    if(mounted)setState(()=>loading=false);
  }
  Future<void> companyChanged(int? id) async{warehouses=id==null?[]:await AppDatabase.instance.getWarehouses(companyId:id);setState((){companyId=id;warehouseId=warehouses.isEmpty?null:warehouses.first.id;});}
  Future<void> save() async{
    if(companyId==null||warehouseId==null)return;
    final id=await AppDatabase.instance.createInventory(companyId:companyId!,warehouseId:warehouseId!,inventoryDate:date.toIso8601String().substring(0,10),responsible:responsible.text.trim().isEmpty?widget.user.fullName:responsible.text,createdBy:widget.user.id);
    if(mounted)Navigator.pop(context,id);
  }
  @override Widget build(BuildContext context)=>AlertDialog(
    title:const Text('Yeni inventarizasiya'),
    content:SizedBox(width:480,child:loading?const Center(child:CircularProgressIndicator()):SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
      DropdownButtonFormField<int>(value:companyId,decoration:const InputDecoration(labelText:'Müəssisə'),items:companies.map((e)=>DropdownMenuItem(value:e.id,child:Text(e.name))).toList(),onChanged:widget.user.isAdmin?companyChanged:null),
      const SizedBox(height:10),
      DropdownButtonFormField<int>(value:warehouseId,decoration:const InputDecoration(labelText:'Anbar'),items:warehouses.map((e)=>DropdownMenuItem(value:e.id,child:Text(e.name))).toList(),onChanged:(v)=>setState(()=>warehouseId=v)),
      const SizedBox(height:10),TextField(controller:responsible,decoration:const InputDecoration(labelText:'Məsul şəxs')),
      const SizedBox(height:6),ListTile(contentPadding:EdgeInsets.zero,title:const Text('Tarix'),subtitle:Text(date.toIso8601String().substring(0,10)),trailing:const Icon(Icons.calendar_month),onTap:()async{final d=await showDatePicker(context:context,firstDate:DateTime(2020),lastDate:DateTime(2100),initialDate:date);if(d!=null)setState(()=>date=d);}),
    ]))),
    actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Ləğv et')),FilledButton(onPressed:loading?null:save,child:const Text('Aç'))],
  );
}

class InventoryCountV2Page extends StatefulWidget{
  const InventoryCountV2Page({super.key,required this.inventoryId,required this.user});
  final int inventoryId; final AppUser user;
  @override State<InventoryCountV2Page> createState()=>_InventoryCountV2PageState();
}
class _InventoryCountV2PageState extends State<InventoryCountV2Page>{
  InventoryHeader? header; List<InventoryLineView> lines=[]; bool loading=true; final search=TextEditingController();
  @override void initState(){super.initState();reload();}
  Future<void> reload()async{header=await AppDatabase.instance.getInventory(widget.inventoryId);if(!widget.user.isAdmin&&header!.createdBy!=widget.user.id){if(mounted)Navigator.pop(context);return;}lines=await AppDatabase.instance.getInventoryLines(widget.inventoryId);if(mounted)setState(()=>loading=false);}
  Future<void> setQty(InventoryLineView l,double q)async{await AppDatabase.instance.updateActualQty(l.lineId,q);await reload();}
  Future<void> removeLine(InventoryLineView l)async{if(header!.isClosed)return;final db=await AppDatabase.instance.database;await db.delete('inventory_lines',where:'id=?',whereArgs:[l.lineId]);await reload();}
  Future<void> close()async{
    final db=await AppDatabase.instance.database;
    await db.transaction((txn)async{
      await txn.rawUpdate('''UPDATE inventory_lines SET actual_qty=0, difference=0-system_qty, difference_amount=(0-system_qty)*unit_price WHERE inventory_id=? AND actual_qty IS NULL''',[widget.inventoryId]);
      await txn.update('inventories',{'status':'closed','closed_at':DateTime.now().toIso8601String()},where:'id=?',whereArgs:[widget.inventoryId]);
    });
    await reload();
  }
  @override Widget build(BuildContext context){
    if(loading||header==null)return const Scaffold(body:Center(child:CircularProgressIndicator()));
    final q=search.text.trim().toLowerCase(); final visible=lines.where((e)=>q.isEmpty||e.productName.toLowerCase().contains(q)).toList();
    return Scaffold(resizeToAvoidBottomInset:true,backgroundColor:_bg,appBar:AppBar(backgroundColor:_navy,foregroundColor:Colors.white,title:Text('${header!.warehouseName ?? ''} · ${header!.inventoryDate}',style:const TextStyle(fontSize:16,fontWeight:FontWeight.w700))),body:Column(children:[
      Padding(padding:const EdgeInsets.fromLTRB(10,10,10,6),child:Row(children:[
        Expanded(child:TextField(controller:search,onChanged:(_)=>setState((){}),decoration:const InputDecoration(isDense:true,prefixIcon:Icon(Icons.search),hintText:'Məhsul axtar'))),
        const SizedBox(width:8),if(!header!.isClosed)FilledButton.icon(style:FilledButton.styleFrom(backgroundColor:_navy,foregroundColor:Colors.white),onPressed:close,icon:const Icon(Icons.save,size:18),label:const Text('Yadda saxla')),
      ])),
      Padding(padding:const EdgeInsets.symmetric(horizontal:12,vertical:4),child:Row(children:[Expanded(flex:5,child:Text(header!.isClosed?'Nəticələr':'Məhsul',style:const TextStyle(fontSize:12,fontWeight:FontWeight.w800))),const Expanded(flex:2,child:Text('Vahid',style:TextStyle(fontSize:11,fontWeight:FontWeight.w700))),const Expanded(flex:2,child:Text('Sistem',textAlign:TextAlign.right,style:TextStyle(fontSize:11,fontWeight:FontWeight.w700))),Expanded(flex:3,child:Text(header!.isClosed?'Fakt / Fərq':'Faktiki',textAlign:TextAlign.right,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w700))),const SizedBox(width:38)])),
      Expanded(child:ListView.builder(padding:EdgeInsets.fromLTRB(8,2,8,MediaQuery.viewInsetsOf(context).bottom+100),itemCount:visible.length,itemBuilder:(context,i){final l=visible[i];return _CountRow(index:i+1,line:l,closed:header!.isClosed,onSave:(v)=>setQty(l,v),onDelete:()=>removeLine(l));})),
    ]));
  }
}

class _CountRow extends StatefulWidget{
  const _CountRow({required this.index,required this.line,required this.closed,required this.onSave,required this.onDelete});
  final int index;final InventoryLineView line;final bool closed;final ValueChanged<double> onSave;final VoidCallback onDelete;
  @override State<_CountRow> createState()=>_CountRowState();
}
class _CountRowState extends State<_CountRow>{
  late final TextEditingController c; final focus=FocusNode();
  @override void initState(){super.initState();c=TextEditingController(text:widget.line.actualQty==null?'':_n(widget.line.actualQty!));}
  @override void dispose(){c.dispose();focus.dispose();super.dispose();}
  void save(String s){final t=s.trim().replaceAll(',','.');widget.onSave(double.tryParse(t)??0);}
  @override Widget build(BuildContext context){final l=widget.line;final diff=l.difference??0;return Container(margin:const EdgeInsets.only(bottom:3),padding:const EdgeInsets.symmetric(horizontal:6,vertical:3),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(8),border:Border.all(color:Colors.black12)),child:Row(children:[
    Expanded(flex:5,child:Text('${widget.index}. ${l.productName}',maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w600,height:1.1))),
    Expanded(flex:2,child:Text(l.unit,style:const TextStyle(fontSize:11,color:Colors.black54))),
    Expanded(flex:2,child:Text(_n(l.systemQty),textAlign:TextAlign.right,style:const TextStyle(fontSize:12))),
    const SizedBox(width:5),
    Expanded(flex:3,child:widget.closed?Column(crossAxisAlignment:CrossAxisAlignment.end,children:[Text(_n(l.actualQty??0),style:const TextStyle(fontSize:12,fontWeight:FontWeight.w700)),Text('Fərq ${diff>0?'+':''}${_n(diff)}',style:TextStyle(fontSize:10,color:diff<0?Colors.red:diff>0?Colors.green:Colors.black45))]):TextField(controller:c,focusNode:focus,keyboardType:const TextInputType.numberWithOptions(decimal:true),textAlign:TextAlign.right,style:const TextStyle(fontSize:13,fontWeight:FontWeight.w700),decoration:const InputDecoration(isDense:true,contentPadding:EdgeInsets.symmetric(horizontal:7,vertical:7),hintText:'0'),onSubmitted:save,onTapOutside:(_){if(c.text.trim().isNotEmpty)save(c.text);focus.unfocus();})),
    SizedBox(width:38,child:widget.closed?const SizedBox():IconButton(padding:EdgeInsets.zero,visualDensity:VisualDensity.compact,tooltip:'Sətrdən sil',icon:const Icon(Icons.close,size:18,color:Colors.redAccent),onPressed:widget.onDelete)),
  ]));}
}

class ProductsV2Page extends StatefulWidget{
  const ProductsV2Page({super.key,required this.user});final AppUser user;
  @override State<ProductsV2Page> createState()=>_ProductsV2PageState();
}
class _ProductsV2PageState extends State<ProductsV2Page>{
  List<Company> companies=[];List<Product> products=[];int? companyId;final search=TextEditingController();
  @override void initState(){super.initState();reload();}
  Future<void> reload()async{companies=await AppDatabase.instance.getCompanies(onlyCompanyId:widget.user.isAdmin?null:widget.user.companyId);companyId=(companyId!=null&&companies.any((e)=>e.id==companyId))?companyId:(companies.isEmpty?null:companies.first.id);products=companyId==null?[]:await AppDatabase.instance.getProducts(companyId:companyId);if(mounted)setState((){});}
  Future<void> add()async{if(companyId==null)return;final ok=await showDialog<bool>(context:context,builder:(_)=>_ProductV2Dialog(companyId:companyId!));if(ok==true)reload();}
  Future<void> del(Product p)async{if(!widget.user.isAdmin)return;final db=await AppDatabase.instance.database;try{await db.delete('products',where:'id=?',whereArgs:[p.id]);await reload();}catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Bu məhsul sənədlərdə istifadə olunduğu üçün silinmədi.')));}}
  @override Widget build(BuildContext context){final q=search.text.toLowerCase();final v=products.where((p)=>q.isEmpty||p.name.toLowerCase().contains(q)).toList();return Container(color:_bg,padding:const EdgeInsets.all(14),child:Column(children:[Row(children:[if(widget.user.isAdmin)SizedBox(width:220,child:DropdownButtonFormField<int>(value:companyId,decoration:const InputDecoration(isDense:true,labelText:'Müəssisə'),items:companies.map((e)=>DropdownMenuItem(value:e.id,child:Text(e.name))).toList(),onChanged:(x){companyId=x;reload();})),if(widget.user.isAdmin)const SizedBox(width:8),Expanded(child:TextField(controller:search,onChanged:(_)=>setState((){}),decoration:const InputDecoration(isDense:true,prefixIcon:Icon(Icons.search),hintText:'Məhsul axtar'))),const SizedBox(width:8),FilledButton.icon(style:FilledButton.styleFrom(backgroundColor:_navy,foregroundColor:Colors.white),onPressed:add,icon:const Icon(Icons.add),label:const Text('Məhsul yarat'))]),const SizedBox(height:10),Expanded(child:ListView.separated(itemCount:v.length,separatorBuilder:(_,__)=>const Divider(height:1),itemBuilder:(context,i){final p=v[i];return ListTile(dense:true,leading:Text('${i+1}.',style:const TextStyle(fontWeight:FontWeight.w800)),title:Text(p.name,style:const TextStyle(fontWeight:FontWeight.w700)),subtitle:Text('${p.category}${p.subcategory.isEmpty?'':' · ${p.subcategory}'} · ${p.unit} · ${_n(p.unitPrice)} ₼'),trailing:widget.user.isAdmin?IconButton(icon:const Icon(Icons.delete_outline,color:Colors.red),onPressed:()=>del(p)):null);}))]));}
}

class _ProductV2Dialog extends StatefulWidget{const _ProductV2Dialog({required this.companyId});final int companyId;@override State<_ProductV2Dialog> createState()=>_ProductV2DialogState();}
class _ProductV2DialogState extends State<_ProductV2Dialog>{final name=TextEditingController(),code=TextEditingController(),sub=TextEditingController(),price=TextEditingController();String cat='Mal',unit='ədəd';Future<void> save()async{if(name.text.trim().isEmpty)return;final finalCode=code.text.trim().isEmpty?'P${DateTime.now().millisecondsSinceEpoch}':code.text.trim();await AppDatabase.instance.upsertProduct(companyId:widget.companyId,category:cat,subcategory:sub.text,code:finalCode,name:name.text,unit:unit,unitPrice:double.tryParse(price.text.replaceAll(',','.'))??0);if(mounted)Navigator.pop(context,true);}@override Widget build(BuildContext context)=>AlertDialog(title:const Text('Məhsul yarat'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:name,decoration:const InputDecoration(labelText:'Məhsulun adı')),const SizedBox(height:8),TextField(controller:sub,decoration:const InputDecoration(labelText:'Alt kateqoriya')),const SizedBox(height:8),DropdownButtonFormField(value:cat,decoration:const InputDecoration(labelText:'Kateqoriya'),items:['Mal','Məhsul','Yarımfabrikat'].map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(),onChanged:(v)=>setState(()=>cat=v??'Mal')),const SizedBox(height:8),DropdownButtonFormField(value:unit,decoration:const InputDecoration(labelText:'Vahid'),items:['ədəd','pors','kq','qr','litr','ml','qutu','paket'].map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(),onChanged:(v)=>setState(()=>unit=v??'ədəd')),const SizedBox(height:8),TextField(controller:price,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Vahid qiyməti ₼')),const SizedBox(height:8),TextField(controller:code,decoration:const InputDecoration(labelText:'Kod (boş qala bilər)'))])),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Ləğv et')),FilledButton(onPressed:save,child:const Text('Yadda saxla'))]);}

class WarehousesV2Page extends StatefulWidget{const WarehousesV2Page({super.key,required this.user});final AppUser user;@override State<WarehousesV2Page> createState()=>_WarehousesV2PageState();}
class _WarehousesV2PageState extends State<WarehousesV2Page>{List<Company> companies=[];List<Warehouse> warehouses=[];int? companyId;@override void initState(){super.initState();reload();}Future<void> reload()async{companies=await AppDatabase.instance.getCompanies(onlyCompanyId:widget.user.isAdmin?null:widget.user.companyId);companyId=(companyId!=null&&companies.any((e)=>e.id==companyId))?companyId:(companies.isEmpty?null:companies.first.id);warehouses=companyId==null?[]:await AppDatabase.instance.getWarehouses(companyId:companyId);if(mounted)setState((){});}Future<void> add()async{if(!widget.user.isAdmin||companyId==null)return;final c=TextEditingController();final ok=await showDialog<bool>(context:context,builder:(_)=>AlertDialog(title:const Text('Anbar yarat'),content:TextField(controller:c,autofocus:true,decoration:const InputDecoration(labelText:'Anbarın adı')),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Ləğv et')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('Yadda saxla'))]));if(ok==true&&c.text.trim().isNotEmpty){await AppDatabase.instance.createWarehouse(companyId!,c.text);reload();}}@override Widget build(BuildContext context)=>Container(color:_bg,padding:const EdgeInsets.all(14),child:Column(children:[Row(children:[if(widget.user.isAdmin)Expanded(child:DropdownButtonFormField<int>(value:companyId,decoration:const InputDecoration(labelText:'Müəssisə'),items:companies.map((e)=>DropdownMenuItem(value:e.id,child:Text(e.name))).toList(),onChanged:(v){companyId=v;reload();})),if(widget.user.isAdmin)const SizedBox(width:8),if(widget.user.isAdmin)FilledButton.icon(style:FilledButton.styleFrom(backgroundColor:_navy,foregroundColor:Colors.white),onPressed:add,icon:const Icon(Icons.add),label:const Text('Anbar yarat'))]),const SizedBox(height:10),Expanded(child:ListView.separated(itemCount:warehouses.length,separatorBuilder:(_,__)=>const Divider(height:1),itemBuilder:(context,i)=>ListTile(dense:true,leading:Text('${i+1}.',style:const TextStyle(fontWeight:FontWeight.w800)),title:Text(warehouses[i].name,style:const TextStyle(fontWeight:FontWeight.w700)),subtitle:Text(warehouses[i].isActive?'Aktiv':'Deaktiv'))))]));}
