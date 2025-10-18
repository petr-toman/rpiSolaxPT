
// --- DB API endpoint ---
const CFG_DB_ENDPOINT = 'fve_config.php';

// Z formuláře -> objekt
function formToCfgWithSn() {
  const cfg = formToCfg(); // už existuje
  // použij aktuální SN ze statusu; pokud není, vyžádej si ho
  let currentSn = (document.getElementById('sn')?.textContent || '—').trim();
  if (!currentSn || currentSn === '—' || currentSn.startsWith('—')) {
    currentSn = prompt('Neznám Sériové číslo (SN). Zadej SN (bude klíčem v DB):', '');
    if (!currentSn) throw new Error('Chybí SN – zrušeno.');
  }
  return { sn: currentSn, ...cfg };
}

// Naplní formulář z objektu
function cfgToForm(cfg) {
  const f = cfgForm;
  const map = ['apiUrl','delay','debuglevel','peak1','peak2','maxPower','maxLoad','BatteryMaxCapacity','sendPwd','passwd','proxy'];
  map.forEach(k=>{
    if (cfg[k] !== undefined) {
      if (k === 'sendPwd') f[k].checked = !!cfg[k];
      else f[k].value = cfg[k];
    }
  });
  pwdWrap.style.display = f.sendPwd.checked ? 'block' : 'none';
  // Ulož i do localStorage, ať je to po ruce
  localStorage.setItem(CFG_KEY, JSON.stringify(formToCfg()));
}

// Uložit do SQLite (INSERT/REPLACE)
async function saveCfgToDb() {
  try{
    const data = formToCfgWithSn();
    const res = await fetch(CFG_DB_ENDPOINT, {
      method: 'POST',
      headers: {'Content-Type':'application/json'},
      body: JSON.stringify({ action:'save', data })
    });
    const out = await res.json();
    if (!res.ok || out.status!=='ok') throw new Error(out.error||('HTTP '+res.status));
    alert('Konfigurace uložena pro SN: ' + data.sn);
  }catch(e){
    console.error(e);
    alert('Uložení selhalo: ' + e.message);
  }
}

// Načíst seznam uložených SN
async function showLoadBox() {
  try{
    const res = await fetch(CFG_DB_ENDPOINT + '?action=list');
    const out = await res.json();
    if (!res.ok || out.status!=='ok') throw new Error(out.error||('HTTP '+res.status));
    const list = Array.isArray(out.items) ? out.items : [];
    const sel = document.getElementById('cfgList');
    sel.innerHTML = '';
    if (list.length===0){
      const opt = document.createElement('option');
      opt.value=''; opt.textContent='(DB je prázdná)';
      sel.appendChild(opt);
    } else {
      list.forEach(row=>{
        const label = row.sn + (row.updated_at ? (' – ' + row.updated_at) : '');
        const opt = document.createElement('option');
        opt.value = row.sn; opt.textContent = label;
        sel.appendChild(opt);
      });
    }
    document.getElementById('loadBox').style.display = 'block';
  }catch(e){
    console.error(e);
    alert('Chyba načítání seznamu: ' + e.message);
  }
}

// Načíst konkrétní SN a propsat do formuláře
async function loadCfgFromDb(sn) {
  try{
    if (!sn) { alert('Neplatný výběr.'); return; }
    const res = await fetch(CFG_DB_ENDPOINT + '?action=get&sn=' + encodeURIComponent(sn));
    const out = await res.json();
    if (!res.ok || out.status!=='ok' || !out.data) throw new Error(out.error||('Config nenalezen.'));
    cfgToForm(out.data);
    alert('Načteno pro SN: ' + sn);
  }catch(e){
    console.error(e);
    alert('Načtení selhalo: ' + e.message);
  }
}

// Dráty na tlačítka
document.getElementById('btnSaveDb').addEventListener('click', saveCfgToDb);
document.getElementById('btnLoadDb').addEventListener('click', showLoadBox);
document.getElementById('btnLoadSelected').addEventListener('click', ()=>{
  const sn = document.getElementById('cfgList').value;
  loadCfgFromDb(sn);
});
document.getElementById('btnLoadCancel').addEventListener('click', ()=>{
  document.getElementById('loadBox').style.display = 'none';
});


    const PROXY_ENDPOINT = 'proxy.php';
    const CFG_KEY = 'solaxCfg2';
    const INV_MODE = ["Waiting","Checking","Normal","Off","Permanent Fault","Updating","EPS Check","EPS Mode","Self Test","Idle","Standby"];

    const el = (id)=>document.getElementById(id);
    function s16(x){ x = (Number(x)||0); return x>=32768? x-65536 : x; }
    function u32(hi,lo){ return ((Number(hi)||0)*65536)+(Number(lo)||0); }
    function s32(hi,lo){ const v=u32(hi,lo); return v>=2147483648? v-4294967296 : v; }
    function pct(val,max){ max=Number(max)||0; if(max<=0) return 0; return Math.max(0,Math.min(100,(val/max)*100)); }
    function fmtN(x,d=0){ return (Number(x)||0).toLocaleString('cs-CZ',{maximumFractionDigits:d,minimumFractionDigits:d}); }
    function debounce(fn,delay=300){ let t; return (...a)=>{ clearTimeout(t); t=setTimeout(()=>fn(...a),delay); }; }
    function getSavedCfg(){ try{return JSON.parse(localStorage.getItem(CFG_KEY)||'{}')}catch{return{}} }
    function hasSavedCfg(){ const s=getSavedCfg(); return s&&Object.keys(s).length>0&&!!s.apiUrl; }

    const settingsPanel = el('settingsPanel');
    const backdrop = el('panelBackdrop');
    const toggleBtn = el('toggleSettings');
    const cfgForm = document.getElementById('cfg');
    const pwdWrap = document.getElementById('pwdWrap');
    const startBtn = el('start');
    const stopBtn  = el('stop');

    cfgForm.sendPwd.addEventListener('change',()=>{ pwdWrap.style.display = cfgForm.sendPwd.checked ? 'block':'none'; });

    const saveCfg = debounce(()=>{
      localStorage.setItem(CFG_KEY, JSON.stringify(formToCfg()));
      console.log('[CFG] auto-save');
    },300);
    cfgForm.addEventListener('input', saveCfg);
    cfgForm.addEventListener('change', saveCfg);

    (function initCfgUI(){
      const saved=getSavedCfg();
      for(const k of ['apiUrl','delay','debuglevel','peak1','peak2','maxPower','maxLoad','sendPwd','passwd','proxy','BatteryMaxCapacity']){
        if(saved[k]!==undefined){
          if(k==='sendPwd') cfgForm[k].checked=!!saved[k];
          else cfgForm[k].value=saved[k];
        }
      }
      pwdWrap.style.display = cfgForm.sendPwd.checked ? 'block' : 'none';
      const showOnLoad=!hasSavedCfg();
      setPanel(showOnLoad);
    })();

    function setPanel(opened){
      toggleBtn.setAttribute('aria-expanded', String(opened));
      settingsPanel.classList.toggle('open', opened);
      if(opened){
        settingsPanel.removeAttribute('hidden');
        backdrop.removeAttribute('hidden');
        requestAnimationFrame(()=>backdrop.classList.add('open'));
      }else{
        settingsPanel.setAttribute('hidden','');
        backdrop.classList.remove('open');
        setTimeout(()=>backdrop.setAttribute('hidden',''), 200);
      }
    }

    toggleBtn.addEventListener('click', ()=> setPanel(!settingsPanel.classList.contains('open')) );
    backdrop.addEventListener('click', ()=> setPanel(false) );

    let timer=null;
    function setRunning(r){
      startBtn.disabled=r;
      stopBtn.disabled=!r;
      startBtn.setAttribute('aria-pressed', String(r));
      stopBtn.setAttribute('aria-pressed', String(!r));
      document.body.classList.toggle('running', r);
    }
    setRunning(false);

    startBtn.addEventListener('click', ()=> startPolling());
    stopBtn.addEventListener('click', ()=>{ if(timer){clearInterval(timer); timer=null;} setRunning(false); });

    function formToCfg(){
      const f = cfgForm;
      return {
        apiUrl: f.apiUrl.value.trim(),
        delay: Math.max(1, Number(f.delay.value)||4),
        debuglevel: Math.max(0, Math.min(2, Number(f.debuglevel.value)||0)),
        peak1: Number(f.peak1.value)||0,
        peak2: Number(f.peak2.value)||0,
        maxPower: Number(f.maxPower.value)||0,
        maxLoad: Number(f.maxLoad.value)||0,
        BatteryMaxCapacity: Number(f.BatteryMaxCapacity.value)||0,
        sendPwd: !!f.sendPwd.checked,
        passwd: f.passwd.value,
        proxy:  f.proxy.value
      };
    }

    async function callProxy(cfg){
      if(!cfg.apiUrl) throw new Error('Není vyplněna API URL');
      const body=new URLSearchParams();
      body.set('target', cfg.apiUrl);
      body.set('proxy', cfg.proxy || '');
      body.set('optType','ReadRealTimeData');
      if(cfg.sendPwd && cfg.passwd) body.set('pwd', cfg.passwd);
      const res=await fetch(PROXY_ENDPOINT,{ method:'POST', headers:{'Content-Type':'application/x-www-form-urlencoded'}, body });
      if(!res.ok) throw new Error('HTTP '+res.status);
      return await res.json();
    }

    function buildStatus(o,cfg){
      const D=o.Data||[];
      const s={
        SerNum:o.sn??null,
        PowerDc1:Number(D[14]||0),
        PowerDc2:Number(D[15]||0),
        ProductionDC_Today:Number(D[82]||0)/10,
        YieldAC_Today:Number(D[70]||0)/10,
        feedInPower:s16(Number(D[34]||0)),
        _feedInPower:s32(Number(D[34]||0),Number(D[35]||0)),
        totalGridIn:u32(Number(D[93]||0),Number(D[92]||0))/100,
        totalGridOut:u32(Number(D[91]||0),Number(D[90]||0))/100,
        load:s16(Number(D[47]||0)),
        batteryPower:s16(Number(D[41]||0)),
        totalChargedIn:Number(D[79]||0)/10,
        totalChargedOut:Number(D[78]||0)/10,
        batterySoC:Number(D[103]||0),
        batteryCapacitykWh:Number(D[106]||0)/10,
        batteryTemp:Number(D[105]||0),
        inverterTemp:Number(D[54]||0),
        inverterPower:s16(Number(D[9]||0)),
        inverterMode:Number(D[19]||0),
        GridL1Power:s16(Number(D[6]||0)),
        GridL2Power:s16(Number(D[7]||0)),
        GridL3Power:s16(Number(D[8]||0)),
        _Yield_Total:u32(Number(D[68]||0),Number(D[69]||0))/10,
        _FeedInEnergy:u32(Number(D[86]||0),Number(D[87]||0))/100,
        _ConsumeEnergy:u32(Number(D[88]||0),Number(D[89]||0))/100,
        PowerDCtotal:0,
        totalPeak:(Number(cfg.peak1)||0)+(Number(cfg.peak2)||0)
      };
      s.PowerDCtotal=s.PowerDc1+s.PowerDc2;
      const totalConsumption=(s.totalGridIn)+(s.YieldAC_Today)-(s.totalGridOut);
      const selfSuff = totalConsumption===0?0:((s.YieldAC_Today - s.totalGridOut)*100/totalConsumption);
      s.totalConsumption=totalConsumption;
      s.selfSufficiencyRate=Math.max(0,Math.min(100,Math.round(selfSuff)));
      return s;
    }

    function render(s,cfg){
      const now=new Date();
      el('sn').textContent = s.SerNum ?? '—';
      el('dt').textContent = now.toLocaleString('cs-CZ');

      el('pv-total').textContent = fmtN(s.PowerDCtotal,0);
      el('pv-1').textContent = fmtN(s.PowerDc1,0);
      el('pv-2').textContent = fmtN(s.PowerDc2,0);
      el('pv-dc-today').textContent = fmtN(s.ProductionDC_Today,1);
      el('bar-pv-total').style.width = pct(s.PowerDCtotal, s.totalPeak) + '%';
      el('bar-pv-1').style.width = pct(s.PowerDc1, cfg.peak1) + '%';
      el('bar-pv-2').style.width = pct(s.PowerDc2, cfg.peak2) + '%';

      el('batt-soc').textContent = fmtN(s.batterySoC,0);
      el('batt-temp').textContent = fmtN(s.batteryTemp,0);
      el('batt-cap').textContent = fmtN(s.batteryCapacitykWh,1);
      el('batt-in').textContent = fmtN(s.totalChargedIn,1);
      el('batt-out').textContent = fmtN(s.totalChargedOut,1);

      const maxWh = Number(cfg.BatteryMaxCapacity)||0;
      const remainingWh = s.batteryCapacitykWh * 1000;
      const battPct = (maxWh>0) ? Math.max(0, Math.min(100, (remainingWh / maxWh) * 100)) : 0;
      el('bar-batt-cap').style.width = battPct + '%';

      const bp = Number(s.batteryPower)||0;
      const battEl = el('batt-power');
      battEl.textContent = (bp>=0 ? 'nabíjení ' : 'vybíjení ') + fmtN(Math.abs(bp),0) + ' W';
      battEl.classList.toggle('ok', bp>=0);
      battEl.classList.toggle('bad', bp<0);
      el('bar-batt-soc').style.width = Math.max(0, Math.min(100, s.batterySoC)) + '%';

      el('inv-mode').textContent = '[' + (INV_MODE[s.inverterMode] ?? s.inverterMode) + ']';
      el('inv-temp').textContent = fmtN(s.inverterTemp,0);
      el('inv-pwr').textContent = fmtN(s.inverterPower,0);
      el('bar-inv').style.width = pct(s.inverterPower, cfg.maxPower) + '%';
      el('l1').textContent = fmtN(s.GridL1Power,0);
      el('l2').textContent = fmtN(s.GridL2Power,0);
      el('l3').textContent = fmtN(s.GridL3Power,0);
      el('inv-ac-today').textContent = fmtN(s.YieldAC_Today,1);

      const fp=Number(s.feedInPower)||0;
      const gridEl=el('grid-dir');
      gridEl.textContent = (fp<0 ? 'odběr ' : 'dodávka ') + fmtN(Math.abs(fp),0) + ' W';
      gridEl.classList.toggle('bad', fp<0);
      gridEl.classList.toggle('ok', fp>=0);
      el('grid-in').textContent = fmtN(s.totalGridIn,2);
      el('grid-out').textContent = fmtN(s.totalGridOut,2);

      el('home-load').textContent = fmtN(s.load,0);
      el('bar-home').style.width = pct(s.load, cfg.maxLoad) + '%';
      el('home-cons').textContent = fmtN(s.totalConsumption,1);
      el('bar-self').style.width = Math.max(0, Math.min(100, s.selfSufficiencyRate)) + '%';
      el('self').textContent = fmtN(s.selfSufficiencyRate,0);
    }

    function startPolling(){
      const cfg = formToCfg();
      localStorage.setItem(CFG_KEY, JSON.stringify(cfg));
      if(timer) clearInterval(timer);
      setRunning(true);
      const tick = async ()=>{
        try{
          const raw = await callProxy(cfg);
          const status = buildStatus(raw, cfg);
          render(status, cfg);
        }catch(e){
          console.warn('Chyba čtení', e);
          el('sn').textContent = '— (chyba spojení)';
          el('dt').textContent = new Date().toLocaleString('cs-CZ');
        }
      };
      tick();
      timer = setInterval(tick, cfg.delay*1000);
    }
