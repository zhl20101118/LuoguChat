// Luogu API debug test - run with: node test_api.js
const https = require('https');
const http = require('http');
const fs = require('fs');

const UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36 Edg/149.0.0.0';

// Read config
const config = JSON.parse(fs.readFileSync('config.json','utf-8'));
let cookie = config.luogu.cookie || '';
const uid = config.luogu.user_id || '';
console.log('UID:', uid);
console.log('Cookie:', cookie.substring(0, 80));

function req(url, opts={}) {
  return new Promise((resolve, reject) => {
    const u = new URL(url);
    const mod = u.protocol === 'https:' ? https : http;
    const options = {
      hostname: u.hostname, port: u.port, path: u.pathname + u.search,
      method: opts.method || 'GET',
      headers: { 'user-agent': UA, ...opts.headers },
      timeout: opts.timeout || 15000,
      rejectUnauthorized: false
    };
    const r = mod.request(options, res => {
      const chunks = [];
      res.on('data', c => chunks.push(c));
      res.on('end', () => {
        const cookies = [];
        (res.headers['set-cookie'] || []).forEach(c => {
          const p = c.split(';')[0];
          if (p) cookies.push(p.trim());
        });
        resolve({
          status: res.statusCode,
          headers: res.headers,
          body: Buffer.concat(chunks).toString('utf-8'),
          cookies
        });
      });
    });
    r.on('error', e => reject(e));
    r.on('timeout', () => { r.destroy(); reject(new Error('timeout')); });
    if (opts.body) r.write(opts.body);
    r.end();
  });
}

async function main() {
  // Step 1: Get C3VK
  console.log('\n=== Step 1: Get C3VK ===');
  try {
    const r1 = await req('https://www.luogu.com.cn/api/chat/record?user=1', {
      headers: { cookie, referer: 'https://www.luogu.com.cn/chat' }
    });
    console.log('Status:', r1.status);
    console.log('Cookies:', r1.cookies);
    console.log('Body length:', r1.body.length);
    
    for (const c of r1.cookies) {
      if (c.startsWith('C3VK=')) {
        const c3vk = c.substring(5);
        console.log('Got C3VK:', c3vk);
        cookie = cookie.replace(/;?\s*C3VK=[^;]*/g, '').replace(/;+$/g, '').trim();
        cookie = `${cookie}; C3VK=${c3vk}`;
      }
    }
  } catch(e) { console.log('C3VK err:', e.message); }

  // Step 2: Get chat list
  console.log('\n=== Step 2: Get Chat List ===');
  try {
    const r2 = await req('https://www.luogu.com.cn/chat', {
      headers: { cookie, referer: 'https://www.luogu.com.cn/' }
    });
    console.log('Status:', r2.status);
    console.log('Body length:', r2.body.length);
    
    // Parse _feInjection
    const m1 = r2.body.match(/window\._feInjection\s*=\s*JSON\.parse\(decodeURIComponent\("([^"]+)"\)\)/);
    if (m1) {
      console.log('Found _feInjection (format 1), length:', m1[1].length);
      try {
        const data = JSON.parse(decodeURIComponent(m1[1]));
        const msgs = data.currentData?.latestMessages?.result || [];
        console.log('Parsed', msgs.length, 'messages');
        if (msgs.length > 0) {
          console.log('First msg:', JSON.stringify(msgs[0]).substring(0, 200));
        }
      } catch(e) { console.log('Parse err:', e.message); }
    } else {
      // Try alternative
      const m2 = r2.body.match(/<script[^>]*>window\._feInjection\s*=\s*JSON\.parse\(decodeURIComponent\("([^"]+)"\)\)<\/script>/);
      if (m2) {
        console.log('Found _feInjection (format 2), length:', m2[1].length);
        try {
          const data = JSON.parse(decodeURIComponent(m2[1]));
          const msgs = data.currentData?.latestMessages?.result || [];
          console.log('Parsed', msgs.length, 'messages');
          if (msgs.length > 0) {
            console.log('First msg:', JSON.stringify(msgs[0]).substring(0, 200));
          }
        } catch(e) { console.log('Parse err:', e.message); }
      } else {
        console.log('_feInjection NOT found');
        // Check if the page has any data
        const hasInjection = r2.body.includes('_feInjection');
        console.log('Has _feInjection string:', hasInjection);
        // Show a snippet
        const idx = r2.body.indexOf('_feInjection');
        if (idx >= 0) {
          console.log('Context at _feInjection:', r2.body.substring(Math.max(0,idx-50), idx+200));
        }
      }
    }
  } catch(e) { console.log('Chat err:', e.message); }
}

main().catch(console.error);
