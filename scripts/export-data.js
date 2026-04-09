#!/usr/bin/env node
// ============================================================
// DinkMate — Full Data Export Script
// Usage: node export-data.js [--user USER_ID] [--table TABLE]
// Output: ./exports/dinkmate-export-YYYY-MM-DD.json
// ============================================================

const https = require('https');
const fs    = require('fs');
const path  = require('path');

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_KEY;  // needs service role

if (!SUPABASE_URL || !SUPABASE_KEY) {
  console.error('Error: Set SUPABASE_URL and SUPABASE_SERVICE_KEY');
  process.exit(1);
}

const args = process.argv.slice(2);
const userFilter  = args.includes('--user')  ? args[args.indexOf('--user')  + 1] : null;
const tableFilter = args.includes('--table') ? args[args.indexOf('--table') + 1] : null;
const dateStr = new Date().toISOString().slice(0, 19).replace(/[:.]/g, '-');

const TABLES = [
  { name: 'profiles',             userCol: 'id'          },
  { name: 'follows',              userCol: 'follower_id'  },
  { name: 'posts',                userCol: 'user_id'      },
  { name: 'likes',                userCol: 'user_id'      },
  { name: 'comments',             userCol: 'user_id'      },
  { name: 'swipes',               userCol: 'swiper_id'    },
  { name: 'matches',              userCol: null           },  // special handling
  { name: 'messages',             userCol: 'sender_id'    },
  { name: 'products',             userCol: 'seller_id'    },
  { name: 'orders',               userCol: null           },  // buyer or seller
  { name: 'saved_products',       userCol: 'user_id'      },
  { name: 'notifications',        userCol: 'user_id'      },
  { name: 'analytics_events',     userCol: 'user_id'      },
  { name: 'creator_earnings',     userCol: 'creator_id'   },
  { name: 'user_badges',          userCol: 'user_id'      },
  { name: 'event_registrations',  userCol: 'user_id'      },
  { name: 'courts',               userCol: null           },  // public table
  { name: 'events',               userCol: 'organizer_id' },
  { name: 'group_chats',          userCol: null           },
  { name: 'group_messages',       userCol: 'sender_id'    },
];

function fetchTable(tableName, filter) {
  return new Promise((resolve, reject) => {
    const url = new URL(`${SUPABASE_URL}/rest/v1/${tableName}`);
    url.searchParams.set('select', '*');
    url.searchParams.set('limit', '100000');
    if (filter) url.searchParams.set(filter.col + '.eq.' + filter.val, '');
    // Supabase filter format
    const filterStr = filter ? `${filter.col}=eq.${filter.val}` : null;
    const fullUrl = filterStr
      ? `${SUPABASE_URL}/rest/v1/${tableName}?select=*&${filterStr}&limit=100000`
      : `${SUPABASE_URL}/rest/v1/${tableName}?select=*&limit=100000`;

    https.get(fullUrl, {
      headers: {
        'apikey': SUPABASE_KEY,
        'Authorization': `Bearer ${SUPABASE_KEY}`,
        'Accept': 'application/json'
      }
    }, (res) => {
      let body = '';
      res.on('data', d => body += d);
      res.on('end', () => {
        try { resolve(JSON.parse(body)); }
        catch(e) { resolve([]); }
      });
    }).on('error', reject);
  });
}

async function main() {
  const outDir = path.join(process.cwd(), 'exports');
  if (!fs.existsSync(outDir)) fs.mkdirSync(outDir);

  const tables = tableFilter ? TABLES.filter(t => t.name === tableFilter) : TABLES;
  const result = {
    exported_at: new Date().toISOString(),
    supabase_url: SUPABASE_URL,
    user_filter: userFilter || 'all',
    tables: {}
  };

  console.log('');
  console.log('DinkMate Data Export');
  console.log('='.repeat(50));
  console.log(`Date:   ${dateStr}`);
  console.log(`User:   ${userFilter || 'ALL USERS'}`);
  console.log(`Tables: ${tables.length}`);
  console.log('');

  let totalRows = 0;
  for (const table of tables) {
    process.stdout.write(`  ${table.name.padEnd(28)}`);
    const filter = (userFilter && table.userCol)
      ? { col: table.userCol, val: userFilter }
      : null;
    const rows = await fetchTable(table.name, filter);
    result.tables[table.name] = rows;
    const count = Array.isArray(rows) ? rows.length : 0;
    totalRows += count;
    console.log(`${count.toString().padStart(6)} rows`);
  }

  console.log('');
  console.log(`  TOTAL: ${totalRows} rows`);

  const outFile = path.join(outDir, `dinkmate-export-${dateStr}.json`);
  fs.writeFileSync(outFile, JSON.stringify(result, null, 2));
  const size = (fs.statSync(outFile).size / 1024).toFixed(1);

  console.log('');
  console.log('='.repeat(50));
  console.log(`Export complete!`);
  console.log(`File: ${outFile} (${size} KB)`);
  console.log('');
}

main().catch(err => {
  console.error('Export failed:', err.message);
  process.exit(1);
});
