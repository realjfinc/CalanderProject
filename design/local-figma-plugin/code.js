const SCREENS = [["welcome", "Welcome", "A little more room for life.", null], ["signup", "Create account", "Make your days your own.", null], ["login", "Welcome back", "Your day is waiting.", null], ["forgot", "Reset password", "We’ll send you a reset link.", null], ["verify", "Check your inbox", "One last step to get started.", null], ["newpass", "Choose a password", "A fresh start for your account.", null], ["onboarding", "Bring your days together", "Connect a calendar or start fresh.", null], ["month", "September 2026", "A little structure. More possibility.", "Calendar"], ["week", "Your week", "September 7–13, 2026", "Calendar"], ["day", "Friday, September 11", "3 events · Time for what matters", "Calendar"], ["empty", "A fresh start", "Your calendar is ready for you.", "Calendar"], ["search", "Search calendar", "Find your next moment.", "Calendar"], ["add", "New event", "Start with the essentials.", null], ["options", "Event options", "Make this event work for you.", null], ["repeat", "Repeat event", "Choose how often it happens.", null], ["reminder", "Event reminder", "A little heads-up goes a long way.", null], ["importance", "Event importance", "Protect plans. Keep room to move.", null], ["guests", "Add guests", "Invite people from your friends.", null], ["detail", "Design review", "Work · Fixed event", null], ["edit", "Edit event", "Update the details of your plan.", null], ["delete", "Delete event?", "Choose which plans to remove.", null], ["import", "Import a schedule", "Less typing. More living.", null], ["link", "Import from a link", "Turn a schedule into calendar events.", null], ["portal", "Connect a portal", "Your school or workplace schedule.", null], ["portalweb", "Sign in to your portal", "Secure browser", null], ["review", "Review imported events", "3 events found · Nothing added yet", null], ["conflict", "A little overlap", "Keep your fixed plans protected.", null], ["importdone", "You’re all set", "Your schedule is ready.", null], ["importerror", "Let’s try that again", "We couldn’t read this schedule.", null], ["sports", "Your sports", "Keep your teams in your day.", "Sports"], ["follow", "Find your teams", "Choose what you want to follow.", null], ["match", "Match details", "Sample fixture · Times are illustrative", null], ["friends", "Better with friends", "Plan a little time together.", "Friends"], ["addfriend", "Find a friend", "Search by their unique username.", null], ["requests", "Friend requests", "Choose who you connect with.", null], ["tags", "Your tags", "A place for every kind of plan.", null], ["newtag", "Create a tag", "Give your events a little color.", null], ["notifications", "Updates", "Your schedule, kept in sync.", null], ["settings", "Settings", "Make Calander feel like you.", "Settings"], ["appearance", "Appearance", "The same calm, day or night.", null], ["connections", "Connected calendars", "All your plans in one place.", null], ["export", "Export calendar", "Take your schedule with you.", null], ["account", "Your account", "A few things about you.", null], ["alerts", "Notification settings", "Stay informed on your terms.", null], ["widgets", "At a glance", "Your day, right where you need it.", null], ["signout", "Sign out?", "Your saved plans will be here.", null]];
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
  async function buildBody(key,p) { switch(key) {
case "welcome": {
spacer(p,10);const hero=box(p,'Your day preview',342,'VERTICAL',12,'tint',24);round(hero,'r24');txt(hero,'FRIDAY, SEPTEMBER 11','Caption','accent');txt(hero,'Space for\nwhat matters.','Display','text',294);txt(hero,'09:00   Design review','Label','text',294);txt(hero,'12:30   Lunch with Maya','Body','muted',294);txt(hero,'18:00   A little time for you','Body','muted',294);txt(p,'Your calendars, friends and favorite teams.\nOne simple place to plan your day.','Body','muted',342);button(p,'Get started');button(p,'I already have an account',true);
break;
}
case "signup": {
field(p,'Full name','Alex Morgan');field(p,'Username','alexmorgan');field(p,'Email','alex@example.com');field(p,'Password','Create a strong password');button(p,'Create account');txt(p,'Already have an account? Log in','Small','accent',342);
break;
}
case "login": {
spacer(p,8);field(p,'Email','alex@example.com');field(p,'Password','Enter your password');txt(p,'Forgot password?','Small','accent',342);button(p,'Log in');txt(p,'────────  or continue with  ────────','Small','muted',342);button(p,'Continue with Google',true);button(p,'Continue with Apple',true);txt(p,'New here? Create an account','Small','accent',342);
break;
}
case "forgot": {
spacer(p,40);note(p,'Forgotten happens.','Enter the email you used for Calander. We’ll help you get back to your plans.');field(p,'Email address','alex@example.com');button(p,'Send reset link');button(p,'Back to log in',true);
break;
}
case "verify": {
spacer(p,40);note(p,'You’ve got mail','We sent a verification link to alex@example.com. Open it to verify your account.');button(p,'I’ve verified my email');button(p,'Resend email',true);txt(p,'Wrong address? Change email','Small','accent',342);txt(p,'For password recovery, the email link opens the Choose a password screen.','Small','muted',342);
break;
}
case "newpass": {
spacer(p,24);field(p,'New password','Enter a new password');field(p,'Confirm password','Re-enter your new password');note(p,'Make it yours. Keep it private.','Use a unique password with at least 8 characters.');button(p,'Save password');
break;
}
case "onboarding": {
note(p,'Your day, all together','Connect the calendars you already use. You can add more whenever you like.');row(p,'Google Calendar','Work and personal calendars');row(p,'Microsoft Outlook','School and workplace accounts');row(p,'Apple iCloud','Connect your iCloud calendar');button(p,'Continue');button(p,'Start with an empty calendar',true);
break;
}
case "empty": {
spacer(p,40);note(p,'A blank page for a good day','Add your first event, import a schedule or connect an existing calendar.');button(p,'Create my first event');button(p,'Import a schedule',true);row(p,'Connect a calendar','Google, Outlook or iCloud');
break;
}
case "search": {
field(p,'Search','Design');chips(p,['All','Work','Personal'],0);heading(p,'2 results');event(p,'Design review','Fri, Sep 11 · 09:00–10:00');event(p,'Design workshop','Tue, Sep 15 · 14:00–15:30','SCHOOL · FIXED','purpleBg');txt(p,'Try an event name, location or tag.','Small','muted',342);
break;
}
case "add": {
field(p,'Event name','Design review');field(p,'Location','Studio 2');row(p,'Date','Friday, September 11, 2026');const times=box(p,'Time fields',342,'HORIZONTAL',12);for(const [a,b] of [['Starts','09:00'],['Ends','10:00']]){const q=box(times,a,165,'VERTICAL',8,'surface',16);round(q,'r12');txt(q,a,'Small','muted');txt(q,b,'Heading');}row(p,'Tag','Work');button(p,'Next: event options');
break;
}
case "options": {
row(p,'Repeat','Does not repeat');row(p,'Reminder','15 minutes before');row(p,'Importance','Fixed · Keep this time protected');row(p,'Guests','Add friends to this event');field(p,'Notes','Bring the latest concepts.');button(p,'Create event');
break;
}
case "repeat": {
p.itemSpacing=8;for(const [i,s] of ['Does not repeat','Every day','Every week','Every 2 weeks','Every month','Every year'].entries())row(p,s,'',i===2?'✓':'○');note(p,'Repeats every Friday','Starting September 11, 2026.');button(p,'Save repeat');
break;
}
case "reminder": {
p.itemSpacing=8;for(const [i,s] of ['At event start','5 minutes before','10 minutes before','15 minutes before','30 minutes before','1 hour before','1 day before'].entries())row(p,s,'',i===3?'✓':'○');button(p,'Save reminder');
break;
}
case "importance": {
note(p,'Plans can have different priorities','Fixed events keep their time. Flexible events can move when you choose to resolve a clash.');row(p,'Fixed','Work, classes and appointments','✓');row(p,'Flexible','Plans with room to move','○');note(p,'You stay in control','Review changes before anything moves.');button(p,'Save importance');
break;
}
case "guests": {
field(p,'Search friends','Find by name or username');row(p,'Maya Chen','@mayachen','✓');row(p,'Sam Rivera','@samrivera','○');row(p,'Jordan Lee','@jordanlee','○');note(p,'Friends only','Add someone as a friend before inviting them.');button(p,'Add 1 guest');
break;
}
case "detail": {
note(p,'Friday, September 11','09:00–10:00 · America/Toronto');row(p,'Studio 2','Location');row(p,'Every week','Reminder: 15 minutes before');row(p,'Maya Chen','1 guest invited');note(p,'Notes','Bring the latest concepts.');button(p,'Edit event');button(p,'Delete event',true);
break;
}
case "edit": {
field(p,'Event name','Design review');field(p,'Location','Studio 2');row(p,'Date and time','Sep 11, 2026 · 09:00–10:00');row(p,'More options','Work · Fixed · Weekly · 1 guest');note(p,'Repeating event','Apply this change to this event or the series.');chips(p,['This event','Entire series'],0);button(p,'Save changes');
break;
}
case "delete": {
spacer(p,32);note(p,'Design review','This is a repeating event. Choose what to delete.');row(p,'Only this event','Friday, September 11','✓');row(p,'This and future events','Starting September 11','○');row(p,'The entire series','All Design review events','○');button(p,'Delete selected events');button(p,'Keep event',true);
break;
}
case "import": {
note(p,'From schedule to calendar','Choose a source. You’ll review the events and tags before adding them.');row(p,'Upload a PDF','Timetables, class plans and schedules');row(p,'Choose a photo','Import from your camera roll');row(p,'Paste a link','A public schedule or event page');row(p,'School or work portal','Sign in to a protected schedule');
break;
}
case "link": {
field(p,'Schedule link','https://example.edu/schedule');row(p,'Default tag','School');note(p,'We’ll look for event details','Dates, times, names and locations will be ready for your review.');button(p,'Find events');button(p,'Use a protected portal instead',true);
break;
}
case "portal": {
field(p,'Portal address','https://portal.example.edu');row(p,'Default tag','School');note(p,'Sign in with your provider','Your portal opens inside Calander. Sign in there, then open the schedule you want to import.');button(p,'Open portal');
break;
}
case "portalweb": {
note(p,'portal.example.edu','Protected portal · Example browser view');heading(p,'Student Portal');field(p,'Student email','you@example.edu');field(p,'Password','Enter on the provider’s website');button(p,'Sign in to portal',true);txt(p,'After signing in, navigate to your schedule.','Small','muted',342);button(p,'Import this page');button(p,'Cancel',true);
break;
}
case "review": {
p.itemSpacing=12;event(p,'Design lecture','Mon, Sep 14 · 10:00–11:30','✓ SCHOOL · FIXED','purpleBg');event(p,'Study group','Tue, Sep 15 · 16:00–17:00','✓ SCHOOL · FLEXIBLE','purpleBg');event(p,'Project workshop','Wed, Sep 16 · 14:00–16:00','✓ SCHOOL · FIXED','purpleBg');row(p,'Assign tags','All selected → School');txt(p,'Tap an event to correct details or deselect it.','Small','muted',342);button(p,'Add 3 events');
break;
}
case "conflict": {
event(p,'Design lecture','Mon, Sep 14 · 10:00–11:30','EXISTING · FIXED','purpleBg');event(p,'Coffee with Maya','Mon, Sep 14 · 11:00–12:00','IMPORTED · FLEXIBLE','greenBg');heading(p,'How would you like to handle this?');row(p,'Move coffee to 11:30','Keep your lecture unchanged','✓');row(p,'Keep both times','Show the overlap in your calendar','○');row(p,'Skip the imported event','','○');button(p,'Confirm choice');
break;
}
case "importdone": {
spacer(p,48);note(p,'3 events added','Your school schedule is now in your calendar. Each event has the School tag.','greenBg');button(p,'View calendar');button(p,'Import another schedule',true);
break;
}
case "importerror": {
spacer(p,32);note(p,'No events found','Try a clearer photo, a different PDF or a page that shows event dates and times.','orangeBg');button(p,'Choose another source');button(p,'Add an event manually',true);
break;
}
case "sports": {
chips(p,['Following','Upcoming'],0);event(p,'North FC vs City United','Sat, Sep 12 · 15:00','FOOTBALL · SAMPLE FIXTURE','greenBg');event(p,'Harbor vs Mountain','Sun, Sep 13 · 19:30','BASKETBALL · SAMPLE FIXTURE','orangeBg');heading(p,'Your teams');row(p,'North FC','Football · Following','✓');row(p,'Harbor','Basketball · Following','✓');button(p,'Follow more teams');
break;
}
case "follow": {
field(p,'Find a team','Search teams or leagues');chips(p,['Football','Basketball'],0);row(p,'North FC','Premier Division','✓');row(p,'City United','Premier Division','+');row(p,'Riverside','National League','+');button(p,'Save followed teams');
break;
}
case "match": {
spacer(p,12);const m=box(p,'Fixture',342,'VERTICAL',12,'greenBg',24);round(m,'r24');txt(m,'FOOTBALL · PREMIER DIVISION','Caption','green',294);txt(m,'North FC\nvs City United','Title','text',294);txt(m,'Saturday, Sep 12 · 15:00','Label','text',294);txt(m,'North Stadium','Body','muted',294);row(p,'Calendar tag','Personal');row(p,'Reminder','30 minutes before');button(p,'Add match to calendar');
break;
}
case "friends": {
field(p,'Search friends','Name or username');row(p,'Maya Chen','@mayachen');row(p,'Sam Rivera','@samrivera');row(p,'Jordan Lee','@jordanlee');row(p,'Friend requests','1 waiting for you','1');button(p,'Add a friend');
break;
}
case "addfriend": {
field(p,'Username','@taylorkim');row(p,'Taylor Kim','@taylorkim','+');button(p,'Send friend request');note(p,'Make plans together','Once your request is accepted, you can invite Taylor to calendar events.');
break;
}
case "requests": {
heading(p,'Received · 1');row(p,'Taylor Kim','@taylorkim');button(p,'Accept request');button(p,'Decline',true);heading(p,'Sent · 1');row(p,'Jamie Park','@jamiepark · Pending','…');
break;
}
case "tags": {
row(p,'●  Work','8 events','›','accent');row(p,'●  Personal','12 events','›','green');row(p,'●  School','6 events','›','purple');note(p,'Keep imports organized','Choose a default tag when you import. You can change each event’s tag during review.');button(p,'Create a tag');
break;
}
case "newtag": {
field(p,'Tag name','Fitness');heading(p,'Color');chips(p,['Blue','Green','Purple'],1);chips(p,['Amber','Rose','Slate'],-1);note(p,'Preview','●  Fitness','greenBg');button(p,'Create tag');
break;
}
case "notifications": {
heading(p,'Today');row(p,'Design review in 15 minutes','09:00 · Studio 2');row(p,'Your schedule changed','Design lecture moved to 10:00');row(p,'Maya accepted your invitation','Design review · Friday');heading(p,'Earlier');row(p,'Calendar connected','Google Calendar is up to date','✓');button(p,'Mark all as read',true);
break;
}
case "settings": {
p.itemSpacing=10;row(p,'Alex Morgan','@alexmorgan');row(p,'Appearance',theme);row(p,'Connected calendars','2 connected');row(p,'Tags','Work, Personal, School');row(p,'Notifications','Reminders and schedule changes');row(p,'Export calendar','Calendar file or image');row(p,'Widgets & Live Activities','Your day at a glance');
break;
}
case "appearance": {
row(p,'Light','Bright and clear',theme==='Light'?'✓':'○');row(p,'Dark','Easy on the eyes',theme==='Dark'?'✓':'○');row(p,'Use device setting','Follow your phone’s appearance','○');note(p,'A preview of your day','Design review · 09:00–10:00');button(p,'Save appearance');
break;
}
case "connections": {
row(p,'Google Calendar','alex@example.com · Connected','✓');row(p,'Microsoft Outlook','School account · Connected','✓');row(p,'Apple iCloud','Connect via iCloud / CalDAV','+');row(p,'Sync status','Updated just now','✓');note(p,'Choose what appears','Tap a connected account to choose calendars or disconnect it.');button(p,'Sync now');
break;
}
case "export": {
chips(p,['.ics file','Image'],0);row(p,'Date range','September 1–30, 2026');row(p,'Include tags','Work, Personal, School');note(p,'Ready for other calendars','An .ics file keeps event dates and times. Choose Image for a visual snapshot.');button(p,'Export calendar');
break;
}
case "account": {
field(p,'Name','Alex Morgan');field(p,'Username','alexmorgan');row(p,'Email','alex@example.com · Verified','✓');row(p,'Password','Send a password reset link');button(p,'Save account');button(p,'Sign out',true);
break;
}
case "alerts": {
row(p,'Upcoming events','Use each event’s reminder','On');row(p,'Schedule changes','Get notified when event times change','On');row(p,'Guest responses','Invitations and RSVPs','On');row(p,'Sports updates','Changes to followed fixtures','Off');note(p,'Phone notifications','Allow notifications in your device settings to receive alerts.');button(p,'Save preferences');
break;
}
case "widgets": {
heading(p,'Home screen widget');event(p,'Up next · Design review','09:00–10:00 · Studio 2','CALANDER · IN 15 MIN');heading(p,'Live Activity');const island=box(p,'Dynamic Island preview',342,'VERTICAL',8,'text',24);round(island,'r24');txt(island,'Design review                  15 min','Label','surface',294);txt(island,'Studio 2 · Starts at 09:00','Small','surface',294);row(p,'Live Activities','Show your next event','On');txt(p,'Add the Calander widget from your iPhone’s home screen widget gallery.','Small','muted',342);button(p,'Done');
break;
}
case "signout": {
spacer(p,32);note(p,'See you soon, Alex','Your calendar is saved to your account. Log in again to pick up where you left off.');button(p,'Sign out');button(p,'Stay signed in',true);
break;
}
case "month": {
p.itemSpacing=12;chips(p,['Month','Week','Day'],0);const cal=box(p,'September calendar',342,'VERTICAL',4,'surface',8);round(cal);const c=dateComponent;let head=box(cal,'Weekdays',326,'HORIZONTAL',2);for(const d of ['M','T','W','T','F','S','S']){const t=txt(head,d,'Caption','muted',44);t.textAlignHorizontal='CENTER';}for(let week=0;week<5;week++){const rr=box(cal,'Week '+week,326,'HORIZONTAL',2);for(let day=0;day<7;day++){const num=week*7+day;const display=num===0?'31':num>30?String(num-30):String(num);const n=instance(rr,c,{Day:display});if(num===11){fill(n,'primary');n.findAllWithCriteria({types:['TEXT']}).forEach(t=>t.fills=[paint('onPrimary')]);}else if(num===0||num>30)n.opacity=.35;}}heading(p,'Friday 11 · 3 events');event(p,'Design review','09:00–10:00 · Studio 2','WORK · FIXED');event(p,'Lunch with Maya','12:30–13:30 · Olive Café','PERSONAL · FLEXIBLE','greenBg');button(p,'+  New event');
break;
}
case "week": {
p.itemSpacing=12;chips(p,['Month','Week','Day'],1);const week=box(p,'Week planner',342,'VERTICAL',8,'surface',12);round(week);const days=box(week,'Dates',318,'HORIZONTAL',6);for(const [i,s] of ['M 7','T 8','W 9','T 10','F 11','S 12','S 13'].entries()){const col=box(days,s,40,'VERTICAL',10,i===4?'tint':null,0);round(col,'r12');txt(col,s,'Caption',i===4?'accent':'muted',40);for(let j=0;j<4;j++){const block=box(col,'Time block',40,'VERTICAL',4,(i+j)%3===0?'tint':(i+j)%4===0?'greenBg':null);block.resize(40,48);block.primaryAxisSizingMode='FIXED';if((i+j)%3===0)txt(block,j===0?'9 am':'2 pm','Caption','accent',40);}}txt(week,'Morning → afternoon · All times local','Caption','muted',318);heading(p,'Friday highlights');event(p,'Design review','09:00–10:00 · Studio 2');button(p,'+  New event');
break;
}
case "day": {
p.itemSpacing=12;chips(p,['Month','Week','Day'],2);heading(p,'TODAY · SEPTEMBER 11');event(p,'Design review','09:00–10:00 · Studio 2','WORK · FIXED');txt(p,'10:00–12:30  ·  2½ hours free','Small','muted',342);event(p,'Lunch with Maya','12:30–13:30 · Olive Café','PERSONAL · FLEXIBLE','greenBg');event(p,'Evening walk','18:00–18:45 · Riverside','PERSONAL · FLEXIBLE','greenBg');button(p,'+  New event');
break;
}
default: throw new Error("Missing screen: "+key);
} }
}
main().catch(error=>{console.error(error);figma.closePlugin('Calander stopped: '+error.message+'. Any partial page has been kept for inspection.');});
