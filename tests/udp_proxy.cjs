// Test-only UDP relay: one instance per client, delaying and dropping both directions.
const dgram = require('node:dgram');
const args = process.argv.slice(2);
const value = (key, fallback) => args.includes(key) ? Number(args[args.indexOf(key) + 1]) : fallback;
const listen = value('--listen', 7200);
const target = value('--target', 7100);
const delay = value('--delay', 60);
const loss = value('--loss', 2) / 100;
const socket = dgram.createSocket('udp4');
let client;
socket.on('message', (packet, remote) => {
  const fromServer = remote.port === target;
  if (!fromServer) client = { address: remote.address, port: remote.port };
  const destination = fromServer ? client : { address: '127.0.0.1', port: target };
  if (!destination || Math.random() < loss) return;
  setTimeout(() => socket.send(packet, destination.port, destination.address), delay);
});
socket.on('error', error => { console.error(error); process.exit(1); });
socket.bind(listen, '127.0.0.1', () => console.log(`PROXY_READY port=${listen} rtt=${delay * 2} loss=${loss}`));
