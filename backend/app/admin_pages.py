from fastapi import APIRouter, Depends, Request
from fastapi.responses import HTMLResponse
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import PresetCard

router = APIRouter(tags=["admin_pages"])

ADMIN_PAGE_HTML = """<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>能量石 管理后台 v0.6.1</title>
<style>
* { margin:0; padding:0; box-sizing:border-box; }
body { background:#121212; color:#e0e0e0; font-family:system-ui,-apple-system,sans-serif; min-height:100vh; }
.login-box { max-width:400px; margin:120px auto; padding:40px; background:#1e1e2e; border-radius:16px; text-align:center; }
.login-box h1 { color:#b794ff; margin-bottom:24px; }
.login-box input { width:100%; padding:12px; margin:12px 0; background:#2a2a4a; border:1px solid #6b4eff; border-radius:8px; color:#fff; font-size:16px; }
.login-box button { width:100%; padding:12px; background:#6b4eff; color:#fff; border:none; border-radius:8px; font-size:16px; cursor:pointer; }
.login-box .error { color:#e91e63; margin-top:8px; }
.header { background:#1a1a2e; padding:16px 24px; display:flex; justify-content:space-between; align-items:center; border-bottom:1px solid #2a2a4a; }
.header h1 { color:#b794ff; font-size:20px; }
.header button { padding:8px 16px; background:#e91e63; color:#fff; border:none; border-radius:8px; cursor:pointer; }
.tabs { display:flex; gap:0; background:#1a1a2e; padding:0 24px; border-bottom:2px solid #2a2a4a; }
.tab { padding:12px 20px; cursor:pointer; color:#888; border-bottom:2px solid transparent; margin-bottom:-2px; transition:.2s; }
.tab:hover { color:#ccc; }
.tab.active { color:#b794ff; border-bottom-color:#6b4eff; }
.content { padding:24px; max-width:1100px; margin:0 auto; }
.card { background:#1e1e2e; border-radius:12px; padding:20px; margin-bottom:12px; }
.card h3 { color:#b794ff; margin-bottom:12px; }
.item-row { display:flex; justify-content:space-between; align-items:center; padding:10px 0; border-bottom:1px solid #2a2a4a; }
.item-row:last-child { border-bottom:none; }
.item-row .info { flex:1; }
.item-row .info .title { color:#fff; }
.item-row .info .sub { color:#888; font-size:13px; margin-top:2px; }
.btn { padding:6px 16px; border-radius:6px; border:none; cursor:pointer; font-size:14px; }
.btn-primary { background:#6b4eff; color:#fff; }
.btn-danger { background:#e91e63; color:#fff; }
.btn-sm { padding:4px 12px; font-size:12px; }
.btn-success { background:#4caf50; color:#fff; }
.modal { display:none; position:fixed; top:0; left:0; right:0; bottom:0; background:rgba(0,0,0,.7); z-index:100; justify-content:center; align-items:center; }
.modal.show { display:flex; }
.modal-box { background:#1e1e2e; border-radius:16px; padding:24px; width:92%; max-width:960px; max-height:95vh; overflow-y:auto; }
.modal-box h3 { color:#b794ff; margin-bottom:16px; }
.modal-box label { display:block; color:#888; margin:8px 0 4px; font-size:13px; }
.modal-box input, .modal-box select, .modal-box textarea { width:100%; padding:10px; background:#2a2a4a; border:1px solid #444; border-radius:8px; color:#fff; font-size:14px; margin-bottom:8px; }
.modal-box textarea { resize:vertical; min-height:80px; }
.modal-grid { display:grid; grid-template-columns:1fr 320px; gap:24px; align-items:start; }
.modal-grid-left { display:flex; flex-direction:column; gap:2px; }
.modal-grid-right { position:sticky; top:8px; }
.form-row { display:flex; gap:8px; align-items:center; }
.form-row > * { flex:1; }
.form-row > label { flex:0 0 auto; min-width:28px; }
.preview-card { border-radius:14px; position:relative; overflow:hidden; transition:border-color .3s,box-shadow .3s; }
.preview-card-bg { position:absolute; inset:0; border-radius:12px; z-index:0; }
.preview-card-content { position:relative; z-index:1; display:flex; flex-direction:column; height:100%; padding:10px; }
.preview-header { display:flex; justify-content:space-between; align-items:center; }
.preview-icon-circle { width:30px; height:30px; border-radius:50%; display:flex; align-items:center; justify-content:center; font-size:14px; border:2px solid; flex-shrink:0; }
.preview-level-circle { width:30px; height:30px; border-radius:50%; display:flex; align-items:center; justify-content:center; font-size:16px; font-weight:bold; color:#fff; flex-shrink:0; }
.preview-name-area { flex:1; text-align:center; padding:0 4px; }
.preview-name { font-size:12px; font-weight:bold; }
.preview-mantra-section { flex:1; margin-top:6px; border-radius:8px; padding:6px; display:flex; flex-direction:column; overflow:hidden; }
.preview-mantra-img { width:100%; border-radius:5px; display:none; }
.preview-mantra-text { font-style:italic; text-align:center; font-size:10px; color:rgba(255,255,255,.85); flex:1; display:flex; align-items:center; justify-content:center; overflow:hidden; line-height:1.4; padding-top:4px; }
.preview-footer { margin-top:4px; }
.preview-energy-row { display:flex; align-items:center; justify-content:center; gap:4px; font-size:11px; font-weight:500; margin-bottom:4px; }
.preview-btn-row { display:flex; justify-content:space-evenly; }
.preview-btn { padding:3px 12px; border-radius:5px; border:none; color:#fff; font-size:10px; }
.modal-actions { display:flex; gap:8px; justify-content:flex-end; margin-top:16px; }
.toast { position:fixed; top:16px; right:16px; padding:12px 20px; border-radius:8px; color:#fff; z-index:200; animation:slideIn .3s; }
.toast.success { background:#4caf50; }
.toast.error { background:#e91e63; }
@keyframes slideIn { from { transform:translateX(100%); opacity:0; } to { transform:translateX(0); opacity:1; } }
.empty { text-align:center; color:#666; padding:40px; }
.badge { display:inline-block; padding:2px 8px; border-radius:4px; font-size:11px; margin-right:4px; }
.badge-lv1 { background:#4caf50; color:#fff; }
.badge-lv2 { background:#2196f3; color:#fff; }
.badge-lv3 { background:#ff9800; color:#fff; }
.badge-lv4 { background:#9c27b0; color:#fff; }
.badge-lv5 { background:#f44336; color:#fff; }
.badge-health { background:#4caf50; color:#fff; }
.badge-love { background:#e91e63; color:#fff; }
.badge-wealth { background:#ffd700; color:#333; }
.badge-career { background:#f44336; color:#fff; }
.badge-family { background:#2196f3; color:#fff; }
.img-preview { width:48px; height:48px; border-radius:8px; object-fit:cover; background:#2a2a4a; margin-right:12px; flex-shrink:0; }
.img-preview-large { width:100%; max-height:200px; border-radius:12px; object-fit:contain; background:#2a2a4a; margin-bottom:12px; }
</style>
</head>
<body>
<div id="app"></div>
<script>
const API = '';
const TOKEN_KEY = 'admin_token';
const DEFAULT_TOKEN = 'quasar-admin-2024';
const CARD_TYPES = {HEALTH:'健康',LOVE:'爱情',WEALTH:'财富',CAREER:'事业',FAMILY:'家庭'};
const LEVELS = {1:'微光',2:'闪烁',3:'明亮',4:'璀璨',5:'耀目'};
const RARITY_NAMES = {IRON:'赤铁',BRONZE:'青铜',SILVER:'白银',GOLD:'黄金',BLACK_GOLD:'黑金'};
const RARITY_TO_LV = {IRON:1,BRONZE:2,SILVER:3,GOLD:4,BLACK_GOLD:5};
const TYPE_NAMES = {UNIT:'单位',SPELL:'法术',ITEM:'装备',RELIC:'遗物'};
const TYPE_COLORS = {
  HEALTH:  {hex:'#4caf50',rgba:'rgba(76,175,80,0.35)',glow:'rgba(76,175,80,0.55)'},
  LOVE:    {hex:'#e91e63',rgba:'rgba(233,30,99,0.35)',glow:'rgba(233,30,99,0.55)'},
  WEALTH:  {hex:'#ffd700',rgba:'rgba(255,215,0,0.35)',glow:'rgba(255,215,0,0.55)'},
  CAREER:  {hex:'#f44336',rgba:'rgba(244,67,54,0.35)',glow:'rgba(244,67,54,0.55)'},
  FAMILY:  {hex:'#2196f3',rgba:'rgba(33,150,243,0.35)',glow:'rgba(33,150,243,0.55)'},
};
const TYPE_ICONS = {HEALTH:'❤️',LOVE:'🌸',WEALTH:'💰',CAREER:'📈',FAMILY:'🏠'};
const RARITY_COLORS_MAP = {IRON:'#9e9e9e',BRONZE:'#cd7f32',SILVER:'#c0c0c0',GOLD:'#ffd700',BLACK_GOLD:'#1a1a2e'};

let token = sessionStorage.getItem(TOKEN_KEY) || '';

function h(tag, attrs, ...children) {
  const el = document.createElement(tag);
  for (const [k,v] of Object.entries(attrs||{})) {
    if (k.startsWith('on')) el.addEventListener(k.slice(2).toLowerCase(), v);
    else if (k === 'className') el.className = v;
    else if (k === 'style') Object.assign(el.style, v);
    else el.setAttribute(k, v);
  }
  for (const c of children.flat()) {
    if (typeof c === 'string') el.appendChild(document.createTextNode(c));
    else if (c) el.appendChild(c);
  }
  return el;
}

async function api(method, path, body) {
  const opts = {method, headers:{'Content-Type':'application/json'}};
  if (token) opts.headers['X-Admin-Token'] = token;
  if (body) opts.body = JSON.stringify(body);
  const res = await fetch(API + path, opts);
  return res.json();
}

function toast(msg, ok=true) {
  const t = h('div',{className:'toast '+(ok?'success':'error')},msg);
  document.body.appendChild(t);
  setTimeout(()=>t.remove(),2500);
}

function badgeLv(n) {
  return h('span',{className:'badge badge-lv'+n}, 'Lv'+n);
}

function badgeType(t) {
  return h('span',{className:'badge badge-'+(t.toLowerCase())}, CARD_TYPES[t]||t);
}

// ========== Login Page ==========
function LoginPage() {
  const input = h('input',{type:'password',placeholder:'请输入管理员Token',value:DEFAULT_TOKEN});
  const err = h('div',{className:'error'});
  const btn = h('button',{onclick:()=>{
    token = input.value || DEFAULT_TOKEN;
    api('POST','/api/admin/login',{admin_token:token}).then(r=>{
      if (r.success) { sessionStorage.setItem(TOKEN_KEY,token); render(); }
      else { err.textContent = '验证失败'; }
    }).catch(()=>{ err.textContent = '网络错误'; });
  }},'登录');
  return h('div',{className:'login-box'},
    h('h1',{},'能量石 管理后台'),
    input, btn, err
  );
}

// ========== Tabs ==========
let activeTab = 'cards';

function Tabs() {
  const tabs = [{id:'cards',label:'卡牌'},{id:'archetypes',label:'原型'},{id:'store',label:'商店'},{id:'plaza',label:'广场'}];
  return h('div',{className:'tabs'},
    ...tabs.map(t=>h('div',{
      className:'tab'+(activeTab===t.id?' active':''),
      onclick:()=>{activeTab=t.id;renderContent();}
    },t.label))
  );
}

// ========== Card Management ==========
let cardPage = 0;
let cardFilters = {faction:'',rarity:'',status:''};
const PAGE_SIZE = 50;

function CardsTab() {
  const container = h('div',{});
  const addBtn = h('button',{className:'btn btn-primary',onclick:showCardModal},'+ 新增卡牌');
  const genBtn = h('button',{className:'btn',style:{background:'#ff9800',color:'#fff',marginRight:'8px'},onclick:async ()=>{
    if (!confirm('将删除所有现有卡牌并重新从原型生成365张卡牌，确认？')) return;
    await api('POST','/api/admin/preset-cards/generate');
    cardPage = 0; cardFilters = {faction:'',rarity:''};
    toast('已重新生成365张卡牌'); renderContent();
  }},'重新生成');
  const header = h('div',{style:{display:'flex',justifyContent:'space-between',alignItems:'center',marginBottom:'16px'}},
    h('h3',{},'预设卡牌池'),
    h('div',{}, genBtn, addBtn)
  );

  // Filters
  const factionSel = h('select',{onchange:function(){cardFilters.faction=this.value;cardPage=0;renderContent();}},
    h('option',{value:''},'全部阵营'),
    ...Object.entries(CARD_TYPES).map(([k,v])=>h('option',{value:k},v))
  );
  const raritySel = h('select',{onchange:function(){cardFilters.rarity=this.value;cardPage=0;renderContent();}},
    h('option',{value:''},'全部稀有度'),
    ...Object.entries(RARITY_NAMES).map(([k,v])=>h('option',{value:k},v))
  );
  const statusSel = h('select',{onchange:function(){cardFilters.status=this.value;cardPage=0;renderContent();}},
    h('option',{value:''},'全部状态'),
    h('option',{value:'PENDING'},'待发行'),
    h('option',{value:'RELEASED'},'已发行'),
  );
  const filterRow = h('div',{style:{display:'flex',gap:'8px',marginBottom:'12px'}}, factionSel, raritySel, statusSel);

  const list = h('div',{});
  const pagination = h('div',{style:{display:'flex',justifyContent:'center',gap:'8px',marginTop:'12px'}});
  container.append(header, filterRow, list, pagination);

  const params = '?skip='+(cardPage*PAGE_SIZE)+'&limit='+PAGE_SIZE
    +(cardFilters.faction?'&faction='+cardFilters.faction:'')
    +(cardFilters.rarity?'&rarity='+cardFilters.rarity:'')
    +(cardFilters.status?'&status='+cardFilters.status:'');

  api('GET','/api/admin/preset-cards'+params).then(data=>{
    if (data.cards && data.cards.length>0) {
      const totalPages = Math.ceil(data.total / PAGE_SIZE);
      list.append(h('div',{style:{color:'#888',marginBottom:'8px'}},
        '共 '+data.total+' 张 (第'+(cardPage+1)+'/'+totalPages+'页)'
      ));
      data.cards.forEach(c=>{
        const img = c.image_url
          ? h('img',{src:c.image_url,className:'img-preview',onerror:function(){this.style.display='none';}})
          : h('div',{className:'img-preview',style:{display:'flex',alignItems:'center',justifyContent:'center',color:'#666',fontSize:'20px'}}, '🃏');
        const rarityBadge = c.rarity
          ? h('span',{className:'badge badge-lv'+(RARITY_TO_LV[c.rarity]||1),style:{marginRight:'4px'}}, RARITY_NAMES[c.rarity]||c.rarity)
          : badgeLv(c.energy_level);
        list.append(h('div',{className:'item-row'},
          h('div',{style:{display:'flex',alignItems:'center',flex:1}},
            img,
            h('div',{className:'info'},
              h('div',{className:'title'}, rarityBadge, badgeType(c.card_type||c.faction||c.card_type), ' '+(c.name||c.mantra)),
              h('div',{className:'sub'},
                (c.card_id||'')+' · '+(c.card_type_sub||'')+' · '+
                h('span',{style:{color:c.status==='RELEASED'?'#4caf50':'#ff9800',fontSize:'12px'}}, c.status==='RELEASED'?'已发行':'待发行'),
              ),
            ),
          ),
          h('div',{style:{display:'flex',gap:'6px'}},
            h('button',{className:'btn btn-success btn-sm',onclick:()=>showCardModal(c)},'编辑'),
            h('button',{className:'btn btn-danger btn-sm',onclick:()=>deleteCard(c.id)},'删除'),
          ),
        ));
      });

      // Pagination controls
      if (totalPages > 1) {
        if (cardPage > 0) {
          pagination.append(h('button',{className:'btn btn-sm',style:{background:'#555',color:'#fff'},onclick:()=>{cardPage--;renderContent();}},'← 上一页'));
        }
        pagination.append(h('span',{style:{color:'#888',padding:'4px 12px'}},(cardPage+1)+' / '+totalPages));
        if (cardPage < totalPages-1) {
          pagination.append(h('button',{className:'btn btn-sm',style:{background:'#555',color:'#fff'},onclick:()=>{cardPage++;renderContent();}},'下一页 →'));
        }
      }
    } else {
      list.append(h('div',{className:'empty'},'暂无卡牌'));
    }
  });

  return h('div',{className:'card'}, container);
}

let editingCard = null;

const IMAGE_FITS = {COVER:'覆盖',CONTAIN:'适配',FILL:'填充',CENTER:'居中',FIT_WIDTH:'按宽',FIT_HEIGHT:'按高',NONE:'原始'};

function showCardModal(card) {
  editingCard = card || null;
  // Basic info
  const type = h('select',{},...Object.entries(CARD_TYPES).map(([k,v])=>h('option',{value:k},v)));
  const mantra = h('input',{placeholder:'咒语内容'});
  const level = h('select',{},...Object.entries(LEVELS).map(([k,v])=>h('option',{value:k},v)));

  // Status toggle
  const statusToggle = h('select',{},
    h('option',{value:'PENDING'},'待发行'),
    h('option',{value:'RELEASED'},'已发行'),
  );

  // Image
  const imageUrl = h('input',{placeholder:'图片URL（可选，留空使用默认图）'});
  const imgPreview = h('img',{style:{display:'none',width:'100%',maxHeight:'80px',borderRadius:'8px',objectFit:'contain',background:'#2a2a4a'}});
  const fileInput = h('input',{type:'file',accept:'image/png,image/jpeg,image/webp,image/gif',style:{marginBottom:'8px'}});
  const uploadBtn = h('button',{className:'btn btn-sm',style:{background:'#555',color:'#fff',marginBottom:'8px'},onclick:async function(){
    if (!fileInput.files || !fileInput.files[0]) { toast('请先选择文件',false); return; }
    const formData = new FormData();
    formData.append('file', fileInput.files[0]);
    try {
      const res = await fetch(API+'/api/admin/upload-image', {method:'POST',headers:{'X-Admin-Token':token},body:formData});
      const data = await res.json();
      if (data.success) { imageUrl.value = data.url; imgPreview.src = data.url; imgPreview.style.display = 'block'; toast('图片上传成功'); }
      else { toast(data.detail||'上传失败',false); }
    } catch(e) { toast('上传失败: '+e.message,false); }
  }},'上传');

  imageUrl.oninput = function() {
    if (this.value) { imgPreview.src = this.value; imgPreview.style.display = 'block'; }
    else { imgPreview.style.display = 'none'; }
    updatePreview();
  };
  fileInput.onchange = function() { updatePreview(); };

  // Layout: dimensions
  const cardWidth = h('input',{type:'number',placeholder:'280',style:{width:'80px'}});
  const cardHeight = h('input',{type:'number',placeholder:'400',style:{width:'80px'}});
  const imageFit = h('select',{},...Object.entries(IMAGE_FITS).map(([k,v])=>h('option',{value:k},v)));

  // Layout: margins
  const marginTop = h('input',{type:'number',placeholder:'0',value:'0',style:{width:'64px'}});
  const marginLeft = h('input',{type:'number',placeholder:'0',value:'0',style:{width:'64px'}});
  const marginBottom = h('input',{type:'number',placeholder:'0',value:'0',style:{width:'64px'}});
  const marginRight = h('input',{type:'number',placeholder:'0',value:'0',style:{width:'64px'}});

  // ====== Full Card Mockup Preview ======
  const previewEls = {};

  const previewCard = h('div',{className:'preview-card'});
  previewEls.card = previewCard;

  const bgLayer = h('div',{className:'preview-card-bg'});
  previewEls.bg = bgLayer;

  function makeCorner(s) {
    return h('div',{style:Object.assign({position:'absolute',width:'14px',height:'14px',zIndex:'2',pointerEvents:'none'},s)});
  }
  const cTL=makeCorner({top:'3px',left:'3px',borderTop:'1px solid',borderLeft:'1px solid',borderRadius:'4px 0 0 0'});
  const cTR=makeCorner({top:'3px',right:'3px',borderTop:'1px solid',borderRight:'1px solid',borderRadius:'0 4px 0 0'});
  const cBL=makeCorner({bottom:'3px',left:'3px',borderBottom:'1px solid',borderLeft:'1px solid',borderRadius:'0 0 0 4px'});
  const cBR=makeCorner({bottom:'3px',right:'3px',borderBottom:'1px solid',borderRight:'1px solid',borderRadius:'0 0 4px 0'});
  previewEls.corners = [cTL,cTR,cBL,cBR];

  const contentDiv = h('div',{className:'preview-card-content'});

  // Header
  const headerRow = h('div',{className:'preview-header'});
  const typeIconCircle = h('div',{className:'preview-icon-circle'});
  const typeIconText = h('span',{});
  typeIconCircle.appendChild(typeIconText);
  previewEls.typeIconCircle = typeIconCircle;
  previewEls.typeIconText = typeIconText;

  const nameArea = h('div',{className:'preview-name-area'});
  const rarityBadge = h('span',{style:{display:'inline-block',padding:'0 5px',borderRadius:'3px',fontSize:'9px',fontWeight:'bold',color:'#fff',marginRight:'3px'}});
  const nameText = h('span',{className:'preview-name'});
  nameArea.appendChild(rarityBadge);
  nameArea.appendChild(nameText);
  previewEls.rarityBadge = rarityBadge;
  previewEls.nameText = nameText;

  const levelCircle = h('div',{className:'preview-level-circle'});
  const levelText = h('span',{});
  levelCircle.appendChild(levelText);
  previewEls.levelCircle = levelCircle;
  previewEls.levelText = levelText;

  headerRow.appendChild(typeIconCircle);
  headerRow.appendChild(nameArea);
  headerRow.appendChild(levelCircle);

  // Mantra section
  const mantraSection = h('div',{className:'preview-mantra-section',
    style:{background:'rgba(0,0,0,.3)',border:'1px solid rgba(255,255,255,.08)'}});
  const mantraImg = h('img',{className:'preview-mantra-img'});
  const mantraTextEl = h('div',{className:'preview-mantra-text'});
  mantraSection.appendChild(mantraImg);
  mantraSection.appendChild(mantraTextEl);
  previewEls.mantraSection = mantraSection;
  previewEls.mantraImg = mantraImg;
  previewEls.mantraText = mantraTextEl;

  // Footer
  const footerDiv = h('div',{className:'preview-footer'});
  const energyRow = h('div',{className:'preview-energy-row'});
  const energyLabel = h('span',{});
  energyRow.appendChild(h('span',{},'\u26A1'));
  energyRow.appendChild(energyLabel);
  previewEls.energyLabel = energyLabel;

  const btnRow = h('div',{className:'preview-btn-row'});
  const chargeBtn = h('button',{className:'preview-btn',style:{background:'#555'}}, '\u5145\u503C');
  const giftBtn   = h('button',{className:'preview-btn',style:{background:'#6B4EFF'}}, '\u8D60\u9001');
  previewEls.chargeBtn = chargeBtn;
  previewEls.giftBtn   = giftBtn;
  btnRow.appendChild(chargeBtn);
  btnRow.appendChild(giftBtn);
  footerDiv.appendChild(energyRow);
  footerDiv.appendChild(btnRow);

  // Assemble content
  contentDiv.appendChild(headerRow);
  contentDiv.appendChild(mantraSection);
  contentDiv.appendChild(footerDiv);

  // Assemble card
  previewCard.appendChild(bgLayer);
  previewCard.appendChild(cTL);
  previewCard.appendChild(cTR);
  previewCard.appendChild(cBL);
  previewCard.appendChild(cBR);
  previewCard.appendChild(contentDiv);

  const previewOuter = h('div',{style:{display:'flex',justifyContent:'center',padding:'4px 0'}}, previewCard);

  // ====== updatePreview (full card mockup) ======
  function updatePreview() {
    const el = previewEls;
    const t = type.value || 'HEALTH';
    const lv = parseInt(level.value) || 1;
    const col = TYPE_COLORS[t] || TYPE_COLORS.HEALTH;
    const icon = TYPE_ICONS[t] || '\u2728';
    const typeName = CARD_TYPES[t] || t;

    // Rarity derived from energy level
    const lvToRarity = {1:'IRON',2:'BRONZE',3:'SILVER',4:'GOLD',5:'BLACK_GOLD'};
    const rk = lvToRarity[lv] || 'IRON';
    const rarityName = RARITY_NAMES[rk] || '';
    const rarityCol = RARITY_COLORS_MAP[rk] || '#888';

    // Scale card
    const cw = parseInt(cardWidth.value) || 280;
    const ch = parseInt(cardHeight.value) || 400;
    const maxW = 280, maxH = 500;
    const scale = Math.min(maxW / cw, maxH / ch);
    el.card.style.width  = Math.round(cw * scale) + 'px';
    el.card.style.height = Math.round(ch * scale) + 'px';

    // Background
    el.bg.style.background = 'linear-gradient(135deg, ' + col.rgba + ', #1A1A2E 50%, #0A0A14)';

    // Border + glow
    el.card.style.border = '2px solid ' + col.hex;
    el.card.style.boxShadow = '0 0 14px ' + col.glow + ', 0 0 28px ' + col.rgba;

    // Corner decorations
    el.corners.forEach(function(c) { c.style.borderColor = col.hex; });

    // Header: type icon circle
    el.typeIconCircle.style.background = col.rgba;
    el.typeIconCircle.style.borderColor = col.hex;
    el.typeIconText.textContent = icon;

    // Header: rarity badge + name
    el.rarityBadge.textContent = rarityName;
    el.rarityBadge.style.background = rarityCol;
    el.nameText.textContent = typeName;
    el.nameText.style.color = col.hex;

    // Header: level circle
    el.levelText.textContent = lv;
    el.levelCircle.style.background = 'radial-gradient(circle, ' + col.hex + ', ' + col.rgba + ')';

    // Mantra section border
    el.mantraSection.style.borderColor = col.rgba;

    // Image
    var src = imageUrl.value || '';
    if (!src && fileInput.files && fileInput.files[0]) {
      src = URL.createObjectURL(fileInput.files[0]);
    }
    if (src) {
      el.mantraImg.src = src;
      el.mantraImg.style.display = 'block';
      el.mantraImg.style.objectFit = (imageFit.value || 'COVER').toLowerCase();
    } else {
      el.mantraImg.style.display = 'none';
    }

    // Image margins (scaled)
    var mt = parseInt(marginTop.value)||0, ml = parseInt(marginLeft.value)||0;
    var mb = parseInt(marginBottom.value)||0, mr = parseInt(marginRight.value)||0;
    el.mantraImg.style.marginTop    = Math.round(mt * scale) + 'px';
    el.mantraImg.style.marginLeft   = Math.round(ml * scale) + 'px';
    el.mantraImg.style.marginBottom = Math.round(mb * scale) + 'px';
    el.mantraImg.style.marginRight  = Math.round(mr * scale) + 'px';

    // Mantra text
    el.mantraText.textContent = mantra.value || '(\u8F93\u5165\u5492\u8BED...)';

    // Footer: energy + buttons
    el.energyLabel.textContent = '\u80FD\u91CF: ' + lv + '/' + lv;
    el.energyLabel.style.color = col.hex;
    el.chargeBtn.style.background = col.hex;
  }

  // Bindings
  type.onchange = updatePreview;
  mantra.oninput = updatePreview;
  level.onchange = updatePreview;
  [cardWidth,cardHeight,marginTop,marginLeft,marginBottom,marginRight].forEach(function(el){el.oninput=updatePreview;});
  imageFit.onchange = updatePreview;

  // Populate fields if editing
  if (card) {
    type.value = card.card_type;
    mantra.value = card.mantra;
    level.value = String(card.energy_level);
    if (card.image_url) { imageUrl.value = card.image_url; imgPreview.src = card.image_url; imgPreview.style.display = 'block'; }
    statusToggle.value = card.status || 'PENDING';
    if (card.card_width) cardWidth.value = card.card_width;
    if (card.card_height) cardHeight.value = card.card_height;
    if (card.image_fit) imageFit.value = card.image_fit;
    marginTop.value = card.margin_top||0;
    marginLeft.value = card.margin_left||0;
    marginBottom.value = card.margin_bottom||0;
    marginRight.value = card.margin_right||0;
  }

  setTimeout(updatePreview, 100);

  const sectionTitle = function(t) { return h('div',{style:{color:'#b794ff',fontWeight:'bold',marginTop:'12px',marginBottom:'6px',borderBottom:'1px solid #333',paddingBottom:'3px'}}, t); };

  const content = h('div',{className:'modal-grid'},
    // ====== LEFT COLUMN ======
    h('div',{className:'modal-grid-left'},
      sectionTitle('\u57FA\u672C\u4FE1\u606F'),
      h('div',{className:'form-row'},
        h('label',{style:{flex:'0 0 auto'}}, '\u7C7B\u578B'), type,
        h('label',{style:{flex:'0 0 auto'}}, '\u7B49\u7EA7'), level,
      ),
      h('label',{},'\u5492\u8BED'), mantra,

      sectionTitle('\u53D1\u884C\u72B6\u6001'),
      h('label',{},'\u72B6\u6001'), statusToggle,

      sectionTitle('\u5361\u724C\u56FE\u7247'),
      h('div',{className:'form-row'}, fileInput, uploadBtn),
      h('label',{},'\u6216\u8F93\u5165\u56FE\u7247URL'), imageUrl,
      h('div',{style:{textAlign:'center'}}, imgPreview),

      sectionTitle('\u5361\u724C\u5E03\u5C40'),
      h('div',{className:'form-row'},
        h('label',{style:{flex:'0 0 auto'}}, '\u5C3A\u5BF8: \u5BBD'), cardWidth,
        h('label',{style:{flex:'0 0 auto'}}, '\u9AD8'), cardHeight,
      ),
      h('label',{},'\u56FE\u7247\u586B\u5145\u6A21\u5F0F'), imageFit,
      h('div',{style:{display:'grid',gridTemplateColumns:'1fr 1fr',gap:'2px 12px'}},
        h('label',{},'\u4E0A\u8FB9\u8DDD'), h('label',{},'\u5DE6\u8FB9\u8DDD'),
        marginTop, marginLeft,
        h('label',{},'\u4E0B\u8FB9\u8DDD'), h('label',{},'\u53F3\u8FB9\u8DDD'),
        marginBottom, marginRight,
      ),
    ),

    // ====== RIGHT COLUMN ======
    h('div',{className:'modal-grid-right'},
      sectionTitle('\u5B9E\u65F6\u9884\u89C8'),
      previewOuter,
    ),
  );

  showModal(card?'\u7F16\u8F91\u5361\u724C':'\u65B0\u589E\u5361\u724C', content, async function(){
    const payload = {
      card_type:type.value, mantra:mantra.value, energy_level:parseInt(level.value),
      image_url:imageUrl.value||null, status:statusToggle.value,
      card_width:parseInt(cardWidth.value)||null, card_height:parseInt(cardHeight.value)||null,
      image_fit:imageFit.value,
      margin_top:parseInt(marginTop.value)||0, margin_left:parseInt(marginLeft.value)||0,
      margin_bottom:parseInt(marginBottom.value)||0, margin_right:parseInt(marginRight.value)||0,
    };
    if (card) { await api('PUT','/api/admin/preset-cards/'+card.id, payload); }
    else { await api('POST','/api/admin/preset-cards', payload); }
    toast(card?'\u5DF2\u66F4\u65B0':'\u521B\u5EFA\u6210\u529F'); closeModal(); renderContent();
  });
}

async function deleteCard(id) {
  if (!confirm('确认删除？')) return;
  await api('DELETE','/api/admin/preset-cards/'+id);
  toast('已删除'); renderContent();
}

// ========== Archetype Management ==========
function ArchetypesTab() {
  const container = h('div',{});
  const header = h('div',{style:{display:'flex',justifyContent:'space-between',alignItems:'center',marginBottom:'16px'}},
    h('h3',{},'卡牌原型 (65个原型 → 365张卡牌)'),
  );
  const list = h('div',{});
  container.append(header, list);

  api('GET','/api/admin/archetypes').then(data=>{
    if (data.archetypes && data.archetypes.length>0) {
      const byFaction = {};
      data.archetypes.forEach(a=>{
        if (!byFaction[a.faction]) byFaction[a.faction] = [];
        byFaction[a.faction].push(a);
      });
      Object.entries(byFaction).forEach(([faction, arches])=>{
        const factionCard = h('div',{className:'card'});
        factionCard.append(h('h3',{style:{marginBottom:'8px'}}, badgeType(faction), ' ('+arches.length+'个原型)'));
        arches.forEach(a=>{
          const rarityBadge = h('span',{className:'badge badge-lv'+(RARITY_TO_LV[a.rarity]||1)}, RARITY_NAMES[a.rarity]||a.rarity);
          const typeBadge = h('span',{className:'badge',style:{background:'#555',color:'#ccc'}}, TYPE_NAMES[a.card_type]||a.card_type);
          let names = [];
          try { names = JSON.parse(a.name_templates_json); } catch(e){}
          const row = h('div',{className:'item-row',style:{cursor:'pointer'},onclick:()=>showArchetypeDetail(a)},
            h('div',{className:'info'},
              h('div',{className:'title'}, rarityBadge, ' ', typeBadge, ' ', a.archetype_id),
              h('div',{className:'sub'}, '名称模板: '+(names.slice(0,3).join(', '))+'... · 费用: '+a.base_cost+' · v'+a.version),
            ),
          );
          factionCard.append(row);
        });
        list.append(factionCard);
      });
    } else {
      list.append(h('div',{className:'empty'},'暂无原型数据'));
    }
  });

  return h('div',{}, container);
}

function showArchetypeDetail(a) {
  let names = [], tags = [], stats = null, effects = [];
  try { names = JSON.parse(a.name_templates_json); } catch(e){}
  try { tags = JSON.parse(a.tags_json||'[]'); } catch(e){}
  try { stats = JSON.parse(a.base_stats_json||'{}'); } catch(e){}
  try { effects = JSON.parse(a.base_effects_json||'[]'); } catch(e){}

  const effectDescs = effects.map(e=>{
    let desc = e.type;
    if (e.target) desc += ' → '+e.target;
    if (e.value) desc += ' ('+e.value+')';
    if (e.condition) desc += ' ['+e.condition+']';
    if (e.subtype) desc += ' ['+e.subtype+']';
    return desc;
  });

  const content = h('div',{style:{maxHeight:'60vh',overflow:'auto'}},
    h('div',{style:{marginBottom:'12px'}},
      h('span',{className:'badge badge-'+(a.faction.toLowerCase()),style:{marginRight:'6px'}}, CARD_TYPES[a.faction]||a.faction),
      h('span',{className:'badge badge-lv'+(RARITY_TO_LV[a.rarity]||1),style:{marginRight:'6px'}}, RARITY_NAMES[a.rarity]||a.rarity),
      h('span',{className:'badge',style:{background:'#555',color:'#ccc',marginRight:'6px'}}, TYPE_NAMES[a.card_type]||a.card_type),
      h('span',{className:'badge',style:{background:a.is_active?'#4caf50':'#e91e63',color:'#fff'}}, a.is_active?'启用':'禁用'),
    ),
    h('p',{style:{color:'#b794ff',fontSize:'16px',marginBottom:'8px'}}, a.archetype_id),
    h('label',{},'ID'), h('p',{style:{color:'#888',marginBottom:'12px'}}, a.archetype_id),
    h('label',{},'名称模板 ('+names.length+'个)'),
    h('div',{style:{color:'#ccc',marginBottom:'12px',background:'#2a2a4a',padding:'8px',borderRadius:'8px'}},
      ...names.map(n=>h('span',{style:{display:'inline-block',marginRight:'8px',marginBottom:'4px',padding:'2px 8px',background:'#444',borderRadius:'4px',fontSize:'13px'}}, n))
    ),
    h('label',{},'费用'), h('p',{style:{color:'#fff',marginBottom:'12px'}}, a.base_cost),
  );

  if (stats && (stats.attack || stats.health)) {
    content.append(
      h('label',{},'基础属性'),
      h('div',{style:{color:'#ccc',marginBottom:'12px'}},
        h('span',{style:{marginRight:'16px'}}, '⚔ 攻击: '+(stats.attack||0)),
        h('span',{}, '❤ 生命: '+(stats.health||0)),
      )
    );
  }

  if (effects.length > 0) {
    const effList = h('div',{style:{marginBottom:'12px'}});
    effects.forEach((e,i)=>{
      effList.append(h('div',{style:{color:'#ccc',padding:'6px 8px',marginBottom:'4px',background:'#2a2a4a',borderRadius:'6px',fontSize:'13px'}},
        h('span',{style:{color:'#888'}}, '#'+(i+1)+' '),
        h('span',{style:{color:'#b794ff'}}, e.type),
        ' → '+e.target+' | 值:'+(e.value||0)+(e.condition?' | 条件:'+e.condition:'')+(e.subtype?' | 子类:'+e.subtype:'')+(e.max?' | 最大:'+e.max:'')+(e.risk?' | 风险:'+e.risk:'')
      ));
    });
    content.append(h('label',{},'效果DSL ('+effects.length+'个)'), effList);
  }

  if (a.lore_template) {
    content.append(h('label',{},'背景文本模板'), h('p',{style:{color:'#ccc',marginBottom:'12px',fontStyle:'italic',background:'#2a2a4a',padding:'8px',borderRadius:'8px'}}, a.lore_template));
  }

  if (tags.length > 0) {
    content.append(h('label',{},'标签'),
      h('div',{style:{marginBottom:'12px'}},
        ...tags.map(t=>h('span',{style:{display:'inline-block',marginRight:'6px',marginBottom:'4px',padding:'2px 8px',background:'#333',borderRadius:'4px',fontSize:'12px',color:'#ccc'}}, t))
      ));
  }

  content.append(
    h('label',{},'版本'), h('p',{style:{color:'#888',marginBottom:'12px'}}, 'v'+a.version),
  );

  showModal('原型详情: '+a.archetype_id, content, null);
}

// ========== Store Management ==========
function StoreTab() {
  const container = h('div',{});
  const addBtn = h('button',{className:'btn btn-primary',onclick:showStoreModal},'+ 新增商品');
  const header = h('div',{style:{display:'flex',justifyContent:'space-between',alignItems:'center',marginBottom:'16px'}},
    h('h3',{},'商店物品'),
    addBtn
  );
  const list = h('div',{});
  container.append(header, list);

  api('GET','/api/admin/store-items').then(data=>{
    if (data.items && data.items.length>0) {
      data.items.forEach(i=>{
        const typeLabel = i.item_type==='STONE' ? '水晶: '+ (CARD_TYPES[i.stone_type]||'') : '能量包: +'+i.energy_amount;
        list.append(h('div',{className:'item-row'},
          h('div',{className:'info'},
            h('div',{className:'title'},i.name+' ('+typeLabel+')'),
            h('div',{className:'sub'},'价格: '+i.price+' 能量 · '+(i.is_active?'上架':'下架')),
          ),
          h('button',{className:'btn btn-danger btn-sm',onclick:()=>deleteStoreItem(i.id)},'删除')
        ));
      });
    } else {
      list.append(h('div',{className:'empty'},'暂无商品'));
    }
  });

  return h('div',{className:'card'}, container);
}

function showStoreModal() {
  const type = h('select',{onchange:function(){stoneType.style.display=this.value==='STONE'?'block':'none';}},
    h('option',{value:'ENERGY_PACK'},'能量包'),
    h('option',{value:'STONE'},'水晶石'),
  );
  const name = h('input',{placeholder:'商品名称'});
  const stoneType = h('select',{style:{display:'none'}},...Object.entries(CARD_TYPES).map(([k,v])=>h('option',{value:k},v)));
  const energy = h('input',{type:'number',placeholder:'能量值',value:'0'});
  const price = h('input',{type:'number',placeholder:'价格（能量点数）',value:'0'});
  const content = h('div',{},
    h('label',{},'商品类型'), type,
    h('label',{},'名称'), name,
    h('label',{},'水晶类型'), stoneType,
    h('label',{},'能量值（能量包有效）'), energy,
    h('label',{},'价格'), price,
  );
  showModal('新增商品', content, async ()=>{
    await api('POST','/api/admin/store-items',{
      item_type:type.value, name:name.value,
      stone_type:type.value==='STONE'?stoneType.value:null,
      energy_amount:parseInt(energy.value)||0,
      price:parseInt(price.value)||0,
    });
    toast('创建成功'); closeModal(); renderContent();
  });
}

async function deleteStoreItem(id) {
  if (!confirm('确认删除？')) return;
  await api('DELETE','/api/admin/store-items/'+id);
  toast('已删除'); renderContent();
}

// ========== Plaza Management (公告 + 活动 + 帖子管理) ==========
let plazaFilter = '';
let plazaPage = 0;
const PLAZA_PAGE_SIZE = 30;

function PlazaTab() {
  const container = h('div',{});
  // Publish section
  const postType = h('select',{style:{marginBottom:'8px'}},
    h('option',{value:'ANNOUNCEMENT'},'公告'),
    h('option',{value:'ACTIVITY'},'活动'),
  );
  const title = h('input',{placeholder:'公告标题（仅公告需要）'});
  const content = h('textarea',{placeholder:'内容',style:{minHeight:'80px'}});
  const publishBtn = h('button',{className:'btn btn-primary',onclick:async ()=>{
    if (!content.value.trim()) return toast('请输入内容',false);
    const type = postType.value;
    if (type === 'ANNOUNCEMENT') {
      if (!title.value.trim()) return toast('请输入公告标题',false);
      await api('POST','/api/admin/announcements',{title:title.value,content:content.value});
      toast('公告已发布到广场');
    } else {
      await api('POST','/api/admin/activities',{content:content.value});
      toast('活动已发布到广场');
    }
    title.value=''; content.value=''; renderContent();
  }},'发布');

  const publishCard = h('div',{className:'card'},
    h('h3',{},'发布到广场'),
    h('label',{},'类型'), postType,
    h('label',{},'标题（公告）'), title,
    h('label',{},'内容'), content,
    h('div',{style:{marginTop:'12px'}}, publishBtn)
  );

  // List section
  const typeFilter = h('select',{onchange:function(){plazaFilter=this.value;plazaPage=0;renderContent();}},
    h('option',{value:''},'全部类型'),
    h('option',{value:'ANNOUNCEMENT'},'公告'),
    h('option',{value:'ACTIVITY'},'活动'),
    h('option',{value:'BLESSING'},'祈福'),
    h('option',{value:'WISH'},'许愿'),
  );
  const listHeader = h('div',{style:{display:'flex',justifyContent:'space-between',alignItems:'center',marginBottom:'12px'}},
    h('h3',{},'广场帖子管理'),
    typeFilter
  );
  const list = h('div',{});
  const pagination = h('div',{style:{display:'flex',justifyContent:'center',gap:'8px',marginTop:'12px'}});

  const listCard = h('div',{className:'card'}, listHeader, list, pagination);

  const params = '?skip='+(plazaPage*PLAZA_PAGE_SIZE)+'&limit='+PLAZA_PAGE_SIZE
    +(plazaFilter?'&post_type='+plazaFilter:'');

  api('GET','/api/admin/plaza-posts'+params).then(data=>{
    if (data.posts && data.posts.length>0) {
      const totalPages = Math.ceil(data.total / PLAZA_PAGE_SIZE);
      list.append(h('div',{style:{color:'#888',marginBottom:'8px'}},
        '共 '+data.total+' 条 (第'+(plazaPage+1)+'/'+totalPages+'页)'
      ));
      data.posts.forEach(p=>{
        const typeLabel = {ANNOUNCEMENT:'公告',ACTIVITY:'活动',BLESSING:'祈福',WISH:'许愿'}[p.post_type]||p.post_type;
        const typeColor = {ANNOUNCEMENT:'#ff9800',ACTIVITY:'#6b4eff',BLESSING:'#e91e63',WISH:'#ffd700'}[p.post_type]||'#888';
        list.append(h('div',{className:'item-row'},
          h('div',{style:{display:'flex',alignItems:'center',flex:1}},
            h('span',{className:'badge',style:{background:typeColor,color:'#fff',marginRight:'8px'}}, typeLabel),
            h('div',{className:'info'},
              h('div',{className:'title'}, p.content.substring(0,80)+(p.content.length>80?'...':'')),
              h('div',{className:'sub'},
                (p.user_nickname||'匿名')+' · '+(p.pray_count||0)+' 祈福 · '+p.created_at
              ),
            ),
          ),
          h('button',{className:'btn btn-danger btn-sm',onclick:async ()=>{
            if (!confirm('确认删除这条帖子？')) return;
            await api('DELETE','/api/admin/plaza-posts/'+p.id);
            toast('已删除'); renderContent();
          }},'删除'),
        ));
      });

      if (totalPages > 1) {
        if (plazaPage > 0) {
          pagination.append(h('button',{className:'btn btn-sm',style:{background:'#555',color:'#fff'},onclick:()=>{plazaPage--;renderContent();}},'← 上一页'));
        }
        pagination.append(h('span',{style:{color:'#888',padding:'4px 12px'}},(plazaPage+1)+' / '+totalPages));
        if (plazaPage < totalPages-1) {
          pagination.append(h('button',{className:'btn btn-sm',style:{background:'#555',color:'#fff'},onclick:()=>{plazaPage++;renderContent();}},'下一页 →'));
        }
      }
    } else {
      list.append(h('div',{className:'empty'},'暂无帖子'));
    }
  });

  container.append(publishCard, listCard);
  return h('div',{}, container);
}

// ========== Modal ==========
let modalCallback = null;

function showModal(title, content, cb) {
  modalCallback = cb;
  const modal = document.getElementById('modal');
  modal.querySelector('h3').textContent = title;
  const body = modal.querySelector('.modal-body');
  body.innerHTML = '';
  body.appendChild(content);
  const confirmBtn = document.getElementById('modal-confirm');
  if (cb) {
    confirmBtn.style.display = '';
    confirmBtn.textContent = '确认';
  } else {
    confirmBtn.style.display = 'none';
  }
  modal.classList.add('show');
}

function closeModal() {
  document.getElementById('modal').classList.remove('show');
}

// ========== Render ==========
function renderContent() {
  const main = document.getElementById('main');
  main.innerHTML = '';
  switch(activeTab) {
    case 'cards': main.appendChild(CardsTab()); break;
    case 'archetypes': main.appendChild(ArchetypesTab()); break;
    case 'store': main.appendChild(StoreTab()); break;
    case 'plaza': main.appendChild(PlazaTab()); break;
  }
}

function render() {
  const app = document.getElementById('app');
  app.innerHTML = '';
  if (!token) {
    app.appendChild(LoginPage());
    return;
  }
  app.appendChild(h('div',{className:'header'},
    h('h1',{},'能量石 管理后台'),
    h('button',{onclick:()=>{sessionStorage.removeItem(TOKEN_KEY);token='';render();}},'退出')
  ));
  app.appendChild(Tabs());
  const main = h('div',{id:'main',className:'content'});
  app.appendChild(main);

  // Modal
  app.appendChild(h('div',{id:'modal',className:'modal'},
    h('div',{className:'modal-box'},
      h('h3',{}),
      h('div',{className:'modal-body'}),
      h('div',{className:'modal-actions'},
        h('button',{className:'btn',onclick:closeModal,style:{background:'#555',color:'#fff'}},'关闭'),
        h('button',{id:'modal-confirm',className:'btn btn-primary',onclick:async ()=>{
          if (modalCallback) await modalCallback();
          closeModal();
        }},'确认'),
      ),
    )
  ));

  renderContent();
}

render();
</script>
</body>
</html>"""


@router.get("/admin", response_class=HTMLResponse)
@router.get("/admin/", response_class=HTMLResponse)
def admin_page():
    """管理后台登录/主页。"""
    return HTMLResponse(content=ADMIN_PAGE_HTML)
