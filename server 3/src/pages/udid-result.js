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

/* Icons */
.hi{display:inline-flex;align-items:center;justify-content:center;width:1em;height:1em;flex-shrink:0}
.hi img{width:100%;height:100%;object-fit:contain}

/* Header */
.hd{text-align:center;margin-bottom:24px}
.hd-icon{width:56px;height:56px;border-radius:50%;display:inline-flex;align-items:center;justify-content:center;margin-bottom:14px;font-size:26px}
.hd-icon.ok{background:linear-gradient(135deg,var(--green),#22C55E)}
.hd-icon.wait{background:linear-gradient(135deg,var(--orange),#F59E0B)}
.hd-icon .hi img{filter:brightness(0) invert(1)}
h1{font-size:22px;font-weight:700;margin-bottom:6px;letter-spacing:-.3px}
.sub{font-size:13px;color:var(--text-muted);line-height:1.5}

/* Device header */
.dev{display:flex;align-items:center;gap:14px;padding-bottom:16px;border-bottom:1px solid var(--border);margin-bottom:4px}
.dev-av{width:44px;height:44px;border-radius:12px;background:var(--blue);display:flex;align-items:center;justify-content:center;flex-shrink:0;font-size:22px}
.dev-av .hi img{filter:brightness(0) invert(1)}
.dev-n{font-size:15px;font-weight:700}
.dev-s{font-size:12px;color:var(--text-muted);margin-top:2px}

/* Rows */
.row{display:flex;align-items:center;padding:13px 0;border-bottom:1px solid var(--border)}
.row:last-child{border-bottom:none}
.row.hl{background:var(--blue-light);margin:8px -12px 0;padding:12px;border-radius:var(--radius-sm);border:none}
.rl{font-size:12px;color:var(--text-muted);flex-shrink:0;min-width:68px;font-weight:500}
.rv{flex:1;font-size:13px;font-weight:600;text-align:right;word-break:break-all;line-height:1.4}
.mono{font-family:'SF Mono',ui-monospace,monospace;font-size:11px;font-weight:700;letter-spacing:.2px}
.cpb{background:none;border:none;padding:5px;cursor:pointer;color:var(--blue);border-radius:6px;flex-shrink:0;margin-left:6px;font-size:16px}
.cpb:active{opacity:.6}

/* Buttons */
.acts{margin-top:16px;display:flex;flex-direction:column;gap:10px}
.btn{display:flex;align-items:center;justify-content:center;gap:8px;width:100%;
  padding:14px;border:none;border-radius:var(--radius-sm);font-family:var(--font);
  font-size:15px;font-weight:700;cursor:pointer;-webkit-tap-highlight-color:transparent}
.bp{background:var(--blue);color:#fff;box-shadow:0 4px 12px rgba(6,109,230,.25)}
.bp:active{transform:scale(.98);opacity:.9}
.bs{background:var(--surface-hover);color:var(--blue);border:1px solid var(--border)}
.bs:active{opacity:.7}

/* Note */
.note{margin-top:16px;padding:14px;background:var(--surface-hover);border-radius:var(--radius-sm);
  border:1px solid var(--border);display:flex;gap:10px}
.note p{font-size:11px;color:var(--text-muted);line-height:1.6}

/* Steps */
.steps{text-align:left;margin:20px 0;background:var(--surface-hover);border-radius:var(--radius-sm);padding:4px 16px;border:1px solid var(--border)}
.st{display:flex;align-items:center;gap:12px;padding:12px 0;font-size:13px}
.st+.st{border-top:1px solid var(--border)}
.sn{width:22px;height:22px;border-radius:50%;background:var(--blue);color:#fff;font-size:11px;font-weight:700;display:flex;align-items:center;justify-content:center;flex-shrink:0}

/* Loading */
.ld{display:flex;flex-direction:column;align-items:center;gap:14px;padding:60px 0}
.sp{width:36px;height:36px;border:3px solid var(--border);border-top-color:var(--blue);border-radius:50%;animation:sp .7s linear infinite}
@keyframes sp{to{transform:rotate(360deg)}}

.brand{margin-top:28px;text-align:center;font-size:12px;color:var(--text-muted);font-weight:500}
.brand b{color:var(--blue);margin-left:4px}

.toast{position:fixed;top:env(safe-area-inset-top,12px);left:50%;transform:translateX(-50%) translateY(-80px);
  background:var(--text);color:var(--bg);padding:10px 20px;border-radius:var(--radius-sm);
  font-size:13px;font-weight:600;transition:transform .25s ease;z-index:99;pointer-events:none}
.toast.show{transform:translateX(-50%) translateY(16px)}
</style>
</head>
<body>
<div class="wrap" id="app"><div class="card"><div class="ld"><div class="sp"></div><div style="font-size:13px;color:var(--text-muted)">正在获取设备信息...</div></div></div></div>
<div class="brand">Powered by <b>${APP_NAME}</b></div>
<div class="toast" id="toast"></div>

<script>
var IC='/admin/icons/',rid=new URLSearchParams(location.search).get('id'),app=document.getElementById('app'),pt=null,pc=0;
function hi(name,sz){sz=sz||20;return '<span class="hi" style="font-size:'+sz+'px"><img src="'+IC+name+'.svg"></span>'}
function toast(m){var t=document.getElementById('toast');t.textContent=m;t.classList.add('show');setTimeout(function(){t.classList.remove('show')},2000)}
function cp(t){if(navigator.clipboard)navigator.clipboard.writeText(t);else{var a=document.createElement('textarea');a.value=t;a.style.cssText='position:fixed;left:-9999px';document.body.appendChild(a);a.select();document.execCommand('copy');document.body.removeChild(a)}toast('已复制到剪贴板')}
function allTxt(d){return['UDID: '+d.udid,d.device_name?'设备: '+d.device_name:'',d.product?'型号: '+d.product:'',d.version?'系统: iOS '+d.version:'',d.serial?'序列号: '+d.serial:''].filter(Boolean).join('\\n')}
function ir(l,v,m){return '<div class="row"><div class="rl">'+l+'</div><div class="rv'+(m?' mono':'')+'">'+v+'</div></div>'}

function ok(d){
  if(pt){clearInterval(pt);pt=null}
  var rs='<div class="row hl"><div class="rl">UDID</div><div class="rv mono">'+d.udid+'</div><button class="cpb" onclick="cp(\\''+d.udid+'\\')">'+hi('document-add-2',16)+'</button></div>';
  if(d.device_name)rs+=ir('设备名称',d.device_name);
  if(d.product)rs+=ir('设备型号',d.product);
  if(d.version)rs+=ir('系统版本','iOS '+d.version);
  if(d.serial)rs+=ir('序列号',d.serial,1);
  if(d.imei)rs+=ir('IMEI',d.imei,1);
  var sh=navigator.share?'<button class="btn bs" onclick="doShare()">'+hi('upload',18)+'分享给开发者</button>':'';
  app.innerHTML='<div class="card">'
    +'<div class="hd"><div class="hd-icon ok">'+hi('tick-circle',28)+'</div><h1>设备识别成功</h1><div class="sub">已获取您的设备信息，请发送给开发者</div></div>'
    +'<div class="dev"><div class="dev-av">'+hi('display-3',22)+'</div><div><div class="dev-n">'+(d.device_name||d.product||'未知设备')+'</div><div class="dev-s">iOS '+(d.version||'-')+'</div></div></div>'
    +rs+'</div>'
    +'<div class="acts"><button class="btn bp" id="cab" onclick="doCA()">'+hi('document-add-2',18)+'复制全部信息</button>'+sh+'</div>'
    +'<div class="note"><div style="font-size:16px;flex-shrink:0">💡</div><div><p>描述文件已自动删除，不会影响您的设备。</p><p>如未删除，可前往「设置 → 通用 → VPN与设备管理」手动移除。</p></div></div>';
  window._d=d}

window.doCA=function(){if(!window._d)return;cp(allTxt(window._d));var b=document.getElementById('cab');if(b){b.innerHTML=hi('tick-circle',18)+'已复制 ✓';setTimeout(function(){b.innerHTML=hi('document-add-2',18)+'复制全部信息'},2000)}};
window.doShare=async function(){if(!navigator.share||!window._d)return;try{await navigator.share({title:'设备 UDID 信息',text:allTxt(window._d)})}catch(e){}};

function wait(){
  app.innerHTML='<div class="card"><div class="hd" style="text-align:center">'
    +'<div class="hd-icon wait">'+hi('time-circle-1',24)+'</div>'
    +'<h1>等待安装描述文件</h1><div class="sub">请在「设置」中完成描述文件的安装</div></div>'
    +'<div class="steps">'
    +'<div class="st"><span class="sn">1</span>打开 iPhone「设置」</div>'
    +'<div class="st"><span class="sn">2</span>点击顶部「已下载的描述文件」</div>'
    +'<div class="st"><span class="sn">3</span>点击「安装」并输入密码</div></div>'
    +'<div class="acts"><button class="btn bp" onclick="poll()">'+hi('refresh-1',18)+'刷新结果</button></div></div>'}

function err(){
  app.innerHTML='<div class="card" style="text-align:center;padding:48px 24px">'
    +'<div style="font-size:48px;margin-bottom:12px">'+hi('danger-triangle',48)+'</div>'
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
