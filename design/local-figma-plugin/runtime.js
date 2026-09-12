// Source for the local, unpublished Figma plugin. build.py produces code.js.
async function main() {
  await Promise.all(['Regular', 'Medium', 'Semi Bold', 'Bold'].map(style =>
    figma.loadFontAsync({ family: 'Inter', style })));
  const pageName = 'Calander · Complete mobile designs';
  let page = figma.root.children.find(p => p.name === pageName);
  if (page) {
    await figma.setCurrentPageAsync(page);
    figma.viewport.scrollAndZoomIntoView(page.children.slice(0, 1));
    figma.closePlugin('This design page already exists. Rename it before generating a new copy.');
    return;
  }
  page = figma.createPage();
  page.name = pageName;
  await figma.setCurrentPageAsync(page);
  const palette = {
    background:['F7F9FC','10151F'], surface:['FFFFFF','1A2230'], text:['172338','F3F6FC'],
    muted:['5F6E83','A7B5CA'], border:['DEE5EF','334155'], accent:['285BE0','90B1FF'],
    primary:['285BE0','4676EC'], onPrimary:['FFFFFF','FFFFFF'], tint:['EAF0FF','202F4D'],
    green:['1B785A','83D9B7'], greenBg:['E8F5EF','1B3832'], purple:['7551B3','C8AFF4'],
    purpleBg:['F2EDFA','332B46'], orange:['93601F','EFC58B'], orangeBg:['FFF3DF','3F3323'],
    danger:['BE3848','FF9EAA']
  };
  const types = {Display:[36,44,'Bold'],Title:[28,36,'Bold'],Heading:[20,28,'Semi Bold'],
    Body:[15,22,'Regular'],Label:[15,22,'Semi Bold'],Small:[13,19,'Regular'],Caption:[11,16,'Medium']};
  const colorVars = {};
  for (const [index, themeName] of ['Light','Dark'].entries()) {
    const c = figma.variables.createVariableCollection('Calander local / ' + themeName);
    colorVars[themeName] = {};
    for (const [name, pair] of Object.entries(palette)) {
      const v = figma.variables.createVariable(name,c,'COLOR');
      v.scopes = ['FRAME_FILL','SHAPE_FILL','TEXT_FILL','STROKE_COLOR'];
      v.setValueForMode(c.defaultModeId, rgb(pair[index]));
      v.setVariableCodeSyntax('WEB','var(--calander-'+name+')');
      colorVars[themeName][name] = v;
    }
  }
  let theme = 'Light';
  let cs = [];
  let dateComponent;
  const components = {}, roots = {}, bodies = {};
  function rgb(h) { return {r:parseInt(h.slice(0,2),16)/255,g:parseInt(h.slice(2,4),16)/255,b:parseInt(h.slice(4,6),16)/255}; }
  function paint(key) { return figma.variables.setBoundVariableForPaint({type:'SOLID',color:rgb(palette[key][theme==='Light'?0:1])},'color',colorVars[theme][key]); }
  function fill(n,key) { n.fills = key ? [paint(key)] : []; }
  function round(n,key='r16') { n.cornerRadius=Number(key.slice(1)); }
  function created(n) { return n; }
  function box(parent,name,w,dir='VERTICAL',gap=12,bg=null,pad=0) {
    const n=figma.createFrame(); n.name=name; parent.appendChild(n);
    n.layoutMode=dir; n.resize(w,1); n.itemSpacing=gap;
    n.primaryAxisSizingMode=dir==='VERTICAL'?'AUTO':'FIXED';
    n.counterAxisSizingMode=dir==='VERTICAL'?'FIXED':'AUTO';
    n.paddingLeft=n.paddingRight=n.paddingTop=n.paddingBottom=pad;
    n.clipsContent=false; fill(n,bg); return n;
  }
  function txt(parent,str,style='Body',color='text',width) {
    const t=figma.createText(); const [size,line,weight]=types[style];
    t.fontName={family:'Inter',style:weight};t.fontSize=size;t.lineHeight={unit:'PIXELS',value:line};
    t.characters=str;t.name=str.slice(0,55);t.fills=[paint(color)];parent.appendChild(t);
    if(width){t.textAutoResize='HEIGHT';t.resize(width,t.height);} return t;
  }
  function prop(comp,n,name) {const key=comp.addComponentProperty(name,'TEXT',n.characters);n.componentPropertyReferences={characters:key};}
  function instance(parent,c,values={}) {
    const n=c.createInstance();parent.appendChild(n);const props={};
    for(const [k,v] of Object.entries(values)){const key=Object.keys(c.componentPropertyDefinitions).find(p=>p.split('#')[0]===k);if(key)props[key]=v;}
    n.setProperties(props); return n;
  }
  function button(p,label,secondary=false){const n=instance(p,cs[secondary?1:0],{Label:label});n.name='Action / '+label;return n;}
  function field(p,label,value){return instance(p,cs[2],{Label:label,Value:value});}
  function event(p,title,detail,meta='WORK · FIXED',tone='tint'){const n=instance(p,cs[3],{Title:title,Detail:detail,Meta:meta});fill(n,tone);return n;}
  function row(p,title,subtitle='',trailing='›',color='text') {
    const r=box(p,title,342,'HORIZONTAL',12,'surface',16);round(r,'r12');r.counterAxisAlignItems='CENTER';
    const labels=box(r,'Labels',236,'VERTICAL',4);txt(labels,title,'Label',color,236);
    if(subtitle)txt(labels,subtitle,'Small','muted',236);
    const end=txt(r,trailing,'Small','accent',62);end.textAlignHorizontal='RIGHT';return r;
  }
  function note(p,title,body,tone='tint'){const n=box(p,title,342,'VERTICAL',8,tone,16);round(n);txt(n,title,'Label','text',310);txt(n,body,'Small','muted',310);return n;}
  function chips(p,labels,active=0){const r=box(p,'Choices',342,'HORIZONTAL',8);labels.forEach((s,i)=>{const n=box(r,s,(342-(labels.length-1)*8)/labels.length,'HORIZONTAL',4,i===active?'primary':'surface',8);round(n,'r12');n.minHeight=44;n.primaryAxisAlignItems='CENTER';n.counterAxisAlignItems='CENTER';txt(n,s,'Small',i===active?'onPrimary':'muted');});return r;}
  function heading(p,s){txt(p,s,'Label','text',342);}
  function spacer(p,h){const n=figma.createFrame();p.appendChild(n);n.name='Space';n.resize(1,h);n.fills=[];return n;}
  function component(parent,name,w,dir='VERTICAL') {const c=figma.createComponent();parent.appendChild(c);c.name=name;c.layoutMode=dir;c.resize(w,52);c.primaryAxisSizingMode=dir==='VERTICAL'?'AUTO':'FIXED';c.counterAxisSizingMode=dir==='VERTICAL'?'FIXED':'AUTO';fill(c,null);return c;}
  function makeComponents() {
    const board=box(page,'Components / '+theme,390,'VERTICAL',24,'background',24);board.x=100+(theme==='Light'?0:470);board.y=500;
    txt(board,theme+' components','Heading');
    const set=[];
    for(const secondary of [false,true]) {
      const c=component(board,secondary?'Button / Secondary':'Button / Primary',342,'HORIZONTAL');
      c.resize(342,52);c.counterAxisSizingMode='FIXED';c.primaryAxisAlignItems='CENTER';c.counterAxisAlignItems='CENTER';
      fill(c,secondary?'surface':'primary');round(c,'r12');if(secondary)c.strokes=[paint('border')];
      prop(c,txt(c,'Continue','Label',secondary?'text':'onPrimary'),'Label');set.push(c);
    }
    const f=component(board,'Field',342);f.itemSpacing=8;
    prop(f,txt(f,'Email','Small','muted',342),'Label');
    const input=box(f,'Input',342,'HORIZONTAL',8,'surface',16);round(input,'r12');input.strokes=[paint('border')];
    prop(f,txt(input,'you@example.com','Body','text',310),'Value');set.push(f);
    const ev=component(board,'Event card',342);ev.paddingTop=ev.paddingBottom=ev.paddingLeft=ev.paddingRight=16;ev.itemSpacing=4;fill(ev,'tint');round(ev);
    prop(ev,txt(ev,'Design review','Label','text',310),'Title');
    prop(ev,txt(ev,'09:00–10:00 · Studio 2','Small','muted',310),'Detail');
    prop(ev,txt(ev,'WORK · FIXED','Caption','accent',310),'Meta');set.push(ev);
    const date=component(board,'Calendar date',44,'HORIZONTAL');date.resize(44,32);date.counterAxisSizingMode='FIXED';date.primaryAxisAlignItems='CENTER';date.counterAxisAlignItems='CENTER';round(date,'r12');prop(date,txt(date,'11','Small'),'Day');
    for(const c of [...set,date]) c.description='Calander '+theme+' reusable component. Text properties can be edited on instances.';
    components[theme]={set,date};
  }
  for(const t of ['Light','Dark']){theme=t;makeComponents();}
  theme='Light';
  const cover=box(page,'START HERE',1320,'VERTICAL',16,'surface',32);cover.x=100;cover.y=100;
  txt(cover,'Calander','Display');txt(cover,'A little structure. More possibility.','Heading');
  txt(cover,'46 mobile screens × 2 themes · Editable components · September 2026','Body','muted',1256);
  txt(cover,'Light screens are above their matching dark screens. Long screens scroll in Present mode. Example accounts, portals and sports fixtures are illustrative. These are UI designs, not a connected app.','Body','muted',1256);
  txt(cover,'Includes accounts, month/week/day calendars, events, repeats, reminders, imports, conflict review, friends, sports, tags, exports, settings and iOS widget concepts.','Small','muted',1256);
  const swatches=box(cover,'Shared palette',1256,'HORIZONTAL',12);
  for(const key of ['primary','tint','greenBg','purpleBg','orangeBg']){const chip=box(swatches,key,170,'VERTICAL',8,key,16);round(chip);txt(chip,key,'Small',key==='primary'?'onPrimary':'text');}
  const icons = [
    '<rect x="3" y="5" width="18" height="16" rx="3"/><path d="M7 3v4m10-4v4M3 11h18"/>',
    '<path d="M8 3h8v5c0 5-8 5-8 0V3Zm0 2H4v3c0 3 4 3 4 3m8-6h4v3c0 3-4 3-4 3M12 12v6m-4 3h8m-8 0v-3h8v3"/>',
    '<circle cx="9" cy="8" r="3"/><path d="M3 21v-3c0-5 12-5 12 0v3m1-16c5 0 5 6 1 6m1 4c4 0 4 3 4 6"/>',
    '<circle cx="12" cy="12" r="3"/><path d="m9 3 6 0 1 3 3 1 2 5-2 5-3 1-1 3H9l-1-3-3-1-2-5 2-5 3-1 1-3Z"/>'
  ];
  let count=0;
  for(const t of ['Light','Dark']) {
    theme=t;cs=components[t].set;dateComponent=components[t].date;roots[t]={};bodies[t]={};
    for(const [i,s] of SCREENS.entries()) {
      const root=box(page,String(i+1).padStart(2,'0')+' / '+s[1]+' / '+theme,390,'VERTICAL',0,'background');
      root.resize(390,844);root.primaryAxisSizingMode='FIXED';root.counterAxisSizingMode='FIXED';root.clipsContent=true;round(root,'r24');
      root.x=100+(i%6)*470;root.y=1450+Math.floor(i/6)*1900+(theme==='Dark'?920:0);roots[t][s[0]]=root;
      const status=box(root,'Status bar',390,'HORIZONTAL',8,null,16);status.resize(390,48);status.counterAxisSizingMode='FIXED';status.primaryAxisAlignItems='SPACE_BETWEEN';txt(status,'9:41','Small');txt(status,'•••  ▰','Small');
      const head=box(root,'Header',390,'VERTICAL',4,null,24);head.paddingTop=12;head.paddingBottom=16;
      txt(head,s[3]||s[0]==='welcome'?'CALANDER':'‹  CALANDER','Caption','accent',342);txt(head,s[1],'Title','text',342);txt(head,s[2],'Small','muted',342);
      const scroll=box(root,'Scrollable content',390,'VERTICAL',0);scroll.layoutSizingVertical='FILL';scroll.clipsContent=true;scroll.overflowDirection='VERTICAL';
      const p=box(scroll,'Content',390,'VERTICAL',16,null,24);p.paddingTop=8;p.paddingBottom=24;bodies[t][s[0]]=p;
      await buildBody(s[0],p);
      if(s[3]) {
        const nav=box(root,'Navigation',390,'HORIZONTAL',6,'surface',12);nav.resize(390,80);nav.counterAxisSizingMode='FIXED';
        for(const [j,label] of ['Calendar','Sports','Friends','Settings'].entries()) {
          const cell=box(nav,'Navigate / '+label,87,'VERTICAL',4);cell.counterAxisAlignItems='CENTER';cell.minHeight=44;
          const hex=palette[label===s[3]?'accent':'muted'][t==='Light'?0:1];
          const icon=figma.createNodeFromSvg('<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#'+hex+'" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">'+icons[j]+'</svg>');cell.appendChild(icon);txt(cell,label,'Caption',label===s[3]?'accent':'muted');
        }
      } else {
        const home=box(root,'Home indicator',390,'HORIZONTAL',0);home.resize(390,24);home.counterAxisSizingMode='FIXED';home.primaryAxisAlignItems='CENTER';home.counterAxisAlignItems='CENTER';
        const bar=figma.createRectangle();home.appendChild(bar);bar.resize(120,4);bar.cornerRadius=2;fill(bar,'text');
      }
      count++;
      if(count%12===0)figma.notify('Building Calander: '+count+' of 92 screens',{timeout:1500});
    }
  }
  // Add the core navigation links. Form controls are visual examples.
  const actionRoutes={'Get started':'signup','I already have an account':'login','Log in':'month','Create account':'verify','Send reset link':'verify','Back to log in':'login','I’ve verified my email':'onboarding','Save password':'login','Start with an empty calendar':'empty','Create my first event':'add','Import a schedule':'import','+  New event':'add','Next: event options':'options','Create event':'detail','Edit event':'edit','Delete event':'delete','Keep event':'detail','Save changes':'detail','Find events':'review','Open portal':'portalweb','Import this page':'review','Add 3 events':'importdone','Confirm choice':'importdone','View calendar':'month','Import another schedule':'import','Choose another source':'import','Add an event manually':'add','Follow more teams':'follow','Save followed teams':'sports','Add match to calendar':'month','Add a friend':'addfriend','Create a tag':'newtag','Stay signed in':'account'};
  for(const t of ['Light','Dark'])for(const [key,root] of Object.entries(roots[t])) {
    for(const n of root.findAll(n=>n.name.startsWith('Action / ')||n.name.startsWith('Navigate / '))) {
      const label=n.name.split(' / ')[1];const target=n.name.startsWith('Navigate')?({Calendar:'month',Sports:'sports',Friends:'friends',Settings:'settings'})[label]:actionRoutes[label];
      if(target)await n.setReactionsAsync([{trigger:{type:'ON_CLICK'},actions:[{type:'NODE',destinationId:roots[t][target].id,navigation:'NAVIGATE',transition:null,preserveScrollPosition:false}]}]);
    }
  }
  const allText=page.findAllWithCriteria({types:['TEXT']});
  const badFonts=allText.filter(n=>n.fontName.family!=='Inter');
  if(badFonts.length)throw new Error('Font verification failed.');
  const invalid=Object.values(roots).flatMap(x=>Object.values(x)).filter(r=>r.width!==390||r.height!==844);
  if(count!==92||invalid.length)throw new Error('Screen count or dimensions did not match the plan.');
  figma.currentPage.selection=[roots.Light.welcome];
  figma.viewport.scrollAndZoomIntoView([roots.Light.welcome,roots.Light.month]);
  figma.closePlugin('Created 92 screens: 46 Light + 46 Dark. Open Present to try the linked flows.');
  // BODY_FUNCTIONS
}
main().catch(error=>{console.error(error);figma.closePlugin('Calander stopped: '+error.message+'. Any partial page has been kept for inspection.');});
