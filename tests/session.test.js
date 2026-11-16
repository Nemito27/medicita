import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import {readFileSync} from 'node:fs';

function harness(snapshot,{getSession=async()=>({data:{session:null},error:null}),qrCode={}}={}){
  const elements=new Map(['#app','#modal','#toast'].map(id=>[id,{innerHTML:'',textContent:'',close(){this.open=false},showModal(){this.open=true}}]));
  const timers=[];let authChanged;
  const source=readFileSync(new URL('../web/src/main.js',import.meta.url),'utf8')
    .replace(/^import .*;\n/gm,'').replace('boot().catch(e=>login(e.message));','');
  const context=vm.createContext({
    document:{querySelector:id=>elements.get(id),addEventListener(){},querySelectorAll:()=>[]},
    setInterval(){},setTimeout(fn){timers.push(fn);return timers.length},clearTimeout(){},configured:true,
    supabase:{auth:{getSession,onAuthStateChange(fn){authChanged=fn}}},
    dayKey:()=> '2026-11-16',dateLabel:String,esc:String,liveSnapshot:snapshot,QRCode:qrCode,
  });
  vm.runInContext(source,context);
  return {context,elements,run:code=>vm.runInContext(code,context),
    auth:(event,id)=>authChanged(event,id?{user:{id}}:null),
    nextTimer:()=>timers.shift()?.(),
    async flushTimers(){while(timers.length)await timers.shift()()},
  };
}
test('a completed request cannot restore patient data after sign-out',async()=>{
  let resolve;const pending=new Promise(r=>resolve=r);const h=harness(()=>pending);
  const request=h.run('refresh(false)');h.run('clearSession()');
  resolve({user:{id:'previous-patient'}});await request;
  assert.equal(h.run('data'),null);
});
test('unverified sessions clear existing data and dialog contents',async()=>{
  const h=harness(async()=>{throw Object.assign(Error('Vuelve a ingresar'),{code:'SESSION_REQUIRED'})});
  h.run("data={user:{id:'previous-patient'}};modal.innerHTML='private appointment';");
  await h.run('refresh(false)');
  assert.equal(h.run('data'),null);assert.equal(h.elements.get('#modal').innerHTML,'');
  assert.match(h.elements.get('#app').innerHTML,/Vuelve a ingresar/);
});
test('switching accounts clears private data immediately even when the new account cannot load',async()=>{
  let fail=false;
  const h=harness(async()=>{if(fail)throw Error('No se pudo conectar');return {user:{id:'previous-admin',role:'admin'},appointments:[{patient_id:'private-patient'}]}});
  h.run('render=()=>{}');
  h.auth('SIGNED_IN','previous-admin');await h.flushTimers();
  h.run("modal.innerHTML='private-patient appointment';");
  fail=true;h.auth('SIGNED_IN','next-patient');
  assert.equal(h.run('data'),null);
  assert.equal(h.elements.get('#modal').innerHTML,'');
  await h.flushTimers();
  assert.equal(h.run('data'),null);
  assert.match(h.elements.get('#app').innerHTML,/No se pudo conectar/);
  assert.doesNotMatch(h.elements.get('#app').innerHTML,/private-patient|previous-admin/);
});
test('an account switch queues its load behind the previous request and discards that response',async()=>{
  let resolve,calls=0;const pending=new Promise(r=>resolve=r);
  const h=harness(()=>++calls===1?pending:Promise.resolve({user:{id:'next-patient'}}));
  h.run('render=()=>{}');
  h.auth('SIGNED_IN','previous-patient');
  const previous=h.nextTimer();
  h.auth('SIGNED_IN','next-patient');
  await h.nextTimer();
  assert.equal(calls,1);
  resolve({user:{id:'previous-patient'},appointments:[{id:'private-appointment'}]});
  await previous;
  assert.equal(h.run('data'),null);
  await h.flushTimers();
  assert.equal(calls,2);assert.equal(h.run('data.user.id'),'next-patient');
});
test('a late startup session cannot replace a newer authentication event',async()=>{
  let resolve;const pending=new Promise(r=>resolve=r);
  const h=harness(async()=>({user:{id:'current-patient'}}),{getSession:()=>pending});
  h.run('render=()=>{}');
  const startup=h.run('boot()');
  h.auth('SIGNED_IN','current-patient');await h.flushTimers();
  resolve({data:{session:{user:{id:'previous-patient'}}},error:null});
  await startup;await h.flushTimers();
  assert.equal(h.run('data.user.id'),'current-patient');
});
test('renewing the same account does not reload or clear its current view',async()=>{
  let calls=0;
  const h=harness(async()=>{calls++;return {user:{id:'current-patient'}}});
  h.run('render=()=>{}');
  h.auth('SIGNED_IN','current-patient');await h.flushTimers();
  h.run("modal.innerHTML='current appointment';");
  h.auth('TOKEN_REFRESHED','current-patient');h.auth('SIGNED_IN','current-patient');
  await h.flushTimers();
  assert.equal(calls,1);assert.equal(h.run('data.user.id'),'current-patient');
  assert.equal(h.elements.get('#modal').innerHTML,'current appointment');
});
test('a QR generated for the previous account cannot reopen after another account signs in',async()=>{
  let resolve,currentId='previous-patient';const pending=new Promise(r=>resolve=r);
  const h=harness(async()=>({user:{id:currentId},
    appointments:currentId==='previous-patient'?[{id:'previous-appointment',slot_id:'shared-slot',checkin_token:'previous-private-token'}]:[],
    slots:[{id:'shared-slot',room_id:1,starts_at:'2027-01-04T12:00:00Z'}],rooms:[{id:1,name:'Box 1'}],
  }),{qrCode:{toDataURL:()=>pending}});
  h.run('render=()=>{}');
  h.auth('SIGNED_IN',currentId);await h.flushTimers();
  const qr=h.run("act('qr','previous-appointment')");
  currentId='next-patient';h.auth('SIGNED_IN',currentId);await h.flushTimers();
  resolve('data:image/png;base64,previous-account-qr');await qr;
  assert.equal(h.run('data.user.id'),'next-patient');
  assert.equal(h.elements.get('#modal').innerHTML,'');
  assert.equal(h.elements.get('#modal').open,false);
});
