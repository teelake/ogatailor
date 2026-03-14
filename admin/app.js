const API_BASE = '/oga-tailor/api';

const loginPage = document.getElementById('login-page');
const dashboardPage = document.getElementById('dashboard-page');
const loginForm = document.getElementById('login-form');
const loginError = document.getElementById('login-error');
const loginBtn = document.getElementById('login-btn');
const logoutBtn = document.getElementById('logout-btn');
const adminEmailEl = document.getElementById('admin-email');
const upcomingLimit = document.getElementById('upcoming-limit');
const navItems = document.querySelectorAll('.nav-item');
const overviewSection = document.getElementById('overview-section');
const plansSection = document.getElementById('plans-section');
const pageTitle = document.getElementById('page-title');

function getToken() {
  return sessionStorage.getItem('admin_token');
}

function setToken(token, admin) {
  sessionStorage.setItem('admin_token', token);
  if (admin) {
    sessionStorage.setItem('admin_email', admin.email);
  }
}

function clearAuth() {
  sessionStorage.removeItem('admin_token');
  sessionStorage.removeItem('admin_email');
}

function showLogin() {
  loginPage.classList.remove('hidden');
  dashboardPage.classList.add('hidden');
}

function showDashboard() {
  loginPage.classList.add('hidden');
  dashboardPage.classList.remove('hidden');
  adminEmailEl.textContent = sessionStorage.getItem('admin_email') || '';
}

function apiFetch(path, options = {}) {
  const token = getToken();
  const headers = {
    'Content-Type': 'application/json',
    ...(token && { Authorization: `Bearer ${token}` }),
    ...options.headers,
  };
  return fetch(`${API_BASE}${path}`, { ...options, headers });
}

async function checkAuth() {
  const token = getToken();
  if (!token) {
    showLogin();
    return;
  }
  const res = await apiFetch('/admin/dashboard?upcoming_limit=8');
  if (res.status === 401) {
    clearAuth();
    showLogin();
    return;
  }
  showDashboard();
  loadDashboard();
  loadPlans();
}

loginForm.addEventListener('submit', async (e) => {
  e.preventDefault();
  const email = document.getElementById('email').value.trim();
  const password = document.getElementById('password').value;
  loginError.classList.add('hidden');
  loginError.textContent = '';
  loginBtn.disabled = true;
  loginBtn.textContent = 'Signing in...';
  try {
    const res = await fetch(`${API_BASE}/admin/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password }),
    });
    const data = await res.json();
    if (!res.ok) {
      throw new Error(data.error || 'Login failed');
    }
    setToken(data.token, data.admin);
    showDashboard();
    loadDashboard();
    loadPlans();
  } catch (err) {
    loginError.textContent = err.message || 'Invalid email or password';
    loginError.classList.remove('hidden');
  } finally {
    loginBtn.disabled = false;
    loginBtn.textContent = 'Sign in';
  }
});

logoutBtn.addEventListener('click', async () => {
  try {
    await apiFetch('/admin/logout', { method: 'POST' });
  } catch (_) {}
  clearAuth();
  showLogin();
});

navItems.forEach((item) => {
  item.addEventListener('click', (e) => {
    e.preventDefault();
    const section = item.getAttribute('data-section');
    navItems.forEach((n) => n.classList.remove('active'));
    item.classList.add('active');
    if (section === 'overview') {
      overviewSection.classList.remove('hidden');
      plansSection.classList.add('hidden');
      pageTitle.textContent = 'Overview';
    } else {
      overviewSection.classList.add('hidden');
      plansSection.classList.remove('hidden');
      pageTitle.textContent = 'Plans';
    }
  });
});

upcomingLimit.addEventListener('change', () => {
  loadDashboard();
});

function renderDashboard(data) {
  const s = data.summary || {};
  document.getElementById('stat-users').textContent = String(s.users ?? 0);
  document.getElementById('stat-customers').textContent = String(s.customers ?? 0);
  document.getElementById('stat-measurements').textContent = String(s.measurements ?? 0);
  document.getElementById('stat-orders').textContent = String(s.orders ?? 0);

  const statusList = data.order_statuses || [];
  const max = Math.max(...statusList.map((r) => Number(r.total || 0)), 1);
  const statusBars = document.getElementById('status-bars');
  const statusListEl = document.getElementById('status-list');
  statusBars.innerHTML = '';
  statusListEl.innerHTML = '';
  for (const row of statusList) {
    const pct = Math.round((Number(row.total || 0) / max) * 100);
    const bar = document.createElement('div');
    bar.className = 'bar';
    bar.innerHTML = `
      <span>${escapeHtml(toTitle(row.status))}</span>
      <span class="bar-fill-wrap"><span class="bar-fill" style="width:${pct}%"></span></span>
      <span>${Number(row.total || 0)}</span>
    `;
    statusBars.appendChild(bar);
    const li = document.createElement('li');
    li.textContent = `${toTitle(row.status)}: ${row.total}`;
    statusListEl.appendChild(li);
  }
  if (statusList.length === 0) {
    statusListEl.innerHTML = '<li>No orders yet</li>';
  }

  const upcoming = document.getElementById('upcoming-list');
  upcoming.innerHTML = '';
  for (const row of data.upcoming_orders || []) {
    const li = document.createElement('li');
    const due = row.due_date ? new Date(row.due_date).toLocaleDateString() : '-';
    li.innerHTML = `<strong>${escapeHtml(row.title || 'Order')}</strong> — ${escapeHtml(
      row.customer_name || '-'
    )} <span class="pill">${escapeHtml(row.status || 'pending')}</span> (due ${due})`;
    upcoming.appendChild(li);
  }
  if (data.upcoming_orders?.length === 0) {
    upcoming.innerHTML = '<li>No upcoming due orders</li>';
  }
}

async function loadDashboard() {
  const limit = Number(upcomingLimit.value || 8);
  const res = await apiFetch(`/admin/dashboard?upcoming_limit=${limit}`);
  if (res.status === 401) {
    clearAuth();
    showLogin();
    return;
  }
  const data = await res.json();
  if (!res.ok) throw new Error(data.error || 'Failed to load dashboard');
  renderDashboard(data);
}

function renderPlans(rows) {
  const grid = document.getElementById('plans-grid');
  grid.innerHTML = '';
  for (const row of rows) {
    const card = document.createElement('article');
    card.className = 'plan-card';
    card.innerHTML = `
      <h3>${escapeHtml(toTitle(row.plan_code || 'plan'))}</h3>
      <div class="plan-form">
        <label>
          Customer limit
          <input data-field="customer_limit" type="number" min="1" placeholder="Unlimited (blank)"
            value="${row.customer_limit == null ? '' : Number(row.customer_limit)}" />
        </label>
        ${check('Cloud sync', 'can_sync', row.can_sync)}
        ${check('Export', 'can_export', row.can_export)}
        ${check('Multi-device', 'can_multi_device', row.can_multi_device)}
        ${check('Advanced reminders', 'can_advanced_reminders', row.can_advanced_reminders)}
        <button type="button" class="btn-save" data-save="${escapeHtml(row.plan_code)}">Save</button>
      </div>
    `;
    grid.appendChild(card);
  }
  grid.querySelectorAll('.btn-save').forEach((btn) => {
    btn.addEventListener('click', async () => {
      const planCode = btn.getAttribute('data-save');
      const card = btn.closest('.plan-card');
      const limitInput = card.querySelector('input[data-field="customer_limit"]');
      const payload = {
        plan_code: planCode,
        customer_limit: limitInput.value.trim() === '' ? null : Number(limitInput.value),
      };
      ['can_sync', 'can_export', 'can_multi_device', 'can_advanced_reminders'].forEach((name) => {
        const el = card.querySelector(`input[data-field="${name}"]`);
        payload[name] = Boolean(el?.checked);
      });
      try {
        btn.disabled = true;
        btn.textContent = 'Saving...';
        const res = await apiFetch('/admin/plans', {
          method: 'PATCH',
          body: JSON.stringify(payload),
        });
        const data = await res.json();
        if (!res.ok) throw new Error(data.error || 'Update failed');
        btn.textContent = 'Saved';
        setTimeout(() => {
          btn.textContent = 'Save';
          btn.disabled = false;
        }, 700);
      } catch (err) {
        btn.disabled = false;
        btn.textContent = 'Save';
        alert(err.message || 'Failed to update plan settings');
      }
    });
  });
}

function check(label, field, value) {
  return `<label>${escapeHtml(label)} <input data-field="${field}" type="checkbox" ${Number(value) === 1 ? 'checked' : ''} /></label>`;
}

async function loadPlans() {
  const res = await apiFetch('/admin/plans');
  if (res.status === 401) {
    clearAuth();
    showLogin();
    return;
  }
  const payload = await res.json();
  if (!res.ok) throw new Error(payload.error || 'Failed to load plans');
  renderPlans(payload.data || []);
}

function toTitle(value) {
  return String(value || '')
    .replaceAll('_', ' ')
    .replace(/\b\w/g, (m) => m.toUpperCase());
}

function escapeHtml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

checkAuth();
