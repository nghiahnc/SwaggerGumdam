import 'dates.dart';

typedef Json = Map<String, dynamic>;
Json asJson(dynamic value) => Map<String, dynamic>.from(value as Map);
List<Json> asJsonList(dynamic value) => (value as List).map(asJson).toList();
List<Json> pageItems(dynamic value) => asJsonList(asJson(value)['items']);
int asInt(dynamic value) => (value as num).toInt();

class ShopUser {
  ShopUser.fromJson(Json j)
    : id = j['id'] as String,
      email = j['email'] as String,
      fullName = j['fullName'] as String,
      role = j['role'] as String;
  final String id, email, fullName, role;
}

class Category {
  Category.fromJson(Json j)
    : id = j['id'] as String,
      name = j['name'] as String,
      slug = j['slug'] as String,
      description = j['description'] as String?,
      isActive = j['isActive'] as bool;
  final String id, name, slug;
  final String? description;
  final bool isActive;
}

class Product {
  Product.fromJson(Json j)
    : id = j['id'] as String,
      categoryId = j['categoryId'] as String,
      name = j['name'] as String,
      slug = j['slug'] as String,
      grade = j['grade'] as String,
      scale = j['scale'] as String,
      description = j['description'] as String?,
      imageUrl = j['imageUrl'] as String?,
      isActive = j['isActive'] as bool;
  final String id, categoryId, name, slug, grade, scale;
  final String? description, imageUrl;
  final bool isActive;
}

class ProductSearchHit {
  ProductSearchHit.fromJson(Json j)
    : id = j['Id'] as String,
      name = j['Name'] as String,
      grade = j['Grade'] as String,
      scale = j['Scale'] as String,
      category = j['Category'] as String,
      fromPriceVnd = j['FromPriceVnd'] == null
          ? null
          : asInt(j['FromPriceVnd']);
  final String id, name, grade, scale, category;
  final int? fromPriceVnd;
}

class Variant {
  Variant.fromJson(Json j)
    : id = j['id'] as String,
      productId = j['productId'] as String,
      sku = j['sku'] as String,
      label = j['label'] as String,
      priceVnd = asInt(j['priceVnd']),
      stock = asInt(j['stock']),
      isActive = j['isActive'] as bool;
  final String id, productId, sku, label;
  final int priceVnd, stock;
  final bool isActive;
}

class Address {
  Address.fromJson(Json j)
    : id = j['id'] as String,
      recipient = j['recipient'] as String,
      phone = j['phone'] as String,
      line1 = j['line1'] as String,
      ward = j['ward'] as String,
      district = j['district'] as String,
      province = j['province'] as String,
      isDefault = j['isDefault'] as bool;
  final String id, recipient, phone, line1, ward, district, province;
  final bool isDefault;
  String get display => '$line1, $ward, $district, $province';
}

class CartLine {
  CartLine.fromJson(Json j)
    : id = j['id'] as String,
      variantId = j['variantId'] as String,
      productName = j['productName'] as String,
      sku = j['sku'] as String,
      unitPriceVnd = asInt(j['unitPriceVnd']),
      quantity = asInt(j['quantity']);
  final String id, variantId, productName, sku;
  final int unitPriceVnd, quantity;
  int get totalVnd => unitPriceVnd * quantity;
}

class OrderLine {
  OrderLine.fromJson(Json j)
    : variantId = j['variantId'] as String,
      productName = j['productName'] as String,
      sku = j['sku'] as String,
      unitPriceVnd = asInt(j['unitPriceVnd']),
      quantity = asInt(j['quantity']);
  final String variantId, productName, sku;
  final int unitPriceVnd, quantity;
}

class ShopOrder {
  ShopOrder.fromJson(Json j)
    : id = j['id'] as String,
      status = j['status'] as String,
      paymentStatus = j['paymentStatus'] as String,
      subtotalVnd = asInt(j['subtotalVnd']),
      discountVnd = asInt(j['discountVnd']),
      totalVnd = asInt(j['totalVnd']),
      createdAtUtc = DateTime.parse(j['createdAtUtc'] as String),
      expiresAtUtc = DateTime.parse(j['expiresAtUtc'] as String),
      items = asJsonList(j['items']).map(OrderLine.fromJson).toList();
  final String id, status, paymentStatus;
  final int subtotalVnd, discountVnd, totalVnd;
  final DateTime createdAtUtc, expiresAtUtc;
  final List<OrderLine> items;
}

class Voucher {
  Voucher.fromJson(Json j)
    : id = j['id'] as String,
      code = j['code'] as String,
      discountVnd = asInt(j['discountVnd']),
      minSubtotalVnd = asInt(j['minSubtotalVnd']),
      maxUses = asInt(j['maxUses']),
      usedCount = asInt(j['usedCount']),
      startsAtUtc = parseUtc(j['startsAtUtc'] as String),
      endsAtUtc = parseUtc(j['endsAtUtc'] as String),
      isActive = j['isActive'] as bool;
  final String id, code;
  final int discountVnd, minSubtotalVnd, maxUses, usedCount;
  final DateTime startsAtUtc, endsAtUtc;
  final bool isActive;
}

class Review {
  Review.fromJson(Json j)
    : id = j['id'] as String,
      productId = j['productId'] as String,
      userId = j['userId'] as String,
      rating = asInt(j['rating']),
      comment = j['comment'] as String,
      createdAtUtc = parseUtc(j['createdAtUtc'] as String);
  final String id, productId, userId, comment;
  final int rating;
  final DateTime createdAtUtc;
}
