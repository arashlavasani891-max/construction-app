/* ===== راسپینا — کنترل پروژه ساختمان — منطق اصلی اپ (فاز ۱: ورود و نقش‌ها) ===== */

firebase.initializeApp(firebaseConfig);
const auth = firebase.auth();
const db = firebase.firestore();

let currentUser = null;   // آبجکت کاربر Firebase Auth
let myProfile = null;     // سند users/{uid}
let loginBusy = false;

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

/* ---------- صفحه‌ی ورود ---------- */
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
      ${errorMsg ? `<div class="auth-error">${errorMsg}</div>` : ''}
      <button id="loginBtn" class="auth-btn">ورود</button>
    </div>
  `;
  document.getElementById('loginBtn').addEventListener('click', doLogin);
  document.getElementById('loginPassword').addEventListener('keydown', (e) => {
    if (e.key === 'Enter') doLogin();
  });
}

async function doLogin() {
  if (loginBusy) return;
  const username = (document.getElementById('loginUsername').value || '').trim();
  const password = document.getElementById('loginPassword').value || '';

  if (!username || !password) {
    renderLogin('نام کاربری و رمز عبور را وارد کنید.');
    return;
  }

  loginBusy = true;
  const btn = document.getElementById('loginBtn');
  if (btn) { btn.disabled = true; btn.textContent = 'در حال بررسی…'; }

  try {
    const usernameDoc = await db.collection('usernames').doc(username).get();
    if (!usernameDoc.exists) {
      throw { code: 'custom/username-not-found' };
    }
    const email = usernameDoc.data().email;
    await auth.signInWithEmailAndPassword(email, password);
    // بعد از این، onAuthStateChanged خودش صفحه را عوض می‌کند.
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
  auth.signOut();
}

/* ---------- صفحه‌ی غیرفعال/بدون دسترسی ---------- */
function renderBlocked() {
  headerSub.textContent = myProfile && myProfile.username ? myProfile.username : '';
  headerRight.innerHTML = `<button class="signout-btn" onclick="doLogout()">خروج</button>`;
  appEl.innerHTML = `
    <div class="center-screen">
      <img src="./icon-192.png" alt="راسپینا">
      <h2>دسترسی فعال نیست</h2>
      <p>حساب کاربری شما در حال حاضر غیرفعال است. با مدیر سیستم تماس بگیرید.</p>
    </div>
  `;
}

/* ---------- پنل مدیر (اسکلت فاز ۱ — بخش‌های بعدی در فازهای آینده اضافه می‌شوند) ---------- */
function renderAdminHome() {
  headerSub.textContent = myProfile.username || '';
  headerRight.innerHTML = `
    <span class="role-badge">مدیر</span>
    <button class="signout-btn" onclick="doLogout()">خروج</button>
  `;
  appEl.innerHTML = `
    <div class="card">
      <h2 style="margin:0 0 8px;">خوش آمدید، ${escapeHtml(myProfile.displayName || myProfile.username || '')}</h2>
      <p style="color:var(--ink-soft); font-size:13px; line-height:1.9;">
        ورود با موفقیت انجام شد. بخش‌های پروژه‌ها، چک‌لیست، نیروی کاری و گزارش‌ها
        در مراحل بعدی به همین صفحه اضافه می‌شوند.
      </p>
    </div>
  `;
}

/* ---------- پنل کاربر عادی (اسکلت فاز ۱) ---------- */
function renderUserHome() {
  headerSub.textContent = myProfile.username || '';
  headerRight.innerHTML = `<button class="signout-btn" onclick="doLogout()">خروج</button>`;
  appEl.innerHTML = `
    <div class="card">
      <h2 style="margin:0 0 8px;">خوش آمدید، ${escapeHtml(myProfile.displayName || myProfile.username || '')}</h2>
      <p style="color:var(--ink-soft); font-size:13px; line-height:1.9;">
        ورود با موفقیت انجام شد. پروژه‌های شما در مراحل بعدی به همین صفحه اضافه می‌شوند.
      </p>
    </div>
  `;
}

function escapeHtml(str) {
  return String(str || '').replace(/[&<>"']/g, (c) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
  }[c]));
}

/* ---------- مسیر اصلی: تشخیص وضعیت ورود ---------- */
auth.onAuthStateChanged(async (user) => {
  currentUser = user;
  setStatus(true);

  if (!user) {
    myProfile = null;
    renderLogin();
    hideSplash();
    return;
  }

  try {
    const doc = await db.collection('users').doc(user.uid).get();
    if (!doc.exists) {
      myProfile = { username: '', displayName: '', roleId: '', active: false };
      renderBlocked();
      hideSplash();
      return;
    }
    myProfile = doc.data();

    if (myProfile.active !== true) {
      renderBlocked();
    } else if (myProfile.roleId === 'admin') {
      renderAdminHome();
    } else {
      renderUserHome();
    }
  } catch (err) {
    console.error(err);
    appEl.innerHTML = `<div class="center-screen"><p class="auth-error">خطا در دریافت اطلاعات کاربر.</p></div>`;
  }
  hideSplash();
});

window.addEventListener('offline', () => setStatus(false));
window.addEventListener('online', () => setStatus(true));
