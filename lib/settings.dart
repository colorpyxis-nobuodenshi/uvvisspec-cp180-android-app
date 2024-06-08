import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'uvvisspec.dart';

  class NumericRangeFormatter extends TextInputFormatter {
 
    final int min;
    final int max;
 
    NumericRangeFormatter({required this.min, required this.max});
 
    @override
    TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
    ) {
      if (newValue.text.isEmpty) {
        return newValue;
      }
 
      final newValueNumber = int.tryParse(newValue.text);
 
      if (newValueNumber == null) {
        return oldValue;
      }
 
      if (newValueNumber < min) {
        return newValue.copyWith(text: min.toString());
      } else if (newValueNumber > max) {
        return newValue.copyWith(text: max.toString());
      } else {
        return newValue;
      }
    }
  }

class SettingsPage extends StatefulWidget {
  //const SettingsPage({Key? key}) : super(key: key);
  SettingsPage(this.settings);
  Settings settings;
  @override
  State<StatefulWidget> createState() {
    return SettingsPageState();
  }
}

class SettingsPageState extends State<SettingsPage> {
  var _wlSumMin = "";
  var _wlSumMax = "";
  var _wlRangeValues = const RangeValues(0.2, 0.44);
  var _exposuretime = "";
  var _integ = "";
  var _integTec = TextEditingController();
  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    final settings = widget.settings;
    _wlSumMin = settings.sumRangeMin.toInt().toString();
    _wlSumMax = settings.sumRangeMax.toInt().toString();
    _wlRangeValues = RangeValues(
        settings.sumRangeMin / 1000.0, settings.sumRangeMax / 1000.0);
    _integ = settings.integ.toString();
    setState(() {
      _exposuretime = settings.deviceExposureTime;
      _integTec = TextEditingController(text: _integ);
      _integTec.selection =
          TextSelection.fromPosition(TextPosition(offset: _integ.length));
    });
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () {
        Settings s = Settings();
        s.sumRangeMin = double.parse(_wlSumMin);
        s.sumRangeMax = double.parse(_wlSumMax);
        s.deviceExposureTime = _exposuretime;
        s.integ = int.parse(_integTec.text.trim());
        Navigator.of(context).pop(s);

        return Future.value(false);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('設定'),
          actions: <Widget>[
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => {},
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              Column(
                children: [
                  Card(
                    child: Column(
                      children: <Widget>[
                        const Text("測定波長囲"),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Column(
                              children: [
                                const Text("短波長端"),
                                Text(
                                  _wlSumMin,
                                  style: const TextStyle(fontSize: 20),
                                ),
                              ],
                            ),
                            ElevatedButton(
                              child: const Text('リセット'),
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white, backgroundColor: Colors.blueGrey,
                              ),
                              onPressed: () {
                                setState(() {
                                  _wlRangeValues = const RangeValues(0.2, 0.44);
                                  _wlSumMin = (_wlRangeValues.start * 1000)
                                      .toInt()
                                      .toString();
                                  _wlSumMax = (_wlRangeValues.end * 1000)
                                      .toInt()
                                      .toString();
                                });
                              },
                            ),
                            Column(
                              children: [
                                const Text("長波長端"),
                                Text(
                                  _wlSumMax,
                                  style: const TextStyle(fontSize: 20),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Center(
                          child: RangeSlider(
                            values: _wlRangeValues,
                            activeColor: Colors.blueGrey,
                            inactiveColor: Colors.blueGrey.shade800,
                            onChanged: (values) {
                              setState(() {
                                _wlRangeValues = values;
                                _wlSumMin = ((_wlRangeValues.start * 100).round()*10)
                                    .toInt()
                                    .toString();
                                _wlSumMax = ((_wlRangeValues.end * 100).round()*10)
                                    .toInt()
                                    .toString();
                              });
                            },
                            min: 0.2,
                            max: 0.44,
                            divisions: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Card(
                    child: Column(
                      children: <Widget>[
                        const Text("時間積算"),
                        TextField(
                          controller: _integTec,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            NumericRangeFormatter(min: 1, max: 600)
                          ],
                        ),
                        const Text("Sec")
                      ],
                    ),
                  ),
                  Card(
                    child: Column(
                      children: <Widget>[
                        const Text("露光時間"),
                        RadioListTile(
                            title: const Text("AUTO"),
                            value: "AUTO",
                            groupValue: _exposuretime,
                            onChanged: (value) => {
                                  setState(
                                      () => {_exposuretime = value.toString()})
                                }),
                        RadioListTile(
                            title: const Text("100us"),
                            value: "100us",
                            groupValue: _exposuretime,
                            onChanged: (value) => {
                                  setState(
                                      () => {_exposuretime = value.toString()})
                                }),
                        RadioListTile(
                            title: const Text("1ms"),
                            value: "1ms",
                            groupValue: _exposuretime,
                            onChanged: (value) => {
                                  setState(
                                      () => {_exposuretime = value.toString()})
                                }),
                        RadioListTile(
                            title: const Text("10ms"),
                            value: "10ms",
                            groupValue: _exposuretime,
                            onChanged: (value) => {
                                  setState(
                                      () => {_exposuretime = value.toString()})
                                }),
                        RadioListTile(
                            title: const Text("100ms"),
                            value: "100ms",
                            groupValue: _exposuretime,
                            onChanged: (value) => {
                                  setState(
                                      () => {_exposuretime = value.toString()})
                                }),
                      ],
                    ),
                  ),
                ],
              ),
              Card(
                child: ListTile(
                  title: const Text("このアプリの情報について"),
                  onTap: (){
                    showLicensePage(
                      context: context,
                      applicationName: "分光放射照度計CP180",
                      applicationVersion: "1.0.0",
                      // applicationIcon: MyAppIcon(),
                      applicationLegalese:
                          "\u{a9} 2023 NOBUO ELECTRONICS CO., LTD.",
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
