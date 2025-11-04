import 'package:flutter/material.dart';
import '../services/device_manager.dart';
import 'firebase_test_screen.dart';

class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  late DeviceManagerService _deviceManager;

  // Light and AC data structures
  List<LightDevice> _lights = [
    LightDevice(
      id: '1',
      name: 'Office Lights Zone 1',
      isOn: true,
      brightness: 70,
      location: 'Main Office',
      color: Colors.white,
    ),
    LightDevice(
      id: '2',
      name: 'Office Lights Zone 2',
      isOn: true,
      brightness: 70,
      location: 'Meeting Room',
      color: Colors.white,
    ),
    LightDevice(
      id: '3',
      name: 'Office Lights Zone 3',
      isOn: false,
      brightness: 0,
      location: 'Break Room',
      color: Colors.white,
    ),
  ];

  List<AirConditionerDevice> _airConditioners = [
    AirConditionerDevice(
      id: '1',
      name: 'Office AC Unit 1',
      isOn: true,
      temperature: 24,
      mode: 'Auto',
      location: 'Main Office',
      fanSpeed: 'Medium',
    ),
    AirConditionerDevice(
      id: '2',
      name: 'Office AC Unit 2',
      isOn: true,
      temperature: 26,
      mode: 'Eco',
      location: 'Conference Room',
      fanSpeed: 'Low',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _deviceManager = DeviceManagerService();
    _deviceManager.addListener(_updateUI);
    _syncWithDeviceManager();
  }

  @override
  void dispose() {
    _deviceManager.removeListener(_updateUI);
    super.dispose();
  }

  void _updateUI() {
    setState(() {});
  }

  void _syncWithDeviceManager() {
    // Sync light states with device manager
    for (var light in _lights) {
      final level = _deviceManager.getLightLevel('Office Lights');
      final brightness = _getLightBrightnessFromLevel(level);
      final isOn = level != 'Off';

      if (light.brightness != brightness || light.isOn != isOn) {
        final index = _lights.indexWhere((l) => l.id == light.id);
        if (index != -1) {
          _lights[index] = light.copyWith(
            brightness: brightness,
            isOn: isOn,
          );
        }
      }
    }

    // Sync AC states with device manager
    final temp1 =
        _deviceManager.getAirConditionerTemperature('Office AC Unit 1');
    final temp2 =
        _deviceManager.getAirConditionerTemperature('Office AC Unit 2');
    final mode1 = _deviceManager.getAirConditionerMode('Office AC Unit 1');
    final mode2 = _deviceManager.getAirConditionerMode('Office AC Unit 2');
    final state1 = _deviceManager.getAirConditionerState('Office AC Unit 1');
    final state2 = _deviceManager.getAirConditionerState('Office AC Unit 2');

    if (_airConditioners[0].temperature != temp1.toInt() ||
        _airConditioners[0].mode != mode1 ||
        _airConditioners[0].isOn != state1) {
      _airConditioners[0] = _airConditioners[0].copyWith(
        temperature: temp1.toInt(),
        mode: mode1,
        isOn: state1,
      );
    }
    if (_airConditioners[1].temperature != temp2.toInt() ||
        _airConditioners[1].mode != mode2 ||
        _airConditioners[1].isOn != state2) {
      _airConditioners[1] = _airConditioners[1].copyWith(
        temperature: temp2.toInt(),
        mode: mode2,
        isOn: state2,
      );
    }
  }

  int _getLightBrightnessFromLevel(String level) {
    switch (level) {
      case 'Off':
        return 0;
      case 'Level 1':
        return 30;
      case 'Level 2':
        return 70;
      case 'Level 3':
        return 100;
      default:
        return 70;
    }
  }

  String _getLevelFromBrightness(int brightness) {
    if (brightness == 0) return 'Off';
    if (brightness <= 30) return 'Level 1';
    if (brightness <= 70) return 'Level 2';
    return 'Level 3';
  }

  @override
  Widget build(BuildContext context) {
    // Responsive breakpoints
    final screenWidth = MediaQuery.of(context).size.width;
    final isWebDemo = screenWidth > 800; // Web demo mode
    final isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isWebDemo ? 24 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isWebDemo, isMobile),
              SizedBox(height: isWebDemo ? 32 : 24),
              _buildLightsSection(isWebDemo, isMobile),
              SizedBox(height: isWebDemo ? 32 : 24),
              _buildAirConditionersSection(isWebDemo, isMobile),
              SizedBox(height: isWebDemo ? 32 : 80), // Extra space for mobile
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isWebDemo, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isWebDemo ? 24 : 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isWebDemo ? 12 : 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.settings,
              color: Colors.white,
              size: isWebDemo ? 28 : 24,
            ),
          ),
          SizedBox(width: isWebDemo ? 16 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Device Control',
                  style: TextStyle(
                    fontSize: isWebDemo ? 28 : 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: isWebDemo ? 8 : 4),
                Text(
                  'Manage your office devices',
                  style: TextStyle(
                    fontSize: isWebDemo ? 16 : 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLightsSection(bool isWebDemo, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.lightbulb,
              color: const Color(0xFF8B5CF6),
              size: isWebDemo ? 28 : 24,
            ),
            SizedBox(width: isWebDemo ? 12 : 8),
            Text(
              'Lights Control',
              style: TextStyle(
                fontSize: isWebDemo ? 24 : 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1F2937),
              ),
            ),
          ],
        ),
        // small action buttons on the right (firebase test)
        Row(
          children: [
            IconButton(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const _FirebaseTestLauncher()));
              },
              icon: const Icon(Icons.cloud_upload, color: Colors.white),
              tooltip: 'Open Firebase Test',
            ),
          ],
        ),
        SizedBox(height: isWebDemo ? 16 : 12),

        // Responsive grid for lights
        if (isWebDemo)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 3 : 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.1,
            ),
            itemCount: _lights.length,
            itemBuilder: (context, index) =>
                _buildLightCard(_lights[index], isWebDemo, isMobile),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _lights.length,
            itemBuilder: (context, index) => Padding(
              padding: EdgeInsets.only(bottom: isWebDemo ? 16 : 12),
              child: _buildLightCard(_lights[index], isWebDemo, isMobile),
            ),
          ),
      ],
    );
  }

  Widget _buildAirConditionersSection(bool isWebDemo, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.ac_unit,
              color: const Color(0xFF06B6D4),
              size: isWebDemo ? 28 : 24,
            ),
            SizedBox(width: isWebDemo ? 12 : 8),
            Text(
              'Air Conditioners',
              style: TextStyle(
                fontSize: isWebDemo ? 24 : 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1F2937),
              ),
            ),
          ],
        ),
        SizedBox(height: isWebDemo ? 16 : 12),

        // Responsive grid for ACs
        if (isWebDemo && _airConditioners.length > 1)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.1,
            ),
            itemCount: _airConditioners.length,
            itemBuilder: (context, index) => _buildAirConditionerCard(
                _airConditioners[index], isWebDemo, isMobile),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _airConditioners.length,
            itemBuilder: (context, index) => Padding(
              padding: EdgeInsets.only(bottom: isWebDemo ? 16 : 12),
              child: _buildAirConditionerCard(
                  _airConditioners[index], isWebDemo, isMobile),
            ),
          ),
      ],
    );
  }

  Widget _buildLightCard(LightDevice light, bool isWebDemo, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isWebDemo ? 20 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: light.isOn ? const Color(0xFF8B5CF6) : Colors.grey.shade300,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with title and action buttons
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      light.name,
                      style: TextStyle(
                        fontSize: isWebDemo ? 18 : 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1F2937),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: isWebDemo ? 4 : 2),
                    Text(
                      light.location,
                      style: TextStyle(
                        fontSize: isWebDemo ? 12 : 11,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Edit and Delete buttons
              Flexible(
                flex: 1,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => _editLight(light),
                      icon: const Icon(Icons.edit),
                      iconSize: isWebDemo ? 18 : 16,
                      color: const Color(0xFF8B5CF6),
                      tooltip: 'Edit Light',
                      padding: EdgeInsets.all(isMobile ? 4 : 8),
                      constraints: BoxConstraints(
                        minWidth: isMobile ? 28 : 36,
                        minHeight: isMobile ? 28 : 36,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _deleteLight(light),
                      icon: const Icon(Icons.delete),
                      iconSize: isWebDemo ? 18 : 16,
                      color: Colors.red.shade400,
                      tooltip: 'Remove Light',
                      padding: EdgeInsets.all(isMobile ? 4 : 8),
                      constraints: BoxConstraints(
                        minWidth: isMobile ? 28 : 36,
                        minHeight: isMobile ? 28 : 36,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: isWebDemo ? 16 : 12),

          // On/Off Switch
          Row(
            children: [
              Transform.scale(
                scale: isWebDemo ? 1.0 : 0.8,
                child: Switch(
                  value: light.isOn,
                  onChanged: (value) => _toggleLight(light, value),
                  activeColor: const Color(0xFF8B5CF6),
                ),
              ),
              SizedBox(width: isWebDemo ? 8 : 4),
              Expanded(
                child: Text(
                  light.isOn ? 'On' : 'Off',
                  style: TextStyle(
                    fontSize: isWebDemo ? 14 : 12,
                    fontWeight: FontWeight.w500,
                    color: light.isOn
                        ? const Color(0xFF10B981)
                        : Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),

          if (light.isOn) ...[
            SizedBox(height: isWebDemo ? 16 : 12),

            // Brightness control
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Brightness: ${light.brightness}%',
                  style: TextStyle(
                    fontSize: isWebDemo ? 12 : 11,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF1F2937),
                  ),
                ),
                SizedBox(height: isWebDemo ? 8 : 4),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: isWebDemo ? 6 : 4,
                    thumbShape: RoundSliderThumbShape(
                      enabledThumbRadius: isWebDemo ? 10 : 8,
                    ),
                  ),
                  child: Slider(
                    value: light.brightness.toDouble(),
                    min: 0,
                    max: 100,
                    divisions: 20,
                    activeColor: const Color(0xFF8B5CF6),
                    onChanged: (value) =>
                        _changeBrightness(light, value.round()),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAirConditionerCard(
      AirConditionerDevice ac, bool isWebDemo, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isWebDemo ? 20 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ac.isOn ? const Color(0xFF06B6D4) : Colors.grey.shade300,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with title and action buttons
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ac.name,
                      style: TextStyle(
                        fontSize: isWebDemo ? 18 : 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1F2937),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: isWebDemo ? 4 : 2),
                    Text(
                      ac.location,
                      style: TextStyle(
                        fontSize: isWebDemo ? 12 : 11,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Edit and Delete buttons
              Flexible(
                flex: 1,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => _editAirConditioner(ac),
                      icon: const Icon(Icons.edit),
                      iconSize: isWebDemo ? 18 : 16,
                      color: const Color(0xFF06B6D4),
                      tooltip: 'Edit AC',
                      padding: EdgeInsets.all(isMobile ? 4 : 8),
                      constraints: BoxConstraints(
                        minWidth: isMobile ? 28 : 36,
                        minHeight: isMobile ? 28 : 36,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _deleteAirConditioner(ac),
                      icon: const Icon(Icons.delete),
                      iconSize: isWebDemo ? 18 : 16,
                      color: Colors.red.shade400,
                      tooltip: 'Remove AC',
                      padding: EdgeInsets.all(isMobile ? 4 : 8),
                      constraints: BoxConstraints(
                        minWidth: isMobile ? 28 : 36,
                        minHeight: isMobile ? 28 : 36,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: isWebDemo ? 16 : 12),

          // On/Off Switch
          Row(
            children: [
              Transform.scale(
                scale: isWebDemo ? 1.0 : 0.8,
                child: Switch(
                  value: ac.isOn,
                  onChanged: (value) => _toggleAirConditioner(ac, value),
                  activeColor: const Color(0xFF06B6D4),
                ),
              ),
              SizedBox(width: isWebDemo ? 8 : 4),
              Expanded(
                child: Text(
                  ac.isOn ? 'On' : 'Off',
                  style: TextStyle(
                    fontSize: isWebDemo ? 14 : 12,
                    fontWeight: FontWeight.w500,
                    color: ac.isOn
                        ? const Color(0xFF10B981)
                        : Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),

          if (ac.isOn) ...[
            SizedBox(height: isWebDemo ? 16 : 12),

            // Temperature control
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Temperature',
                        style: TextStyle(
                          fontSize: isWebDemo ? 12 : 11,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF1F2937),
                        ),
                      ),
                      SizedBox(height: isWebDemo ? 4 : 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF06B6D4).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${ac.temperature}°C',
                          style: TextStyle(
                            fontSize: isWebDemo ? 16 : 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF06B6D4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: isWebDemo ? 16 : 8),
                Column(
                  children: [
                    IconButton(
                      onPressed: () =>
                          _changeTemperature(ac, ac.temperature + 1),
                      icon: const Icon(Icons.add),
                      iconSize: isWebDemo ? 20 : 16,
                      color: const Color(0xFF06B6D4),
                      constraints: BoxConstraints(
                        minWidth: isMobile ? 32 : 40,
                        minHeight: isMobile ? 32 : 40,
                      ),
                    ),
                    IconButton(
                      onPressed: () =>
                          _changeTemperature(ac, ac.temperature - 1),
                      icon: const Icon(Icons.remove),
                      iconSize: isWebDemo ? 20 : 16,
                      color: const Color(0xFF06B6D4),
                      constraints: BoxConstraints(
                        minWidth: isMobile ? 32 : 40,
                        minHeight: isMobile ? 32 : 40,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            SizedBox(height: isWebDemo ? 12 : 8),

            // Mode Selection
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mode',
                  style: TextStyle(
                    fontSize: isWebDemo ? 12 : 11,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF1F2937),
                  ),
                ),
                SizedBox(height: isWebDemo ? 4 : 2),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButton<String>(
                    value: ac.mode,
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: ['Heat', 'Cool', 'Eco', 'Dry'].map((mode) {
                      return DropdownMenuItem(
                        value: mode,
                        child: Text(
                          mode,
                          style: TextStyle(
                            fontSize: isWebDemo ? 13 : 12,
                            color: const Color(0xFF1F2937),
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        _changeMode(ac, value);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // Light control methods
  void _toggleLight(LightDevice light, bool isOn) {
    setState(() {
      final index = _lights.indexWhere((l) => l.id == light.id);
      if (index != -1) {
        _lights[index] = light.copyWith(isOn: isOn);

        // Sync with device manager
        _deviceManager.updateLightState('Office Lights', isOn);
        if (isOn) {
          final level = _getLevelFromBrightness(_lights[index].brightness);
          _deviceManager.updateLightLevel('Office Lights', level);
        } else {
          _deviceManager.updateLightLevel('Office Lights', 'Off');
        }
        _syncWithDeviceManager();
      }
    });
  }

  void _changeBrightness(LightDevice light, int brightness) {
    setState(() {
      final index = _lights.indexWhere((l) => l.id == light.id);
      if (index != -1) {
        _lights[index] = light.copyWith(brightness: brightness);

        // Sync with device manager
        final level = _getLevelFromBrightness(brightness);
        _deviceManager.updateLightLevel('Office Lights', level);
      }
    });
  }

  void _editLight(LightDevice light) {
    // TODO: Implement edit light dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Edit ${light.name}'),
        backgroundColor: const Color(0xFF8B5CF6),
      ),
    );
  }

  void _deleteLight(LightDevice light) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Light'),
        content: Text('Are you sure you want to remove "${light.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _lights.removeWhere((l) => l.id == light.id);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Light removed successfully'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Air conditioner control methods
  void _toggleAirConditioner(AirConditionerDevice ac, bool isOn) {
    setState(() {
      final index = _airConditioners.indexWhere((a) => a.id == ac.id);
      if (index != -1) {
        _airConditioners[index] = ac.copyWith(isOn: isOn);

        // Sync with device manager
        _deviceManager.updateAirConditionerState(ac.name, isOn);
        _syncWithDeviceManager();
      }
    });
  }

  void _changeTemperature(AirConditionerDevice ac, int temperature) {
    if (temperature >= 16 && temperature <= 30) {
      setState(() {
        final index = _airConditioners.indexWhere((a) => a.id == ac.id);
        if (index != -1) {
          _airConditioners[index] = ac.copyWith(temperature: temperature);

          // Sync with device manager
          _deviceManager.updateAirConditionerTemperature(
              ac.name, temperature.toDouble());
        }
      });
    }
  }

  void _changeMode(AirConditionerDevice ac, String mode) {
    setState(() {
      final index = _airConditioners.indexWhere((a) => a.id == ac.id);
      if (index != -1) {
        _airConditioners[index] = ac.copyWith(mode: mode);

        // Sync with device manager
        _deviceManager.updateAirConditionerMode(ac.name, mode);
        _syncWithDeviceManager();
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${ac.name} mode changed to $mode'),
        backgroundColor: const Color(0xFF06B6D4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _editAirConditioner(AirConditionerDevice ac) {
    // TODO: Implement edit AC dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Edit ${ac.name}'),
        backgroundColor: const Color(0xFF06B6D4),
      ),
    );
  }

  void _deleteAirConditioner(AirConditionerDevice ac) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Air Conditioner'),
        content: Text('Are you sure you want to remove "${ac.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _airConditioners.removeWhere((a) => a.id == ac.id);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Air conditioner removed successfully'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// Small launcher to avoid importing the test screen everywhere
class _FirebaseTestLauncher extends StatelessWidget {
  const _FirebaseTestLauncher();

  @override
  Widget build(BuildContext context) {
    // Lazy import the test screen when pushed to avoid extra dependencies on main flow
    return FutureBuilder(
      future: Future.delayed(Duration.zero),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        // Use MaterialPageRoute to push the actual test screen
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const _FirebaseTestRedirect()));
        });
        return const SizedBox.shrink();
      },
    );
  }
}

class _FirebaseTestRedirect extends StatelessWidget {
  const _FirebaseTestRedirect();

  @override
  Widget build(BuildContext context) {
    // Import here to avoid static import at top
    return const _FirebaseTestHost();
  }
}

// Host that actually constructs the test screen. Kept private to avoid polluting imports.
class _FirebaseTestHost extends StatelessWidget {
  const _FirebaseTestHost();

  @override
  Widget build(BuildContext context) {
    // Directly return the screen defined in separate file
    return const FirebaseTestScreen();
  }
}

// Light device model
class LightDevice {
  final String id;
  final String name;
  final String location;
  final bool isOn;
  final int brightness;
  final Color color;

  LightDevice({
    required this.id,
    required this.name,
    required this.location,
    required this.isOn,
    required this.brightness,
    required this.color,
  });

  LightDevice copyWith({
    String? id,
    String? name,
    String? location,
    bool? isOn,
    int? brightness,
    Color? color,
  }) {
    return LightDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      isOn: isOn ?? this.isOn,
      brightness: brightness ?? this.brightness,
      color: color ?? this.color,
    );
  }
}

// Air conditioner device model
class AirConditionerDevice {
  final String id;
  final String name;
  final String location;
  final bool isOn;
  final int temperature;
  final String mode;
  final String fanSpeed;

  AirConditionerDevice({
    required this.id,
    required this.name,
    required this.location,
    required this.isOn,
    required this.temperature,
    required this.mode,
    required this.fanSpeed,
  });

  AirConditionerDevice copyWith({
    String? id,
    String? name,
    String? location,
    bool? isOn,
    int? temperature,
    String? mode,
    String? fanSpeed,
  }) {
    return AirConditionerDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      isOn: isOn ?? this.isOn,
      temperature: temperature ?? this.temperature,
      mode: mode ?? this.mode,
      fanSpeed: fanSpeed ?? this.fanSpeed,
    );
  }
}
