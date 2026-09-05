/* ===== راسپینا — کنترل پروژه ساختمان — منطق اصلی اپ (فاز ۱ تا ۴) ===== */

firebase.initializeApp(firebaseConfig);
const auth = firebase.auth();
const db = firebase.firestore();

let currentUser = null;
let myProfile = null;
let loginBusy = false;

let myProjects = [];
let projectsUnsub = null;
let currentProject = null;
let currentBlocks = [];        // بلوک‌های پروژه‌ی جاری (هرکدام با floors)

const appEl = document.getElementById('app');
const headerRight = document.getElementById('headerRight');
const headerSub = document.getElementById('headerSub');
const statusDot = document.getElementById('statusDot');
const syncNote = document.getElementById('syncNote');

function hideSplash() {
  const s = document.getElementById('splashScreen');
  if (s) s.classList.add('hide');
}
function setStatus(online) {
  if (!statusDot || !syncNote) return;
  statusDot.classList.toggle('off', !online);
  syncNote.textContent = online ? 'متصل' : 'قطع ارتباط';
}
function escapeHtml(str) {
  return String(str || '').replace(/[&<>"']/g, (c) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
  }[c]));
}
function isAdminUser() { return myProfile && myProfile.roleId === 'admin'; }

/* ================= ورود ================= */

function renderLogin(errorMsg) {
  headerRight.innerHTML = '';
  headerSub.textContent = 'راسپینا';
  appEl.innerHTML = `
    <div class="center-screen">
      <img src="./icon-192.png" alt="راسپینا">
      <h2>ورود به سامانه</h2>
      <p>نام کاربری و رمز عبور خود را وارد کنید.</p>
      <input id="loginUsername" class="auth-input" placeholder="نام کاربری" autocomplete="username">
      <input id="loginPassword" class="auth-input" type="password" placeholder="رمز عبور" autocomplete="current-password">
      ${errorMsg ? `<div class="auth-error">${escapeHtml(errorMsg)}</div>` : ''}
      <button id="loginBtn" class="auth-btn">ورود</button>
      <button class="btn-danger" style="margin-top:14px;" onclick="renderSignup()">حساب ندارید؟ ثبت‌نام کنید</button>
    </div>
  `;
  document.getElementById('loginBtn').addEventListener('click', doLogin);
  document.getElementById('loginPassword').addEventListener('keydown', (e) => {
    if (e.key === 'Enter') doLogin();
  });
}

/* ---------- ثبت‌نام خودکار (نیاز به تایید مدیر) ---------- */

function renderSignup(errorMsg) {
  headerRight.innerHTML = '';
  headerSub.textContent = 'راسپینا';
  appEl.innerHTML = `
    <div class="center-screen">
      <img src="./icon-192.png" alt="راسپینا">
      <h2>ثبت‌نام</h2>
      <p>بعد از ثبت‌نام، حساب شما تا زمان تایید مدیر سیستم غیرفعال خواهد بود.</p>
      <input id="suUsername" class="auth-input" placeholder="نام کاربری">
      <input id="suDisplayName" class="auth-input" placeholder="نام و نام خانوادگی">
      <input id="suPassword" class="auth-input" type="password" placeholder="رمز عبور (حداقل ۶ کاراکتر)">
      <input id="suPassword2" class="auth-input" type="password" placeholder="تکرار رمز عبور">
      ${errorMsg ? `<div class="auth-error">${escapeHtml(errorMsg)}</div>` : ''}
      <button id="signupBtn" class="auth-btn">ثبت‌نام</button>
      <button class="btn-danger" style="margin-top:14px;" onclick="renderLogin()">بازگشت به ورود</button>
    </div>
  `;
  document.getElementById('signupBtn').addEventListener('click', doSignup);
}

async function doSignup() {
  const username = document.getElementById('suUsername').value.trim();
  const displayName = document.getElementById('suDisplayName').value.trim();
  const password = document.getElementById('suPassword').value;
  const password2 = document.getElementById('suPassword2').value;

  if (!username || !password) { renderSignup('نام کاربری و رمز عبور را وارد کنید.'); return; }
  if (password.length < 6) { renderSignup('رمز عبور باید حداقل ۶ کاراکتر باشد.'); return; }
  if (password !== password2) { renderSignup('تکرار رمز عبور مطابقت ندارد.'); return; }

  const btn = document.getElementById('signupBtn');
  btn.disabled = true; btn.textContent = 'در حال ثبت‌نام…';

  try {
    const existing = await db.collection('usernames').doc(username).get();
    if (existing.exists) { renderSignup('این نام کاربری قبلاً استفاده شده.'); return; }

    const email = username + '@raspina.local';
    const cred = await auth.createUserWithEmailAndPassword(email, password);
    const uid = cred.user.uid;

    await db.collection('usernames').doc(username).set({ email });
    await db.collection('users').doc(uid).set({
      username, displayName, roleId: 'user', active: false,
      assignedProjectIds: [], assignedChecklistCategoryIds: [],
    });
    // بعد از این، onAuthStateChanged خودش صفحه‌ی «در انتظار تایید» را نشان می‌دهد.
  } catch (err) {
    console.error(err);
    let msg = 'ثبت‌نام ناموفق بود.';
    if (err.code === 'auth/email-already-in-use') msg = 'این نام کاربری قبلاً استفاده شده.';
    renderSignup(msg);
  }
}

async function doLogin() {
  if (loginBusy) return;
  const username = (document.getElementById('loginUsername').value || '').trim();
  const password = document.getElementById('loginPassword').value || '';
  if (!username || !password) { renderLogin('نام کاربری و رمز عبور را وارد کنید.'); return; }

  loginBusy = true;
  const btn = document.getElementById('loginBtn');
  if (btn) { btn.disabled = true; btn.textContent = 'در حال بررسی…'; }

  try {
    const usernameDoc = await db.collection('usernames').doc(username).get();
    if (!usernameDoc.exists) throw { code: 'custom/username-not-found' };
    const email = usernameDoc.data().email;
    await auth.signInWithEmailAndPassword(email, password);
  } catch (err) {
    loginBusy = false;
    renderLogin(loginErrorMessage(err));
  }
}

function loginErrorMessage(err) {
  const code = err && err.code;
  if (code === 'custom/username-not-found') return 'نام کاربری یافت نشد.';
  if (code === 'auth/wrong-password' || code === 'auth/invalid-credential') return 'رمز عبور اشتباه است.';
  if (code === 'auth/too-many-requests') return 'تعداد تلاش‌ها زیاد بوده، کمی صبر کنید.';
  if (code === 'auth/network-request-failed') return 'مشکل در اتصال اینترنت.';
  return 'ورود ناموفق بود، دوباره تلاش کنید.';
}

function doLogout() {
  if (projectsUnsub) { projectsUnsub(); projectsUnsub = null; }
  currentProject = null;
  auth.signOut();
}

function renderBlocked() {
  headerSub.textContent = myProfile && myProfile.username ? myProfile.username : '';
  headerRight.innerHTML = `<button class="signout-btn" onclick="doLogout()">خروج</button>`;
  appEl.innerHTML = `
    <div class="center-screen">
      <img src="./icon-192.png" alt="راسپینا">
      <h2>در انتظار تایید مدیر</h2>
      <p>حساب کاربری شما هنوز توسط مدیر سیستم تایید یا فعال نشده است. لطفاً بعداً دوباره امتحان کنید یا با مدیر تماس بگیرید.</p>
    </div>
  `;
}

/* ================= لیست پروژه‌ها ================= */

function startProjectsListener() {
  if (projectsUnsub) projectsUnsub();

  if (isAdminUser()) {
    projectsUnsub = db.collection('projects')
      .orderBy('createdAt', 'desc')
      .onSnapshot((snap) => {
        myProjects = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
        if (!currentProject) renderProjectList();
      }, (err) => {
        console.error(err);
        appEl.innerHTML = `<div class="center-screen"><p class="auth-error">خطا در دریافت پروژه‌ها.</p></div>`;
      });
  } else {
    loadProjectsForUser();
  }
}

async function loadProjectsForUser() {
  const ids = myProfile.assignedProjectIds || [];
  if (ids.length === 0) { myProjects = []; renderProjectList(); return; }
  const docs = await Promise.all(ids.map((id) => db.collection('projects').doc(id).get()));
  myProjects = docs.filter((d) => d.exists && d.data().active !== false)
    .map((d) => ({ id: d.id, ...d.data() }));
  renderProjectList();
}

function renderProjectList() {
  currentProject = null;
  const admin = isAdminUser();

  headerSub.textContent = myProfile.username || '';
  headerRight.innerHTML = `
    ${admin ? '<button class="signout-btn" onclick="renderAdminPanel()">پنل مدیریت</button>' : ''}
    <button class="signout-btn" onclick="doLogout()">خروج</button>
  `;

  let listHtml;
  if (myProjects.length === 0) {
    listHtml = `
      <div class="card flat" style="text-align:center; color:var(--ink-soft); font-size:13px; line-height:1.9;">
        هیچ پروژه‌ای برای شما تعریف نشده است.${admin ? '' : '<br>با مدیر سیستم تماس بگیرید.'}
      </div>`;
  } else {
    listHtml = myProjects.map((p) => `
      <div class="card">
        <div class="card-row" onclick="openProject('${p.id}')">
          <div>
            <div class="card-title">${escapeHtml(p.name)}</div>
            <div class="card-sub">${escapeHtml(p.description) || 'کد: ' + escapeHtml(p.code || '—')}</div>
          </div>
          ${p.active === false ? '<span class="chip off">غیرفعال</span>' : '<span class="arrow">‹</span>'}
        </div>
      </div>`).join('');
  }

  appEl.innerHTML = `
    <div class="section-title">پروژه‌ها</div>
    ${listHtml}
    ${admin ? '<div style="height:70px;"></div>' : ''}
  `;

  if (admin) {
    const fab = document.createElement('button');
    fab.className = 'fab';
    fab.textContent = '+ پروژه جدید';
    fab.onclick = renderProjectBuilder;
    appEl.appendChild(fab);
  }
}

/* ================= ساخت پروژه‌ی جدید ================= */

let builderBlocks = [];

function newFloorGroup() { return { type: 'residential', floorStart: 1, floorEnd: 1, repeatCount: 1, unitsPerFloor: 0 }; }
function newBlock() { return { name: 'بلوک ' + (builderBlocks.length + 1), groups: [newFloorGroup()] }; }

function renderProjectBuilder() {
  builderBlocks = [newBlock()];
  headerRight.innerHTML = `<button class="back-btn" onclick="renderProjectList()">بازگشت</button>`;
  headerSub.textContent = 'ساخت پروژه جدید';
  drawBuilder();
}

function computeBuilderTotals() {
  let floors = 0, units = 0;
  for (const b of builderBlocks) for (const g of b.groups) {
    const fc = floorCountOf(g);
    floors += fc;
    units += fc * (parseInt(g.unitsPerFloor) || 0);
  }
  return { blocks: builderBlocks.length, floors, units };
}
function floorCountOf(g) {
  if (g.type === 'residential') {
    const s = parseInt(g.floorStart) || 1, e = parseInt(g.floorEnd) || 1;
    return Math.max(0, e - s + 1);
  }
  return parseInt(g.repeatCount) || 1;
}
function floorLabelOf(g, index) {
  switch (g.type) {
    case 'parking': return `پارکینگ ${index + 1}`;
    case 'ground': return 'همکف';
    case 'roof': return 'بام';
    default: { const start = parseInt(g.floorStart) || 1; return `طبقه ${start + index}`; }
  }
}

function drawBuilder() {
  const totals = computeBuilderTotals();
  appEl.innerHTML = `
    <div class="section-title">اطلاعات پروژه</div>
    <div class="card flat">
      <label class="field-label">نام پروژه</label>
      <input id="pName" class="field-input" placeholder="مثلاً برج راسپینا">
      <label class="field-label">کد پروژه</label>
      <input id="pCode" class="field-input" placeholder="اختیاری">
      <label class="field-label">توضیحات</label>
      <input id="pDesc" class="field-input" placeholder="اختیاری">
    </div>
    <div class="section-title">بلوک‌ها</div>
    <div id="blocksHost"></div>
    <button class="btn-secondary" onclick="addBlock()">+ افزودن بلوک</button>
    <div class="summary-strip">
      <div class="summary-item"><div class="summary-num">${totals.blocks}</div><div class="summary-label">بلوک</div></div>
      <div class="summary-item"><div class="summary-num">${totals.floors}</div><div class="summary-label">طبقه</div></div>
      <div class="summary-item"><div class="summary-num">${totals.units}</div><div class="summary-label">واحد</div></div>
    </div>
    <div id="builderError" class="auth-error" style="margin-bottom:10px;"></div>
    <button id="submitBuilderBtn" class="btn-primary" style="width:100%;" onclick="submitBuilder()">ساخت پروژه</button>
  `;
  drawBlocks();
}

function drawBlocks() {
  const host = document.getElementById('blocksHost');
  host.innerHTML = builderBlocks.map((b, bi) => `
    <div class="subcard">
      <div class="subcard-head">
        <input class="field-input" style="margin-bottom:0;" value="${escapeHtml(b.name)}"
               oninput="builderBlocks[${bi}].name=this.value">
        ${builderBlocks.length > 1 ? `<button class="icon-btn" onclick="removeBlock(${bi})">✕</button>` : ''}
      </div>
      ${b.groups.map((g, gi) => drawGroup(b, bi, g, gi)).join('')}
      <button class="btn-secondary" onclick="addGroup(${bi})">+ افزودن گروه طبقه</button>
    </div>`).join('');
}

function drawGroup(block, bi, g, gi) {
  const isResidential = g.type === 'residential';
  return `
    <div class="subcard" style="background:var(--panel);">
      <div class="subcard-head">
        <select class="field-input" style="margin-bottom:0;" onchange="builderBlocks[${bi}].groups[${gi}].type=this.value; drawBlocks(); refreshTotals();">
          <option value="parking" ${g.type === 'parking' ? 'selected' : ''}>پارکینگ</option>
          <option value="ground" ${g.type === 'ground' ? 'selected' : ''}>همکف</option>
          <option value="residential" ${g.type === 'residential' ? 'selected' : ''}>مسکونی (بازه طبقه)</option>
          <option value="roof" ${g.type === 'roof' ? 'selected' : ''}>بام</option>
        </select>
        ${block.groups.length > 1 ? `<button class="icon-btn" onclick="removeGroup(${bi},${gi})">✕</button>` : ''}
      </div>
      ${isResidential ? `
        <div class="row-2">
          <div><label class="field-label">از طبقه</label>
            <input type="number" class="field-input" value="${g.floorStart}"
                   oninput="builderBlocks[${bi}].groups[${gi}].floorStart=this.value; refreshTotals();"></div>
          <div><label class="field-label">تا طبقه</label>
            <input type="number" class="field-input" value="${g.floorEnd}"
                   oninput="builderBlocks[${bi}].groups[${gi}].floorEnd=this.value; refreshTotals();"></div>
        </div>` : `
        <label class="field-label">تعداد طبقه از این نوع</label>
        <input type="number" class="field-input" value="${g.repeatCount}"
               oninput="builderBlocks[${bi}].groups[${gi}].repeatCount=this.value; refreshTotals();">`}
      <label class="field-label">تعداد واحد در هر طبقه (۰ = بدون واحد)</label>
      <input type="number" class="field-input" value="${g.unitsPerFloor}"
             oninput="builderBlocks[${bi}].groups[${gi}].unitsPerFloor=this.value; refreshTotals();">
    </div>`;
}

function addBlock() { builderBlocks.push(newBlock()); drawBlocks(); refreshTotals(); }
function removeBlock(i) { builderBlocks.splice(i, 1); drawBlocks(); refreshTotals(); }
function addGroup(bi) { builderBlocks[bi].groups.push(newFloorGroup()); drawBlocks(); refreshTotals(); }
function removeGroup(bi, gi) { builderBlocks[bi].groups.splice(gi, 1); drawBlocks(); refreshTotals(); }

function refreshTotals() {
  const totals = computeBuilderTotals();
  const el = document.querySelector('.summary-strip');
  if (!el) return;
  el.innerHTML = `
    <div class="summary-item"><div class="summary-num">${totals.blocks}</div><div class="summary-label">بلوک</div></div>
    <div class="summary-item"><div class="summary-num">${totals.floors}</div><div class="summary-label">طبقه</div></div>
    <div class="summary-item"><div class="summary-num">${totals.units}</div><div class="summary-label">واحد</div></div>`;
}

async function submitBuilder() {
  const name = document.getElementById('pName').value.trim();
  const code = document.getElementById('pCode').value.trim();
  const desc = document.getElementById('pDesc').value.trim();
  const errEl = document.getElementById('builderError');
  const btn = document.getElementById('submitBuilderBtn');
  if (!name) { errEl.textContent = 'نام پروژه را وارد کنید.'; return; }
  errEl.textContent = '';
  btn.disabled = true;
  btn.textContent = 'در حال ساخت…';

  try {
    const newProject = await createProjectWithStructure(name, code, desc, builderBlocks);
    // به‌روزرسانی فوری لیست، بدون نیاز به منتظر ماندن برای Listener
    myProjects = [newProject, ...myProjects.filter((p) => p.id !== newProject.id)];
    renderProjectList();
  } catch (err) {
    console.error(err);
    errEl.textContent = 'خطا در ساخت پروژه: ' + (err.message || err);
    btn.disabled = false;
    btn.textContent = 'ساخت پروژه';
  }
}

async function createProjectWithStructure(name, code, description, blocks) {
  const projectRef = db.collection('projects').doc();
  const nowLocal = new Date();
  const projectData = { name, code, description, active: true, createdAt: firebase.firestore.FieldValue.serverTimestamp() };
  const writes = [{ ref: projectRef, data: projectData }];

  let blockOrder = 0;
  for (const b of blocks) {
    const blockRef = db.collection('blocks').doc();
    writes.push({ ref: blockRef, data: { projectId: projectRef.id, name: b.name, order: blockOrder++ } });
    let floorOrder = 0;
    for (const g of b.groups) {
      const fc = floorCountOf(g);
      const unitsPerFloor = parseInt(g.unitsPerFloor) || 0;
      for (let i = 0; i < fc; i++) {
        const floorRef = db.collection('floors').doc();
        writes.push({ ref: floorRef, data: {
          blockId: blockRef.id, projectId: projectRef.id, name: floorLabelOf(g, i),
          order: floorOrder++, type: g.type, unitsCount: unitsPerFloor } });
        for (let u = 1; u <= unitsPerFloor; u++) {
          const unitRef = db.collection('units').doc();
          writes.push({ ref: unitRef, data: {
            floorId: floorRef.id, blockId: blockRef.id, projectId: projectRef.id, name: 'واحد ' + u } });
        }
      }
    }
  }
  for (let i = 0; i < writes.length; i += 400) {
    const chunk = writes.slice(i, i + 400);
    const batch = db.batch();
    chunk.forEach((w) => batch.set(w.ref, w.data));
    await batch.commit();
  }
  // آبجکت محلی برای نمایش فوری (createdAt واقعی کمی بعد از سرور می‌رسد)
  return { id: projectRef.id, ...projectData, createdAt: { toMillis: () => nowLocal.getTime() } };
}

/* ================= صفحه‌ی پروژه ================= */

async function openProject(projectId) {
  const p = myProjects.find((x) => x.id === projectId);
  if (!p) return;
  currentProject = p;

  headerSub.textContent = p.name;
  headerRight.innerHTML = `<button class="back-btn" onclick="renderProjectList()">بازگشت</button>`;
  appEl.innerHTML = `<div class="center-screen"><span class="sync-note"><span class="dot"></span><span>در حال بارگذاری…</span></span></div>`;

  const blocksSnap = await db.collection('blocks').where('projectId', '==', projectId).get();
  const blocks = blocksSnap.docs.map((d) => ({ id: d.id, ...d.data() })).sort((a, b) => (a.order || 0) - (b.order || 0));
  for (const b of blocks) {
    const floorsSnap = await db.collection('floors').where('blockId', '==', b.id).get();
    b.floors = floorsSnap.docs.map((d) => ({ id: d.id, ...d.data() })).sort((a, b2) => (a.order || 0) - (b2.order || 0));
  }
  currentBlocks = blocks;
  renderProjectHome();
}

function renderProjectHome() {
  const p = currentProject;
  const admin = isAdminUser();

  const treeHtml = currentBlocks.map((b, i) => `
    <div class="tree-block">
      <div class="tree-head" onclick="toggleTreeBlock(${i})">
        <span>${escapeHtml(b.name)}</span>
        <span class="cnt" style="margin-inline-start:auto;">${b.floors.length} طبقه</span>
      </div>
      <div class="tree-body" id="treeBody${i}">
        ${b.floors.map((f) => `
          <div class="tree-floor"><span>${escapeHtml(f.name)}</span>
            <span class="cnt">${f.unitsCount > 0 ? f.unitsCount + ' واحد' : 'بدون واحد'}</span></div>
        `).join('') || '<div class="tree-floor">طبقه‌ای ثبت نشده</div>'}
      </div>
    </div>`).join('');

  appEl.innerHTML = `
    <div class="section-title">${escapeHtml(p.name)}</div>
    ${p.description ? `<p style="color:var(--ink-soft); font-size:12.5px; margin-top:-6px;">${escapeHtml(p.description)}</p>` : ''}
    <div class="module-grid">
      <div class="module-tile" onclick="openChecklistModule()"><div class="em">📋</div><div class="lbl">چک‌لیست ساختمان</div></div>
      <div class="module-tile" onclick="openWorkforceModule()"><div class="em">👷</div><div class="lbl">نیروی کاری</div></div>
      <div class="module-tile" style="grid-column:span 2;" onclick="openReportsModule()"><div class="em">📊</div><div class="lbl">داشبورد و گزارش</div></div>
    </div>
    <div class="section-title">ساختار پروژه</div>
    ${treeHtml || '<div class="card flat">بلوکی برای این پروژه تعریف نشده.</div>'}
    ${admin ? `
      <div style="margin-top:18px;">
        <button class="btn-danger" onclick="confirmDeactivateProject()">غیرفعال کردن این پروژه</button>
      </div>` : ''}
  `;
}

function toggleTreeBlock(i) {
  const el = document.getElementById('treeBody' + i);
  if (el) el.classList.toggle('open');
}

async function confirmDeactivateProject() {
  if (!currentProject) return;
  if (!confirm('این پروژه غیرفعال شود؟ اطلاعات آن حذف نمی‌شود.')) return;
  await db.collection('projects').doc(currentProject.id).update({ active: false });
  renderProjectList();
}

/* ================= پنل مدیریت (سراسری) ================= */

function renderAdminPanel() {
  headerSub.textContent = 'پنل مدیریت';
  headerRight.innerHTML = `<button class="back-btn" onclick="renderProjectList()">بازگشت</button>`;
  appEl.innerHTML = `
    <div class="module-grid">
      <div class="module-tile" onclick="renderChecklistAdmin()"><div class="em">📋</div><div class="lbl">چک‌لیست ساختمان</div></div>
      <div class="module-tile" onclick="renderContractorsAdmin()"><div class="em">🏗️</div><div class="lbl">پیمانکاران</div></div>
      <div class="module-tile" style="grid-column:span 2;" onclick="renderUsersAdmin()"><div class="em">👤</div><div class="lbl">کاربران</div></div>
    </div>
  `;
}

/* ---- مدیریت دسته‌بندی‌های چک‌لیست ---- */

function renderChecklistAdmin() {
  headerSub.textContent = 'مدیریت چک‌لیست';
  headerRight.innerHTML = `<button class="back-btn" onclick="renderAdminPanel()">بازگشت</button>`;
  appEl.innerHTML = `
    <div class="section-title">دسته‌بندی‌ها</div>
    <div id="catList" class="card flat">در حال بارگذاری…</div>
    <div class="card flat">
      <label class="field-label">دسته‌بندی جدید</label>
      <div class="row-2">
        <input id="newCatName" class="field-input" placeholder="مثلاً ابنیه">
        <button class="btn-primary" onclick="addChecklistCategory()">افزودن</button>
      </div>
    </div>
  `;
  db.collection('checklistCategories').orderBy('order').get().then((snap) => {
    const cats = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    const host = document.getElementById('catList');
    if (!host) return;
    host.innerHTML = cats.length ? cats.map((c) => `
      <div class="card-row" style="padding:8px 0;" onclick="renderChecklistItemsAdmin('${c.id}','${escapeHtml(c.name)}')">
        <span class="card-title" style="font-size:13.5px;">${escapeHtml(c.name)}</span>
        <span class="arrow">‹</span>
      </div>`).join('') : 'دسته‌بندی‌ای ثبت نشده.';
  });
}

async function addChecklistCategory() {
  const nameEl = document.getElementById('newCatName');
  const name = nameEl.value.trim();
  if (!name) return;
  const countSnap = await db.collection('checklistCategories').get();
  await db.collection('checklistCategories').add({ name, order: countSnap.size });
  nameEl.value = '';
  renderChecklistAdmin();
}

/* ---- مدیریت آیتم‌های یک دسته ---- */

function renderChecklistItemsAdmin(categoryId, categoryName) {
  headerSub.textContent = categoryName;
  headerRight.innerHTML = `<button class="back-btn" onclick="renderChecklistAdmin()">بازگشت</button>`;
  appEl.innerHTML = `
    <div class="section-title">فعالیت‌های «${escapeHtml(categoryName)}»</div>
    <div id="itemList" class="card flat">در حال بارگذاری…</div>
    <div class="card flat">
      <label class="field-label">فعالیت جدید</label>
      <input id="newItemName" class="field-input" placeholder="نام فعالیت">
      <label class="field-label">وزن (٪ از کل پیشرفت — اختیاری)</label>
      <input id="newItemWeight" type="number" class="field-input" placeholder="0">
      <button class="btn-primary" style="width:100%;" onclick="addChecklistItem('${categoryId}')">افزودن فعالیت</button>
    </div>
  `;
  loadChecklistItemsAdmin(categoryId);
}

async function loadChecklistItemsAdmin(categoryId) {
  const snap = await db.collection('checklistItems').where('categoryId', '==', categoryId).get();
  const items = snap.docs.map((d) => ({ id: d.id, ...d.data() })).sort((a, b) => (a.order || 0) - (b.order || 0));
  const host = document.getElementById('itemList');
  if (!host) return;
  host.innerHTML = items.length ? items.map((it) => `
    <div class="card-row" style="padding:8px 0;">
      <span>${escapeHtml(it.name)} ${it.weight ? `<span class="chip">${it.weight}%</span>` : ''}</span>
      <button class="icon-btn" onclick="deleteChecklistItem('${it.id}','${categoryId}','${escapeHtml(categoryName_global)}')">حذف</button>
    </div>`).join('') : 'فعالیتی ثبت نشده.';
}

let categoryName_global = '';
function addChecklistItem(categoryId) {
  categoryName_global = document.getElementById('itemList') ? headerSub.textContent : '';
  return _addChecklistItem(categoryId);
}
async function _addChecklistItem(categoryId) {
  const nameEl = document.getElementById('newItemName');
  const weightEl = document.getElementById('newItemWeight');
  const name = nameEl.value.trim();
  if (!name) return;
  const countSnap = await db.collection('checklistItems').where('categoryId', '==', categoryId).get();
  await db.collection('checklistItems').add({
    categoryId, parentItemId: null, name, order: countSnap.size,
    weight: parseFloat(weightEl.value) || 0,
  });
  nameEl.value = ''; weightEl.value = '';
  loadChecklistItemsAdmin(categoryId);
}
async function deleteChecklistItem(itemId, categoryId) {
  if (!confirm('این فعالیت حذف شود؟')) return;
  await db.collection('checklistItems').doc(itemId).delete();
  loadChecklistItemsAdmin(categoryId);
}

/* ---- مدیریت پیمانکاران ---- */

function renderContractorsAdmin() {
  headerSub.textContent = 'پیمانکاران';
  headerRight.innerHTML = `<button class="back-btn" onclick="renderAdminPanel()">بازگشت</button>`;
  appEl.innerHTML = `
    <div class="section-title">لیست پیمانکاران</div>
    <div id="contractorList" class="card flat">در حال بارگذاری…</div>
    <div class="card flat">
      <label class="field-label">نام پیمانکار</label>
      <input id="newContractorName" class="field-input" placeholder="مثلاً شرکت سازه پایدار">
      <label class="field-label">نوع فعالیت (اختیاری)</label>
      <input id="newContractorType" class="field-input" placeholder="مثلاً بتن‌ریزی">
      <button class="btn-primary" style="width:100%;" onclick="addContractor()">افزودن پیمانکار</button>
    </div>
  `;
  loadContractorsAdmin();
}

async function loadContractorsAdmin() {
  const snap = await db.collection('contractors').orderBy('name').get();
  const list = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
  const host = document.getElementById('contractorList');
  if (!host) return;
  host.innerHTML = list.length ? list.map((c) => `
    <div class="card-row" style="padding:8px 0;">
      <span>${escapeHtml(c.name)} ${c.activityType ? `<span class="chip">${escapeHtml(c.activityType)}</span>` : ''} ${c.active === false ? '<span class="chip off">غیرفعال</span>' : ''}</span>
      <button class="icon-btn" onclick="toggleContractorActive('${c.id}', ${c.active === false})">${c.active === false ? 'فعال‌سازی' : 'غیرفعال'}</button>
    </div>`).join('') : 'پیمانکاری ثبت نشده.';
}

async function addContractor() {
  const nameEl = document.getElementById('newContractorName');
  const typeEl = document.getElementById('newContractorType');
  const name = nameEl.value.trim();
  if (!name) return;
  await db.collection('contractors').add({
    name, code: '', activityType: typeEl.value.trim(), description: '', active: true,
  });
  nameEl.value = ''; typeEl.value = '';
  loadContractorsAdmin();
}
async function toggleContractorActive(id, makeActive) {
  await db.collection('contractors').doc(id).update({ active: makeActive });
  loadContractorsAdmin();
}

/* ================= ماژول چک‌لیست/ثبت پیشرفت (داخل پروژه) ================= */

async function openChecklistModule() {
  appEl.innerHTML = `<div class="center-screen"><span class="sync-note"><span class="dot"></span><span>در حال بارگذاری…</span></span></div>`;
  const snap = await db.collection('checklistCategories').orderBy('order').get();
  let cats = snap.docs.map((d) => ({ id: d.id, ...d.data() }));

  if (!isAdminUser()) {
    const allowed = myProfile.assignedChecklistCategoryIds || [];
    cats = cats.filter((c) => allowed.includes(c.id));
  }

  if (cats.length === 0) {
    appEl.innerHTML = `<div class="card flat" style="text-align:center;">هیچ چک‌لیستی برای شما تعریف نشده است.</div>
      <button class="btn-secondary" style="margin-top:10px;" onclick="renderProjectHome()">بازگشت</button>`;
    return;
  }
  if (cats.length === 1) { openProgressEntry(cats[0]); return; }

  appEl.innerHTML = `
    <div class="section-title">انتخاب دسته‌بندی</div>
    ${cats.map((c) => `
      <div class="card"><div class="card-row" onclick='openProgressEntry(${JSON.stringify(c)})'>
        <span class="card-title">${escapeHtml(c.name)}</span><span class="arrow">‹</span>
      </div></div>`).join('')}
    <button class="btn-secondary" onclick="renderProjectHome()">بازگشت</button>
  `;
}

async function openProgressEntry(category) {
  headerSub.textContent = 'ثبت پیشرفت — ' + category.name;
  headerRight.innerHTML = `<button class="back-btn" onclick="renderProjectHome()">بازگشت</button>`;
  appEl.innerHTML = `<div class="center-screen"><span class="sync-note"><span class="dot"></span><span>در حال بارگذاری…</span></span></div>`;

  const itemsSnap = await db.collection('checklistItems').where('categoryId', '==', category.id).get();
  const items = itemsSnap.docs.map((d) => ({ id: d.id, ...d.data() })).sort((a, b) => (a.order || 0) - (b.order || 0));

  appEl.innerHTML = `
    <div class="section-title">ثبت پیشرفت — ${escapeHtml(category.name)}</div>
    <div class="card flat">
      <label class="field-label">بلوک</label>
      <select id="peBlock" class="field-input" onchange="peOnBlockChange()">
        <option value="">— انتخاب کنید —</option>
        ${currentBlocks.map((b) => `<option value="${b.id}">${escapeHtml(b.name)}</option>`).join('')}
      </select>
      <label class="field-label">طبقه</label>
      <select id="peFloor" class="field-input" onchange="peOnFloorChange()"><option value="">ابتدا بلوک را انتخاب کنید</option></select>
      <label class="field-label">واحد (اختیاری)</label>
      <select id="peUnit" class="field-input"><option value="">— بدون واحد مشخص —</option></select>
      <label class="field-label">فعالیت</label>
      <select id="peItem" class="field-input">
        <option value="">— انتخاب کنید —</option>
        ${items.map((it) => `<option value='${it.id}'>${escapeHtml(it.name)}</option>`).join('')}
      </select>
      <label class="field-label">درصد پیشرفت: <span id="peProgressLabel">0</span>٪</label>
      <input id="peProgress" type="range" min="0" max="100" value="0" style="width:100%;"
             oninput="document.getElementById('peProgressLabel').textContent=this.value">
      <label class="field-label">توضیحات (اختیاری)</label>
      <input id="peDesc" class="field-input" placeholder="توضیحات">
    </div>
    <div id="peError" class="auth-error" style="margin-bottom:10px;"></div>
    <button id="peSubmitBtn" class="btn-primary" style="width:100%;" onclick="submitProgress('${category.id}')">ثبت</button>
    <div class="section-title">ثبت‌های امروز</div>
    <div id="peTodayList" class="card flat">—</div>
  `;
  loadTodayProgress(category.id);
}

function peOnBlockChange() {
  const blockId = document.getElementById('peBlock').value;
  const floorSel = document.getElementById('peFloor');
  const unitSel = document.getElementById('peUnit');
  unitSel.innerHTML = '<option value="">— بدون واحد مشخص —</option>';
  if (!blockId) { floorSel.innerHTML = '<option value="">ابتدا بلوک را انتخاب کنید</option>'; return; }
  const block = currentBlocks.find((b) => b.id === blockId);
  floorSel.innerHTML = '<option value="">— انتخاب کنید —</option>' +
    (block ? block.floors.map((f) => `<option value="${f.id}">${escapeHtml(f.name)}</option>`).join('') : '');
}

async function peOnFloorChange() {
  const floorId = document.getElementById('peFloor').value;
  const unitSel = document.getElementById('peUnit');
  unitSel.innerHTML = '<option value="">— بدون واحد مشخص —</option>';
  if (!floorId) return;
  const snap = await db.collection('units').where('floorId', '==', floorId).get();
  const units = snap.docs.map((d) => ({ id: d.id, ...d.data() })).sort((a, b) => a.name.localeCompare(b.name, 'fa'));
  unitSel.innerHTML += units.map((u) => `<option value="${u.id}">${escapeHtml(u.name)}</option>`).join('');
}

async function submitProgress(categoryId) {
  const blockId = document.getElementById('peBlock').value;
  const floorId = document.getElementById('peFloor').value;
  const unitId = document.getElementById('peUnit').value || null;
  const itemId = document.getElementById('peItem').value;
  const percent = parseFloat(document.getElementById('peProgress').value) || 0;
  const desc = document.getElementById('peDesc').value.trim();
  const errEl = document.getElementById('peError');
  const btn = document.getElementById('peSubmitBtn');

  if (!blockId || !floorId || !itemId) {
    errEl.textContent = 'بلوک، طبقه و فعالیت را انتخاب کنید.';
    return;
  }
  errEl.textContent = '';
  btn.disabled = true; btn.textContent = 'در حال ثبت…';

  try {
    await db.collection('progressRecords').add({
      projectId: currentProject.id, blockId, floorId, unitId,
      checklistCategoryId: categoryId, checklistItemId: itemId,
      progressPercent: percent, description: desc, photoUrl: null,
      createdBy: currentUser.uid, createdByUsername: myProfile.username || '',
      createdAt: firebase.firestore.FieldValue.serverTimestamp(),
    });
    document.getElementById('peDesc').value = '';
    document.getElementById('peProgress').value = 0;
    document.getElementById('peProgressLabel').textContent = '0';
    loadTodayProgress(categoryId);
  } catch (err) {
    console.error(err);
    errEl.textContent = 'خطا در ثبت: ' + (err.message || err);
  }
  btn.disabled = false; btn.textContent = 'ثبت';
}

async function loadTodayProgress(categoryId) {
  const host = document.getElementById('peTodayList');
  if (!host) return;
  const snap = await db.collection('progressRecords')
    .where('projectId', '==', currentProject.id)
    .where('checklistCategoryId', '==', categoryId)
    .get();
  const startOfDay = new Date(); startOfDay.setHours(0, 0, 0, 0);
  const records = snap.docs.map((d) => ({ id: d.id, ...d.data() }))
    .filter((r) => r.createdAt && r.createdAt.toDate && r.createdAt.toDate() >= startOfDay)
    .sort((a, b) => b.createdAt.toMillis() - a.createdAt.toMillis());

  host.innerHTML = records.length ? records.map((r) => `
    <div class="card-row" style="padding:6px 0; cursor:default;">
      <span style="font-size:12.5px;">${r.progressPercent}٪ ${r.description ? '— ' + escapeHtml(r.description) : ''}</span>
      <span class="chip">${escapeHtml(r.createdByUsername)}</span>
    </div>`).join('') : 'هنوز ثبتی امروز نداشتید.';
}

/* ================= ماژول نیروی کاری (داخل پروژه) ================= */

async function openWorkforceModule() {
  headerRight.innerHTML = `<button class="back-btn" onclick="renderProjectHome()">بازگشت</button>`;
  headerSub.textContent = 'نیروی کاری — ' + currentProject.name;
  appEl.innerHTML = `<div class="center-screen"><span class="sync-note"><span class="dot"></span><span>در حال بارگذاری…</span></span></div>`;

  const snap = await db.collection('contractors').orderBy('name').get();
  const contractors = snap.docs.map((d) => ({ id: d.id, ...d.data() })).filter((c) => c.active !== false);

  appEl.innerHTML = `
    <div class="section-title">ثبت استقرار نفرات</div>
    <div class="card flat">
      <label class="field-label">پیمانکار</label>
      <select id="wfContractor" class="field-input">
        <option value="">— انتخاب کنید —</option>
        ${contractors.map((c) => `<option value='${c.id}' data-name="${escapeHtml(c.name)}">${escapeHtml(c.name)}</option>`).join('')}
      </select>
      <label class="field-label">شرح فعالیت</label>
      <input id="wfActivity" class="field-input" placeholder="مثلاً قالب‌بندی سقف">
      <div class="row-2">
        <div><label class="field-label">استادکار</label>
          <input id="wfSkilled" type="number" class="field-input" value="0" oninput="wfUpdateTotal()"></div>
        <div><label class="field-label">کارگر</label>
          <input id="wfLabor" type="number" class="field-input" value="0" oninput="wfUpdateTotal()"></div>
      </div>
      <div style="font-size:12.5px; color:var(--ink-soft); margin-bottom:10px;">مجموع نفرات: <b id="wfTotal">0</b></div>
      <label class="field-label">توضیحات (اختیاری)</label>
      <input id="wfDesc" class="field-input" placeholder="توضیحات">
    </div>
    <div id="wfError" class="auth-error" style="margin-bottom:10px;"></div>
    <button id="wfSubmitBtn" class="btn-primary" style="width:100%;" onclick="submitWorkforce()">ثبت</button>
    <div class="section-title">ثبت‌های امروز</div>
    <div id="wfTodayList" class="card flat">—</div>
  `;
  loadTodayWorkforce();
}

function wfUpdateTotal() {
  const s = parseInt(document.getElementById('wfSkilled').value) || 0;
  const l = parseInt(document.getElementById('wfLabor').value) || 0;
  document.getElementById('wfTotal').textContent = s + l;
}

async function submitWorkforce() {
  const sel = document.getElementById('wfContractor');
  const contractorId = sel.value;
  const contractorName = sel.selectedOptions[0] ? sel.selectedOptions[0].dataset.name : '';
  const activity = document.getElementById('wfActivity').value.trim();
  const skilled = parseInt(document.getElementById('wfSkilled').value) || 0;
  const labor = parseInt(document.getElementById('wfLabor').value) || 0;
  const desc = document.getElementById('wfDesc').value.trim();
  const errEl = document.getElementById('wfError');
  const btn = document.getElementById('wfSubmitBtn');

  if (!contractorId || !activity) {
    errEl.textContent = 'پیمانکار و شرح فعالیت را وارد کنید.';
    return;
  }
  errEl.textContent = '';
  btn.disabled = true; btn.textContent = 'در حال ثبت…';

  try {
    await db.collection('workforceRecords').add({
      projectId: currentProject.id, contractorId, contractorName,
      activityDescription: activity, skilledCount: skilled, laborCount: labor,
      totalCount: skilled + labor, description: desc,
      createdBy: currentUser.uid, createdByUsername: myProfile.username || '',
      createdAt: firebase.firestore.FieldValue.serverTimestamp(),
    });
    document.getElementById('wfActivity').value = '';
    document.getElementById('wfSkilled').value = 0;
    document.getElementById('wfLabor').value = 0;
    document.getElementById('wfDesc').value = '';
    wfUpdateTotal();
    loadTodayWorkforce();
  } catch (err) {
    console.error(err);
    errEl.textContent = 'خطا در ثبت: ' + (err.message || err);
  }
  btn.disabled = false; btn.textContent = 'ثبت';
}

async function loadTodayWorkforce() {
  const host = document.getElementById('wfTodayList');
  if (!host) return;
  const snap = await db.collection('workforceRecords').where('projectId', '==', currentProject.id).get();
  const startOfDay = new Date(); startOfDay.setHours(0, 0, 0, 0);
  const records = snap.docs.map((d) => ({ id: d.id, ...d.data() }))
    .filter((r) => r.createdAt && r.createdAt.toDate && r.createdAt.toDate() >= startOfDay)
    .sort((a, b) => b.createdAt.toMillis() - a.createdAt.toMillis());

  host.innerHTML = records.length ? records.map((r) => `
    <div class="card-row" style="padding:6px 0; cursor:default;">
      <span style="font-size:12.5px;">${escapeHtml(r.contractorName)} — ${escapeHtml(r.activityDescription)} (${r.totalCount} نفر)</span>
      <span class="chip">${escapeHtml(r.createdByUsername)}</span>
    </div>`).join('') : 'هنوز ثبتی امروز نداشتید.';
}

/* ================= داشبورد و گزارش‌ها (فاز ۵) ================= */

function weightedAverage(valueByKey, weightByKey) {
  const keys = Object.keys(valueByKey);
  if (keys.length === 0) return 0;
  let totalWeight = 0;
  keys.forEach((k) => { totalWeight += (weightByKey[k] || 0); });
  if (totalWeight <= 0) {
    // بدون وزن مشخص: میانگین ساده
    const sum = keys.reduce((s, k) => s + valueByKey[k], 0);
    return sum / keys.length;
  }
  let sum = 0;
  keys.forEach((k) => { sum += valueByKey[k] * (weightByKey[k] || 0); });
  return sum / totalWeight;
}

function averageByKey(records, keyFn) {
  const groups = {};
  records.forEach((r) => {
    const k = keyFn(r);
    if (!k) return;
    (groups[k] = groups[k] || []).push(r.progressPercent);
  });
  const result = {};
  Object.keys(groups).forEach((k) => {
    const arr = groups[k];
    result[k] = arr.reduce((a, b) => a + b, 0) / arr.length;
  });
  return result;
}

async function openReportsModule() {
  headerRight.innerHTML = `<button class="back-btn" onclick="renderProjectHome()">بازگشت</button>`;
  headerSub.textContent = 'داشبورد و گزارش — ' + currentProject.name;
  appEl.innerHTML = `<div class="center-screen"><span class="sync-note"><span class="dot"></span><span>در حال محاسبه…</span></span></div>`;

  const [progSnap, catSnap, itemSnap, wfSnap] = await Promise.all([
    db.collection('progressRecords').where('projectId', '==', currentProject.id).get(),
    db.collection('checklistCategories').orderBy('order').get(),
    db.collection('checklistItems').get(),
    db.collection('workforceRecords').where('projectId', '==', currentProject.id).get(),
  ]);

  const allRecords = progSnap.docs.map((d) => ({ id: d.id, ...d.data() }))
    .filter((r) => r.createdAt && r.createdAt.toMillis)
    .sort((a, b) => b.createdAt.toMillis() - a.createdAt.toMillis());

  // آخرین رکورد به‌ازای هر (فعالیت + بلوک + طبقه + واحد) — چون allRecords نزولی است.
  const latestByKey = {};
  allRecords.forEach((r) => {
    const key = `${r.checklistItemId}_${r.blockId}_${r.floorId}_${r.unitId || ''}`;
    if (!(key in latestByKey)) latestByKey[key] = r;
  });
  const latestRecords = Object.values(latestByKey);

  const categories = catSnap.docs.map((d) => ({ id: d.id, ...d.data() }));
  const allItems = itemSnap.docs.map((d) => ({ id: d.id, ...d.data() }));
  const weightByItem = {};
  allItems.forEach((it) => { weightByItem[it.id] = it.weight || 0; });

  const percentsByItem = {};
  latestRecords.forEach((r) => {
    (percentsByItem[r.checklistItemId] = percentsByItem[r.checklistItemId] || []).push(r.progressPercent);
  });
  const avgPercentByItem = {};
  Object.keys(percentsByItem).forEach((k) => {
    const arr = percentsByItem[k];
    avgPercentByItem[k] = arr.reduce((a, b) => a + b, 0) / arr.length;
  });

  const overallProgress = weightedAverage(avgPercentByItem, weightByItem);

  const progressByCategory = categories.map((cat) => {
    const itemIds = allItems.filter((it) => it.categoryId === cat.id).map((it) => it.id);
    const subset = {};
    itemIds.forEach((id) => { if (id in avgPercentByItem) subset[id] = avgPercentByItem[id]; });
    return { name: cat.name, percent: weightedAverage(subset, weightByItem) };
  });

  const progressByBlockMap = averageByKey(latestRecords, (r) => r.blockId);
  const progressByBlock = currentBlocks.map((b) => ({
    name: b.name, percent: progressByBlockMap[b.id] || 0,
  }));

  // نیروی کاری: مجموع نفرات به تفکیک پیمانکار
  const wfRecords = wfSnap.docs.map((d) => d.data());
  const totalsByContractor = {};
  wfRecords.forEach((r) => {
    totalsByContractor[r.contractorName] = (totalsByContractor[r.contractorName] || 0) + (r.totalCount || 0);
  });
  const contractorRows = Object.keys(totalsByContractor)
    .map((name) => ({ name, total: totalsByContractor[name] }))
    .sort((a, b) => b.total - a.total);
  const grandTotalWorkforce = contractorRows.reduce((s, c) => s + c.total, 0);

  function bar(label, percent) {
    const p = Math.max(0, Math.min(100, Math.round(percent)));
    return `
      <div style="margin-bottom:12px;">
        <div style="display:flex; justify-content:space-between; font-size:12px; margin-bottom:4px;">
          <span>${escapeHtml(label)}</span><span style="color:var(--gold); font-family:'JetBrains Mono',monospace;">${p}٪</span>
        </div>
        <div style="background:var(--panel-2); border-radius:8px; height:8px; overflow:hidden;">
          <div style="background:var(--gold); height:100%; width:${p}%;"></div>
        </div>
      </div>`;
  }

  window.__reportData = { overallProgress, progressByCategory, progressByBlock, contractorRows, grandTotalWorkforce, wfRecordsCount: wfRecords.length };

  appEl.innerHTML = `
    <div style="display:flex; gap:8px; margin-bottom:6px;">
      <button class="btn-secondary" style="flex:1;" onclick="exportReportExcel()">خروجی اکسل</button>
      <button class="btn-secondary" style="flex:1;" onclick="exportReportPdf()">خروجی PDF</button>
    </div>
    <div class="section-title">پیشرفت کلی پروژه</div>
    <div class="card">
      <div style="text-align:center; font-family:'JetBrains Mono',monospace; font-size:34px; font-weight:800; color:var(--gold);">
        ${Math.round(overallProgress)}٪
      </div>
    </div>

    <div class="section-title">پیشرفت به تفکیک دسته‌بندی</div>
    <div class="card flat">
      ${progressByCategory.length ? progressByCategory.map((c) => bar(c.name, c.percent)).join('') : 'دسته‌بندی‌ای ثبت نشده.'}
    </div>

    <div class="section-title">پیشرفت به تفکیک بلوک</div>
    <div class="card flat">
      ${progressByBlock.length ? progressByBlock.map((b) => bar(b.name, b.percent)).join('') : 'بلوکی ثبت نشده.'}
    </div>

    <div class="section-title">نیروی کاری (مجموع کل)</div>
    <div class="summary-strip">
      <div class="summary-item"><div class="summary-num">${grandTotalWorkforce}</div><div class="summary-label">نفر × روز</div></div>
      <div class="summary-item"><div class="summary-num">${wfRecords.length}</div><div class="summary-label">ثبت</div></div>
      <div class="summary-item"><div class="summary-num">${contractorRows.length}</div><div class="summary-label">پیمانکار</div></div>
    </div>
    <div class="card flat">
      ${contractorRows.length ? contractorRows.map((c) => `
        <div class="card-row" style="padding:6px 0; cursor:default;">
          <span style="font-size:12.5px;">${escapeHtml(c.name)}</span>
          <span class="chip">${c.total} نفر × روز</span>
        </div>`).join('') : 'ثبتی وجود ندارد.'}
    </div>
  `;
}

/* ================= مدیریت کاربران (فاز ۶) ================= */

let usersAdminCache = [];
let usersAdminProjectsCache = [];
let usersAdminCategoriesCache = [];

async function renderUsersAdmin() {
  headerSub.textContent = 'کاربران';
  headerRight.innerHTML = `<button class="back-btn" onclick="renderAdminPanel()">بازگشت</button>`;
  appEl.innerHTML = `<div class="center-screen"><span class="sync-note"><span class="dot"></span><span>در حال بارگذاری…</span></span></div>`;

  const [usersSnap, projSnap, catSnap] = await Promise.all([
    db.collection('users').get(),
    db.collection('projects').get(),
    db.collection('checklistCategories').orderBy('order').get(),
  ]);
  usersAdminCache = usersSnap.docs.map((d) => ({ id: d.id, ...d.data() }))
    .sort((a, b) => (a.username || '').localeCompare(b.username || '', 'fa'));
  usersAdminProjectsCache = projSnap.docs.map((d) => ({ id: d.id, ...d.data() }));
  usersAdminCategoriesCache = catSnap.docs.map((d) => ({ id: d.id, ...d.data() }));

  drawUsersAdmin();
}

function drawUsersAdmin() {
  appEl.innerHTML = `
    <div class="section-title">لیست کاربران</div>
    ${usersAdminCache.map((u) => `
      <div class="card">
        <div class="card-row" onclick="renderUserForm('${u.id}')">
          <div>
            <div class="card-title">${escapeHtml(u.username)}</div>
            <div class="card-sub">${u.roleId === 'admin' ? 'مدیر' : 'کاربر عادی'} — ${(u.assignedProjectIds || []).length} پروژه</div>
          </div>
          ${u.active === false ? '<span class="chip off">غیرفعال</span>' : '<span class="arrow">‹</span>'}
        </div>
      </div>`).join('') || '<div class="card flat">کاربری ثبت نشده.</div>'}
    <button class="btn-primary" style="width:100%; margin-top:10px;" onclick="renderUserForm(null)">+ کاربر جدید</button>
  `;
}

function renderUserForm(userId) {
  const editing = userId ? usersAdminCache.find((u) => u.id === userId) : null;
  headerRight.innerHTML = `<button class="back-btn" onclick="drawUsersAdmin()">بازگشت</button>`;
  headerSub.textContent = editing ? 'ویرایش کاربر' : 'کاربر جدید';

  const assignedProjectIds = editing ? (editing.assignedProjectIds || []) : [];
  const assignedCatIds = editing ? (editing.assignedChecklistCategoryIds || []) : [];

  appEl.innerHTML = `
    <div class="section-title">${editing ? 'ویرایش کاربر' : 'ساخت کاربر جدید'}</div>
    <div class="card flat">
      <label class="field-label">نام کاربری</label>
      <input id="ufUsername" class="field-input" value="${editing ? escapeHtml(editing.username) : ''}" ${editing ? 'disabled' : ''}>
      ${!editing ? `
        <label class="field-label">رمز عبور</label>
        <input id="ufPassword" type="password" class="field-input" placeholder="حداقل ۶ کاراکتر">
      ` : ''}
      <label class="field-label">نام نمایشی</label>
      <input id="ufDisplayName" class="field-input" value="${editing ? escapeHtml(editing.displayName || '') : ''}">
      <label class="field-label">نقش</label>
      <select id="ufRole" class="field-input">
        <option value="user" ${editing && editing.roleId !== 'admin' ? 'selected' : ''}>کاربر عادی</option>
        <option value="admin" ${editing && editing.roleId === 'admin' ? 'selected' : ''}>مدیر</option>
      </select>
      <label class="field-label">
        <input type="checkbox" id="ufActive" ${!editing || editing.active !== false ? 'checked' : ''}> فعال باشد
      </label>
    </div>

    <div class="section-title">پروژه‌های قابل‌دسترس</div>
    <div class="card flat">
      ${usersAdminProjectsCache.length ? usersAdminProjectsCache.map((p) => `
        <label style="display:flex; align-items:center; gap:8px; padding:6px 0; font-size:13px;">
          <input type="checkbox" class="ufProjectChk" value="${p.id}" ${assignedProjectIds.includes(p.id) ? 'checked' : ''}>
          ${escapeHtml(p.name)}
        </label>`).join('') : 'پروژه‌ای وجود ندارد.'}
    </div>

    <div class="section-title">دسته‌بندی‌های چک‌لیست قابل‌دسترس</div>
    <div class="card flat">
      ${usersAdminCategoriesCache.length ? usersAdminCategoriesCache.map((c) => `
        <label style="display:flex; align-items:center; gap:8px; padding:6px 0; font-size:13px;">
          <input type="checkbox" class="ufCatChk" value="${c.id}" ${assignedCatIds.includes(c.id) ? 'checked' : ''}>
          ${escapeHtml(c.name)}
        </label>`).join('') : 'دسته‌بندی‌ای وجود ندارد.'}
    </div>

    <div id="ufError" class="auth-error" style="margin-bottom:10px;"></div>
    <button id="ufSubmitBtn" class="btn-primary" style="width:100%;" onclick="submitUserForm('${userId || ''}')">
      ${editing ? 'ذخیره تغییرات' : 'ساخت کاربر'}
    </button>
  `;
}

async function submitUserForm(userId) {
  const editing = userId ? usersAdminCache.find((u) => u.id === userId) : null;
  const displayName = document.getElementById('ufDisplayName').value.trim();
  const roleId = document.getElementById('ufRole').value;
  const active = document.getElementById('ufActive').checked;
  const assignedProjectIds = Array.from(document.querySelectorAll('.ufProjectChk:checked')).map((el) => el.value);
  const assignedChecklistCategoryIds = Array.from(document.querySelectorAll('.ufCatChk:checked')).map((el) => el.value);
  const errEl = document.getElementById('ufError');
  const btn = document.getElementById('ufSubmitBtn');
  errEl.textContent = '';

  if (editing) {
    btn.disabled = true; btn.textContent = 'در حال ذخیره…';
    try {
      await db.collection('users').doc(editing.id).update({
        displayName, roleId, active, assignedProjectIds, assignedChecklistCategoryIds,
      });
      renderUsersAdmin();
    } catch (err) {
      console.error(err);
      errEl.textContent = 'خطا در ذخیره: ' + (err.message || err);
      btn.disabled = false; btn.textContent = 'ذخیره تغییرات';
    }
    return;
  }

  const username = document.getElementById('ufUsername').value.trim();
  const password = document.getElementById('ufPassword').value;
  if (!username || !password || password.length < 6) {
    errEl.textContent = 'نام کاربری و رمز عبور (حداقل ۶ کاراکتر) را وارد کنید.';
    return;
  }

  btn.disabled = true; btn.textContent = 'در حال ساخت…';
  const existing = await db.collection('usernames').doc(username).get();
  if (existing.exists) {
    errEl.textContent = 'این نام کاربری قبلاً استفاده شده.';
    btn.disabled = false; btn.textContent = 'ساخت کاربر';
    return;
  }

  const email = username + '@raspina.local';
  // یک نمونه‌ی موقت و جدا از Firebase می‌سازیم تا با ساخت کاربر جدید،
  // نشست ورود مدیر (شما) قطع نشود.
  const secondaryApp = firebase.initializeApp(firebaseConfig, 'Secondary-' + Date.now());
  try {
    const secondaryAuth = secondaryApp.auth();
    const cred = await secondaryAuth.createUserWithEmailAndPassword(email, password);
    const newUid = cred.user.uid;
    await secondaryAuth.signOut();

    await db.collection('usernames').doc(username).set({ email });
    await db.collection('users').doc(newUid).set({
      username, displayName, roleId, active,
      assignedProjectIds, assignedChecklistCategoryIds,
    });

    await secondaryApp.delete();
    renderUsersAdmin();
  } catch (err) {
    console.error(err);
    errEl.textContent = 'خطا در ساخت کاربر: ' + (err.code === 'auth/email-already-in-use'
      ? 'این نام کاربری قبلاً استفاده شده.' : (err.message || err));
    btn.disabled = false; btn.textContent = 'ساخت کاربر';
    try { await secondaryApp.delete(); } catch (e) {}
  }
}

/* ================= خروجی اکسل / PDF (فاز ۷) ================= */

function exportReportExcel() {
  const d = window.__reportData;
  if (!d) return;
  const wb = XLSX.utils.book_new();

  const summarySheet = XLSX.utils.aoa_to_sheet([
    ['پروژه', currentProject.name],
    ['پیشرفت کلی (٪)', Math.round(d.overallProgress)],
    ['مجموع نفر × روز', d.grandTotalWorkforce],
    ['تعداد ثبت نیروی کاری', d.wfRecordsCount],
  ]);
  XLSX.utils.book_append_sheet(wb, summarySheet, 'خلاصه');

  const catSheet = XLSX.utils.aoa_to_sheet([
    ['دسته‌بندی', 'درصد پیشرفت'],
    ...d.progressByCategory.map((c) => [c.name, Math.round(c.percent)]),
  ]);
  XLSX.utils.book_append_sheet(wb, catSheet, 'دسته‌بندی‌ها');

  const blockSheet = XLSX.utils.aoa_to_sheet([
    ['بلوک', 'درصد پیشرفت'],
    ...d.progressByBlock.map((b) => [b.name, Math.round(b.percent)]),
  ]);
  XLSX.utils.book_append_sheet(wb, blockSheet, 'بلوک‌ها');

  const wfSheet = XLSX.utils.aoa_to_sheet([
    ['پیمانکار', 'مجموع نفر × روز'],
    ...d.contractorRows.map((c) => [c.name, c.total]),
  ]);
  XLSX.utils.book_append_sheet(wb, wfSheet, 'نیروی کاری');

  XLSX.writeFile(wb, `گزارش-${currentProject.name}.xlsx`);
}

function exportReportPdf() {
  const d = window.__reportData;
  if (!d) return;

  const rows = (title, arr, key) => `
    <h3>${title}</h3>
    <table>
      <tr><th>${key === 'contractor' ? 'پیمانکار' : 'عنوان'}</th><th>${key === 'contractor' ? 'مجموع نفر × روز' : 'درصد پیشرفت'}</th></tr>
      ${arr.map((x) => `<tr><td>${escapeHtml(x.name)}</td><td>${key === 'contractor' ? x.total : Math.round(x.percent) + '٪'}</td></tr>`).join('')}
    </table>`;

  const html = `
    <!DOCTYPE html><html lang="fa" dir="rtl"><head><meta charset="UTF-8">
    <title>گزارش ${escapeHtml(currentProject.name)}</title>
    <style>
      body{ font-family:Tahoma, Arial, sans-serif; padding:24px; color:#111; }
      h1{ font-size:20px; margin-bottom:4px; }
      h3{ font-size:14px; margin:20px 0 8px; border-bottom:1px solid #ccc; padding-bottom:4px; }
      table{ width:100%; border-collapse:collapse; font-size:13px; }
      th, td{ border:1px solid #ccc; padding:6px 10px; text-align:right; }
      th{ background:#f0f0f0; }
      .big{ font-size:30px; font-weight:bold; text-align:center; margin:14px 0; }
    </style></head>
    <body>
      <h1>گزارش پروژه: ${escapeHtml(currentProject.name)}</h1>
      <div>تاریخ گزارش: ${new Date().toLocaleDateString('fa-IR')}</div>
      <div class="big">پیشرفت کلی: ${Math.round(d.overallProgress)}٪</div>
      ${rows('پیشرفت به تفکیک دسته‌بندی', d.progressByCategory, 'cat')}
      ${rows('پیشرفت به تفکیک بلوک', d.progressByBlock, 'cat')}
      ${rows('نیروی کاری', d.contractorRows, 'contractor')}
      <script>window.onload = () => window.print();</script>
    </body></html>`;

  const w = window.open('', '_blank');
  w.document.write(html);
  w.document.close();
}

/* ================= مسیر اصلی ================= */

auth.onAuthStateChanged(async (user) => {
  currentUser = user;
  setStatus(true);
  if (projectsUnsub) { projectsUnsub(); projectsUnsub = null; }

  if (!user) { myProfile = null; renderLogin(); hideSplash(); return; }

  try {
    const doc = await db.collection('users').doc(user.uid).get();
    if (!doc.exists) {
      myProfile = { username: '', displayName: '', roleId: '', active: false };
      renderBlocked(); hideSplash(); return;
    }
    myProfile = doc.data();
    if (myProfile.active !== true) renderBlocked();
    else startProjectsListener();
  } catch (err) {
    console.error(err);
    appEl.innerHTML = `<div class="center-screen"><p class="auth-error">خطا در دریافت اطلاعات کاربر.</p></div>`;
  }
  hideSplash();
});

window.addEventListener('offline', () => setStatus(false));
window.addEventListener('online', () => setStatus(true));
