const tokenInput = document.getElementById("token");
const loadBtn = document.getElementById("loadBtn");
const authMsg = document.getElementById("authMsg");
const dashboard = document.getElementById("dashboard");
const upcomingLimit = document.getElementById("upcomingLimit");

const planVal = document.getElementById("planVal");
const customersVal = document.getElementById("customersVal");
const measurementsVal = document.getElementById("measurementsVal");
const statuses = document.getElementById("statuses");
const statusBars = document.getElementById("statusBars");
const upcoming = document.getElementById("upcoming");
const plansGrid = document.getElementById("plansGrid");

let currentToken = "";

loadBtn.addEventListener("click", async () => {
  const token = tokenInput.value.trim();
  if (!token) {
    authMsg.textContent = "Enter a valid token first.";
    return;
  }
  authMsg.textContent = "Loading...";
  try {
    currentToken = token;
    const limit = Number(upcomingLimit.value || 8);
    const res = await fetch(`/oga-tailor/api/admin/dashboard?upcoming_limit=${encodeURIComponent(limit)}`, {
      headers: {
        Authorization: `Bearer ${token}`,
      },
    });
    const data = await res.json();
    if (!res.ok) {
      throw new Error(data.error || "Could not load dashboard");
    }
    render(data);
    await loadPlans();
    dashboard.classList.remove("hidden");
    authMsg.textContent = "Dashboard loaded.";
  } catch (error) {
    authMsg.textContent = error.message || "Dashboard request failed.";
  }
});

function render(data) {
  const summary = data.summary || {};
  planVal.textContent = summary.plan_code || "-";
  customersVal.textContent = String(summary.customers ?? 0);
  measurementsVal.textContent = String(summary.measurements ?? 0);

  statuses.innerHTML = "";
  statusBars.innerHTML = "";
  const list = data.order_statuses || [];
  const max = Math.max(...list.map((r) => Number(r.total || 0)), 1);
  for (const row of list) {
    const li = document.createElement("li");
    li.textContent = `${row.status}: ${row.total}`;
    statuses.appendChild(li);

    const bar = document.createElement("div");
    bar.className = "bar";
    const pct = Math.round((Number(row.total || 0) / max) * 100);
    bar.innerHTML = `
      <span>${escapeHtml(row.status)}</span>
      <span class="bar-fill-wrap"><span class="bar-fill" style="width:${pct}%"></span></span>
      <span>${Number(row.total || 0)}</span>
    `;
    statusBars.appendChild(bar);
  }
  if (!statuses.children.length) {
    statuses.innerHTML = "<li>No orders yet</li>";
    statusBars.innerHTML = "";
  }

  upcoming.innerHTML = "";
  for (const row of data.upcoming_orders || []) {
    const li = document.createElement("li");
    const due = row.due_date ? new Date(row.due_date).toLocaleDateString() : "-";
    li.innerHTML = `<strong>${escapeHtml(row.title || "Order")}</strong> - ${escapeHtml(
      row.customer_name || "-"
    )} <span class="pill">${escapeHtml(row.status || "pending")}</span> (due ${due})`;
    upcoming.appendChild(li);
  }
  if (!upcoming.children.length) {
    upcoming.innerHTML = "<li>No upcoming due orders</li>";
  }
}

async function loadPlans() {
  const res = await fetch("/oga-tailor/api/admin/plans", {
    headers: { Authorization: `Bearer ${currentToken}` },
  });
  const payload = await res.json();
  if (!res.ok) {
    throw new Error(payload.error || "Could not load plan settings");
  }
  renderPlans(payload.data || []);
}

function renderPlans(rows) {
  plansGrid.innerHTML = "";
  for (const row of rows) {
    const card = document.createElement("article");
    card.className = "card";
    card.innerHTML = `
      <h3>${escapeHtml(toTitle(row.plan_code || "plan"))}</h3>
      <div class="plan-form">
        <label>
          Customer limit
          <input data-field="customer_limit" type="number" min="1" placeholder="Unlimited (blank)"
            value="${row.customer_limit == null ? "" : Number(row.customer_limit)}" />
        </label>
        ${check("Cloud sync", "can_sync", row.can_sync)}
        ${check("Export", "can_export", row.can_export)}
        ${check("Multi-device", "can_multi_device", row.can_multi_device)}
        ${check("Advanced reminders", "can_advanced_reminders", row.can_advanced_reminders)}
        <div class="actions">
          <button data-save="${escapeHtml(row.plan_code)}">Save ${escapeHtml(toTitle(row.plan_code))}</button>
        </div>
      </div>
    `;
    plansGrid.appendChild(card);
  }

  plansGrid.querySelectorAll("button[data-save]").forEach((btn) => {
    btn.addEventListener("click", async () => {
      const planCode = btn.getAttribute("data-save");
      const card = btn.closest(".card");
      const limitInput = card.querySelector('input[data-field="customer_limit"]');
      const payload = {
        plan_code: planCode,
        customer_limit: limitInput.value.trim() === "" ? null : Number(limitInput.value),
      };
      [
        "can_sync",
        "can_export",
        "can_multi_device",
        "can_advanced_reminders",
      ].forEach((name) => {
        const el = card.querySelector(`input[data-field="${name}"]`);
        payload[name] = Boolean(el.checked);
      });
      try {
        btn.disabled = true;
        btn.textContent = "Saving...";
        const res = await fetch("/oga-tailor/api/admin/plans", {
          method: "PATCH",
          headers: {
            Authorization: `Bearer ${currentToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify(payload),
        });
        const data = await res.json();
        if (!res.ok) throw new Error(data.error || "Update failed");
        btn.textContent = "Saved";
        setTimeout(() => {
          btn.textContent = `Save ${toTitle(planCode)}`;
          btn.disabled = false;
        }, 700);
      } catch (error) {
        btn.disabled = false;
        btn.textContent = `Save ${toTitle(planCode)}`;
        authMsg.textContent = error.message || "Failed to update plan settings.";
      }
    });
  });
}

function check(label, field, value) {
  return `<label>${escapeHtml(label)} <input data-field="${field}" type="checkbox" ${Number(value) === 1 ? "checked" : ""} /></label>`;
}

function toTitle(value) {
  return String(value || "")
    .replaceAll("_", " ")
    .replace(/\b\w/g, (m) => m.toUpperCase());
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}
