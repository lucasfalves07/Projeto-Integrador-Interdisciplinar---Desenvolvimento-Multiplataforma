/**
 * Firestore migration/diagnostic script (Node.js + firebase-admin)
 *
 * What it does (safe by default – dry-run):
 *  - users: ensure tipo from perfil, ensure turmas is an array (convert string -> [string])
 *  - turmas: ensure top-level professorId (try derive from disciplinas[0].professorId)
 *  - mensagens: normalize { mensagem, enviadaEm(Timestamp), de, turmaId? } and 1:1 { toUid, chatKey }
 *  - notas: normalize dataLancamento to Timestamp
 *
 * Usage:
 *  1) npm i firebase-admin yargs
 *  2) export GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccount.json
 *  3) node scripts/migrate_firestore.js --project <projectId> --dry-run
 *     node scripts/migrate_firestore.js --project <projectId> --fix
 */

const admin = require('firebase-admin');
const yargs = require('yargs/yargs');
const { hideBin } = require('yargs/helpers');

const argv = yargs(hideBin(process.argv))
  .option('project', { type: 'string', demandOption: true, describe: 'Firebase project ID' })
  .option('fix', { type: 'boolean', default: false, describe: 'Apply fixes (otherwise dry-run)' })
  .option('limit', { type: 'number', default: 0, describe: 'Limit processed docs per collection (0 = all)' })
  .help().argv;

if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  console.error('ERROR: Set GOOGLE_APPLICATION_CREDENTIALS to a service account JSON file.');
  process.exit(1);
}

admin.initializeApp({ projectId: argv.project });
const db = admin.firestore();

function toTs(v) {
  if (!v) return null;
  if (v._seconds) return new admin.firestore.Timestamp(v._seconds, v._nanoseconds || 0);
  if (typeof v === 'string') {
    const d = new Date(v);
    if (!isNaN(d.getTime())) return admin.firestore.Timestamp.fromDate(d);
    return null;
  }
  return v; // may already be Timestamp
}

function chatKey(a, b) {
  return a <= b ? `${a}_${b}` : `${b}_${a}`;
}

async function processUsers() {
  console.log('\n== users ==');
  const snap = await db.collection('users').get();
  let fixes = 0;
  for (const doc of snap.docs) {
    const data = doc.data() || {};
    const update = {};

    // tipo from perfil
    if (!data.tipo && data.perfil && typeof data.perfil === 'string') {
      update.tipo = data.perfil.toLowerCase();
    }

    // turmas as array
    if (typeof data.turmas === 'string' && data.turmas.trim()) {
      update.turmas = [data.turmas.trim()];
    }

    if (Object.keys(update).length) {
      fixes++;
      console.log(`users/${doc.id} ->`, update);
      if (argv.fix) await doc.ref.set({ ...update, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
    }
  }
  console.log(`users fixes: ${fixes}`);
}

async function processTurmas() {
  console.log('\n== turmas ==');
  const snap = await db.collection('turmas').get();
  let fixes = 0;
  for (const doc of snap.docs) {
    const data = doc.data() || {};
    if (!data.professorId) {
      let derived = null;
      if (Array.isArray(data.disciplinas) && data.disciplinas.length && data.disciplinas[0].professorId) {
        derived = data.disciplinas[0].professorId;
      }
      const update = { professorId: derived || '' };
      fixes++;
      console.log(`turmas/${doc.id} -> set professorId: '${update.professorId || '(EMPTY)'}'`);
      if (argv.fix) await doc.ref.set(update, { merge: true });
    }
  }
  console.log(`turmas fixes: ${fixes}`);
}

async function processMensagens() {
  console.log('\n== mensagens ==');
  const snap = await db.collection('mensagens').get();
  let fixes = 0;
  for (const doc of snap.docs) {
    const data = doc.data() || {};
    const update = {};
    // normalize mensagem
    if (!data.mensagem && data.texto) update.mensagem = String(data.texto);
    // normalize enviadaEm
    if (!data.enviadaEm && (data.timestamp || (data.enviadaEm && data.enviadaEm._seconds))) {
      const ts = toTs(data.timestamp || data.enviadaEm);
      if (ts) update.enviadaEm = ts;
    }
    // direct messages: toUid + chatKey
    if (data.toUid && !data.chatKey && data.de) update.chatKey = chatKey(String(data.de), String(data.toUid));

    if (Object.keys(update).length) {
      fixes++;
      console.log(`mensagens/${doc.id} ->`, update);
      if (argv.fix) await doc.ref.set(update, { merge: true });
    }
  }
  console.log(`mensagens fixes: ${fixes}`);
}

async function processNotas() {
  console.log('\n== notas ==');
  const snap = await db.collection('notas').get();
  let fixes = 0;
  for (const doc of snap.docs) {
    const data = doc.data() || {};
    const update = {};
    if (data.dataLancamento && typeof data.dataLancamento === 'string') {
      const ts = toTs(data.dataLancamento);
      if (ts) update.dataLancamento = ts;
    }
    if (Object.keys(update).length) {
      fixes++;
      console.log(`notas/${doc.id} ->`, update);
      if (argv.fix) await doc.ref.set(update, { merge: true });
    }
  }
  console.log(`notas fixes: ${fixes}`);
}

(async () => {
  console.log(`Project: ${argv.project}  mode: ${argv.fix ? 'FIX' : 'DRY-RUN'}`);
  await processUsers();
  await processTurmas();
  await processMensagens();
  await processNotas();
  console.log('\nDone.');
  process.exit(0);
})();

