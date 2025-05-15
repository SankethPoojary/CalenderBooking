import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calendar Booking',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(vertical: 14),
            textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      home: BookingPage(),
    );
  }
}

class BookingPage extends StatefulWidget {
  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final TextEditingController userIdController = TextEditingController();
  DateTime? startTime;
  DateTime? endTime;

  List bookings = [];
  final String backendUrl = 'http://192.168.195.83:3000';

  String? editingBookingId;

  @override
  void initState() {
    super.initState();
    fetchBookings();
  }

  Future<void> fetchBookings() async {
    try {
      final response = await http.get(Uri.parse('$backendUrl/bookings'));
      if (response.statusCode == 200) {
        setState(() {
          bookings = jsonDecode(response.body);
        });
      } else {
        showMessage('Failed to load bookings', Colors.red);
      }
    } catch (e) {
      showMessage('Error fetching bookings', Colors.red);
    }
  }

  Future<void> createOrUpdateBooking() async {
    if (userIdController.text.isEmpty || startTime == null || endTime == null) {
      showMessage('Please fill all fields', Colors.red);
      return;
    }

    if (startTime!.isAfter(endTime!) || startTime!.isAtSameMomentAs(endTime!)) {
      showMessage('Start time must be before end time', Colors.red);
      return;
    }

    try {
      final url = editingBookingId == null
          ? Uri.parse('$backendUrl/bookings')
          : Uri.parse('$backendUrl/bookings/$editingBookingId');

      final response = editingBookingId == null
          ? await http.post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'userId': userIdController.text.trim(),
                'startTime': startTime!.toUtc().toIso8601String(),
                'endTime': endTime!.toUtc().toIso8601String(),
              }),
            )
          : await http.put(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'userId': userIdController.text.trim(),
                'startTime': startTime!.toUtc().toIso8601String(),
                'endTime': endTime!.toUtc().toIso8601String(),
              }),
            );

      if (response.statusCode == 201 || response.statusCode == 200) {
        showMessage(editingBookingId == null ? 'Booking created!' : 'Booking updated!', Colors.green);
        clearForm();
        fetchBookings();
      } else {
        final resBody = jsonDecode(response.body);
        showMessage(resBody['error'] ?? 'Failed to create/update booking', Colors.red);
      }
    } catch (e) {
      showMessage('Error creating/updating booking', Colors.red);
    }
  }

  Future<void> deleteBooking(String bookingId) async {
    try {
      final response = await http.delete(Uri.parse('$backendUrl/bookings/$bookingId'));
      if (response.statusCode == 200) {
        showMessage('Booking deleted', Colors.green);
        if (editingBookingId == bookingId) clearForm();
        fetchBookings();
      } else {
        showMessage('Failed to delete booking', Colors.red);
      }
    } catch (e) {
      showMessage('Error deleting booking', Colors.red);
    }
  }

  void clearForm() {
    userIdController.clear();
    startTime = null;
    endTime = null;
    editingBookingId = null;
    setState(() {});
  }

  void populateFormForEdit(Map booking) {
    userIdController.text = booking['userId'];
    startTime = DateTime.parse(booking['startTime']).toLocal();
    endTime = DateTime.parse(booking['endTime']).toLocal();
    editingBookingId = booking['id'];
    setState(() {});
  }

  void showMessage(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  Future<void> pickStartTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: startTime ?? DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime(2100),
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: startTime != null ? TimeOfDay.fromDateTime(startTime!) : TimeOfDay.now(),
    );
    if (time == null) return;

    setState(() {
      startTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> pickEndTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: endTime ?? (startTime ?? DateTime.now()).add(Duration(hours: 1)),
      firstDate: DateTime(2023),
      lastDate: DateTime(2100),
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: endTime != null ? TimeOfDay.fromDateTime(endTime!) : TimeOfDay.now(),
    );
    if (time == null) return;

    setState(() {
      endTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  String formatDateTime(DateTime? dt) {
    if (dt == null) return 'Select';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text('Calendar Booking'),
        centerTitle: true,
        elevation: 3,
        backgroundColor: Colors.indigo,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    TextField(
                      controller: userIdController,
                      decoration: InputDecoration(
                        labelText: 'User ID',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: pickStartTime,
                            icon: Icon(Icons.calendar_today),
                            label: Text('Start: ${formatDateTime(startTime)}'),
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: pickEndTime,
                            icon: Icon(Icons.calendar_today_outlined),
                            label: Text('End: ${formatDateTime(endTime)}'),
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: createOrUpdateBooking,
                      child: Text(
                        editingBookingId == null ? 'Create Booking' : 'Update Booking',
                        style: TextStyle(fontSize: 18),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                    if (editingBookingId != null)
                      TextButton(
                        onPressed: clearForm,
                        child: Text('Cancel Edit', style: TextStyle(color: Colors.grey.shade600)),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),
            Expanded(
              child: bookings.isEmpty
                  ? Center(
                      child: Text(
                        'No bookings yet',
                        style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                      ),
                    )
                  : ListView.separated(
                      itemCount: bookings.length,
                      separatorBuilder: (_, __) => SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final booking = bookings[index];
                        return Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 2,
                          child: ListTile(
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            title: Text(
                              'User: ${booking['userId']}',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Start: ${booking['startTime']}'),
                                  Text('End: ${booking['endTime']}'),
                                ],
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.edit, color: Colors.indigo),
                                  onPressed: () => populateFormForEdit(booking),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete, color: Colors.redAccent),
                                  onPressed: () => showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text('Delete Booking'),
                                      content: Text('Are you sure you want to delete this booking?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            deleteBooking(booking['id']);
                                            Navigator.pop(context);
                                          },
                                          child: Text('Delete', style: TextStyle(color: Colors.red)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );     
  }
}
