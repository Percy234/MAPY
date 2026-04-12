import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html;
import '../models/fuel_price_model.dart';
import '../models/vehicle_model.dart';

class PetrolimexRetailPrice {
  const PetrolimexRetailPrice({
    required this.productName,
    required this.zone1Price,
    required this.zone2Price,
    required this.updatedAt,
    this.link,
  });

  final String productName;
  final double zone1Price;
  final double zone2Price;
  final DateTime updatedAt;
  final String? link;
}

class _PetrolimexRetailRow {
  const _PetrolimexRetailRow({required this.displayOrder, required this.price});

  final int displayOrder;
  final PetrolimexRetailPrice price;
}

class _PetrolimexQueryIds {
  const _PetrolimexQueryIds({
    required this.systemId,
    required this.repositoryId,
    required this.repositoryEntityId,
  });

  final String systemId;
  final String repositoryId;
  final String repositoryEntityId;
}

class PetrolimexService {
  static const String _homepageUrl = 'https://petrolimex.com.vn/index.html';
  static const String _portalsApiUrl =
      'https://portals.petrolimex.com.vn/~apis/portals/cms.item/search';

  // These IDs are used by Petrolimex website script to load the hover price table.
  static const String _fallbackSystemId = '6783dc1271ff449e95b74a9520964169';
  static const String _fallbackRepositoryId =
      'a95451e23b474fe5886bfb7cf843f53c';
  static const String _fallbackRepositoryEntityId =
      '3801378fe1e045b1afa10de7c5776124';

  static const Duration _timeout = Duration(seconds: 30);

  static const Map<String, String> _jsonHeaders = {
    'accept': 'application/json, text/plain, */*',
    'user-agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36',
  };

  Future<List<PetrolimexRetailPrice>> fetchRetailPrices() async {
    final fallbackIds = const _PetrolimexQueryIds(
      systemId: _fallbackSystemId,
      repositoryId: _fallbackRepositoryId,
      repositoryEntityId: _fallbackRepositoryEntityId,
    );

    try {
      // Primary strategy: call the same public APIs endpoint with known IDs.
      final direct = await _fetchRetailPricesByIds(fallbackIds);
      if (direct.isNotEmpty) {
        return direct;
      }

      // Secondary strategy: refresh IDs from homepage + sunrise script.
      final homepageResponse = await http
          .get(Uri.parse(_homepageUrl))
          .timeout(
            _timeout,
            onTimeout: () =>
                throw Exception('Timeout khi tai trang chu Petrolimex'),
          );

      if (homepageResponse.statusCode != 200) {
        throw Exception(
          'Khong the tai trang chu: ${homepageResponse.statusCode}',
        );
      }

      final document = html.parse(homepageResponse.body);
      final sunriseScriptUrl = _extractSunriseScriptUrl(document);
      final sunriseScript = await _downloadSunriseScript(
        sunriseScriptUrl: sunriseScriptUrl,
      );

      final ids = _extractQueryIds(
        homepageHtml: homepageResponse.body,
        sunriseScript: sunriseScript,
      );

      final fromDynamicIds = await _fetchRetailPricesByIds(ids);
      if (fromDynamicIds.isNotEmpty) {
        return fromDynamicIds;
      }

      throw Exception('API tra ve danh sach rong');
    } catch (e) {
      throw Exception('Loi cao du lieu Petrolimex: $e');
    }
  }

  Future<List<PetrolimexRetailPrice>> _fetchRetailPricesByIds(
    _PetrolimexQueryIds ids,
  ) async {
    final query = <String, String>{'x-request': _encodeXRequest(ids)};

    final apiResponse = await http
        .get(
          Uri.parse(_portalsApiUrl).replace(queryParameters: query),
          headers: _jsonHeaders,
        )
        .timeout(
          _timeout,
          onTimeout: () =>
              throw Exception('Timeout khi lay bang gia Petrolimex'),
        );

    if (apiResponse.statusCode != 200) {
      throw Exception('Khong the lay bang gia: ${apiResponse.statusCode}');
    }

    return _parseRetailPrices(apiResponse.body);
  }

  Future<List<FuelPriceModel>> fetchFuelPrices() async {
    final retailPrices = await fetchRetailPrices();

    PetrolimexRetailPrice? findByKeywords(List<String> keywords) {
      for (final price in retailPrices) {
        final normalized = price.productName.toUpperCase();
        if (keywords.any((keyword) => normalized.contains(keyword))) {
          return price;
        }
      }
      return null;
    }

    final mapped = <FuelPriceModel>[];

    final e5 = findByKeywords(['E5 RON 92']);
    if (e5 != null) {
      mapped.add(
        FuelPriceModel.create(
          fuelType: FuelType.e5Ron92,
          price: e5.zone1Price,
          updatedAt: e5.updatedAt,
          source: 'Petrolimex',
        ),
      );
    }

    final ron95 =
        findByKeywords(['RON 95-III']) ??
        findByKeywords(['RON 95-V', 'RON 95']);
    if (ron95 != null) {
      mapped.add(
        FuelPriceModel.create(
          fuelType: FuelType.ron95,
          price: ron95.zone1Price,
          updatedAt: ron95.updatedAt,
          source: 'Petrolimex',
        ),
      );
    }

    final diesel =
        findByKeywords(['DO 0,05S-II']) ??
        findByKeywords(['DO 0,001S-V', 'DO 0.001S-V']);
    if (diesel != null) {
      mapped.add(
        FuelPriceModel.create(
          fuelType: FuelType.diesel,
          price: diesel.zone1Price,
          updatedAt: diesel.updatedAt,
          source: 'Petrolimex',
        ),
      );
    }

    if (mapped.isEmpty) {
      throw Exception('Khong anh xa duoc gia xang theo FuelType');
    }

    return mapped;
  }

  String _extractSunriseScriptUrl(dynamic document) {
    final scripts = document.querySelectorAll('script[src]');
    for (final script in scripts) {
      final src = script.attributes['src'];
      if (src != null && src.contains('/_themes/sunrise/js/all.js')) {
        return _toAbsoluteUrl(src);
      }
    }
    throw Exception('Khong tim thay script sunrise js');
  }

  Future<String> _downloadSunriseScript({
    required String sunriseScriptUrl,
  }) async {
    final response = await http
        .get(Uri.parse(sunriseScriptUrl))
        .timeout(
          _timeout,
          onTimeout: () =>
              throw Exception('Timeout khi tai script cua Petrolimex'),
        );
    if (response.statusCode != 200) {
      throw Exception('Khong the tai script: ${response.statusCode}');
    }
    return response.body;
  }

  _PetrolimexQueryIds _extractQueryIds({
    required String homepageHtml,
    required String sunriseScript,
  }) {
    final pricesScope = _extractPricesScope(sunriseScript);

    final systemId =
        _firstMatch(
          homepageHtml,
          RegExp(r'system:"([a-f0-9]{32})"', caseSensitive: false),
        ) ??
        _fallbackSystemId;
    final repositoryId =
        _firstMatch(
          pricesScope,
          RegExp(
            r'RepositoryID:\s*\{\s*Equals:\s*"([a-f0-9]{32})"',
            caseSensitive: false,
          ),
        ) ??
        _fallbackRepositoryId;
    final repositoryEntityId =
        _firstMatch(
          pricesScope,
          RegExp(
            r'RepositoryEntityID:\s*\{\s*Equals:\s*"([a-f0-9]{32})"',
            caseSensitive: false,
          ),
        ) ??
        _fallbackRepositoryEntityId;

    return _PetrolimexQueryIds(
      systemId: systemId,
      repositoryId: repositoryId,
      repositoryEntityId: repositoryEntityId,
    );
  }

  String _extractPricesScope(String sunriseScript) {
    final start = sunriseScript.indexOf('__vieapps.prices');
    if (start < 0) {
      return sunriseScript;
    }

    final end = math.min(start + 5000, sunriseScript.length);
    return sunriseScript.substring(start, end);
  }

  String _encodeXRequest(_PetrolimexQueryIds ids) {
    final payload = {
      'FilterBy': {
        'And': [
          {
            'SystemID': {'Equals': ids.systemId},
          },
          {
            'RepositoryID': {'Equals': ids.repositoryId},
          },
          {
            'RepositoryEntityID': {'Equals': ids.repositoryEntityId},
          },
          {
            'Status': {'Equals': 'Published'},
          },
        ],
      },
      'SortBy': {'LastModified': 'Descending'},
      'Pagination': {
        'TotalRecords': -1,
        'TotalPages': 0,
        'PageSize': 0,
        'PageNumber': 0,
      },
    };

    return _toBase64UrlNoPadding(jsonEncode(payload));
  }

  List<PetrolimexRetailPrice> _parseRetailPrices(String rawJson) {
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Du lieu API khong hop le');
    }

    final objects = decoded['Objects'];
    if (objects is! List) {
      throw Exception('Khong co danh sach gia trong API');
    }

    final rows = <_PetrolimexRetailRow>[];

    for (final item in objects) {
      if (item is! Map) {
        continue;
      }

      final title = (item['Title'] ?? '').toString().trim();
      if (title.isEmpty) {
        continue;
      }

      final zone1 = _toPrice(item['Zone1Price']);
      final zone2 = _toPrice(item['Zone2Price']);
      if (zone1 == null || zone2 == null) {
        continue;
      }

      final displayOrder =
          _toInt(item['DIsplayOrder']) ??
          _toInt(item['OrderIndex']) ??
          rows.length;
      final updatedAt =
          DateTime.tryParse(
            (item['LastModified'] ?? '').toString(),
          )?.toLocal() ??
          DateTime.now();
      final link = _normalizeLink((item['Link'] ?? '').toString());

      rows.add(
        _PetrolimexRetailRow(
          displayOrder: displayOrder,
          price: PetrolimexRetailPrice(
            productName: title,
            zone1Price: zone1,
            zone2Price: zone2,
            updatedAt: updatedAt,
            link: link,
          ),
        ),
      );
    }

    if (rows.isEmpty) {
      final total = decoded['TotalRecords'];
      throw Exception(
        'Khong parse duoc bang gia Petrolimex (TotalRecords=$total)',
      );
    }

    rows.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    return rows.map((row) => row.price).toList(growable: false);
  }

  String _toAbsoluteUrl(String src) {
    if (src.startsWith('http://') || src.startsWith('https://')) {
      return src;
    }
    if (src.startsWith('//')) {
      return 'https:$src';
    }
    return Uri.parse(_homepageUrl).resolve(src).toString();
  }

  String _toBase64UrlNoPadding(String value) {
    final base64UrlValue = base64Url.encode(utf8.encode(value));
    return base64UrlValue.replaceAll('=', '');
  }

  String? _firstMatch(String source, RegExp regex) {
    final match = regex.firstMatch(source);
    if (match == null || match.groupCount < 1) {
      return null;
    }
    return match.group(1);
  }

  int? _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value == null) {
      return null;
    }
    return int.tryParse(value.toString());
  }

  double? _toPrice(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    if (value == null) {
      return null;
    }

    final raw = value.toString().trim();
    if (raw.isEmpty) {
      return null;
    }

    final normalized = raw
        .replaceAll('.', '')
        .replaceAll(',', '.')
        .replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(normalized);
  }

  String? _normalizeLink(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == '#') {
      return null;
    }
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    return Uri.parse(_homepageUrl).resolve(trimmed).toString();
  }
}
