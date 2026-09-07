class School {
  final String id;
  final String name;
  final String? imageUrl;
  final String? city;
  final String? state;
  final String description;
  final String address;
  final String websiteUrl;

  const School({
    required this.id,
    required this.name,
    this.imageUrl,
    this.city,
    this.state,
    this.description = '',
    this.address = '',
    this.websiteUrl = '',
  });

  factory School.fromMap(Map<String, dynamic> map, String id) {
    return School(
      id: id,
      name: map['name'] ?? '',
      imageUrl: map['imageUrl'],
      city: map['city'],
      state: map['state'],
      description: map['description'] as String? ?? '',
      address: map['address'] as String? ?? '',
      websiteUrl:
          map['websiteUrl'] as String? ?? map['website'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'imageUrl': imageUrl,
      'city': city,
      'state': state,
      'description': description,
      'address': address,
      'websiteUrl': websiteUrl,
    };
  }
}
