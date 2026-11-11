import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../core/util.dart';

/// Port of report-docx.js: a real, editable Word (.docx) file.
/// Teal triple page border, SpeechCare ribbon header, footer with page numbers,
/// RTL aware for Arabic/Darija, signature block = the Mebarki / SpeechCare logo + therapist details.
const String _teal = '0F7A72', _purple = '5B3F8C', _gold = 'C9A24A', _ink = '17262B';

class DocxData {
  final bool rtl;
  final String title, patient, age, meta, pageWord, dateLine, file;
  final List<Map<String, String>> sections;
  final Map<String, String> me;
  DocxData({required this.rtl, required this.title, required this.patient, required this.age, required this.meta, required this.sections, required this.me, required this.pageWord, required this.dateLine, required this.file});
}

// ------------------------------------------------------------ zip (store only)
final List<int> _crcTable = () {
  final t = List<int>.filled(256, 0);
  for (var n = 0; n < 256; n++) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1);
    }
    t[n] = c & 0xFFFFFFFF;
  }
  return t;
}();

int _crc32(List<int> b) {
  var c = 0xFFFFFFFF;
  for (final x in b) {
    c = _crcTable[(c ^ x) & 255] ^ (c >> 8);
  }
  return (c ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}

class _F {
  final String name;
  final List<int> data;
  _F(this.name, this.data);
}

Uint8List _zip(List<_F> files) {
  final d = DateTime.now();
  final time = (d.hour << 11) | (d.minute << 5) | (d.second >> 1);
  final date = ((d.year - 1980) << 9) | (d.month << 5) | d.day;
  final out = BytesBuilder();
  final central = BytesBuilder();
  var off = 0;
  for (final f in files) {
    final name = utf8.encode(f.name);
    final data = f.data;
    final crc = _crc32(data);
    final lh = ByteData(30);
    lh.setUint32(0, 0x04034b50, Endian.little);
    lh.setUint16(4, 20, Endian.little);
    lh.setUint16(6, 0x0800, Endian.little);
    lh.setUint16(8, 0, Endian.little);
    lh.setUint16(10, time, Endian.little);
    lh.setUint16(12, date, Endian.little);
    lh.setUint32(14, crc, Endian.little);
    lh.setUint32(18, data.length, Endian.little);
    lh.setUint32(22, data.length, Endian.little);
    lh.setUint16(26, name.length, Endian.little);
    lh.setUint16(28, 0, Endian.little);
    out.add(lh.buffer.asUint8List());
    out.add(name);
    out.add(data);
    final ch = ByteData(46);
    ch.setUint32(0, 0x02014b50, Endian.little);
    ch.setUint16(4, 20, Endian.little);
    ch.setUint16(6, 20, Endian.little);
    ch.setUint16(8, 0x0800, Endian.little);
    ch.setUint16(10, 0, Endian.little);
    ch.setUint16(12, time, Endian.little);
    ch.setUint16(14, date, Endian.little);
    ch.setUint32(16, crc, Endian.little);
    ch.setUint32(20, data.length, Endian.little);
    ch.setUint32(24, data.length, Endian.little);
    ch.setUint16(28, name.length, Endian.little);
    ch.setUint32(42, off, Endian.little);
    central.add(ch.buffer.asUint8List());
    central.add(name);
    off += 30 + name.length + data.length;
  }
  final cbytes = central.toBytes();
  final end = ByteData(22);
  end.setUint32(0, 0x06054b50, Endian.little);
  end.setUint16(8, files.length, Endian.little);
  end.setUint16(10, files.length, Endian.little);
  end.setUint32(12, cbytes.length, Endian.little);
  end.setUint32(16, off, Endian.little);
  out.add(cbytes);
  out.add(end.buffer.asUint8List());
  return out.toBytes();
}

// ---------------------------------------------------------------- xml helpers
String _x(dynamic s) {
  var t = str(s).replaceAll(RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F]'), '');
  return t.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
}

bool _isAr(String t) {
  final a = RegExp(r'[\u0600-\u06FF\u0750-\u077F]').allMatches(t).length;
  final l = RegExp(r'[A-Za-zÀ-ÿ]').allMatches(t).length;
  return a > l;
}

String _run(String text, {bool b = false, bool i = false, String color = _ink, int sz = 22, bool rtl = false}) {
  final rp = '<w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Arial"/>${b ? '<w:b/><w:bCs/>' : ''}${i ? '<w:i/><w:iCs/>' : ''}<w:color w:val="$color"/><w:sz w:val="$sz"/><w:szCs w:val="$sz"/>${rtl ? '<w:rtl/>' : ''}';
  return '<w:r><w:rPr>$rp</w:rPr><w:t xml:space="preserve">${_x(text)}</w:t></w:r>';
}

String _para(String runs, {bool keep = false, String pBdr = '', String shd = '', bool rtl = false, int before = 0, int? after, int line = 276, String jc = ''}) {
  final pp = '${keep ? '<w:keepNext/>' : ''}$pBdr${shd.isNotEmpty ? '<w:shd w:val="clear" w:color="auto" w:fill="$shd"/>' : ''}${rtl ? '<w:bidi/>' : ''}<w:spacing w:before="$before" w:after="${after ?? 100}" w:line="$line" w:lineRule="auto"/>${jc.isNotEmpty ? '<w:jc w:val="$jc"/>' : ''}';
  return '<w:p><w:pPr>$pp</w:pPr>$runs</w:p>';
}

String _image(String rid, int id, String name, double wIn, double hIn) {
  final cx = (wIn * 914400).round(), cy = (hIn * 914400).round();
  return '<w:r><w:drawing><wp:inline distT="0" distB="0" distL="0" distR="0"><wp:extent cx="$cx" cy="$cy"/><wp:docPr id="$id" name="${_x(name)}" descr="${_x(name)}"/>'
      '<wp:cNvGraphicFramePr><a:graphicFrameLocks xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" noChangeAspect="1"/></wp:cNvGraphicFramePr>'
      '<a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">'
      '<pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"><pic:nvPicPr><pic:cNvPr id="$id" name="${_x(name)}"/><pic:cNvPicPr/></pic:nvPicPr>'
      '<pic:blipFill><a:blip r:embed="$rid"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>'
      '<pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="$cx" cy="$cy"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr></pic:pic>'
      '</a:graphicData></a:graphic></wp:inline></w:drawing></w:r>';
}

const String _ns = 'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"';
const String _head = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n';
const String _relNs = 'http://schemas.openxmlformats.org/package/2006/relationships';
const String _rel = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships/';

Future<Uint8List> buildDocx(DocxData d) async {
  final ban = (await rootBundle.load('assets/images/banner.jpeg')).buffer.asUint8List();
  final sig = (await rootBundle.load('assets/images/signature.png')).buffer.asUint8List();
  const bw = 4.7;
  final bh = bw * 229 / 900;
  const sw = 1.2;
  final rtlDoc = d.rtl;
  final body = StringBuffer();
  body.write(_para(_run(d.title, b: true, sz: 40, color: 'FFFFFF', rtl: rtlDoc), shd: _teal, jc: 'center', rtl: rtlDoc, before: 60, after: 160, line: 320));
  body.write(_para(_run(d.patient, b: true, sz: 26, color: _teal, rtl: rtlDoc) + (d.age.isNotEmpty ? _run('  –  ${d.age}', sz: 24, color: '4A5A60', rtl: rtlDoc) : ''), rtl: rtlDoc, after: 40));
  if (d.meta.isNotEmpty) body.write(_para(_run(d.meta, sz: 20, color: '5A6A70', rtl: rtlDoc), rtl: rtlDoc, after: 120));
  for (final s in d.sections) {
    final t = s['t'] ?? '';
    final h = _isAr(t) || rtlDoc;
    body.write(_para(_run(t, b: true, sz: 26, color: _purple, rtl: h),
        keep: true, rtl: h, before: 220, after: 80, pBdr: '<w:pBdr><w:bottom w:val="single" w:sz="10" w:space="2" w:color="$_teal"/></w:pBdr>'));
    for (final line in (s['v'] ?? '').split(RegExp(r'\r?\n'))) {
      final r = rtlDoc || _isAr(line);
      body.write(_para(line.trim().isNotEmpty ? _run(line, rtl: r) : '', rtl: r, after: line.trim().isNotEmpty ? 80 : 20));
    }
  }
  final me = d.me;
  final nobd = '<w:tblBorders><w:top w:val="nil"/><w:left w:val="nil"/><w:bottom w:val="nil"/><w:right w:val="nil"/><w:insideH w:val="nil"/><w:insideV w:val="nil"/></w:tblBorders>';
  final info = StringBuffer();
  info.write(_para(_run(me['name'] ?? '', b: true, sz: 28, color: _teal, rtl: rtlDoc), rtl: rtlDoc, after: 20));
  final mt = me['title'] ?? '';
  if (mt.isNotEmpty) info.write(_para(_run(mt, i: true, sz: 22, color: _purple, rtl: rtlDoc || _isAr(mt)), rtl: rtlDoc || _isAr(mt), after: 20));
  final contact = [me['phone'], me['email']].where((e) => e != null && e.isNotEmpty).join('  ·  ');
  if (contact.isNotEmpty) info.write(_para(_run(contact, sz: 20, color: '4A5A60'), rtl: false, jc: rtlDoc ? 'right' : '', after: 20));
  final ad = me['addr'] ?? '';
  if (ad.isNotEmpty) info.write(_para(_run(ad, sz: 20, color: '4A5A60', rtl: rtlDoc || _isAr(ad)), rtl: rtlDoc || _isAr(ad), after: 20));
  final sigP = _para(_image('rIdSig', 20, 'Signature', sw, sw), after: 0, jc: 'center');
  final tbl = '<w:tbl><w:tblPr>${rtlDoc ? '<w:bidiVisual/>' : ''}<w:tblW w:w="0" w:type="auto"/>$nobd<w:tblLayout w:type="fixed"/></w:tblPr>'
      '<w:tblGrid><w:gridCol w:w="2100"/><w:gridCol w:w="6700"/></w:tblGrid><w:tr><w:trPr><w:cantSplit/></w:trPr>'
      '<w:tc><w:tcPr><w:tcW w:w="2100" w:type="dxa"/><w:vAlign w:val="center"/></w:tcPr>$sigP</w:tc>'
      '<w:tc><w:tcPr><w:tcW w:w="6700" w:type="dxa"/><w:vAlign w:val="center"/></w:tcPr>${info.toString()}</w:tc></w:tr></w:tbl>';
  body.write(_para(_run(d.dateLine, sz: 20, color: '5A6A70', rtl: rtlDoc), rtl: rtlDoc, before: 360, after: 80, keep: true, pBdr: '<w:pBdr><w:top w:val="single" w:sz="8" w:space="6" w:color="$_gold"/></w:pBdr>'));
  body.write(tbl);
  body.write(_para('', after: 0));

  final borders = ['top', 'left', 'bottom', 'right'].map((s) => '<w:$s w:val="thinThickThinSmallGap" w:sz="18" w:space="22" w:color="$_teal"/>').join();
  final sect = '<w:sectPr><w:headerReference w:type="default" r:id="rIdHdr"/><w:footerReference w:type="default" r:id="rIdFtr"/>'
      '<w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="2100" w:right="1250" w:bottom="1500" w:left="1250" w:header="620" w:footer="520" w:gutter="0"/>'
      '<w:pgBorders w:offsetFrom="page">$borders</w:pgBorders><w:cols w:space="720"/>${rtlDoc ? '<w:bidi/>' : ''}</w:sectPr>';
  final doc = '$_head<w:document $_ns><w:body>${body.toString()}$sect</w:body></w:document>';
  final hdr = '$_head<w:hdr $_ns>${_para(_image('rIdBan', 10, 'SpeechCare', bw, bh), jc: 'center', after: 0, line: 240)}</w:hdr>';
  final ftr = '$_head<w:ftr $_ns><w:p><w:pPr><w:pBdr><w:top w:val="single" w:sz="8" w:space="4" w:color="$_gold"/></w:pBdr><w:jc w:val="center"/></w:pPr>'
      '${_run('\u2581\u2583\u2585\u2583\u2581  ', sz: 18, color: _gold)}${_run('SpeechCare', b: true, sz: 18, color: _teal)}${_run('  \u2581\u2583\u2585\u2583\u2581', sz: 18, color: _gold)}'
      '${_run('     ${d.pageWord} ', sz: 18, color: '5A6A70')}'
      '<w:fldSimple w:instr=" PAGE "><w:r><w:rPr><w:sz w:val="18"/><w:color w:val="5A6A70"/></w:rPr><w:t>1</w:t></w:r></w:fldSimple></w:p></w:ftr>';
  final styles = '$_head<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:eastAsia="Calibri" w:cs="Arial"/><w:sz w:val="22"/><w:szCs w:val="22"/><w:lang w:val="en-US" w:eastAsia="en-US" w:bidi="ar-DZ"/></w:rPr></w:rPrDefault><w:pPrDefault><w:pPr><w:spacing w:after="100" w:line="276" w:lineRule="auto"/></w:pPr></w:pPrDefault></w:docDefaults><w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/><w:qFormat/></w:style></w:styles>';
  final ct = '$_head<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Default Extension="png" ContentType="image/png"/><Default Extension="jpeg" ContentType="image/jpeg"/>'
      '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/><Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>'
      '<Override PartName="/word/header1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml"/><Override PartName="/word/footer1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml"/>'
      '<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/></Types>';
  final rels = '$_head<Relationships xmlns="$_relNs"><Relationship Id="rId1" Type="${_rel}officeDocument" Target="word/document.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/></Relationships>';
  final core = '$_head<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><dc:title>${_x(d.title)}</dc:title><dc:creator>${_x((me['name'] ?? '').isEmpty ? 'SpeechCare' : me['name'])}</dc:creator><dcterms:created xsi:type="dcterms:W3CDTF">${DateTime.now().toUtc().toIso8601String()}</dcterms:created></cp:coreProperties>';
  final docRels = '$_head<Relationships xmlns="$_relNs"><Relationship Id="rIdSt" Type="${_rel}styles" Target="styles.xml"/><Relationship Id="rIdHdr" Type="${_rel}header" Target="header1.xml"/><Relationship Id="rIdFtr" Type="${_rel}footer" Target="footer1.xml"/><Relationship Id="rIdSig" Type="${_rel}image" Target="media/signature.png"/></Relationships>';
  final hdrRels = '$_head<Relationships xmlns="$_relNs"><Relationship Id="rIdBan" Type="${_rel}image" Target="media/banner.jpeg"/></Relationships>';
  List<int> u(String s) => utf8.encode(s);
  return _zip([
    _F('[Content_Types].xml', u(ct)),
    _F('_rels/.rels', u(rels)),
    _F('docProps/core.xml', u(core)),
    _F('word/document.xml', u(doc)),
    _F('word/styles.xml', u(styles)),
    _F('word/header1.xml', u(hdr)),
    _F('word/footer1.xml', u(ftr)),
    _F('word/_rels/document.xml.rels', u(docRels)),
    _F('word/_rels/header1.xml.rels', u(hdrRels)),
    _F('word/media/banner.jpeg', ban),
    _F('word/media/signature.png', sig),
  ]);
}

const String kDocxMime = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

/// Writes the file to the cache folder and opens the Android share sheet (Word, WPS, Drive, email…).
/// Returns 'shared' | 'cancelled' | 'error'.
Future<String> deliverDocx(String name, Uint8List bytes) async {
  try {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/$name');
    await f.writeAsBytes(bytes, flush: true);
    final r = await Share.shareXFiles([XFile(f.path, mimeType: kDocxMime, name: name)], subject: name, text: name);
    return r.status == ShareResultStatus.dismissed ? 'cancelled' : 'shared';
  } catch (_) {
    return 'error';
  }
}

/// Plain-text share (client message / AI review).
Future<void> shareText(String text, [String? title]) async {
  try {
    await Share.share(text, subject: title ?? 'SpeechCare');
  } catch (_) {}
}
