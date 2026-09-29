// Every item a server pastes in has to work the moment it is used.
//
// - ox_inventory calls `client.export` on the CLIENT, so each one must be
//   registered with exports() in client/. Registering it only on the server
//   leaves the item dead.
// - The qb file has to declare the same items, or half the servers get a
//   different list.
// - Each item needs its picture, or the inventory shows a blank slot.
// - Config.Tablet.item has to be one of the items shipped.
import { readFileSync, readdirSync, existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const read = (rel) => readFileSync(path.join(ROOT, rel), 'utf8');
const problems = [];

const ox = read('items/ox_inventory.lua');
const qb = read('items/qb_core.lua');

const oxItems = [...ox.matchAll(/^\['([a-z0-9_]+)'\]/gm)].map((m) => m[1]);
const qbItems = [...qb.matchAll(/^\['([a-z0-9_]+)'\]/gm)].map((m) => m[1]);

for (const item of oxItems) if (!qbItems.includes(item)) problems.push(`${item} is in the ox file but not the qb file`);
for (const item of qbItems) if (!oxItems.includes(item)) problems.push(`${item} is in the qb file but not the ox file`);

const clientSrc = readdirSync(path.join(ROOT, 'client')).filter((f) => f.endsWith('.lua')).map((f) => read(`client/${f}`)).join('\n');

for (const m of ox.matchAll(/export\s*=\s*'([^'.]+)\.([^']+)'/g)) {
    const [, resource, name] = m;
    if (resource !== 'XS-Dealerships') problems.push(`ox export points at "${resource}", not XS-Dealerships`);
    if (!clientSrc.includes(`exports('${name}'`)) problems.push(`ox calls ${resource}.${name} on the client, and no client file registers exports('${name}')`);
}

for (const item of oxItems) {
    if (!existsSync(path.join(ROOT, 'inventory_images', `${item}.png`))) problems.push(`no picture for ${item} in inventory_images/`);
}

const tabletItem = (read('config.lua').match(/item\s*=\s*'([a-z0-9_]*)'/) || [])[1];
if (tabletItem && !oxItems.includes(tabletItem)) problems.push(`Config.Tablet.item is "${tabletItem}", which the items files do not declare`);

if (problems.length) {
    console.log('check-items FAILED');
    for (const p of problems) console.log(`  ${p}`);
    process.exit(1);
}

console.log(`check-items ok — ${oxItems.length} item(s), exports, pictures and config agree`);
