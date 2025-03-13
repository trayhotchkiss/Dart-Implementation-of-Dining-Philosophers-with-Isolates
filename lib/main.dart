import 'dart:async';
import 'dart:isolate';

void main() {
  start();
}

void start() async {
  var receivePort = ReceivePort();
  await Isolate.spawn(coordinator, receivePort.sendPort);

  var coordinatorPort = await receivePort.first as SendPort;
  List<SendPort> philosopherPorts = [];

  for (int i = 0; i < 5; i++) {
    var philosopherReceivePort = ReceivePort();
    await Isolate.spawn(philosopher, philosopherReceivePort.sendPort);
    var sendPort = await philosopherReceivePort.first as SendPort;
    philosopherPorts.add(sendPort);

    // Initialize each philosopher with their ID and the coordinator's port
    sendPort.send({'id': i, 'coordinator': coordinatorPort});
  }
}

void coordinator(SendPort sendPort) {
  var receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  List<bool> chopsticks = List.filled(5, true);
  receivePort.listen((message) {
    var id = message['id'] as int;
    var request = message['request'] as String;
    var responsePort = message['port'] as SendPort;

    if (request == 'pickup') {
      int left = id;
      int right = (id + 1) % 5;

      if (chopsticks[left] && chopsticks[right]) {
        chopsticks[left] = false;
        chopsticks[right] = false;
        responsePort.send(true); // Allow philosopher to eat
      } else {
        responsePort.send(false); // Deny access to chopsticks
      }
    } else if (request == 'putdown') {
      chopsticks[id] = true;
      chopsticks[(id + 1) % 5] = true;
      responsePort.send(true);
    }
  });
}

void philosopher(SendPort sendPort) {
  var receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  int? id;
  SendPort? coordinatorPort;
  receivePort.listen((message) {
    if (message is Map) {
      id = message['id'] as int;
      coordinatorPort = message['coordinator'] as SendPort;
    } else if (message == true) {
      print('Philosopher $id is eating.');
      Future.delayed(Duration(seconds: 2), () {
        print('Philosopher $id finished eating.');
        coordinatorPort?.send({
          'id': id!,
          'request': 'putdown',
          'port': receivePort.sendPort,
        });
      });
    } else {
      print('Philosopher $id is thinking.');
      Future.delayed(Duration(seconds: 2), () {
        coordinatorPort?.send({
          'id': id!,
          'request': 'pickup',
          'port': receivePort.sendPort,
        });
      });
    }
  });

  Future.delayed(Duration.zero, () {
    coordinatorPort?.send({
      'id': id!,
      'request': 'pickup',
      'port': receivePort.sendPort,
    });
  });
}
