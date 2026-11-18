const fs=require('fs'),vm=require('vm'),assert=require('node:assert/strict');
const src=fs.readFileSync(require('node:path').join(__dirname,'../supabase/functions/mint/index.ts'),'utf8').replace(/^import .*;\n/gm,'');
const compiled={outputText:require('node:module').stripTypeScriptTypes(src)};
async function run(body,opts={}){
 let handler,charged=0,cover=0,song=0,usedUrl,inserted;
 const admin={auth:{getUser:async()=>({data:{user:{id:'owner'}}})},storage:{from:()=>({createSignedUrl:async()=>opts.missing?{error:'missing'}:{data:{signedUrl:'https://ucnruxztueysdohgamdy.supabase.co/storage/v1/object/sign/covers/owner/track.mp3?token=server-signed'}},upload:async()=>opts.uploadError?{error:'failed'}:{},getPublicUrl:()=>({data:{publicUrl:'https://ucnruxztueysdohgamdy.supabase.co/storage/v1/object/public/inputs/owner/test'}})})},rpc:async(name)=>{if(name==='spend_credits')charged++;return {data:true}},from:()=>({insert:(row)=>{inserted=row;return{select:()=>({single:async()=>({data:{id:'job'}})})}}})};
 const ctx={Deno:{env:{get:n=>n==='SUPABASE_URL'?'https://ucnruxztueysdohgamdy.supabase.co':'test'},serve:f=>handler=f},createClient:()=>admin,startCover:async(p,u)=>{cover++;usedUrl=u;return'cover-task'},startGeneration:async()=>{song++;return'song-task'},generateLyrics:async()=>({text:'test',title:'test'}),fetch:async()=>new Response(null,{status:opts.headFail?404:200,headers:{'content-length':'2900000','content-type':'audio/mpeg'}}),URL,Response,Request,TextDecoder,Uint8Array,atob,crypto:require('node:crypto').webcrypto};
 vm.runInNewContext(compiled.outputText,ctx);
 const res=await handler(new Request('https://test.invalid',{method:'POST',headers:{Authorization:'Bearer test','Content-Type':'application/json'},body:JSON.stringify(body)}));
 return {status:res.status,result:await res.json(),charged,cover,song,usedUrl,inserted};
}
(async()=>{
 const url='https://ucnruxztueysdohgamdy.supabase.co/storage/v1/object/sign/covers/owner/track.mp3?token=client';
 let r=await run({kind:'cover',audioUrl:url});assert.equal(r.cover,1);assert.equal(r.song,0);assert.equal(r.result.referenceAccepted,true);assert.equal(r.inserted.kind,'cover');assert.match(r.usedUrl,/server-signed/);
 r=await run({kind:'cover',upload_url:url});assert.equal(r.cover,1);
 for(const body of [{kind:'cover'},{kind:'cover',audioUrl:'https://other.invalid/file.mp3'},{kind:'cover',audioUrl:url.replace('/owner/','/other/')},{kind:'cover',audioBase64:'!!!!'}]){r=await run(body);assert.ok(r.status>=400);assert.equal(r.charged,0);assert.equal(r.cover+r.song,0);}
 for(const opt of [{missing:true},{headFail:true}]){r=await run({kind:'cover',audioUrl:url},opt);assert.equal(r.charged,0);assert.equal(r.song,0);assert.ok(r.status>=400);}
 r=await run({kind:'cover',audioBase64:btoa('RIFFtest')});assert.equal(r.cover,1);assert.equal(r.song,0);
 r=await run({kind:'song',prompt:'test'});assert.equal(r.song,1);assert.equal(r.cover,0);
 r=await run({action:'lyrics',prompt:'test'});assert.equal(r.charged,0);assert.equal(r.result.lyrics,'test');
 console.log('PASS: 11 isolated route/validation tests; no real provider requests or credits used.');
})().catch(e=>{console.error(e);process.exit(1)});
