import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(KreiselApp());
}

class KreiselApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kreisel',
      theme: ThemeData.dark().copyWith(
        primaryColor: Color(0xFF007AFF),
        scaffoldBackgroundColor: Color(0xFF000000),
        cardColor: Color(0xFF1C1C1E),
        dividerColor: Color(0xFF38383A),
      ),
      home: LoginPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Models
class User {
  final int userId;
  final String email;
  final String fullName;
  final String role;

  User({
    required this.userId,
    required this.email,
    required this.fullName,
    required this.role,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['userId'],
      email: json['email'],
      fullName: json['fullName'],
      role: json['role'],
    );
  }
}

class Item {
  final int id;
  final String name;
  final String? size;
  final bool available;
  final String? description;
  final String? brand;
  final String location;
  final String gender;
  final String category;
  final String subcategory;
  final String zustand;

  Item({
    required this.id,
    required this.name,
    this.size,
    required this.available,
    this.description,
    this.brand,
    required this.location,
    required this.gender,
    required this.category,
    required this.subcategory,
    required this.zustand,
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      id: json['id'],
      name: json['name'],
      size: json['size'],
      available: json['available'],
      description: json['description'],
      brand: json['brand'],
      location: json['location'],
      gender: json['gender'],
      category: json['category'],
      subcategory: json['subcategory'],
      zustand: json['zustand'],
    );
  }
}

class Rental {
  final int id;
  final User user;
  final Item item;
  final DateTime rentalDate;
  final DateTime endDate;
  final DateTime? returnDate;
  final bool extended;

  Rental({
    required this.id,
    required this.user,
    required this.item,
    required this.rentalDate,
    required this.endDate,
    this.returnDate,
    required this.extended,
  });

  factory Rental.fromJson(Map<String, dynamic> json) {
    return Rental(
      id: json['id'],
      user: User.fromJson(json['user']),
      item: Item.fromJson(json['item']),
      rentalDate: DateTime.parse(json['rentalDate']),
      endDate: DateTime.parse(json['endDate']),
      returnDate:
          json['returnDate'] != null
              ? DateTime.parse(json['returnDate'])
              : null,
      extended: json['extended'],
    );
  }

  bool get isActive => returnDate == null;
  bool get isOverdue => isActive && DateTime.now().isAfter(endDate);
}

// API Service
class ApiService {
  static const String baseUrl = 'http://localhost:8080/api';
  static User? currentUser;

  static Future<User> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final user = User.fromJson(jsonDecode(response.body));
      currentUser = user;
      return user;
    } else {
      throw Exception('Login fehlgeschlagen');
    }
  }

  static Future<User> register(
    String fullName,
    String email,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'fullName': fullName,
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final user = User.fromJson(jsonDecode(response.body));
      currentUser = user;
      return user;
    } else {
      throw Exception('Registrierung fehlgeschlagen');
    }
  }

  static Future<List<Item>> getItems({
    required String location,
    bool? available,
    String? searchQuery,
    String? gender,
    String? category,
    String? subcategory,
    String? size,
  }) async {
    var params = {'location': location};
    if (available != null) params['available'] = available.toString();
    if (searchQuery != null && searchQuery.isNotEmpty)
      params['searchQuery'] = searchQuery;
    if (gender != null) params['gender'] = gender;
    if (category != null) params['category'] = category;
    if (subcategory != null) params['subcategory'] = subcategory;
    if (size != null) params['size'] = size;

    final uri = Uri.parse('$baseUrl/items').replace(queryParameters: params);
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList.map((json) => Item.fromJson(json)).toList();
    } else {
      throw Exception('Fehler beim Laden der Items');
    }
  }

  static Future<Rental> rentItem(int itemId, DateTime endDate) async {
    if (currentUser == null) throw Exception('Nicht angemeldet');

    final response = await http.post(
      Uri.parse('$baseUrl/rentals/user/${currentUser!.userId}/rent'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'item': {'id': itemId},
        'endDate': endDate.toIso8601String().split('T')[0],
      }),
    );

    if (response.statusCode == 200) {
      return Rental.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Ausleihe fehlgeschlagen');
    }
  }

  static Future<List<Rental>> getActiveRentals() async {
    if (currentUser == null) throw Exception('Nicht angemeldet');

    final response = await http.get(
      Uri.parse('$baseUrl/rentals/user/${currentUser!.userId}/active'),
    );

    if (response.statusCode == 200) {
      List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList.map((json) => Rental.fromJson(json)).toList();
    } else {
      throw Exception('Fehler beim Laden der aktiven Ausleihen');
    }
  }

  static Future<List<Rental>> getRentalHistory() async {
    if (currentUser == null) throw Exception('Nicht angemeldet');

    final response = await http.get(
      Uri.parse('$baseUrl/rentals/user/${currentUser!.userId}/history'),
    );

    if (response.statusCode == 200) {
      List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList.map((json) => Rental.fromJson(json)).toList();
    } else {
      throw Exception('Fehler beim Laden der Ausleih-Historie');
    }
  }

  static Future<Rental> extendRental(int rentalId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/rentals/$rentalId/extend'),
    );

    if (response.statusCode == 200) {
      return Rental.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Verlängerung fehlgeschlagen');
    }
  }

  static Future<Rental> returnRental(int rentalId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/rentals/$rentalId/return'),
    );

    if (response.statusCode == 200) {
      return Rental.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception('Rückgabe fehlgeschlagen');
    }
  }
}

// Login Page
class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  bool _isRegistering = false;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo/Title
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Color(0xFF007AFF),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Icon(
                  CupertinoIcons.cube_box,
                  size: 60,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 32),
              Text(
                'Kreisel',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'HM Equipment Verleih',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              SizedBox(height: 48),

              // Form Fields
              if (_isRegistering)
                _buildTextField(
                  controller: _fullNameController,
                  placeholder: 'Vollständiger Name',
                  icon: CupertinoIcons.person,
                ),
              _buildTextField(
                controller: _emailController,
                placeholder: 'E-Mail (@hm.edu)',
                icon: CupertinoIcons.mail,
                keyboardType: TextInputType.emailAddress,
              ),
              _buildTextField(
                controller: _passwordController,
                placeholder: 'Passwort',
                icon: CupertinoIcons.lock,
                isPassword: true,
              ),

              SizedBox(height: 32),

              // Action Button
              Container(
                width: double.infinity,
                height: 54,
                child: CupertinoButton(
                  color: Color(0xFF007AFF),
                  borderRadius: BorderRadius.circular(16),
                  onPressed: _isLoading ? null : _handleAuth,
                  child:
                      _isLoading
                          ? CupertinoActivityIndicator(color: Colors.white)
                          : Text(
                            _isRegistering ? 'Registrieren' : 'Anmelden',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                ),
              ),

              SizedBox(height: 16),

              // Toggle Button
              CupertinoButton(
                onPressed: () {
                  setState(() {
                    _isRegistering = !_isRegistering;
                  });
                },
                child: Text(
                  _isRegistering
                      ? 'Bereits registriert? Anmelden'
                      : 'Noch kein Account? Registrieren',
                  style: TextStyle(color: Color(0xFF007AFF)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String placeholder,
    required IconData icon,
    bool isPassword = false,
    TextInputType? keyboardType,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: keyboardType,
        style: TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: TextStyle(color: Colors.grey),
          prefixIcon: Icon(icon, color: Colors.grey),
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(20),
        ),
      ),
    );
  }

  void _handleAuth() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showAlert('Fehler', 'Bitte alle Felder ausfüllen');
      return;
    }

    if (!_emailController.text.endsWith('@hm.edu')) {
      _showAlert('Fehler', 'Nur HM E-Mail-Adressen sind erlaubt');
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isRegistering) {
        if (_fullNameController.text.isEmpty) {
          _showAlert('Fehler', 'Name ist erforderlich');
          return;
        }
        await ApiService.register(
          _fullNameController.text,
          _emailController.text,
          _passwordController.text,
        );
      } else {
        await ApiService.login(_emailController.text, _passwordController.text);
      }

      Navigator.pushReplacement(
        context,
        CupertinoPageRoute(builder: (context) => LocationSelectionPage()),
      );
    } catch (e) {
      _showAlert('Fehler', e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showAlert(String title, String message) {
    showCupertinoDialog(
      context: context,
      builder:
          (context) => CupertinoAlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              CupertinoDialogAction(
                child: Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
    );
  }
}

// Location Selection Page
class LocationSelectionPage extends StatelessWidget {
  final List<Map<String, dynamic>> locations = [
    {
      'name': 'PASING',
      'displayName': 'Campus Pasing',
      'icon': CupertinoIcons.building_2_fill,
      'color': Color(0xFF007AFF),
    },
    {
      'name': 'LOTHSTRASSE',
      'displayName': 'Campus Lothstraße',
      'icon': CupertinoIcons.location_fill,
      'color': Color(0xFF32D74B),
    },
    {
      'name': 'KARLSTRASSE',
      'displayName': 'Campus Karlstraße',
      'icon': CupertinoIcons.map_fill,
      'color': Color(0xFFFF9500),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            children: [
              SizedBox(height: 40),
              Text(
                'Standort wählen',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Wähle deinen Campus aus',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              SizedBox(height: 48),
              Expanded(
                child: ListView.builder(
                  itemCount: locations.length,
                  itemBuilder: (context, index) {
                    final location = locations[index];
                    return Container(
                      margin: EdgeInsets.only(bottom: 16),
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder:
                                  (context) => HomePage(
                                    selectedLocation: location['name'],
                                    locationDisplayName:
                                        location['displayName'],
                                  ),
                            ),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Color(0xFF1C1C1E),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: location['color'].withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: location['color'].withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  location['icon'],
                                  color: location['color'],
                                  size: 30,
                                ),
                              ),
                              SizedBox(width: 20),
                              Expanded(
                                child: Text(
                                  location['displayName'],
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Icon(
                                CupertinoIcons.chevron_right,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Homepage
class HomePage extends StatefulWidget {
  final String selectedLocation;
  final String locationDisplayName;

  HomePage({required this.selectedLocation, required this.locationDisplayName});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  List<Item> _items = [];
  List<Item> _filteredItems = [];
  bool _isLoading = true;
  bool _showOnlyAvailable = true;
  String? _selectedGender;
  String? _selectedCategory;
  String? _selectedSubcategory;

  final Map<String, List<String>> categorySubcategories = {
    'KLEIDUNG': ['HOSEN', 'JACKEN'],
    'SCHUHE': ['STIEFEL', 'WANDERSCHUHE'],
    'ACCESSOIRES': ['MUETZEN', 'HANDSCHUHE', 'SCHALS', 'BRILLEN'],
    'TASCHEN': [],
    'EQUIPMENT': ['FLASCHEN', 'SKI', 'SNOWBOARDS', 'HELME'],
  };

  @override
  void initState() {
    super.initState();
    _loadItems();
    _searchController.addListener(_filterItems);
  }

  Future<void> _loadItems() async {
    try {
      final items = await ApiService.getItems(
        location: widget.selectedLocation,
      );
      setState(() {
        _items = items;
        _isLoading = false;
      });
      _filterItems();
    } catch (e) {
      setState(() => _isLoading = false);
      _showAlert('Fehler', 'Items konnten nicht geladen werden');
    }
  }

  void _filterItems() {
    setState(() {
      _filteredItems =
          _items.where((item) {
            // Verfügbarkeitsfilter
            if (_showOnlyAvailable && !item.available) return false;

            // Suchfilter
            if (_searchController.text.isNotEmpty) {
              final query = _searchController.text.toLowerCase();
              if (!item.name.toLowerCase().contains(query) &&
                  !(item.brand?.toLowerCase().contains(query) ?? false) &&
                  !(item.description?.toLowerCase().contains(query) ?? false)) {
                return false;
              }
            }

            // Gender Filter
            if (_selectedGender != null && item.gender != _selectedGender)
              return false;

            // Category Filter
            if (_selectedCategory != null && item.category != _selectedCategory)
              return false;

            // Subcategory Filter
            if (_selectedSubcategory != null &&
                item.subcategory != _selectedSubcategory)
              return false;

            return true;
          }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.pop(context),
                        child: Icon(
                          CupertinoIcons.back,
                          color: Color(0xFF007AFF),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          widget.locationDisplayName,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder:
                                  (context) => ActivitiesPage(
                                    selectedLocation: widget.selectedLocation,
                                    locationDisplayName:
                                        widget.locationDisplayName,
                                  ),
                            ),
                          );
                        },
                        child: Icon(
                          CupertinoIcons.list_bullet,
                          color: Color(0xFF007AFF),
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Suchen...',
                        hintStyle: TextStyle(color: Colors.grey),
                        prefixIcon: Icon(
                          CupertinoIcons.search,
                          color: Colors.grey,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                      ),
                    ),
                  ),

                  SizedBox(height: 16),

                  // Available Toggle
                  Row(
                    children: [
                      Text(
                        'Nur verfügbare:',
                        style: TextStyle(color: Colors.white),
                      ),
                      SizedBox(width: 8),
                      CupertinoSwitch(
                        value: _showOnlyAvailable,
                        onChanged: (value) {
                          setState(() => _showOnlyAvailable = value);
                          _filterItems();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Filter Chips
            Container(
              height: 120,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Gender Filter
                    Row(
                      children: [
                        _buildFilterChip('DAMEN', _selectedGender, (value) {
                          setState(
                            () =>
                                _selectedGender =
                                    _selectedGender == value ? null : value,
                          );
                          _filterItems();
                        }),
                        _buildFilterChip('HERREN', _selectedGender, (value) {
                          setState(
                            () =>
                                _selectedGender =
                                    _selectedGender == value ? null : value,
                          );
                          _filterItems();
                        }),
                        _buildFilterChip('UNISEX', _selectedGender, (value) {
                          setState(
                            () =>
                                _selectedGender =
                                    _selectedGender == value ? null : value,
                          );
                          _filterItems();
                        }),
                      ],
                    ),
                    SizedBox(height: 8),
                    // Category Filter
                    Row(
                      children:
                          categorySubcategories.keys.map((category) {
                            return _buildFilterChip(
                              category,
                              _selectedCategory,
                              (value) {
                                setState(() {
                                  _selectedCategory =
                                      _selectedCategory == value ? null : value;
                                  _selectedSubcategory =
                                      null; // Reset subcategory
                                });
                                _filterItems();
                              },
                            );
                          }).toList(),
                    ),
                    SizedBox(height: 8),
                    // Subcategory Filter
                    if (_selectedCategory != null &&
                        categorySubcategories[_selectedCategory]!.isNotEmpty)
                      Row(
                        children:
                            categorySubcategories[_selectedCategory]!.map((
                              subcategory,
                            ) {
                              return _buildFilterChip(
                                subcategory,
                                _selectedSubcategory,
                                (value) {
                                  setState(
                                    () =>
                                        _selectedSubcategory =
                                            _selectedSubcategory == value
                                                ? null
                                                : value,
                                  );
                                  _filterItems();
                                },
                              );
                            }).toList(),
                      ),
                  ],
                ),
              ),
            ),

            // Items List
            Expanded(
              child:
                  _isLoading
                      ? Center(child: CupertinoActivityIndicator())
                      : _filteredItems.isEmpty
                      ? Center(
                        child: Text(
                          'Keine Items gefunden',
                          style: TextStyle(color: Colors.grey, fontSize: 18),
                        ),
                      )
                      : ListView.builder(
                        padding: EdgeInsets.all(24),
                        itemCount: _filteredItems.length,
                        itemBuilder: (context, index) {
                          return _buildItemCard(_filteredItems[index]);
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    String? selectedValue,
    Function(String) onTap,
  ) {
    final isSelected = selectedValue == label;
    return Container(
      margin: EdgeInsets.only(right: 8),
      child: CupertinoButton(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: isSelected ? Color(0xFF007AFF) : Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(20),
        minSize: 0,
        onPressed: () => onTap(label),
        child: Text(
          label.toLowerCase().replaceAll('_', ' '),
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(Item item) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              item.available
                  ? Color(0xFF32D74B).withOpacity(0.3)
                  : Color(0xFFFF453A).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        item.available ? Color(0xFF32D74B) : Color(0xFFFF453A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item.available ? 'Verfügbar' : 'Ausgeliehen',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            if (item.brand != null)
              Text(
                item.brand!,
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            if (item.size != null)
              Text(
                'Größe: ${item.size}',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            if (item.description != null)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  item.description!,
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
            SizedBox(height: 12),
            Row(
              children: [
                _buildInfoChip(item.gender),
                _buildInfoChip(item.category),
                _buildInfoChip(item.subcategory),
                if (item.zustand != null) _buildInfoChip(item.zustand),
              ],
            ),
            if (item.available)
              Padding(
                padding: EdgeInsets.only(top: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    color: Color(0xFF007AFF),
                    borderRadius: BorderRadius.circular(12),
                    padding: EdgeInsets.symmetric(vertical: 12),
                    onPressed: () => _showRentDialog(item),
                    child: Text(
                      'Ausleihen',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String text) {
    return Container(
      margin: EdgeInsets.only(right: 8),
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text.toLowerCase(),
        style: TextStyle(color: Colors.white70, fontSize: 12),
      ),
    );
  }

  void _showRentDialog(Item item) {
    DateTime selectedDate = DateTime.now().add(Duration(days: 7));

    showCupertinoDialog(
      context: context,
      builder:
          (context) => CupertinoAlertDialog(
            title: Text('${item.name} ausleihen'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 16),
                Text('Bis wann möchten Sie das Item ausleihen?'),
                SizedBox(height: 16),
                Container(
                  height: 200,
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    initialDateTime: selectedDate,
                    minimumDate: DateTime.now().add(Duration(days: 1)),
                    maximumDate: DateTime.now().add(Duration(days: 60)),
                    onDateTimeChanged: (DateTime date) {
                      selectedDate = date;
                    },
                  ),
                ),
              ],
            ),
            actions: [
              CupertinoDialogAction(
                child: Text('Abbrechen'),
                onPressed: () => Navigator.pop(context),
              ),
              CupertinoDialogAction(
                child: Text('Ausleihen'),
                isDestructiveAction: false,
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    await ApiService.rentItem(item.id, selectedDate);
                    _showAlert('Erfolg', 'Item erfolgreich ausgeliehen!');
                    _loadItems(); // Liste aktualisieren
                  } catch (e) {
                    _showAlert('Fehler', e.toString());
                  }
                },
              ),
            ],
          ),
    );
  }

  void _showAlert(String title, String message) {
    showCupertinoDialog(
      context: context,
      builder:
          (context) => CupertinoAlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              CupertinoDialogAction(
                child: Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
    );
  }
}

class ActivitiesPage extends StatefulWidget {
  final String selectedLocation;
  final String locationDisplayName;

  ActivitiesPage({
    required this.selectedLocation,
    required this.locationDisplayName,
  });

  @override
  _ActivitiesPageState createState() => _ActivitiesPageState();
}

class _ActivitiesPageState extends State<ActivitiesPage> {
  List<Rental> _activeRentals = [];
  List<Rental> _rentalHistory = [];
  bool _isLoading = true;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _loadRentals();
  }

  Future<void> _loadRentals() async {
    try {
      final active = await ApiService.getActiveRentals();
      final history = await ApiService.getRentalHistory();
      setState(() {
        _activeRentals = active;
        _rentalHistory = history;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showAlert('Fehler', 'Ausleihen konnten nicht geladen werden');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header mit Zurück zur Startseite
            Container(
              padding: EdgeInsets.all(24),
              child: Row(
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        CupertinoPageRoute(
                          builder:
                              (context) => HomePage(
                                selectedLocation: widget.selectedLocation,
                                locationDisplayName: widget.locationDisplayName,
                              ),
                        ),
                      );
                    },
                    child: Icon(CupertinoIcons.back, color: Color(0xFF007AFF)),
                  ),
                  SizedBox(width: 16),
                  Text(
                    'Meine Aktivitäten',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // Segmented Control
            Container(
              margin: EdgeInsets.symmetric(horizontal: 24),
              child: CupertinoSlidingSegmentedControl<int>(
                backgroundColor: Color(0xFF1C1C1E),
                thumbColor: Color(0xFF007AFF),
                groupValue: _selectedTab,
                children: {
                  0: Text(
                    'Aktiv (${_activeRentals.length})',
                    style: TextStyle(color: Colors.white),
                  ),
                  1: Text(
                    'Historie (${_rentalHistory.length})',
                    style: TextStyle(color: Colors.white),
                  ),
                },
                onValueChanged: (value) {
                  setState(() => _selectedTab = value!);
                },
              ),
            ),

            SizedBox(height: 24),

            Expanded(
              child:
                  _isLoading
                      ? Center(child: CupertinoActivityIndicator())
                      : _selectedTab == 0
                      ? _buildActiveRentals()
                      : _buildRentalHistory(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveRentals() {
    if (_activeRentals.isEmpty) {
      return Center(
        child: Text(
          'Keine aktiven Ausleihen',
          style: TextStyle(color: Colors.grey, fontSize: 18),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 24),
      itemCount: _activeRentals.length,
      itemBuilder: (context, index) {
        return _buildActiveRentalCard(_activeRentals[index]);
      },
    );
  }

  Widget _buildRentalHistory() {
    if (_rentalHistory.isEmpty) {
      return Center(
        child: Text(
          'Keine vergangenen Ausleihen',
          style: TextStyle(color: Colors.grey, fontSize: 18),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 24),
      itemCount: _rentalHistory.length,
      itemBuilder: (context, index) {
        final rental = _rentalHistory[index];
        return Container(
          margin: EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Color(0xFF38383A), width: 1),
          ),
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                rental.item.name,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Ausgeliehen: ${rental.rentalDate.toLocal().toIso8601String().split("T")[0]}',
              ),
              Text(
                'Zurückgegeben: ${rental.returnDate?.toLocal().toIso8601String().split("T")[0]}',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActiveRentalCard(Rental rental) {
    final isOverdue = rental.isOverdue;

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isOverdue
                  ? Color(0xFFFF453A).withOpacity(0.5)
                  : Color(0xFF007AFF).withOpacity(0.3),
          width: 1,
        ),
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  rental.item.name,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isOverdue ? Color(0xFFFF453A) : Color(0xFF007AFF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isOverdue ? 'Überfällig' : 'Aktiv',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Ende: ${rental.endDate.toLocal().toIso8601String().split("T")[0]}',
            style: TextStyle(color: Colors.grey),
          ),
          SizedBox(height: 12),

          // Buttons: Verlängern + Zurückgeben
          Row(
            children: [
              Expanded(
                child: CupertinoButton(
                  color: Color(0xFF32D74B),
                  padding: EdgeInsets.symmetric(vertical: 12),
                  borderRadius: BorderRadius.circular(12),
                  onPressed:
                      rental.extended
                          ? null
                          : () async {
                            try {
                              await ApiService.extendRental(rental.id);
                              _showAlert('Erfolg', '1 Monat verlängert');
                              _loadRentals();
                            } catch (e) {
                              _showAlert('Fehler', e.toString());
                            }
                          },
                  child: Text(
                    rental.extended
                        ? 'Bereits verlängert'
                        : '1 Monat verlängern',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: CupertinoButton(
                  color: Color(0xFFFF453A),
                  padding: EdgeInsets.symmetric(vertical: 12),
                  borderRadius: BorderRadius.circular(12),
                  onPressed: () async {
                    try {
                      await ApiService.returnRental(rental.id);
                      _showAlert('Erfolg', 'Item zurückgegeben');
                      _loadRentals();
                    } catch (e) {
                      _showAlert('Fehler', e.toString());
                    }
                  },
                  child: Text(
                    'Zurückgeben',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAlert(String title, String message) {
    showCupertinoDialog(
      context: context,
      builder:
          (context) => CupertinoAlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              CupertinoDialogAction(
                child: Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
    );
  }
}
