import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import {readFileSync} from 'node:fs';

function harness(snapshot){
  const elements=new Map(['#app','#modal','#toast'].map(id=>[id,{innerHTML:'',textContent:'',close(){this.open=false}}]));
  const source=readFileSync(new URL('../web/src/main.js',import.meta.url),'utf8')
    .replace(/^import .*;\n/gm,'').replace('boot().catch(e=>login(e.message));','');
  const context=vm.createContext({
    document:{querySelector:id=>elements.get(id),addEventListener(){},querySelectorAll:()=>[]},
    setInterval(){},setTimeout(){},clearTimeout(){},configured:true,supabase:null,
    dayKey:()=> '2026-11-16',esc:String,liveSnapshot:snapshot,
  });
  vm.runInContext(source,context);
  return {context,elements,run:code=>vm.runInContext(code,context)};
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
