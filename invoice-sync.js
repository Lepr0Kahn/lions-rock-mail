/* Lions Rock Documents V2 — Supabase cross-device sync */
(function () {
  "use strict";

  var SUPABASE_URL = "https://xsvczfqvscnvmngwcmtp.supabase.co";
  var SUPABASE_PUBLISHABLE_KEY = "sb_publishable_ZQGFWpZzlDsWBRclrySAyg_CYWqvU40";
  var DELETE_QUEUE_KEY = "lions_rock_cloud_delete_queue_v1";
  var INITIALIZED_PREFIX = "lions_rock_cloud_initialized_";
  var LAST_SYNC_KEY = "lions_rock_cloud_last_sync";
  var USER_STORE_PREFIX = "lions_rock_business_v2_user_";
  var ACTIVE_LOCAL_USER_KEY = "lions_rock_active_local_user";

  var sb = null;
  var cloudUser = null;
  var cloudBusy = false;
  var cloudApplying = false;
  var syncTimer = null;
  var syncInterval = null;
  var hadLocalAtLoad = false;
  var originalSaveStore = null;

  function byId(id) { return document.getElementById(id); }
  function nowIso() { return new Date().toISOString(); }
  function parseJson(s, fallback) { try { var value = JSON.parse(s); return value == null ? fallback : value; } catch (_) { return fallback; } }
  function asTime(v) { var n = Date.parse(v || ""); return isFinite(n) ? n : 0; }
  function cloneCloud(v) { return JSON.parse(JSON.stringify(v)); }
  function deleteQueueKey() { return DELETE_QUEUE_KEY + "_" + (cloudUser ? cloudUser.id : "anon"); }
  function userStoreKey(uid) { return USER_STORE_PREFIX + String(uid || ""); }

  function persistCurrentUserStore() {
    var uid = localStorage.getItem(ACTIVE_LOCAL_USER_KEY);
    if (uid && window.STORE) {
      try { localStorage.setItem(userStoreKey(uid), JSON.stringify(window.STORE)); } catch (_) {}
    }
  }

  function switchLocalStoreForUser(uid) {
    if (!uid || typeof window.migrateStore !== "function") return;
    var mainKey = window.STORE_KEY || "lions_rock_business_v2";
    var activeUid = localStorage.getItem(ACTIVE_LOCAL_USER_KEY);
    var mainRaw = localStorage.getItem(mainKey);

    // First upgrade from the old single-user local store: assign it to the
    // first authenticated account on this browser (the existing owner).
    if (!activeUid && mainRaw) {
      localStorage.setItem(userStoreKey(uid), mainRaw);
      activeUid = uid;
    }

    if (activeUid && activeUid !== uid && mainRaw) {
      localStorage.setItem(userStoreKey(activeUid), mainRaw);
    }

    var incoming = localStorage.getItem(userStoreKey(uid));
    var nextStore;
    if (incoming) {
      nextStore = window.migrateStore(parseJson(incoming, {}));
      hadLocalAtLoad = true;
    } else {
      nextStore = window.migrateStore({});
      hadLocalAtLoad = false;
    }

    cloudApplying = true;
    try {
      window.STORE = nextStore;
      window.SERVICES = window.STORE.services;
      localStorage.setItem(mainKey, JSON.stringify(nextStore));
      localStorage.setItem(ACTIVE_LOCAL_USER_KEY, uid);
    } finally {
      cloudApplying = false;
    }
    refreshAppAfterCloud();
  }

  function setCloudStatus(message, tone) {
    var el = byId("cloud-status");
    var dot = byId("cloud-dot");
    if (el) el.textContent = message;
    if (dot) {
      dot.className = "cloud-dot " + (tone || "");
      dot.title = message;
    }
  }

  function setAuthUi(session) {
    var signedIn = !!(session && session.user);
    var signedOutBox = byId("cloud-auth-fields");
    var signedInBox = byId("cloud-signed-in");
    var userEl = byId("cloud-user");
    if (signedOutBox) signedOutBox.style.display = signedIn ? "none" : "grid";
    if (signedInBox) signedInBox.style.display = signedIn ? "flex" : "none";
    if (userEl) userEl.textContent = signedIn ? session.user.email : "";
    if (!signedIn) setCloudStatus(navigator.onLine ? "Not signed in" : "Offline · local only", "offline");
  }

  function stableSettings(s) {
    var o = Object.assign({}, s || {});
    delete o.updated_at;
    return JSON.stringify(o);
  }

  function stableServices(s) {
    return JSON.stringify(s || []);
  }

  function flattenServices(store) {
    var rows = [];
    (store.services || []).forEach(function (section, si) {
      (section.items || []).forEach(function (item, ii) {
        if (!item.id) item.id = "custom-" + ((typeof uuid === "function") ? uuid().slice(0, 8) : Date.now() + "-" + si + "-" + ii);
        rows.push({
          local_id: String(item.id),
          category: section.section || "Services",
          name: item.name || "Service",
          description: item.desc || "",
          price: Math.max(0, Number(item.price || 0)),
          sort_order: si * 1000 + ii * 10
        });
      });
    });
    return rows;
  }

  function rebuildServices(rows) {
    var groups = [];
    var map = {};
    (rows || []).slice().sort(function (a, b) {
      return Number(a.sort_order || 0) - Number(b.sort_order || 0) || String(a.name || "").localeCompare(String(b.name || ""));
    }).forEach(function (r) {
      var cat = r.category || "Services";
      if (!map[cat]) {
        map[cat] = { section: cat, items: [] };
        groups.push(map[cat]);
      }
      map[cat].items.push({
        id: r.local_id || ("cloud-" + r.id),
        name: r.name || "Service",
        desc: r.description || "",
        price: Number(r.price || 0)
      });
    });
    return groups;
  }

  function queueTombstone(entityType, entityKey) {
    if (!entityKey) return;
    var q = parseJson(localStorage.getItem(deleteQueueKey()), []);
    q = q.filter(function (x) { return !(x.entity_type === entityType && x.entity_key === String(entityKey)); });
    q.push({ entity_type: entityType, entity_key: String(entityKey), deleted_at: nowIso() });
    localStorage.setItem(deleteQueueKey(), JSON.stringify(q));
  }

  function captureDeletes(before, after) {
    if (!before || !after) return;
    var currentDocs = new Set((after.documents || []).map(function (x) { return String(x.id); }));
    (before.documents || []).forEach(function (x) { if (x.id && !currentDocs.has(String(x.id))) queueTombstone("document", x.id); });

    var currentClients = new Set((after.clients || []).map(function (x) { return String(x.id); }));
    (before.clients || []).forEach(function (x) { if (x.id && !currentClients.has(String(x.id))) queueTombstone("client", x.id); });

    var beforeServices = flattenServices(before).map(function (x) { return x.local_id; });
    var afterServices = new Set(flattenServices(after).map(function (x) { return x.local_id; }));
    beforeServices.forEach(function (id) { if (!afterServices.has(id)) queueTombstone("service", id); });
  }

  function installSaveHook() {
    if (typeof window.saveStore !== "function" || originalSaveStore) return;
    originalSaveStore = window.saveStore;
    window.saveStore = function () {
      var before = parseJson(localStorage.getItem(window.STORE_KEY || "lions_rock_business_v2"), null);
      var ts = nowIso();

      if (window.STORE && window.STORE.settings &&
          stableSettings(before && before.settings) !== stableSettings(window.STORE.settings)) {
        window.STORE.settings.updated_at = ts;
      }
      if (window.STORE &&
          stableServices(before && before.services) !== stableServices(window.STORE.services)) {
        window.STORE.services_updated_at = ts;
      }

      originalSaveStore();
      persistCurrentUserStore();
      if (!cloudApplying) {
        captureDeletes(before, window.STORE);
        scheduleSync();
      }
    };
  }

  function refreshAppAfterCloud() {
    try { if (typeof window.buildClientPicker === "function") window.buildClientPicker(); } catch (_) {}
    try { if (typeof window.buildProjectPicker === "function") window.buildProjectPicker(); } catch (_) {}
    try { if (typeof window.buildServicesList === "function") window.buildServicesList(); } catch (_) {}
    try { if (typeof window.renderPreview === "function") window.renderPreview(); } catch (_) {}
    try {
      if (window.state && window.state.view === "history" && typeof window.renderHistory === "function") window.renderHistory();
      if (window.state && window.state.view === "clients" && typeof window.renderClients === "function") window.renderClients();
      if (window.state && window.state.view === "dashboard" && typeof window.renderDashboard === "function") window.renderDashboard();
      if (window.state && window.state.view === "settings" && typeof window.renderSettings === "function") window.renderSettings();
    } catch (_) {}
  }

  function mergeById(localRows, remoteRows) {
    var map = new Map();
    (localRows || []).forEach(function (r) { if (r && r.id) map.set(String(r.id), cloneCloud(r)); });
    (remoteRows || []).forEach(function (r) {
      if (!r || !r.id) return;
      var key = String(r.id);
      var cur = map.get(key);
      var rt = asTime(r.updated_at || r.created_at);
      var lt = asTime(cur && (cur.updated_at || cur.created_at));
      if (!cur || rt >= lt) map.set(key, cloneCloud(r));
    });
    return Array.from(map.values());
  }

  function applyTombstonesToLocal(store, tombstones) {
    var docIds = new Set(), clientIds = new Set(), serviceIds = new Set();
    (tombstones || []).forEach(function (t) {
      if (t.entity_type === "document") docIds.add(String(t.entity_key));
      else if (t.entity_type === "client") clientIds.add(String(t.entity_key));
      else if (t.entity_type === "service") serviceIds.add(String(t.entity_key));
    });
    store.documents = (store.documents || []).filter(function (d) { return !docIds.has(String(d.id)); });
    store.clients = (store.clients || []).filter(function (c) { return !clientIds.has(String(c.id)); });
    if (serviceIds.size) {
      (store.services || []).forEach(function (sec) {
        sec.items = (sec.items || []).filter(function (it) { return !serviceIds.has(String(it.id)); });
      });
      store.services = (store.services || []).filter(function (sec) { return (sec.items || []).length; });
    }
  }

  function mapRemoteSnapshot(remote) {
    var serviceIdToLocal = {};
    (remote.services || []).forEach(function (s) { serviceIdToLocal[String(s.id)] = s.local_id || null; });

    var itemsByDoc = {};
    (remote.items || []).forEach(function (it) {
      var k = String(it.document_id);
      if (!itemsByDoc[k]) itemsByDoc[k] = [];
      itemsByDoc[k].push({
        service_id: it.service_id ? serviceIdToLocal[String(it.service_id)] : null,
        name: it.name || "",
        desc: it.description || "",
        qty: Number(it.qty || 1),
        price: Number(it.unit_price || 0)
      });
    });

    var clients = (remote.clients || []).map(function (c) {
      return {
        id: c.id,
        name: c.name || "",
        email: c.email || "",
        phone: c.phone || "",
        address: c.address || "",
        notes: c.notes || "",
        created_at: c.created_at,
        updated_at: c.updated_at
      };
    });

    var docs = (remote.documents || []).map(function (d) {
      var amountPaid = Number(d.amount_paid || 0);
      var total = Number(d.total || 0);
      var localStatus = (typeof window.getStatusFromNumbers === "function")
        ? window.getStatusFromNumbers(d.doc_type, total, amountPaid, d.due_date)
        : (d.doc_type === "quote" ? "quote" : (amountPaid >= total && total > 0 ? "paid" : amountPaid > 0 ? "partial" : "due"));
      return {
        id: d.id,
        booking_id: d.booking_id || null,
        currency: d.currency || "BBD",
        client_id: d.client_id || null,
        project_id: d.project_id || null,
        project_name: ((remote.projects || []).find(function (p) { return String(p.id) === String(d.project_id || ""); }) || {}).name || "",
        type: d.doc_type,
        paid: localStatus === "paid",
        payment_status: localStatus,
        doc_number: d.doc_number || "",
        doc_date: d.doc_date || "",
        due_date: d.due_date || null,
        client_name: d.client_name || "",
        client_email: d.client_email || "",
        client_phone: d.client_phone || "",
        client_address: d.client_address || "",
        items: itemsByDoc[String(d.id)] || [],
        discount: Number(d.discount || 0),
        tax_pct: Number(d.tax_pct || 0),
        deposit_pct: Number(d.deposit_pct || 0),
        subtotal: Number(d.subtotal || 0),
        tax: Number(d.tax || 0),
        total: total,
        amount_paid: amountPaid,
        payment_date: d.payment_date || (d.paid_at ? String(d.paid_at).slice(0, 10) : null),
        paid_at: d.paid_at || null,
        notes: d.notes || "",
        source_quote_id: d.converted_from_quote_id || null,
        created_at: d.created_at,
        updated_at: d.updated_at
      };
    });

    var projects = (remote.projects || []).map(function (p) {
      return {
        id: p.id,
        client_id: p.client_id || null,
        name: p.name || "",
        project_type: p.project_type || "Project",
        status: p.status || "active",
        description: p.description || "",
        start_date: p.start_date || null,
        due_date: p.due_date || null,
        created_at: p.created_at,
        updated_at: p.updated_at
      };
    });

    var settings = null;
    if (remote.settings) {
      var s = remote.settings;
      settings = {
        business_name: s.business_name || "THE LION'S ROCK MEDIA FACILITY",
        tagline: s.tagline || "ENGINEERED FOR POWER · MIXED FOR IMPACT",
        email: s.business_email || "",
        phone: s.business_phone || "",
        instagram: s.instagram || s.instagram_personal || "",
        currency: s.currency || "BBD",
        default_deposit_pct: Number(s.default_deposit_pct == null ? 50 : s.default_deposit_pct),
        quote_validity_days: Number(s.quote_valid_days == null ? 14 : s.quote_valid_days),
        invoice_due_days: Number(s.invoice_due_days == null ? 14 : s.invoice_due_days),
        updated_at: s.updated_at
      };
    }

    var serviceUpdated = 0;
    (remote.services || []).forEach(function (s) { serviceUpdated = Math.max(serviceUpdated, asTime(s.updated_at)); });

    return {
      clients: clients,
      projects: projects,
      documents: docs,
      services: rebuildServices(remote.services || []),
      services_updated_at: serviceUpdated ? new Date(serviceUpdated).toISOString() : null,
      settings: settings,
      tombstones: remote.tombstones || []
    };
  }

  async function fetchRemote() {
    var uid = cloudUser.id;
    var results = await Promise.all([
      sb.from("clients").select("*").eq("user_id", uid),
      sb.from("projects").select("*").eq("user_id", uid),
      sb.from("documents").select("*").eq("user_id", uid),
      sb.from("document_items").select("*").eq("user_id", uid),
      sb.from("services").select("*").eq("user_id", uid),
      sb.from("business_settings").select("*").eq("user_id", uid).maybeSingle(),
      sb.from("sync_tombstones").select("*").eq("user_id", uid)
    ]);
    for (var i = 0; i < results.length; i++) {
      if (results[i].error) throw results[i].error;
    }
    return {
      clients: results[0].data || [],
      projects: results[1].data || [],
      documents: results[2].data || [],
      items: results[3].data || [],
      services: results[4].data || [],
      settings: results[5].data || null,
      tombstones: results[6].data || []
    };
  }

  function mapSettingsForCloud() {
    var s = window.STORE.settings || {};
    return {
      user_id: cloudUser.id,
      business_name: s.business_name || "THE LION'S ROCK MEDIA FACILITY",
      business_email: s.email || "",
      business_phone: s.phone || "",
      instagram: s.instagram || "",
      instagram_personal: s.instagram || "@yofavengineer",
      currency: s.currency || "BBD",
      default_deposit_pct: Number(s.default_deposit_pct == null ? 50 : s.default_deposit_pct),
      quote_valid_days: Number(s.quote_validity_days == null ? 14 : s.quote_validity_days),
      invoice_due_days: Number(s.invoice_due_days == null ? 14 : s.invoice_due_days),
      tagline: s.tagline || "ENGINEERED FOR POWER · MIXED FOR IMPACT"
    };
  }

  function mapClientsForCloud() {
    var uid = cloudUser.id;
    return (window.STORE.clients || []).filter(function (c) { return c && c.id && c.name; }).map(function (c) {
      return {
        id: c.id,
        user_id: uid,
        name: c.name || "",
        email: c.email || null,
        phone: c.phone || null,
        address: c.address || null,
        notes: c.notes || null,
        created_at: c.created_at || nowIso(),
        updated_at: c.updated_at || c.created_at || nowIso()
      };
    });
  }

  function mapServicesForCloud() {
    var uid = cloudUser.id;
    var cur = (window.STORE.settings && window.STORE.settings.currency) || "BBD";
    return flattenServices(window.STORE).map(function (s) {
      return {
        user_id: uid,
        local_id: s.local_id,
        category: s.category,
        name: s.name,
        description: s.description || null,
        price: s.price,
        currency: cur,
        is_active: true,
        sort_order: s.sort_order
      };
    });
  }

  function cloudDocStatus(d) {
    var st = d.payment_status;
    if (!st && typeof window.getStatusFromNumbers === "function") st = window.getStatusFromNumbers(d.type, d.total, d.amount_paid, d.due_date);
    if (d.type === "quote") return "open";
    if (st === "paid") return "paid";
    if (st === "partial") return "partial";
    if (st === "overdue") return "overdue";
    return "open";
  }

  function mapDocumentsForCloud() {
    var uid = cloudUser.id;
    var cur = (window.STORE.settings && window.STORE.settings.currency) || "BBD";
    return (window.STORE.documents || []).filter(function (d) { return d && d.id && d.doc_number; }).map(function (d) {
      var total = Number(d.total || 0);
      var paid = Number(d.amount_paid != null ? d.amount_paid : (d.paid ? total : 0));
      return {
        id: d.id,
        user_id: uid,
        booking_id: d.booking_id || null,
        client_id: d.client_id || null,
        project_id: d.project_id || null,
        doc_type: d.type === "invoice" ? "invoice" : "quote",
        doc_number: d.doc_number,
        status: cloudDocStatus(d),
        doc_date: d.doc_date || (typeof window.todayISO === "function" ? window.todayISO() : new Date().toISOString().slice(0, 10)),
        due_date: d.due_date || null,
        currency: d.currency || cur,
        discount: Number(d.discount || 0),
        tax_pct: Number(d.tax_pct || 0),
        deposit_pct: Number(d.deposit_pct == null ? 50 : d.deposit_pct),
        subtotal: Number(d.subtotal || 0),
        tax: Number(d.tax || 0),
        total: total,
        amount_paid: paid,
        balance_due: Math.max(0, total - paid),
        payment_date: d.payment_date || null,
        notes: d.notes || null,
        client_name: d.client_name || null,
        client_email: d.client_email || null,
        client_phone: d.client_phone || null,
        client_address: d.client_address || null,
        paid_at: d.paid_at || null,
        converted_from_quote_id: d.source_quote_id || null,
        created_at: d.created_at || nowIso(),
        updated_at: d.updated_at || d.created_at || nowIso()
      };
    });
  }

  function mapItemsForCloud() {
    var uid = cloudUser.id;
    var rows = [];
    (window.STORE.documents || []).forEach(function (d) {
      (d.items || []).forEach(function (it, idx) {
        var qty = Math.max(0.01, Number(it.qty || 1));
        var price = Math.max(0, Number(it.price || 0));
        rows.push({
          document_id: d.id,
          user_id: uid,
          service_id: null,
          name: it.name || "Item",
          description: it.desc || null,
          qty: qty,
          unit_price: price,
          line_total: qty * price,
          sort_order: idx * 10
        });
      });
    });
    return rows;
  }

  function resolveDocumentNumberConflicts(remoteDocs) {
    var used = new Map();
    (remoteDocs || []).forEach(function (d) { if (d.doc_number) used.set(d.doc_number, String(d.id)); });

    function nextFor(prefix) {
      var max = 0;
      Array.from(used.keys()).concat((window.STORE.documents || []).map(function (d) { return d.doc_number || ""; })).forEach(function (n) {
        var m = String(n).match(new RegExp("^" + prefix + "-(\\\\d+)$"));
        if (m) max = Math.max(max, parseInt(m[1], 10));
      });
      var candidate;
      do { max += 1; candidate = prefix + "-" + String(max).padStart(4, "0"); } while (used.has(candidate));
      return candidate;
    }

    var changed = false;
    (window.STORE.documents || []).forEach(function (d) {
      if (!d.doc_number) return;
      var owner = used.get(d.doc_number);
      if (owner && owner !== String(d.id)) {
        var prefix = d.type === "quote" ? "QUO" : ((d.payment_status === "paid" || d.paid) ? "RCP" : "INV");
        d.doc_number = nextFor(prefix);
        d.updated_at = nowIso();
        changed = true;
      }
      used.set(d.doc_number, String(d.id));
    });
    if (changed && originalSaveStore) {
      cloudApplying = true;
      try { originalSaveStore(); } finally { cloudApplying = false; }
      if (typeof window.toast === "function") window.toast("A document number conflict was resolved for cloud sync");
    }
  }

  async function upsertInChunks(table, rows, options) {
    if (!rows.length) return;
    for (var i = 0; i < rows.length; i += 100) {
      var res = await sb.from(table).upsert(rows.slice(i, i + 100), options || {});
      if (res.error) throw res.error;
    }
  }

  async function pushLocal(remoteForConflicts) {
    resolveDocumentNumberConflicts((remoteForConflicts && remoteForConflicts.documents) || []);

    var settingsRes = await sb.from("business_settings").upsert(mapSettingsForCloud(), { onConflict: "user_id" });
    if (settingsRes.error) throw settingsRes.error;

    await upsertInChunks("clients", mapClientsForCloud(), { onConflict: "id" });
    await upsertInChunks("services", mapServicesForCloud(), { onConflict: "user_id,local_id" });
    await upsertInChunks("documents", mapDocumentsForCloud(), { onConflict: "id" });

    var docIds = (window.STORE.documents || []).map(function (d) { return d.id; }).filter(Boolean);
    for (var i = 0; i < docIds.length; i += 100) {
      var del = await sb.from("document_items").delete().in("document_id", docIds.slice(i, i + 100));
      if (del.error) throw del.error;
    }
    await upsertInChunks("document_items", mapItemsForCloud());
  }

  async function flushDeleteQueue() {
    var q = parseJson(localStorage.getItem(deleteQueueKey()), []);
    if (!q.length) return;
    var rows = q.map(function (x) {
      return { user_id: cloudUser.id, entity_type: x.entity_type, entity_key: String(x.entity_key), deleted_at: x.deleted_at || nowIso() };
    });
    var t = await sb.from("sync_tombstones").upsert(rows, { onConflict: "user_id,entity_type,entity_key" });
    if (t.error) throw t.error;

    for (var i = 0; i < q.length; i++) {
      var x = q[i], res;
      if (x.entity_type === "document") res = await sb.from("documents").delete().eq("id", x.entity_key);
      else if (x.entity_type === "client") res = await sb.from("clients").delete().eq("id", x.entity_key);
      else if (x.entity_type === "service") res = await sb.from("services").delete().eq("local_id", x.entity_key);
      if (res && res.error) throw res.error;
    }
    localStorage.removeItem(deleteQueueKey());
  }

  function mergeRemoteIntoLocal(mapped) {
    var merged = cloneCloud(window.STORE || {});
    applyTombstonesToLocal(merged, mapped.tombstones);

    var remoteClientKeys = new Set((mapped.tombstones || []).filter(function (t) { return t.entity_type === "client"; }).map(function (t) { return String(t.entity_key); }));
    var remoteDocKeys = new Set((mapped.tombstones || []).filter(function (t) { return t.entity_type === "document"; }).map(function (t) { return String(t.entity_key); }));

    var localClients = (merged.clients || []).filter(function (c) { return !remoteClientKeys.has(String(c.id)); });
    var localDocs = (merged.documents || []).filter(function (d) { return !remoteDocKeys.has(String(d.id)); });

    merged.clients = mergeById(localClients, mapped.clients);
    merged.projects = mapped.projects || [];
    merged.documents = mergeById(localDocs, mapped.documents);

    var localSettingsTime = asTime(merged.settings && merged.settings.updated_at);
    var remoteSettingsTime = asTime(mapped.settings && mapped.settings.updated_at);
    if (mapped.settings && remoteSettingsTime >= localSettingsTime) merged.settings = mapped.settings;

    var localServicesTime = asTime(merged.services_updated_at);
    var remoteServicesTime = asTime(mapped.services_updated_at);
    if (mapped.services && mapped.services.length && remoteServicesTime >= localServicesTime) {
      merged.services = mapped.services;
      merged.services_updated_at = mapped.services_updated_at;
    }

    merged.version = Math.max(2, Number(merged.version || 2));

    cloudApplying = true;
    try {
      window.STORE = merged;
      window.SERVICES = window.STORE.services;
      originalSaveStore();
      persistCurrentUserStore();
    } finally {
      cloudApplying = false;
    }
    refreshAppAfterCloud();
  }

  async function syncAll(reason) {
    if (!cloudUser || !sb || cloudBusy) return;
    if (!navigator.onLine) {
      setCloudStatus("Offline · changes saved locally", "offline");
      return;
    }
    cloudBusy = true;
    setCloudStatus(reason === "manual" ? "Syncing now…" : "Syncing…", "syncing");
    var syncButton = byId("cloud-sync");
    if (syncButton) syncButton.disabled = true;

    try {
      await flushDeleteQueue();

      var initKey = INITIALIZED_PREFIX + cloudUser.id;
      var initialized = localStorage.getItem(initKey) === "1";
      var remote = await fetchRemote();

      if (!initialized && hadLocalAtLoad) {
        setCloudStatus("Uploading this device’s V2 data…", "syncing");
        await pushLocal(remote);
        remote = await fetchRemote();
      }

      var mapped = mapRemoteSnapshot(remote);
      mergeRemoteIntoLocal(mapped);

      await pushLocal(remote);
      remote = await fetchRemote();
      mapped = mapRemoteSnapshot(remote);
      mergeRemoteIntoLocal(mapped);

      localStorage.setItem(initKey, "1");
      localStorage.setItem(LAST_SYNC_KEY, nowIso());
      hadLocalAtLoad = true;
      setCloudStatus("Synced · " + new Date().toLocaleTimeString([], { hour: "numeric", minute: "2-digit" }), "online");
    } catch (err) {
      console.error("Lions Rock cloud sync:", err);
      setCloudStatus("Sync error · local copy is safe", "error");
      if (typeof window.toast === "function") window.toast("Cloud sync failed: " + (err.message || err), true);
    } finally {
      cloudBusy = false;
      if (syncButton) syncButton.disabled = false;
    }
  }

  function scheduleSync() {
    if (!cloudUser || cloudApplying) return;
    clearTimeout(syncTimer);
    syncTimer = setTimeout(function () { syncAll("auto"); }, 1200);
  }

  async function handleSession(session) {
    var nextUser = session && session.user ? session.user : null;
    if (!nextUser) {
      persistCurrentUserStore();
      cloudUser = null;
      setAuthUi(session);
      if (syncInterval) clearInterval(syncInterval);
      syncInterval = null;
      return;
    }

    cloudUser = nextUser;
    switchLocalStoreForUser(cloudUser.id);
    setAuthUi(session);
    setCloudStatus(navigator.onLine ? "Signed in · preparing sync…" : "Signed in · offline", navigator.onLine ? "syncing" : "offline");
    await syncAll("login");
    if (syncInterval) clearInterval(syncInterval);
    syncInterval = setInterval(function () { syncAll("auto"); }, 45000);
  }

  async function signIn() {
    var email = (byId("cloud-email") && byId("cloud-email").value || "").trim();
    var password = (byId("cloud-password") && byId("cloud-password").value || "");
    if (!email || !password) {
      if (typeof window.toast === "function") window.toast("Enter your email and password", true);
      return;
    }
    setCloudStatus("Signing in…", "syncing");
    var res = await sb.auth.signInWithPassword({ email: email, password: password });
    if (res.error) {
      setCloudStatus("Sign-in failed", "error");
      if (typeof window.toast === "function") window.toast(res.error.message, true);
    }
  }

  async function signUp() {
    setCloudStatus("Access is by approved invitation only", "offline");
    if (typeof window.toast === "function") window.toast("Apply for access from the Lions Rock Studio sign-in page.", true);
  }

  async function signOut() {
    await sb.auth.signOut();
    cloudUser = null;
    setAuthUi(null);
  }

  function wireUi() {
    var signInBtn = byId("cloud-signin");
    var signUpBtn = byId("cloud-signup");
    var signOutBtn = byId("cloud-signout");
    var syncBtn = byId("cloud-sync");
    if (signInBtn) signInBtn.addEventListener("click", signIn);
    if (signUpBtn) signUpBtn.addEventListener("click", signUp);
    if (signOutBtn) signOutBtn.addEventListener("click", signOut);
    if (syncBtn) syncBtn.addEventListener("click", function () { syncAll("manual"); });

    ["cloud-email", "cloud-password"].forEach(function (id) {
      var el = byId(id);
      if (el) el.addEventListener("keydown", function (e) { if (e.key === "Enter") signIn(); });
    });

    window.addEventListener("online", function () { setCloudStatus(cloudUser ? "Back online · syncing…" : "Online · not signed in", cloudUser ? "syncing" : ""); syncAll("online"); });
    window.addEventListener("offline", function () { setCloudStatus("Offline · changes saved locally", "offline"); });
    window.addEventListener("focus", function () { syncAll("focus"); });
  }

  async function initCloud() {
    hadLocalAtLoad = !!localStorage.getItem(window.STORE_KEY || "lions_rock_business_v2") ||
                     !!localStorage.getItem(window.OLD_STORE_KEY || "lions_den_studio_v1");
    installSaveHook();

    if (!window.supabase || !window.supabase.createClient) {
      setCloudStatus("Cloud library failed to load · local mode", "error");
      return;
    }

    sb = window.supabase.createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, {
      auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true }
    });

    wireUi();

    var sessionRes = await sb.auth.getSession();
    if (sessionRes.error) console.warn(sessionRes.error);
    await handleSession(sessionRes.data && sessionRes.data.session);

    sb.auth.onAuthStateChange(function (_event, session) {
      setTimeout(function () { handleSession(session); }, 0);
    });
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", initCloud);
  else initCloud();
})();