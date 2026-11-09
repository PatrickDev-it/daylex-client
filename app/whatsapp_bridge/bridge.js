'use strict';

const os = require('node:os');
const path = require('node:path');
const fs = require('node:fs');
const readline = require('node:readline');
const { Client, LocalAuth } = require('whatsapp-web.js');

const dataPath = path.join(process.env.APPDATA || path.join(os.homedir(), '.config'), 'Daylex', 'WhatsApp');
const browsers = [process.env.DAYLEX_CHROME_PATH,
  'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
  'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
  'C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe',
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'];
const executablePath = browsers.find(candidate => candidate && fs.existsSync(candidate));
const client = new Client({ authStrategy: new LocalAuth({ dataPath }),
  puppeteer: { headless: true, ...(executablePath ? { executablePath } : {}) } });
let state = 'starting';
let qr = null;
const contactsById = new Map();

function emit(value) {
  process.stdout.write(`${JSON.stringify(value)}\n`);
}

function status() {
  return { state, connected: state === 'ready', qr };
}

client.on('qr', value => { state = 'pairing'; qr = value; emit({ event: 'status', ...status() }); });
client.on('authenticated', () => { state = 'connecting'; qr = null; emit({ event: 'status', ...status() }); });
client.on('ready', () => { state = 'ready'; qr = null; emit({ event: 'status', ...status() }); });
client.on('auth_failure', () => {
  state = 'auth_failure'; qr = null; contactsById.clear();
  emit({ event: 'status', ...status() });
  setTimeout(() => process.exit(1), 2000);
});
client.on('disconnected', () => {
  state = 'disconnected'; qr = null; contactsById.clear();
  emit({ event: 'status', ...status() });
  setTimeout(() => process.exit(1), 2000);
});

async function command(method, args) {
  if (method === 'status') return status();
  if (state !== 'ready') throw new Error('WhatsApp non collegato. Scansiona il QR in Impostazioni.');
  if (method === 'find_contact') {
    const query = String(args.query || '').trim().toLocaleLowerCase();
    if (query.length < 2 || query.length > 100) throw new Error('Inserisci almeno due caratteri del nome.');
    const contacts = await client.getContacts();
    const found = contacts.filter(c => !c.isGroup && [c.name, c.pushname, c.shortName, c.number]
      .some(value => String(value || '').toLocaleLowerCase().includes(query))).slice(0, 10);
    contactsById.clear();
    for (const c of found) contactsById.set(c.id._serialized, c);
    return { contacts: found.map(c => ({ id: c.id._serialized,
      name: String(c.name || c.pushname || c.number || '').slice(0, 100),
      number: String(c.number || '').slice(0, 30) })) };
  }
  if (method === 'send_message') {
    const id = String(args.contactId || '');
    const message = String(args.message || '').trim();
    if (!contactsById.has(id)) throw new Error('Cerca prima il contatto e usa il suo ID esatto.');
    if (!message || message.length > 2000) throw new Error('Il messaggio deve contenere da 1 a 2000 caratteri.');
    const sent = await client.sendMessage(id, message);
    return { id: sent.id._serialized, recipient: contactsById.get(id).name || contactsById.get(id).number,
      accepted: true };
  }
  throw new Error(`Comando sconosciuto: ${method}`);
}

const input = readline.createInterface({ input: process.stdin });
input.on('line', async line => {
  let request;
  try {
    request = JSON.parse(line);
    const result = await command(request.method, request.args || {});
    emit({ id: request.id, ok: true, result });
  } catch (error) {
    emit({ id: request?.id, ok: false, error: error.message || String(error) });
  }
});
input.on('close', async () => {
  try { await client.destroy(); } catch { /* Browser may still be starting. */ }
  process.exit(0);
});

client.initialize().catch(error => {
  state = 'error';
  emit({ event: 'status', ...status(), error: error.message || String(error) });
  setTimeout(() => process.exit(1), 2000);
});
