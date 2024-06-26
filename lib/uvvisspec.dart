import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';
import 'dart:async';
import 'dart:convert';
import 'package:rxdart/rxdart.dart';
import 'package:usb_serial/usb_serial.dart';
import 'package:usb_serial/transaction.dart';

//
class ResultReport {
  List<double> sp = [];
  List<double> wl = [];
  double pwl = 0.0;
  double ir = 0.0;
  double pp = 0.0;
  List<double> spRaw = [];
  List<double> wlRaw = [];
  double wlRangeMin = 200;
  double wlRangeMax = 440;
  int integ = 1;
  double ai = 0.0;
  String measureDatetime = "";
  //String unit = "W\u2219m\u207B\u00B2\u2219nm\u207B\u00B9";
}

// Map<Unit, String> unitMap = {
//   Unit.w : "W/m2",
//   Unit.photon : "photons/m2/s",
//   Unit.mol : "umol/m2/s",
// };

class Settings {
  double sumRangeMin = 200;
  double sumRangeMax = 440;
  String deviceExposureTime = "AUTO";
  int integ = 1;
}

// enum Unit {
//   w,
//   photon,
//   mol
// }

class UVVisSpecResultConverter {
  Future<ResultReport> execute(Settings settings, UVVisSpecDeviceResult result) async {

    var report = ResultReport();

    final integ = settings.integ;
    var ai = 0.0;
    final wl = [...result.wl];
    var sp = [...result.sp];
    var sp2 = [...sp];
    final l1 = settings.sumRangeMin;
    final l2 = settings.sumRangeMax;
    for(var i=0; i<wl.length; i++) {
      if(wl[i] < l1){
        sp2[i] = 0;
      }
      if(wl[i] > l2){
        sp2[i] = 0;
      }
    }
    var pp = sp2.reduce(max);
    var pwl = wl[sp2.indexWhere((x) => (x == pp))];
    var ir = 0.0;

    for(var i=0; i<wl.length; i++) {
      ir += sp2[i];
    }
    ai = ir * integ;
    report.sp = sp;
    report.wl = wl;
    report.ir = ir;
    report.pp = pp;
    report.pwl = pwl;
    report.ai = ai;
    report.wlRangeMin = l1;
    report.wlRangeMax = l2;

    return report;
  }
  Future<UVVisSpecDeviceResult> average(List<UVVisSpecDeviceResult> results) async {
    var splist = results.map((e) => e.sp).toList();
    var len = splist.first.length;
    var n = results.length;
    var sp = [...results.first.sp];
    var wl = [...results.first.wl];
    for(var i = 0; i < len; i++) {
      sp[i] = 0.0;
      for(var j = 0; j < n; j++) {
        sp[i] += splist[j][i];
      }
      sp[i] /= n;
    }
    //var ai = results.map((e) => e.ir).reduce((value, element) => value + element);
    var pp = sp.reduce(max);
    var pwl = wl[sp.indexWhere((x) => (x == pp))];
    var ir = 0.0;
    for(var i=0; i<wl.length; i++) {
      ir += sp[i];
    }
    var value = UVVisSpecDeviceResult();
    value.sp = sp;
    value.wl = wl;
    value.ir = ir;
    value.pp = pp;
    value.pwl = pwl;
    
    return value;
  }
}


class UVVisSpecDeviceResult {
  List<double> sp = [];
  List<double> wl = [];
  double pwl = 0.0;
  double ir = 0.0;
  double pp = 0.0;
  List<double> spRaw = [];
  List<double> wlRaw = [];
}

class UVVisSpecDeviceStatus {
  bool detached = false;
  bool connected = false;
  bool measurestarted = false;
  bool measurestopped = false;
  bool darkcorrected = false;
  bool deviceerror = false;
  bool devicewarn = false;
}

class UvVisSpecDevice {
  UsbPort? _port;
  Transaction<String>? _transaction;
  //Timer? _timer;

  final _status = UVVisSpecDeviceStatus();
  final _resultSubject = PublishSubject<UVVisSpecDeviceResult>();
  final _statusSubject = PublishSubject<UVVisSpecDeviceStatus>();
  //bool _measuring = false;

  Future<void> initialize() async {

    UsbSerial.usbEventStream!.listen((UsbEvent event) async {
      if(event.event == UsbEvent.ACTION_USB_ATTACHED) {
        _statusSubject.add(_status);
        var devices = await UsbSerial.listDevices();
        for(var device in devices){
          var res = await _connectTo(device);
          if(res) {
            _status.connected = true;
            _status.detached = false;
            _statusSubject.add(_status);
          }
        }
        
      }
      if(event.event == UsbEvent.ACTION_USB_DETACHED) {
        _status.connected = false;
        _status.detached = true;
        _statusSubject.add(_status);
      }
      
    });

    var devices = await UsbSerial.listDevices();
    for(var device in devices){
      var res = await _connectTo(device);
      if(res) {
        _status.connected = true;
        _status.detached = false;
        _statusSubject.add(_status);
      }
    }
  }

  Future<void> deinitialize() async {
    await measStop();
    //_timer?.cancel();
    await _connectTo(null);
  }

  // Future<void> measStart() async {  
  //   if(_status.connected == false) {
  //     return;
  //   }
  //   _timer = Timer.periodic(const Duration(milliseconds:200),
  //    (timer) async {

  //       if(_measuring) {
  //         return;
  //       }

  //       if(_status.measurestopped){
  //         timer.cancel();
  //         return;
  //       }

  //       if(_status.measurestarted){
  //         _measuring = true;
  //         await meas();
  //         await status();
  //         _measuring = false;
  //       }
        
  //     });

  //   _status.measurestarted = true;
  //   _status.measurestopped = false;
  //   _statusSubject.add(_status);
  // }

  // Future<void> measStop() async {
  //   _status.measurestarted = false;
  //   _status.measurestopped = true;
  //   _statusSubject.add(_status);
  // }

  Future<void> meas() async {
    try
    {
      var res = await _transaction?.transaction(_port!, const AsciiEncoder().convert('MEAS\n'), const Duration(seconds: 60));
      if(res == null) {
        _status.detached = true;
        _statusSubject.add(_status);
        return;
      }
      var values = res.split('\r');
      var len = values.length - 1;
      var wl = <double>[];
      var p = <double>[];  
      for(var i=0;i<len;i++)
      {
        var values2 = values[i].split(':');
        wl.add(double.parse(values2[0]));
        p.add(double.parse(values2[1]));
        if(p[i] < 1e-9){
          p[i] = 0.0;
        }
      }

      var r = _correct(wl, p);
      var wl2 = r[0];
      var p2 = r[1];
      var pp = p2.reduce(max);
      var pwl = wl2[p2.indexWhere((x) => (x == pp))];
      var ir = 0.0;
      for(var i=0; i<wl2.length; i++) {
        ir += p2[i];
      }

      var result = UVVisSpecDeviceResult();
      result.wlRaw = wl;
      result.spRaw = p;
      result.ir = ir;
      result.pwl = pwl;
      result.sp = p2;
      result.wl = wl2;
      result.pp = pp;
      _resultSubject.add(result);
    }
    catch(e)
    {
      return;
    }
  }

  Future<void> dark() async {
    var res = await _transaction?.transaction(_port!, const AsciiEncoder().convert('DARK\n'), const Duration(seconds: 60));
  }

  Future<void> status() async {
    var res = await _transaction?.transaction(_port!, const AsciiEncoder().convert('ST?\n'), const Duration(seconds: 60));
    var v = res?.split('/')[1].split(':');
    if(v != null) {
      var status = v[0];//int.parse(v[0]);
      //var temperature = double.parse(v[1]);
      _status.devicewarn = status == "W" ? true : false;
      _status.deviceerror = status == "E" ? true : false;
      _statusSubject.add(_status);
    }

  }
  
  Future<void> changeExposureTime(String exp) async {
    var msg = "EXP/100us\n";
    switch (exp) {
      case "AUTO":
        msg = "EXP/AUTO\n";
        break;
      case "100us":
        msg = "EXP/100us\n";
        break;
      case "1ms":
        msg = "EXP/1ms\n";
        break;
      case "10ms":
        msg = "EXP/10ms\n";
        break;
      case "100ms":
        msg = "EXP/100ms\n";
        break;
      default:
    }
    var res = await _transaction?.transaction(_port!, const AsciiEncoder().convert(msg), const Duration(seconds: 60));
  }

  Stream<UVVisSpecDeviceResult> get resultStream {
    return _resultSubject.stream;
  }

  Stream<UVVisSpecDeviceStatus> get statusStream {
    return _statusSubject.stream;
  }

  Future<bool> _connectTo(UsbDevice? device) async {

    if (_transaction != null) {
      _transaction?.dispose();
      _transaction = null;
    }

    if (_port != null) {
      _port?.close();
      _port = null;
    }

    if (device == null) {
      return false;
    }

    _port = await device.create();
    var res = await _port?.open();
    if (res == null || res == false) {
      return false;
    }

    await _port?.setDTR(false);
    await _port?.setRTS(false);
    await _port?.setPortParameters(
        9600, UsbPort.DATABITS_8, UsbPort.STOPBITS_1, UsbPort.PARITY_NONE);

    _transaction = Transaction.stringTerminated(
        (_port!.inputStream) as Stream<Uint8List>, Uint8List.fromList([10]));

    

    var res5 = await _transaction?.transaction(_port!, const AsciiEncoder().convert('EXP/AUTO\n'), const Duration(seconds: 1));
    
    return true;
  }

  List<List<double>> _correct(List<double> wl, List<double> sp)
  {
    var wlMax = 440;
    var wlMin = 200;
    var len = wlMax - wlMin + 1;
    var wl2 = List.generate(len, (index) => (index + wlMin).toDouble());
    var sp2 = List.generate(len, (index) => 0.0);
    for(var i=0;i<len;i++)
    {
      sp2[i] = _interporateLagrange(wl2[i], wl, sp);
    }
    
    return [wl2, sp2];
  }
  double _interporateSpline(double xx, List<double> xa, List<double> ya)
  {
    var y = ya;
    var x = xa;
    var n = x.length;

    var h = List.generate(n, (idx) => 0.0);
    var diff1 = List.generate(n, (idx) => 0.0);
    var diff2 = List.generate(n, (idx) => 0.0);

    if(x[0] == xx)
    {
      return y[0];
    }
    if(x[n-1] == xx)
    {
      return y[n-1];
    }
    for(var i=1;i<n;i++)
    {
      h[i] = x[i] - x[i-1];
      diff1[i] = h[i] == 0.0 ? 0.0 : (y[i] - y[i-1]) / h[i];
    }
    for(var i=1;i<n-1;i++)
    {
      diff2[i] = (diff1[i+1] - diff1[i]) / (x[i+1] - x[i-1]);
    }
    
    var t = 1;
    for(var i=1;i<n;i++)
    {
      t = i;
      if(xx < x[i])
      {
        break;
      }
    }
    
    var yy0 = diff2[t-1]/(6.0*h[t])*(x[t]-xx)*(x[t]-xx)*(x[t]-xx);
    var yy1 = diff2[t]/(6.0*h[t])*(xx-x[t-1])*(xx-x[t-1])*(xx-x[t-1]);
    var yy2 = (y[t-1]/h[t]-h[t]*diff2[t-1]/6.0)*(x[t]-xx);
    var yy3 = (y[t]/h[t]-h[t]*diff2[t]/6.0)*(xx-x[t-1]);
    var yy = yy0 + yy1 + yy2 + yy3;
    if(yy < 0.0)
    {
      yy = 0.0;
    }
    return yy;
  }

  double _interporateLinear(double xx, List<double> xa, List<double> ya)
  {
      var x1 = 0.0;
      var x2 = 0.0;
      var y1 = 0.0;
      var y2 = 0.0;
      var x = 0.0;
      var t2 = 1;
      var t1 = 1;
      var len = xa.length;

      for(var i=1;i<len;i++)
      {
          x = xa[i];
          if(x > xx)
          {
              t2 = i;
              x2 = x;
              break;
          }
      }
      t1 = t2 - 1;
      
      x1 = xa[t1];

      y1 = ya[t1];
      y2 = ya[t2];

      var value = (x2 - x1 ) == 0.0 ? 0.0 : y1 + (y2 - y1) * (xx - x1) / (x2 - x1);
      if(value < 0.0)
      {
        value = 0.0;
      }
      return value;
  }

  double _interporateLagrange(double x, List<double> xa, List<double> ya)
  {
      var t1 = 2;

      for(var i=2;i<xa.length-1;i++)
      {
          t1 = i;
          if(xa[i] > x)
          {    
            break;
          }
      }
      var xx = [xa[t1-2],xa[t1-1],xa[t1],xa[t1+1]];
      var yy = [ya[t1-2],ya[t1-1],ya[t1],ya[t1+1]];
      var p = 0.0;
      var s = 0.0;
      for(var j=0;j<xx.length;j++)
      {
        p = yy[j];
        for(var i=0;i<xx.length;i++)
        {
          if(i==j) continue;
          p *= (xx[j] - xx[i]) == 0.0 ? 0.0 : (x - xx[i])/(xx[j] - xx[i]); 
        }
        s += p;
      }
      if(s < 0.0)
      {
        s = 0.0;
      }
      return s;
  }

}

extension UvVisSpecDeviceAccumulatedIrradianceExtention on UvVisSpecDevice {
  Stream<double> getResultAccumulatedIrradianceStream(int integrationTime) {
    return resultAverageStream.bufferCount(integrationTime, 1).flatMap((value) {
      return Future(() async {
        return value.map((e) => e.ir).reduce((value, element) => value + element);
      }).asStream();
    });
  }
}

extension UvVisSpecDeviceExtention on UvVisSpecDevice {
  
  Stream<UVVisSpecDeviceResult> get resultAverageStream {
    return _resultSubject.stream.bufferCount(3, 1).flatMap((value) {
      return Future(() async {
        var splist = value.map((e) => e.sp).toList();
        var len = splist.first.length;
        var n = value.length;
        var sp = [...value.first.sp];
        var wl = [...value.first.wl];
        for(var i = 0; i < len; i++) {
          sp[i] = 0.0;
          for(var j = 0; j < n; j++) {
            sp[i] += splist[j][i];
          }
          sp[i] /= n;
        }
        
        var pp = sp.reduce(max);
        var pwl = wl[sp.indexWhere((x) => (x == pp))];
        var ir = 0.0;
        for(var i=0; i<wl.length; i++) {
          ir += sp[i];
        }
        var result = UVVisSpecDeviceResult();
        result.sp = sp;
        result.wl = wl;
        result.ir = ir;
        result.pp = pp;
        result.pwl = pwl;
        
        return result;
          }).asStream();
      });
  }
  // Future<UVVisSpecDeviceResult> average(List<UVVisSpecDeviceResult> results) async {
  //   var splist = results.map((e) => e.sp).toList();
  //   var len = splist.first.length;
  //   var n = results.length;
  //   var sp = [...results.first.sp];
  //   var wl = [...results.first.wl];
  //   for(var i = 0; i < len; i++) {
  //     sp[i] = 0.0;
  //     for(var j = 0; j < n; j++) {
  //       sp[i] += splist[j][i];
  //     }
  //     sp[i] /= n;
  //   }
    
  //   var pp = sp.reduce(max);
  //   var pwl = wl[sp.indexWhere((x) => (x == pp))];
  //   var ir = 0.0;
  //   for(var i=0; i<wl.length; i++) {
  //     ir += sp[i];
  //   }
  //   var value = UVVisSpecDeviceResult();
  //   value.sp = sp;
  //   value.wl = wl;
  //   value.ir = ir;
  //   value.pp = pp;
  //   value.pwl = pwl;
    
  //   return value;
  // }
  static bool _measuring = false;
  Future<void> measStart() async {  
    if(_status.connected == false) {
      return;
    }
    Timer.periodic(const Duration(milliseconds:200),
     (timer) async {

        if(_measuring) {
          return;
        }

        if(_status.measurestopped){
          timer.cancel();
          return;
        }

        if(_status.measurestarted){
          _measuring = true;
          await meas();
          await status();
          _measuring = false;
        }
        
      });

    _status.measurestarted = true;
    _status.measurestopped = false;
    _statusSubject.add(_status);
  }

  Future<void> measStop() async {
    _status.measurestarted = false;
    _status.measurestopped = true;
    _statusSubject.add(_status);
  }
}