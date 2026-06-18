const APP_NAME = process.env.APP_NAME || 'CertVault';

module.exports = function () {
  return `<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no,viewport-fit=cover">
<meta name="apple-mobile-web-app-capable" content="yes">
<title>设备信息 - ${APP_NAME}</title>
<link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700&display=swap" rel="stylesheet">
<style>
:root{
  --bg:#F6F7FA;--surface:#FFFFFF;--surface-hover:#F9F9F9;--border:#EFF2F3;
  --text:#2C3659;--text-sec:#5F6680;--text-muted:#7C8499;
  --blue:#066DE6;--blue-light:rgba(6,109,230,.08);
  --green:#4CD964;--orange:#FF6D00;--red:#E60019;
  --radius:16px;--radius-sm:10px;
  --shadow:0 2px 8px rgba(44,54,89,.04),0 0 0 1px rgba(44,54,89,.03);
  --font:'Plus Jakarta Sans',-apple-system,BlinkMacSystemFont,system-ui,sans-serif;
}
@media(prefers-color-scheme:dark){:root{
  --bg:#111315;--surface:#202427;--surface-hover:#282C30;--border:#292E32;
  --text:#FFFFFF;--text-sec:#B8BFCF;--text-muted:#919BB0;
  --blue-light:rgba(6,109,230,.15);
  --shadow:0 2px 8px rgba(0,0,0,.2),0 0 0 1px rgba(255,255,255,.04);
}}
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:var(--font);background:var(--bg);color:var(--text);
  min-height:100vh;min-height:100dvh;display:flex;flex-direction:column;
  align-items:center;padding:20px;padding-top:calc(20px + env(safe-area-inset-top));
  -webkit-font-smoothing:antialiased}
.wrap{width:100%;max-width:420px;flex:1;display:flex;flex-direction:column;justify-content:center}
.card{background:var(--surface);border-radius:var(--radius);padding:28px 24px;box-shadow:var(--shadow)}
h1{font-size:22px;font-weight:700;margin-bottom:6px;letter-spacing:-.3px}
.sub{font-size:13px;color:var(--text-muted);line-height:1.5}
.hd{text-align:center;margin-bottom:24px}
.hd-icon{width:56px;height:56px;border-radius:50%;display:inline-flex;align-items:center;justify-content:center;margin-bottom:14px;font-size:26px}
.hd-icon.ok{background:linear-gradient(135deg,var(--green),#22C55E)}
.hd-icon.wait{background:linear-gradient(135deg,var(--orange),#F59E0B)}
.dev{display:flex;align-items:center;gap:14px;padding-bottom:16px;border-bottom:1px solid var(--border);margin-bottom:4px}
.dev-av{width:44px;height:44px;border-radius:12px;background:var(--blue);display:flex;align-items:center;justify-content:center;flex-shrink:0;font-size:22px;color:#fff}
.dev-n{font-size:15px;font-weight:700}
.dev-s{font-size:12px;color:var(--text-muted);margin-top:2px}
.row{display:flex;align-items:center;padding:13px 0;border-bottom:1px solid var(--border)}
.row:last-child{border-bottom:none}
.row.hl{background:var(--blue-light);margin:8px -12px 0;padding:12px;border-radius:var(--radius-sm);border:none}
.rl{font-size:12px;color:var(--text-muted);flex-shrink:0;min-width:68px;font-weight:500}
.rv{flex:1;font-size:13px;font-weight:600;text-align:right;word-break:break-all;line-height:1.4}
.mono{font-family:'SF Mono',ui-monospace,monospace;font-size:11px;font-weight:700;letter-spacing:.2px}
.cpb{background:none;border:none;padding:5px;cursor:pointer;color:var(--blue);border-radius:6px;flex-shrink:0;margin-left:6px;display:inline-flex;align-items:center}
.cpb:active{opacity:.6}
.cpb svg{display:block}
.acts{margin-top:16px;display:flex;flex-direction:column;gap:10px}
.btn{display:flex;align-items:center;justify-content:center;gap:8px;width:100%;
  padding:14px;border:none;border-radius:var(--radius-sm);font-family:var(--font);
  font-size:15px;font-weight:700;cursor:pointer;-webkit-tap-highlight-color:transparent;text-decoration:none}
.bp{background:var(--blue);color:#fff;box-shadow:0 4px 12px rgba(6,109,230,.25)}
.bp:active{transform:scale(.98);opacity:.9}
.bs{background:var(--surface-hover);color:var(--blue);border:1px solid var(--border)}
.bs:active{opacity:.7}
.bg{background:linear-gradient(135deg,#4CD964,#22C55E);color:#fff;box-shadow:0 4px 12px rgba(34,197,94,.25)}
.bg:active{transform:scale(.98);opacity:.9}
.btn:disabled{opacity:.5;pointer-events:none}
.bind-panel{margin-top:16px}
.bind-panel .card{padding:20px}
.bind-title{font-size:15px;font-weight:700;margin-bottom:14px;display:flex;align-items:center;gap:8px}
.field{margin-bottom:12px}
.field label{display:block;font-size:12px;color:var(--text-muted);margin-bottom:6px;font-weight:600}
.field input,.field select{width:100%;padding:11px 14px;border:1px solid var(--border);border-radius:var(--radius-sm);
  font-family:var(--font);font-size:14px;background:var(--surface-hover);color:var(--text);outline:none;
  -webkit-appearance:none;appearance:none}
.field input:focus,.field select:focus{border-color:var(--blue);box-shadow:0 0 0 3px var(--blue-light)}
.field select{background-image:url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 24 24' fill='none' stroke='%237C8499' stroke-width='2.5'%3E%3Cpath d='M6 9l6 6 6-6'/%3E%3C/svg%3E");
  background-repeat:no-repeat;background-position:right 12px center;padding-right:36px}
.bind-result{margin-top:12px;padding:14px;border-radius:var(--radius-sm);font-size:13px;line-height:1.6}
.bind-result.ok{background:rgba(76,217,100,.1);border:1px solid rgba(76,217,100,.2);color:#16A34A}
.bind-result.fail{background:rgba(230,0,25,.08);border:1px solid rgba(230,0,25,.15);color:var(--red)}
@media(prefers-color-scheme:dark){.bind-result.ok{color:#4CD964}.bind-result.fail{color:#FF6B6B}}
.step-list{margin:12px 0 8px;padding:0}
.step-item{display:flex;align-items:center;gap:10px;padding:9px 0;font-size:13px;border-bottom:1px solid var(--border)}
.step-item:last-child{border-bottom:none}
.step-badge{width:20px;height:20px;border-radius:50%;display:flex;align-items:center;justify-content:center;flex-shrink:0;font-size:11px;font-weight:700;color:#fff}
.step-badge.ok{background:var(--green)}.step-badge.skip{background:var(--orange)}.step-badge.err{background:var(--red)}
.pw-box{display:flex;align-items:center;gap:8px;margin:10px 0;padding:12px 14px;
  background:var(--surface-hover);border:1px solid var(--border);border-radius:var(--radius-sm)}
.pw-box .pw-val{flex:1;font-family:'SF Mono',ui-monospace,monospace;font-size:16px;font-weight:700;letter-spacing:1px}
.dl-acts{margin-top:14px;display:flex;flex-direction:column;gap:10px}
.note{margin-top:16px;padding:14px;background:var(--surface-hover);border-radius:var(--radius-sm);
  border:1px solid var(--border);display:flex;gap:10px}
.note p{font-size:11px;color:var(--text-muted);line-height:1.6}
.tut{margin-top:16px}
.tut .card{padding:0;overflow:hidden}
.tut-hd{display:flex;align-items:center;justify-content:space-between;padding:16px 20px;cursor:pointer;-webkit-tap-highlight-color:transparent;user-select:none}
.tut-hd:active{opacity:.7}
.tut-title{font-size:15px;font-weight:700;display:flex;align-items:center;gap:8px}
.tut-arrow{font-size:12px;color:var(--text-muted);transition:transform .25s ease}
.tut-arrow.open{transform:rotate(180deg)}
.tut-body{max-height:0;overflow:hidden;transition:max-height .35s ease}
.tut-body.open{max-height:800px}
.tut-inner{padding:0 20px 20px}
.tut-step{display:flex;gap:14px;position:relative;padding-bottom:20px}
.tut-step:last-child{padding-bottom:0}
.tut-step:not(:last-child)::after{content:'';position:absolute;left:15px;top:34px;bottom:0;width:2px;background:var(--border)}
.tut-num{width:30px;height:30px;border-radius:50%;background:var(--blue);color:#fff;font-size:13px;font-weight:700;display:flex;align-items:center;justify-content:center;flex-shrink:0;position:relative;z-index:1}
.tut-ct{flex:1;padding-top:4px}
.tut-ct h4{font-size:14px;font-weight:700;margin-bottom:4px}
.tut-ct p{font-size:12px;color:var(--text-muted);line-height:1.6}
.tut-tip{margin-top:14px;padding:12px 14px;background:var(--blue-light);border-radius:var(--radius-sm);font-size:12px;color:var(--blue);line-height:1.6;display:flex;gap:8px}
.steps{text-align:left;margin:20px 0;background:var(--surface-hover);border-radius:var(--radius-sm);padding:4px 16px;border:1px solid var(--border)}
.st{display:flex;align-items:center;gap:12px;padding:12px 0;font-size:13px}
.st+.st{border-top:1px solid var(--border)}
.sn{width:22px;height:22px;border-radius:50%;background:var(--blue);color:#fff;font-size:11px;font-weight:700;display:flex;align-items:center;justify-content:center;flex-shrink:0}
.ld{display:flex;flex-direction:column;align-items:center;gap:14px;padding:60px 0}
.sp{width:36px;height:36px;border:3px solid var(--border);border-top-color:var(--blue);border-radius:50%;animation:sp .7s linear infinite}
@keyframes sp{to{transform:rotate(360deg)}}
.brand{margin-top:28px;text-align:center;font-size:12px;color:var(--text-muted);font-weight:500}
.brand b{color:var(--blue);margin-left:4px}
.toast{position:fixed;top:env(safe-area-inset-top,12px);left:50%;transform:translateX(-50%) translateY(-80px);
  background:var(--text);color:var(--bg);padding:10px 20px;border-radius:var(--radius-sm);
  font-size:13px;font-weight:600;transition:transform .25s ease;z-index:99;pointer-events:none}
.toast.show{transform:translateX(-50%) translateY(16px)}
.hidden{display:none!important}
</style>
</head>
<body>
<div class="wrap" id="app"><div class="card"><div class="ld"><div class="sp"></div><div style="font-size:13px;color:var(--text-muted)">正在获取设备信息...</div></div></div></div>
<div class="brand">Powered by <b>${APP_NAME}</b></div>
<div class="toast" id="toast"></div>

<script>
function ic(n,s){s=s||16;var v='<svg width="'+s+'" height="'+s+'" viewBox="0 0 24 24" fill="currentColor" style="display:inline-block;vertical-align:middle;flex-shrink:0">';var m={check:v+'<path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z"/></svg>',copy:v+'<path d="M16 1H4a2 2 0 00-2 2v14h2V3h12V1zm3 4H8a2 2 0 00-2 2v14a2 2 0 002 2h11a2 2 0 002-2V7a2 2 0 00-2-2zm0 16H8V7h11v14z"/></svg>',phone:v+'<path d="M17 1.01L7 1a2 2 0 00-2 2v18a2 2 0 002 2h10a2 2 0 002-2V3a2 2 0 00-2-1.99zM17 19H7V5h10v14zm-4.2 2h-1.6v-1h1.6v1z"/></svg>',link:v+'<path d="M3.9 12a3.1 3.1 0 010-4.39l2.83-2.83a3.1 3.1 0 014.24 0 3.1 3.1 0 01.21 4.11l-1.13 1.13-1.41-1.41.98-.98a1.1 1.1 0 000-1.56 1.1 1.1 0 00-1.56 0L5.23 9.19a1.1 1.1 0 000 1.56l1.41 1.41-1.42 1.42A3.07 3.07 0 013.9 12zm16.2 0a3.1 3.1 0 010 4.39l-2.83 2.83a3.1 3.1 0 01-4.24 0 3.1 3.1 0 01-.21-4.11l1.13-1.13 1.41 1.41-.98.98a1.1 1.1 0 000 1.56 1.1 1.1 0 001.56 0l2.83-2.83a1.1 1.1 0 000-1.56l-1.41-1.41 1.42-1.42c.38.35.78.8 1.32 1.29zM8.29 16.95l1.41-1.41 6.36-6.36 1.41 1.41-6.36 6.36-1.41-1.41-.71.71z"/></svg>',lock:v+'<path d="M18 8h-1V6A5 5 0 007 6v2H6a2 2 0 00-2 2v10a2 2 0 002 2h12a2 2 0 002-2V10a2 2 0 00-2-2zM9 6a3 3 0 016 0v2H9V6zm9 14H6V10h12v10zm-6-3a2 2 0 100-4 2 2 0 000 4z"/></svg>',download:v+'<path d="M19 9h-4V3H9v6H5l7 7 7-7zM5 18v2h14v-2H5z"/></svg>',pkg:v+'<path d="M20 2H4a2 2 0 00-2 2v2a1 1 0 001 1h18a1 1 0 001-1V4a2 2 0 00-2-2zM3 9v11a2 2 0 002 2h14a2 2 0 002-2V9H3zm7 2h4v3h3l-5 5-5-5h3v-3z"/></svg>',install:v+'<path d="M12 2a10 10 0 100 20 10 10 0 000-20zm1 12.59V8h-2v6.59l-2.29-2.3-1.42 1.42L12 18.41l4.71-4.7-1.42-1.42L13 14.59z"/></svg>',refresh:v+'<path d="M17.65 6.35A7.96 7.96 0 0012 4a8 8 0 108 8h-2a6 6 0 11-1.76-4.24L14 10h7V3l-3.35 3.35z"/></svg>',info:v+'<path d="M12 2a10 10 0 100 20 10 10 0 000-20zm1 15h-2v-6h2v6zm0-8h-2V7h2v2z"/></svg>',alert:v+'<path d="M1 21h22L12 2 1 21zm12-3h-2v-2h2v2zm0-4h-2v-4h2v4z"/></svg>',book:v+'<path d="M21 5a2 2 0 00-2-2H5a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2V5zm-4 0v9l-2.5-1.5L12 14V5h5z"/></svg>',clock:v+'<path d="M12 2a10 10 0 100 20 10 10 0 000-20zm1 11h-2V7h2v4h3v2h-3z"/></svg>'};return m[n]||'';}
var rid=new URLSearchParams(location.search).get('id'),app=document.getElementById('app'),pt=null,pc=0;
function toast(m){var t=document.getElementById('toast');t.textContent=m;t.classList.add('show');setTimeout(function(){t.classList.remove('show')},2000)}
function cp(t){if(navigator.clipboard)navigator.clipboard.writeText(t);else{var a=document.createElement('textarea');a.value=t;a.style.cssText='position:fixed;left:-9999px';document.body.appendChild(a);a.select();document.execCommand('copy');document.body.removeChild(a)}toast('已复制到剪贴板')}
function allTxt(d){return['UDID: '+d.udid,d.device_name?'设备: '+d.device_name:'',d.product?'型号: '+d.product:'',d.version?'系统: iOS '+d.version:'',d.serial?'序列号: '+d.serial:''].filter(Boolean).join('\\n')}
function ir(l,v,m){return '<div class="row"><div class="rl">'+l+'</div><div class="rv'+(m?' mono':'')+'">'+v+'</div></div>'}
function hideEl(id){var e=document.getElementById(id);if(e)e.classList.add('hidden')}

var authToken=null;

window.toggleTut=function(hd){
  var body=hd.nextElementSibling;
  var arrow=hd.querySelector('.tut-arrow');
  if(body.classList.contains('open')){body.classList.remove('open');arrow.classList.remove('open')}
  else{body.classList.add('open');arrow.classList.add('open')}
};

function ok(d){
  if(pt){clearInterval(pt);pt=null}
  if(d.auth_token)authToken=d.auth_token;
  if(d.account_id)window._presetAccountId=d.account_id;

  var rs='<div class="row hl"><div class="rl">UDID</div><div class="rv mono">'+d.udid+'</div><button class="cpb" onclick="cp(\\''+d.udid+'\\')">'+ic('copy',14)+'</button></div>';
  if(d.device_name)rs+=ir('设备名称',d.device_name);
  if(d.product)rs+=ir('设备型号',d.product);
  if(d.version)rs+=ir('系统版本','iOS '+d.version);
  if(d.serial)rs+=ir('序列号',d.serial,1);
  if(d.imei)rs+=ir('IMEI',d.imei,1);

  app.innerHTML='<div class="card">'
    +'<div class="hd"><div class="hd-icon ok" style="color:#fff">'+ic('check',26)+'</div><h1>设备识别成功</h1><div class="sub">已获取您的设备信息</div></div>'
    +'<div class="dev"><div class="dev-av">'+ic('phone',22)+'</div><div><div class="dev-n">'+(d.device_name||d.product||'未知设备')+'</div><div class="dev-s">iOS '+(d.version||'-')+'</div></div></div>'
    +rs+'</div>'
    +'<div id="mainArea"></div>'
    +'<div class="acts" id="fallbackActs">'
    +'<button class="btn bg" onclick="showBind()">'+ic('link',16)+' 一键签名绑定</button>'
    +'<button class="btn bp" id="cab" onclick="doCA()">'+ic('copy',16)+' 复制全部信息</button>'
    +'</div>'
    +'<div id="bindArea"></div>'
    +'<div class="note">'+ic('info',16)+' <div><p>描述文件已自动删除，不会影响您的设备。</p><p>如未删除，可前往「设置 → 通用 → VPN与设备管理」手动移除。</p></div></div>';
  window._d=d;

  if(d.auth_token&&d.account_id){
    hideEl('fallbackActs');
    autoBindWithAccount(d);
  }else{
    checkExistingBind(d.udid);
  }
}

window.doCA=function(){if(!window._d)return;cp(allTxt(window._d));var b=document.getElementById('cab');if(b){b.innerHTML=ic('check',16)+' 已复制';setTimeout(function(){b.innerHTML=ic('copy',16)+' 复制全部信息'},2000)}};

window.showBind=function(){
  var ba=document.getElementById('bindArea');
  if(!ba)return;
  if(authToken){loadAccounts();return}
  ba.innerHTML='<div class="bind-panel"><div class="card">'
    +'<div class="bind-title">'+ic('lock',16)+' 登录管理员账号</div>'
    +'<div class="field"><label>用户名</label><input id="bl_user" type="text" placeholder="请输入用户名" autocapitalize="none" autocorrect="off"></div>'
    +'<div class="field"><label>密码</label><input id="bl_pass" type="password" placeholder="请输入密码"></div>'
    +'<div id="bl_err"></div>'
    +'<button class="btn bp" id="bl_btn" onclick="doLogin()" style="margin-top:4px">登录</button>'
    +'</div></div>'
};

window.doLogin=async function(){
  var u=document.getElementById('bl_user').value.trim();
  var p=document.getElementById('bl_pass').value;
  var eb=document.getElementById('bl_err');
  var lb=document.getElementById('bl_btn');
  if(!u||!p){eb.innerHTML='<div class="bind-result fail">请输入用户名和密码</div>';return}
  lb.disabled=true;lb.textContent='登录中...';
  try{
    var r=await fetch('/api/udid/login',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({username:u,password:p})});
    var j=await r.json();
    if(j.success){authToken=j.data.token;loadAccounts()}
    else{eb.innerHTML='<div class="bind-result fail">'+(j.message||'登录失败')+'</div>';lb.disabled=false;lb.textContent='登录'}
  }catch(e){eb.innerHTML='<div class="bind-result fail">网络错误</div>';lb.disabled=false;lb.textContent='登录'}
};

async function autoBindWithAccount(d){
  var ma=document.getElementById('mainArea');
  if(!ma||!d.account_id||!d.auth_token||!d.udid)return;
  var dn=d.device_name||d.product||'Device';
  ma.innerHTML='<div class="bind-panel"><div class="card">'
    +'<div class="bind-title">'+ic('clock',16)+' 自动签名绑定中...</div>'
    +'<div style="font-size:13px;color:var(--text-muted)">正在为此设备注册证书和描述文件，请稍候（10-30秒）...</div>'
    +'</div></div>';
  try{
    var r=await fetch('/api/udid/bindall',{method:'POST',headers:{'Content-Type':'application/json','Authorization':'Bearer '+d.auth_token},
      body:JSON.stringify({account_id:d.account_id,udid:d.udid,name:dn})});
    var j=await r.json();
    if(j.success){
      ma.innerHTML=renderBindSuccess(j.message,j.data);
    }else{
      hideEl('fallbackActs');
      ma.innerHTML='<div class="bind-panel"><div class="card">'
        +'<div class="bind-title">'+ic('alert',16)+' 自动绑定失败</div>'
        +'<div class="bind-result fail">'+( j.message||'失败')+'</div>'
        +'</div></div>';
      var fa=document.getElementById('fallbackActs');if(fa)fa.classList.remove('hidden');
    }
  }catch(e){
    ma.innerHTML='';
    var fa=document.getElementById('fallbackActs');if(fa)fa.classList.remove('hidden');
  }
}

async function checkExistingBind(udid){
  var ma=document.getElementById('mainArea');
  if(!ma||!udid)return;
  try{
    var url='/api/udid/device-bindinfo?udid='+encodeURIComponent(udid);
    if(authToken)url+='&token='+encodeURIComponent(authToken);
    var r=await fetch(url);
    var j=await r.json();
    if(!j.success||!j.data.bound||!j.data.has_resources)return;
    var d=j.data;
    if(d.authenticated&&d.resources&&d.resources[0]&&d.resources[0].download_url){
      hideEl('fallbackActs');
      ma.innerHTML=renderExistResources(d.resources);
    }else{
      ma.innerHTML='<div class="bind-panel"><div class="card">'
        +'<div class="bind-title">'+ic('check',16)+' <span style="color:var(--green)">此设备已绑定签名</span></div>'
        +'<div style="font-size:13px;color:var(--text-muted);margin-bottom:12px">登录后可直接下载已有的 P12 签名包</div>'
        +'<div class="field"><label>用户名</label><input id="ex_user" type="text" placeholder="请输入用户名" autocapitalize="none" autocorrect="off"></div>'
        +'<div class="field"><label>密码</label><input id="ex_pass" type="password" placeholder="请输入密码"></div>'
        +'<div id="ex_err"></div>'
        +'<button class="btn bp" id="ex_btn" onclick="doExLogin()" style="margin-top:4px">登录查看签名包</button>'
        +'</div></div>';
    }
  }catch(e){}
}

function getTutorialHtml(pw){
  var p=pw||'123456';
  return '<div class="tut"><div class="card">'
    +'<div class="tut-hd" onclick="toggleTut(this)">'
    +'<div class="tut-title">'+ic('book',16)+' 全能签使用教程</div>'
    +'<span class="tut-arrow">▼</span></div>'
    +'<div class="tut-body"><div class="tut-inner">'
    +'<div class="tut-step"><div class="tut-num">1</div><div class="tut-ct">'
    +'<h4>安装全能签 + 下载 P12 签名包</h4>'
    +'<p>点击上方「签名安装全能签」按钮安装全能签到设备，安装完成后到「设置 → 通用 → VPN与设备管理」信任证书。</p>'
    +'<p style="margin-top:4px">然后点击「下载 P12 签名包」将签名包保存到手机。</p>'
    +'</div></div>'
    +'<div class="tut-step"><div class="tut-num">2</div><div class="tut-ct">'
    +'<h4>打开全能签获取 UDID</h4>'
    +'<p>打开全能签 App，进入「设置」页面，可以查看到设备的 UDID 信息（和上方显示的一致）。</p>'
    +'</div></div>'
    +'<div class="tut-step"><div class="tut-num">3</div><div class="tut-ct">'
    +'<h4>导入 P12 签名包</h4>'
    +'<p>在全能签中点击「导入文件」，选择刚刚下载的 P12 压缩包，系统会自动识别证书和描述文件。</p>'
    +'<p style="margin-top:4px">导入时输入 P12 密码：</p>'
    +'<div class="pw-box" style="margin-top:6px"><span style="font-size:12px;color:var(--text-muted)">密码:</span><span class="pw-val">'+p+'</span><button class="cpb" onclick="cp(\\''+p+'\\')">'+ic('copy',14)+'</button></div>'
    +'</div></div>'
    +'<div class="tut-step"><div class="tut-num">4</div><div class="tut-ct">'
    +'<h4>验证证书是否有效</h4>'
    +'<p>导入成功后，进入全能签的「证书」页面，查看刚导入的证书状态是否显示为<span style="color:var(--green);font-weight:700"> 有效</span>。</p>'
    +'<p style="margin-top:4px">证书有效即可使用全能签对任意 IPA 进行签名安装。</p>'
    +'</div></div>'
    +'<div class="tut-tip">'+ic('info',14)+' <span>签名包包含 P12 证书和描述文件，导入全能签后即可签名安装任意 IPA 应用。证书有效期内可反复使用。</span></div>'
    +'</div></div></div></div>';
}

function renderExistResources(res){
  var h='<div class="bind-panel"><div class="card"><div class="bind-title">'+ic('check',16)+' <span style="color:var(--green)">此设备已绑定签名</span></div>';
  var pw='123456';
  res.forEach(function(r,i){
    var label=r.bundle_identifier||r.profile_name||('签名包 '+(i+1));
    if(r.cert_password)pw=r.cert_password;
    h+='<div style="padding:10px 0'+(i>0?';border-top:1px solid var(--border)':'')+'">';
    h+='<div style="font-size:13px;font-weight:600;margin-bottom:4px">'+label+'</div>';
    h+='<div style="font-size:11px;color:var(--text-muted);margin-bottom:4px">'+(r.cert_name||r.cert_type)+' · '+(r.profile_name||r.profile_type)+'</div>';
    h+='<div class="pw-box"><span style="font-size:12px;color:var(--text-muted)">P12 密码:</span><span class="pw-val">'+r.cert_password+'</span><button class="cpb" onclick="cp(\\''+r.cert_password+'\\')">'+ic('copy',14)+'</button></div>';
    h+='<div class="dl-acts">';
    h+='<button class="btn bg esign-btn" onclick="signAndInstallEsign(\\''+r.cert_id+'\\',\\''+r.profile_id+'\\',this)">'+ic('pkg',16)+' 签名安装全能签</button>';
    h+='<a href="'+r.download_url+'" class="btn bp" download>'+ic('download',16)+' 下载 P12 签名包</a>';
    h+='</div><div class="esign-result"></div></div>';
  });
  h+='</div></div>';
  h+=getTutorialHtml(pw);
  return h;
}

function renderBindSuccess(msg,data){
  var stepsHtml='';
  if(data.steps&&data.steps.length){
    stepsHtml='<div class="step-list">';
    data.steps.forEach(function(s){
      var badge=s.status==='success'?'ok':(s.status==='skipped'?'skip':'err');
      var icon=s.status==='success'?'✓':(s.status==='skipped'?'↩':'✗');
      stepsHtml+='<div class="step-item"><span class="step-badge '+badge+'">'+icon+'</span><span>'+s.message+'</span></div>';
    });
    stepsHtml+='</div>';
  }
  var pw=data.certificate?data.certificate.password:'123456';
  var h='<div class="bind-panel"><div class="card">'
    +'<div class="bind-title">'+ic('check',16)+' <span style="color:var(--green)">签名绑定完成</span></div>'
    +'<div class="bind-result ok" style="margin-bottom:8px">'+ic('check',14)+' '+msg+'</div>'
    +stepsHtml
    +'<div class="pw-box"><span style="font-size:12px;color:var(--text-muted)">P12 密码:</span><span class="pw-val">'+pw+'</span><button class="cpb" onclick="cp(\\''+pw+'\\')">'+ic('copy',14)+'</button></div>'
    +'<div class="dl-acts">'
    +'<button class="btn bg esign-btn" onclick="signAndInstallEsign(\\''+data.certificate.id+'\\',\\''+data.profile.id+'\\',this)">'+ic('pkg',16)+' 签名安装全能签</button>';
  if(data.download_url){
    h+='<a href="'+data.download_url+'" class="btn bp" download>'+ic('download',16)+' 下载 P12 签名包 (ZIP)</a>';
  }
  h+='</div><div class="esign-result"></div></div></div>';
  h+=getTutorialHtml(pw);
  window._bindResult=data;
  return h;
}

window.doExLogin=async function(){
  var u=document.getElementById('ex_user').value.trim();
  var p=document.getElementById('ex_pass').value;
  var eb=document.getElementById('ex_err');
  var lb=document.getElementById('ex_btn');
  if(!u||!p){eb.innerHTML='<div class="bind-result fail">请输入用户名和密码</div>';return}
  lb.disabled=true;lb.textContent='登录中...';
  try{
    var r=await fetch('/api/udid/login',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({username:u,password:p})});
    var j=await r.json();
    if(j.success){
      authToken=j.data.token;
      hideEl('fallbackActs');
      if(window._d)checkExistingBind(window._d.udid);
    }else{
      eb.innerHTML='<div class="bind-result fail">'+(j.message||'登录失败')+'</div>';
      lb.disabled=false;lb.textContent='登录查看签名包';
    }
  }catch(e){eb.innerHTML='<div class="bind-result fail">网络错误</div>';lb.disabled=false;lb.textContent='登录查看签名包'}
};

async function loadAccounts(){
  var ba=document.getElementById('bindArea');
  if(!ba||!authToken)return;
  ba.innerHTML='<div class="bind-panel"><div class="card"><div class="bind-title">'+ic('link',16)+' 一键签名绑定</div><div style="text-align:center;padding:20px 0;color:var(--text-muted);font-size:13px">加载账号列表...</div></div></div>';
  try{
    var r=await fetch('/api/udid/accounts',{headers:{'Authorization':'Bearer '+authToken}});
    var j=await r.json();
    if(!j.success||!j.data.length){
      ba.innerHTML='<div class="bind-panel"><div class="card"><div class="bind-title">'+ic('link',16)+' 一键签名绑定</div><div class="bind-result fail">'+(j.data&&j.data.length===0?'暂无可用开发者账号':j.message||'获取失败')+'</div></div></div>';
      return}
    var opts='';j.data.forEach(function(a){opts+='<option value="'+a.id+'">'+a.name+'</option>'});
    var dn=window._d?(window._d.device_name||window._d.product||''):'';
    ba.innerHTML='<div class="bind-panel"><div class="card">'
      +'<div class="bind-title">'+ic('link',16)+' 一键签名绑定</div>'
      +'<div class="field"><label>开发者账号</label><select id="bd_acc">'+opts+'</select></div>'
      +'<div class="field"><label>设备名称</label><input id="bd_name" type="text" value="'+dn.replace(/"/g,'&quot;')+'" placeholder="输入设备名称"></div>'
      +'<div class="field"><label>Bundle ID（可选，留空自动生成）</label><input id="bd_bundle" type="text" placeholder="com.example.app"></div>'
      +'<div id="bd_res"></div>'
      +'<button class="btn bg" id="bd_btn" onclick="doBind()">一键签名绑定</button>'
      +'</div></div>'
  }catch(e){ba.innerHTML='<div class="bind-panel"><div class="card"><div class="bind-result fail">网络错误</div></div></div>'}
}

window.doBind=async function(){
  var acc=document.getElementById('bd_acc').value;
  var nm=document.getElementById('bd_name').value.trim();
  var bi=(document.getElementById('bd_bundle')||{}).value||'';
  var rb=document.getElementById('bd_res');
  var bb=document.getElementById('bd_btn');
  if(!nm){rb.innerHTML='<div class="bind-result fail">请输入设备名称</div>';return}
  if(!window._d||!window._d.udid){rb.innerHTML='<div class="bind-result fail">UDID 不可用</div>';return}
  bb.disabled=true;bb.textContent='签名绑定中，请稍候...';
  rb.innerHTML='<div style="padding:8px 0;color:var(--text-muted);font-size:13px">正在注册设备、创建证书和描述文件，可能需要 10-30 秒...</div>';
  try{
    var body={account_id:acc,udid:window._d.udid,name:nm};
    if(bi.trim())body.bundle_identifier=bi.trim();
    var r=await fetch('/api/udid/bindall',{method:'POST',headers:{'Content-Type':'application/json','Authorization':'Bearer '+authToken},body:JSON.stringify(body)});
    var j=await r.json();
    if(j.success){
      hideEl('fallbackActs');
      document.getElementById('bindArea').innerHTML='';
      var ma=document.getElementById('mainArea');
      if(ma)ma.innerHTML=renderBindSuccess(j.message,j.data);
    }else{
      rb.innerHTML='<div class="bind-result fail">✗ '+(j.message||'签名绑定失败')+'</div>';
      bb.disabled=false;bb.textContent='一键签名绑定';
    }
  }catch(e){
    rb.innerHTML='<div class="bind-result fail">网络错误，请重试</div>';
    bb.disabled=false;bb.textContent='一键签名绑定';
  }
};

window.signAndInstallEsign=async function(certId,profileId,btnEl){
  var btn=btnEl||document.querySelector('.esign-btn');
  var er=btn?btn.closest('.card').querySelector('.esign-result'):null;
  if(!btn)return;
  btn.disabled=true;btn.textContent='正在签名全能签...';
  if(er)er.innerHTML='<div style="padding:8px 0;color:var(--text-muted);font-size:13px">使用你的证书签名全能签 IPA，可能需要 10-30 秒...</div>';
  try{
    var r=await fetch('/api/udid/sign-esign',{method:'POST',headers:{'Content-Type':'application/json','Authorization':'Bearer '+authToken},body:JSON.stringify({cert_id:certId,profile_id:profileId})});
    var j=await r.json();
    if(j.success){
      var d=j.data;
      btn.textContent='签名完成';btn.disabled=true;
      var h='<div class="bind-result ok" style="margin-top:8px">'+ic('check',14)+' 全能签签名成功！</div>';
      h+='<div class="dl-acts" style="margin-top:10px">';
      h+='<a href="'+d.install_url+'" class="btn bg">'+ic('install',16)+' 安装全能签到设备</a>';
      h+='</div>';
      h+='<div style="font-size:11px;color:var(--text-muted);margin-top:8px;line-height:1.5">安装后到「设置 → 通用 → VPN与设备管理」信任证书即可打开</div>';
      if(er)er.innerHTML=h;
    }else{
      btn.disabled=false;btn.innerHTML=ic('pkg',16)+' 签名安装全能签';
      if(er)er.innerHTML='<div class="bind-result fail">'+ic('alert',14)+' '+(j.message||'签名失败')+'</div>';
    }
  }catch(e){
    btn.disabled=false;btn.innerHTML=ic('pkg',16)+' 签名安装全能签';
    if(er)er.innerHTML='<div class="bind-result fail">网络错误，请重试</div>';
  }
};

function wait(){
  app.innerHTML='<div class="card"><div class="hd" style="text-align:center">'
    +'<div class="hd-icon wait" style="color:#fff">'+ic('clock',26)+'</div>'
    +'<h1>等待安装描述文件</h1><div class="sub">请在「设置」中完成描述文件的安装</div></div>'
    +'<div class="steps">'
    +'<div class="st"><span class="sn">1</span>打开 iPhone「设置」</div>'
    +'<div class="st"><span class="sn">2</span>点击顶部「已下载的描述文件」</div>'
    +'<div class="st"><span class="sn">3</span>点击「安装」并输入密码</div></div>'
    +'<div class="acts"><button class="btn bp" onclick="poll()">'+ic('refresh',16)+' 刷新结果</button></div></div>'}

function err(){
  app.innerHTML='<div class="card" style="text-align:center;padding:48px 24px">'
    +'<div style="margin-bottom:12px;color:var(--orange)">'+ic('alert',48)+'</div>'
    +'<h1>链接无效</h1><div class="sub">未找到设备信息或链接已过期，请重新获取</div></div>'}

async function poll(){
  if(!rid){err();return}
  try{var r=await fetch('/api/udid/result/'+rid),j=await r.json();
    if(j.success&&j.data&&j.data.status==='success'&&j.data.udid){ok(j.data)}
    else{wait();if(!pt)pt=setInterval(poll,3000);pc++;if(pc>100&&pt){clearInterval(pt);pt=null}}}
  catch(e){wait()}}
poll();
</script>
</body>
</html>`;
};
