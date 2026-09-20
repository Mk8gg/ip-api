#!/usr/bin/env python3
import json,os,subprocess
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
PORT=int(os.environ.get("PANEL_PORT","18080")); TOKEN=os.environ.get("PANEL_TOKEN","")
def run(c):
 try:return subprocess.check_output(c,stderr=subprocess.STDOUT,text=True,timeout=15)
 except Exception as e:return str(e)
def data():
 try:
  with open("/etc/sing-box/config.json") as f:c=json.load(f)
  i=c["inbounds"][0]; d=i["tls"]["server_name"]; p=i["users"][0]["password"]
 except Exception:return {}
 return {"sing_box":run(["systemctl","is-active","sing-box"]).strip(),"version":run(["sing-box","version"]).splitlines()[0],"domain":d,"password":p,"ech":os.path.exists("/etc/sing-box/ech/ech-key.pem"),"listen":run(["ss","-lntup"])}
HTML='''<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Hy2 Manager</title><style>body{background:#0b0f14;color:#eee;font:15px system-ui;max-width:900px;margin:30px auto;padding:20px}.c{background:#121821;border:1px solid #293543;border-radius:14px;padding:18px;margin:12px 0}button{padding:9px;margin:4px;background:#202b38;color:white;border:1px solid #39495a;border-radius:8px}pre{white-space:pre-wrap;word-break:break-all}</style><h1>Hysteria2 Manager</h1><div class=c id=i>加载中</div><div class=c><button onclick="a('restart')">重启</button><button onclick="a('logs')">日志</button></div><div class=c><pre id=o></pre></div><script>const t=new URLSearchParams(location.search).get('token');async function l(){let r=await fetch('/api/status',{headers:{Authorization:'Bearer '+t}}),d=await r.json();i.innerHTML=Object.entries(d).filter(x=>x[0]!='listen'&&x[0]!='password').map(x=>'<p><b>'+x[0]+'</b>: '+x[1]+'</p>').join('')+'<p><b>节点</b>: hysteria2://'+d.password+'@'+d.domain+':443/?sni='+d.domain+'#'+d.domain}async function a(x){let r=await fetch('/api/'+x,{method:'POST',headers:{Authorization:'Bearer '+t}});o.textContent=await r.text();l()}l()</script>'''
class H(BaseHTTPRequestHandler):
 def ok(self):return self.headers.get("Authorization","")=="Bearer "+TOKEN
 def out(self,n,b,ct="text/plain"):
  b=b.encode();self.send_response(n);self.send_header("Content-Type",ct);self.send_header("Content-Length",str(len(b)));self.end_headers();self.wfile.write(b)
 def do_GET(self):
  if self.path.startswith("/api/"):
   if not self.ok():return self.out(401,"Unauthorized")
   if self.path=="/api/status":
    d=data();self.out(200,json.dumps(d,ensure_ascii=False));return
   return self.out(404,"Not Found")
  self.out(200,HTML,"text/html; charset=utf-8")
 def do_POST(self):
  if not self.ok():return self.out(401,"Unauthorized")
  if self.path=="/api/restart":return self.out(200,run(["systemctl","restart","sing-box"]))
  if self.path=="/api/logs":return self.out(200,run(["journalctl","-u","sing-box","-n","80","--no-pager"]))
  self.out(404,"Not Found")
 def log_message(self,*a):pass
ThreadingHTTPServer(("0.0.0.0",PORT),H).serve_forever()
