import 'package:flutter/material.dart';

class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  State<NotificationsSettingsScreen> createState() =>
      _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState
    extends State<NotificationsSettingsScreen> {
  // State variables for notification toggles
  bool _pushNotifications = true;
  bool _weatherAlerts = true;
  bool _fieldReminderActivities = true;
  bool _fieldRemindMeAt = false;
  bool _pestReminderActivities = true;
  bool _pestRemindMeAt = false;
  bool _coffeeManagementReminderActivities = true;
  bool _coffeeManagementRemindMeAt = false;

  // Placeholder DateTime variables for "Remind Me At"
  DateTime? _fieldReminderTime;
  DateTime? _pestReminderTime;
  DateTime? _coffeeManagementReminderTime;

  // Define coffee brown color consistent with CoffeeCore theme
  final Color coffeeBrown = Colors.brown[700]!;

  // Helper method to create a brown circle with an icon
  Widget _buildIcon(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: coffeeBrown,
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: 20,
      ),
    );
  }

  // Method to show a custom dialog for picking date and time
  Future<DateTime?> _showDateTimePickerDialog(BuildContext context) async {
    DateTime? selectedDate;
    TimeOfDay? selectedTime;

    return await showDialog<DateTime>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Select Date and Time'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: () async {
                  final DateTime? pickedDate = await showDatePicker(
                    context: dialogContext,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                  );
                  if (pickedDate != null) {
                    setState(() {
                      selectedDate = pickedDate;
                    });
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: coffeeBrown),
                child: const Text('Pick Date',
                    style: TextStyle(color: Colors.white)),
              ),
              if (selectedDate != null)
                Text(
                    'Selected Date: ${selectedDate.toString().substring(0, 10)}'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: selectedDate != null
                    ? () async {
                        final TimeOfDay? pickedTime = await showTimePicker(
                          context: dialogContext,
                          initialTime: TimeOfDay.now(),
                        );
                        if (pickedTime != null) {
                          setState(() {
                            selectedTime = pickedTime;
                          });
                        }
                      }
                    : null,
                style: ElevatedButton.styleFrom(backgroundColor: coffeeBrown),
                child: const Text('Pick Time',
                    style: TextStyle(color: Colors.white)),
              ),
              if (selectedTime != null)
                Text('Selected Time: ${selectedTime!.format(context)}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, null),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: (selectedDate != null && selectedTime != null)
                  ? () {
                      final DateTime combinedDateTime = DateTime(
                        selectedDate!.year,
                        selectedDate!.month,
                        selectedDate!.day,
                        selectedTime!.hour,
                        selectedTime!.minute,
                      );
                      Navigator.pop(dialogContext, combinedDateTime);
                    }
                  : null,
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }

  // Placeholder method to simulate getting reminder time from another section
  DateTime? _getReminderTimeFromSection(String section) {
    switch (section) {
      case 'field':
        return _fieldReminderActivities
            ? DateTime.now().add(const Duration(hours: 1))
            : null;
      case 'pest':
        return _pestReminderActivities
            ? DateTime.now().add(const Duration(hours: 2))
            : null;
      case 'coffeeManagement':
        return _coffeeManagementReminderActivities
            ? DateTime.now().add(const Duration(hours: 3))
            : null;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double cardWidth = screenWidth - 32.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notification Settings',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: coffeeBrown,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 4,
                child: SizedBox(
                  width: cardWidth,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'General Notifications',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: coffeeBrown,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SwitchListTile(
                          secondary: _buildIcon(Icons.notifications),
                          title: Text(
                            'Send Me Push Notifications',
                            style: TextStyle(color: coffeeBrown),
                          ),
                          value: _pushNotifications,
                          activeThumbColor: coffeeBrown,
                          onChanged: (bool value) {
                            setState(() {
                              _pushNotifications = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 4,
                child: SizedBox(
                  width: cardWidth,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Coffee Field Data Notifications',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: coffeeBrown,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SwitchListTile(
                          secondary: _buildIcon(Icons.cloud),
                          title: Text(
                            'Weather Alerts',
                            style: TextStyle(color: coffeeBrown),
                          ),
                          value: _weatherAlerts,
                          activeThumbColor: coffeeBrown,
                          onChanged: (bool value) {
                            setState(() {
                              _weatherAlerts = value;
                            });
                          },
                        ),
                        const Divider(height: 1, thickness: 1, indent: 50),
                        SwitchListTile(
                          secondary: _buildIcon(Icons.event),
                          title: Text(
                            'Remind Me About Field Activities',
                            style: TextStyle(color: coffeeBrown),
                          ),
                          value: _fieldReminderActivities,
                          activeThumbColor: coffeeBrown,
                          onChanged: (bool value) {
                            setState(() {
                              _fieldReminderActivities = value;
                              if (!value) _fieldRemindMeAt = false;
                            });
                          },
                        ),
                        const Divider(height: 1, thickness: 1, indent: 50),
                        ListTile(
                          leading: _buildIcon(Icons.access_time),
                          title: Text(
                            'Remind Me At${_fieldRemindMeAt && _fieldReminderTime != null ? ' ($_fieldReminderTime)' : ''}',
                            style: TextStyle(color: coffeeBrown),
                          ),
                          trailing: Switch(
                            value: _fieldRemindMeAt,
                            activeThumbColor: coffeeBrown,
                            onChanged: _fieldReminderActivities
                                ? (bool value) async {
                                    setState(() {
                                      _fieldRemindMeAt = value;
                                    });
                                    if (value) {
                                      if (_fieldReminderActivities) {
                                        final autoTime =
                                            _getReminderTimeFromSection(
                                                'field');
                                        if (autoTime != null) {
                                          setState(() {
                                            _fieldReminderTime = autoTime;
                                          });
                                        } else if (mounted) {
                                          final time =
                                              await _showDateTimePickerDialog(
                                                  context);
                                          if (time != null) {
                                            setState(() {
                                              _fieldReminderTime = time;
                                            });
                                          }
                                        }
                                      } else if (mounted) {
                                        final time =
                                            await _showDateTimePickerDialog(
                                                context);
                                        if (time != null) {
                                          setState(() {
                                            _fieldReminderTime = time;
                                          });
                                        }
                                      }
                                    } else {
                                      setState(() {
                                        _fieldReminderTime = null;
                                      });
                                    }
                                  }
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 4,
                child: SizedBox(
                  width: cardWidth,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Coffee Pest Management Notifications',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: coffeeBrown,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SwitchListTile(
                          secondary: _buildIcon(Icons.bug_report),
                          title: Text(
                            'Remind Me About Pest Activities',
                            style: TextStyle(color: coffeeBrown),
                          ),
                          value: _pestReminderActivities,
                          activeThumbColor: coffeeBrown,
                          onChanged: (bool value) {
                            setState(() {
                              _pestReminderActivities = value;
                              if (!value) _pestRemindMeAt = false;
                            });
                          },
                        ),
                        const Divider(height: 1, thickness: 1, indent: 50),
                        ListTile(
                          leading: _buildIcon(Icons.access_time),
                          title: Text(
                            'Remind Me At${_pestRemindMeAt && _pestReminderTime != null ? ' ($_pestReminderTime)' : ''}',
                            style: TextStyle(color: coffeeBrown),
                          ),
                          trailing: Switch(
                            value: _pestRemindMeAt,
                            activeThumbColor: coffeeBrown,
                            onChanged: _pestReminderActivities
                                ? (bool value) async {
                                    setState(() {
                                      _pestRemindMeAt = value;
                                    });
                                    if (value) {
                                      if (_pestReminderActivities) {
                                        final autoTime =
                                            _getReminderTimeFromSection('pest');
                                        if (autoTime != null) {
                                          setState(() {
                                            _pestReminderTime = autoTime;
                                          });
                                        } else if (mounted) {
                                          final time =
                                              await _showDateTimePickerDialog(
                                                  context);
                                          if (time != null) {
                                            setState(() {
                                              _pestReminderTime = time;
                                            });
                                          }
                                        }
                                      } else if (mounted) {
                                        final time =
                                            await _showDateTimePickerDialog(
                                                context);
                                        if (time != null) {
                                          setState(() {
                                            _pestReminderTime = time;
                                          });
                                        }
                                      }
                                    } else {
                                      setState(() {
                                        _pestReminderTime = null;
                                      });
                                    }
                                  }
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 4,
                child: SizedBox(
                  width: cardWidth,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Coffee Management Notifications',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: coffeeBrown,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SwitchListTile(
                          secondary: _buildIcon(Icons.local_cafe),
                          title: Text(
                            'Remind Me About Coffee Management Activities',
                            style: TextStyle(color: coffeeBrown),
                          ),
                          value: _coffeeManagementReminderActivities,
                          activeThumbColor: coffeeBrown,
                          onChanged: (bool value) {
                            setState(() {
                              _coffeeManagementReminderActivities = value;
                              if (!value) _coffeeManagementRemindMeAt = false;
                            });
                          },
                        ),
                        const Divider(height: 1, thickness: 1, indent: 50),
                        ListTile(
                          leading: _buildIcon(Icons.access_time),
                          title: Text(
                            'Remind Me At${_coffeeManagementRemindMeAt && _coffeeManagementReminderTime != null ? ' ($_coffeeManagementReminderTime)' : ''}',
                            style: TextStyle(color: coffeeBrown),
                          ),
                          trailing: Switch(
                            value: _coffeeManagementRemindMeAt,
                            activeThumbColor: coffeeBrown,
                            onChanged: _coffeeManagementReminderActivities
                                ? (bool value) async {
                                    setState(() {
                                      _coffeeManagementRemindMeAt = value;
                                    });
                                    if (value) {
                                      if (_coffeeManagementReminderActivities) {
                                        final autoTime =
                                            _getReminderTimeFromSection(
                                                'coffeeManagement');
                                        if (autoTime != null) {
                                          setState(() {
                                            _coffeeManagementReminderTime =
                                                autoTime;
                                          });
                                        } else if (mounted) {
                                          final time =
                                              await _showDateTimePickerDialog(
                                                  context);
                                          if (time != null) {
                                            setState(() {
                                              _coffeeManagementReminderTime =
                                                  time;
                                            });
                                          }
                                        }
                                      } else if (mounted) {
                                        final time =
                                            await _showDateTimePickerDialog(
                                                context);
                                        if (time != null) {
                                          setState(() {
                                            _coffeeManagementReminderTime =
                                                time;
                                          });
                                        }
                                      }
                                    } else {
                                      setState(() {
                                        _coffeeManagementReminderTime = null;
                                      });
                                    }
                                  }
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
