import 'package:hive/hive.dart';

import '../models/place_model.dart';
import '../utils/constants.dart';
import '../utils/hive_manager.dart';

class PlaceRepository {
  Box<PlaceModel> get _box =>
      HiveManager.getBox<PlaceModel>(DatabaseConfig.placesBox);

  Future<List<PlaceModel>> getAll() async => _box.values.toList(growable: false);

  Future<void> save(PlaceModel place) async => _box.put(place.id, place);

  Future<void> delete(String placeId) async => _box.delete(placeId);

  Future<void> saveAll(Iterable<PlaceModel> places) async {
    final payload = <String, PlaceModel>{
      for (final place in places) place.id: place,
    };
    await _box.putAll(payload);
  }
}
