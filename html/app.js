function postNUI(action, payload) {
  try {
    var xhr = new XMLHttpRequest();
    xhr.open('POST', 'https://' + GetParentResourceName() + '/' + action, true);
    xhr.setRequestHeader('Content-Type', 'application/json; charset=UTF-8');
    xhr.send(JSON.stringify(payload || {}));
  } catch (e) {
    console.warn('[NUI] post failed:', action, e);
  }
}

var state = {
  currentMenu: [],
  currentRestaurant: null,
  isUIOpen: false,
  restaurantData: {},
  selectedIngredients: [],
  currentRecipes: [],
  shopPrices: {},
  tabAccess: {},
  editingId: null,
  saving: false,
  basket: [],
  staff: []
};

var foodEmojis = {
  pasta: '🍝', steak: '🥩', soup: '🍲', pizza: '🍕', burger: '🍔', salad: '🥗', sandwich: '🥪',
  fish: '🐟', chicken: '🍗', rice: '🍚', noodles: '🍜', bread: '🍞', cake: '🍰', cookie: '🍪', "default": '🍽️'
};
function getFoodEmoji(name) {
  name = (name || '').toLowerCase();
  for (var k in foodEmojis) {
    if (name.indexOf(k) !== -1) return foodEmojis[k];
  }
  return foodEmojis["default"];
}

function mapTextToTab(label) {
  var t = String(label || '').toLowerCase();
  if (t.indexOf('ingredient') !== -1) return 'shop';
  if (t.indexOf('customer') !== -1) return 'menu';
  if (t.indexOf('recipe') !== -1) return 'recipes';
  if (t.indexOf('staff') !== -1) return 'staff';
  if (['shop','menu','recipes','staff'].indexOf(t.trim()) !== -1) return t.trim();
  return null;
}
function getTabNameFromButton(btn) {
  if (!btn) return null;
  if (btn.dataset && btn.dataset.tab) return btn.dataset.tab;
  var oc = btn.getAttribute('onclick') || '';
  var m = oc.match(/switchTab\(['"]([^'"]+)['"]\)/);
  if (m) return m[1];
  return mapTextToTab(btn.textContent);
}
function activateTab(name) {
  if (!name) return;
  var buttons = document.querySelectorAll('.nav-tabs .nav-tab, .nav-tabs button');
  for (var i=0;i<buttons.length;i++) {
    var b = buttons[i];
    var n = getTabNameFromButton(b);
    if (n === name) b.classList.add('active'); else b.classList.remove('active');
  }
  var panels = document.querySelectorAll('.tab-panel');
  for (var j=0;j<panels.length;j++) {
    var p = panels[j];
    var show = (p.id === (name + '-tab'));
    if (show) { p.classList.add('active'); p.style.display = 'block'; }
    else { p.classList.remove('active'); p.style.display = 'none'; }
  }
  var recipesList = document.getElementById('recipesList');
  if (recipesList) recipesList.style.display = (name === 'recipes') ? 'block' : 'none';

  if (name === 'shop') renderShop();
  else if (name === 'menu') renderCustomerMenu();
  else if (name === 'recipes') renderRecipes();
  else if (name === 'staff') { requestStaff(); renderStaffInfo(); postNUI('getClockins', { restaurant: state.currentRestaurant }); }
}
function switchTab(name){ activateTab(name); }
window.switchTab = switchTab;

document.addEventListener('click', function (e) {
  var staffList = document.getElementById('staffList');
  var actBtn = e.target.closest('[data-action][data-cid]');
  if (actBtn && staffList && staffList.contains(actBtn)) {
    var action = actBtn.getAttribute('data-action');
    var cid = actBtn.getAttribute('data-cid');

    if (action === 'remove') {
      showConfirmModal({
        title: 'Remove Employee',
        message: 'Are you sure you want to remove this employee?',
        onConfirm: function () {
          postNUI('staffAction', {
            restaurant: state.currentRestaurant,
            action: action,
            cid: cid
          });
        }
      });
    } else {
      postNUI('staffAction', {
        restaurant: state.currentRestaurant,
        action: action,
        cid: cid
      });
    }
    return;
  }

  var tabBtn = e.target.closest('.nav-tab, .nav-tabs button');
  if (tabBtn) {
    var name = getTabNameFromButton(tabBtn);
    if (name) {
      e.preventDefault();
      activateTab(name);
    }
    return;
  }
});

document.addEventListener('DOMContentLoaded', function(){
  var activeBtn = document.querySelector('.nav-tab.active, .nav-tabs button.active');
  var initial = activeBtn ? getTabNameFromButton(activeBtn) : 'shop';
  var anyVisible = (function(){
    var list = document.querySelectorAll('.tab-panel');
    for (var i=0;i<list.length;i++){
      var p = list[i];
      if (p.style.display === 'block' || p.classList.contains('active')) return true;
    }
    return false;
  })();
  if (!anyVisible) activateTab(initial || 'shop');
});

function basketFindIndex(itemName, price) {
  for (var i=0;i<state.basket.length;i++){
    var it = state.basket[i];
    if (it.itemName === itemName && Number(it.price) === Number(price)) return i;
  }
  return -1;
}
function basketAdd(itemName, price, qty) {
  qty = Math.max(1, parseInt(qty || 1, 10));
  var idx = basketFindIndex(itemName, price);
  if (idx === -1) state.basket.push({ itemName: itemName, price: Number(price||0), qty: qty });
  else state.basket[idx].qty += qty;
  renderBasket();
  toggleBasket(true);
}
function basketRemoveAt(idx) {
  if (idx >=0) state.basket.splice(idx,1);
  renderBasket();
}
function basketSetQty(idx, qty) {
  qty = Math.max(1, parseInt(qty || 1, 10));
  if (state.basket[idx]) state.basket[idx].qty = qty;
  renderBasket();
}
function basketTotal() {
  var t = 0;
  for (var i=0;i<state.basket.length;i++){
    t += state.basket[i].price * state.basket[i].qty;
  }
  return t;
}
function updateBasketBadge() {
  var count = 0;
  for (var i=0;i<state.basket.length;i++) count += state.basket[i].qty;
  var fab = document.getElementById('basketFab');
  var span = document.getElementById('basketCount');
  if (span) span.textContent = String(count);
  if (fab) fab.style.display = count > 0 ? 'block' : 'none';
}
function renderBasket() {
  var itemsDiv = document.getElementById('basketItems');
  var totalEl = document.getElementById('basketTotal');
  if (!itemsDiv || !totalEl) return;

  if (!state.basket.length) {
    itemsDiv.innerHTML = '<div class="muted">Your basket is empty.</div>';
  } else {
    var html = '';
    for (var i=0;i<state.basket.length;i++){
      var it = state.basket[i];
      html += ''
        + '<div class="basket-item" data-idx="' + i + '">'
        + '  <div class="basket-item-name">' + it.itemName.replace(/_/g,' ') + '</div>'
        + '  <div class="basket-item-qty">'
        + '    <span>$' + Number(it.price).toLocaleString() + ' ×</span>'
        + '    <input type="number" min="1" value="' + it.qty + '" class="basket-qty-input" />'
        + '  </div>'
        + '  <button class="basket-item-remove">Remove</button>'
        + '</div>';
    }
    itemsDiv.innerHTML = html;
  }

  totalEl.textContent = '$' + basketTotal().toLocaleString();
  updateBasketBadge();
}
function toggleBasket(open) {
  var panel = document.getElementById('basketPanel');
  if (!panel) return;
  if (typeof open === 'boolean') panel.style.display = open ? 'flex' : 'none';
  else panel.style.display = (panel.style.display === 'none' || !panel.style.display) ? 'flex' : 'none';
}

function clearBasket() {
  state.basket = [];
  renderBasket();
  var fab = document.getElementById('basketFab');
  var badge = document.getElementById('basketCount');
  var panel = document.getElementById('basketPanel');
  if (fab) fab.style.display = 'none';
  if (badge) badge.textContent = '0';
  if (panel) panel.style.display = 'none';
}

function renderShop() {
  var grid = document.getElementById('shopGrid');
  if (!grid) return;

  var sp = state.shopPrices || {};
  var html = '';
  for (var itemName in sp) {
    var entry = sp[itemName];
    var price = (entry && typeof entry === 'object') ? (entry.price || 0) : entry;
    html += ''
      + '<div class="shop-item">'
      + '  <div>'
      + '    <div class="shop-item-name">' + itemName.replace(/_/g,' ') + '</div>'
      + '    <div class="shop-item-price">$' + Number(price || 0).toLocaleString() + '</div>'
      + '    <div class="shop-qty">'
      + '      <input type="number" min="1" value="1" class="shop-qty-input" />'
      + '      <button class="btn btn-secondary shop-add" data-item="' + itemName + '" data-price="' + price + '">Add to Basket</button>'
      + '    </div>'
      + '  </div>'
      + '</div>';
  }
  grid.innerHTML = html || '<div class="muted">No shop items available.</div>';

  var rows = grid.querySelectorAll('.shop-item');
  for (var i=0;i<rows.length;i++){
    (function(row){
      var qtyInput = row.querySelector('.shop-qty-input');
      var addBtn   = row.querySelector('.shop-add');
      if (!addBtn) return;
      var itemName = addBtn.getAttribute('data-item');
      var price    = Number(addBtn.getAttribute('data-price') || 0);

      addBtn.onclick = function(){
        var qty = qtyInput ? qtyInput.value : 1;
        basketAdd(itemName, price, qty);
      };
    })(rows[i]);
  }
}

function showPaymentModal(onChoice) {
  var overlay = document.createElement('div');
  overlay.className = 'modal-overlay';
  overlay.innerHTML =
    '<div class="modal">'
  + '  <h3>Choose Payment</h3>'
  + '  <p>Select how you want to pay for these items.</p>'
  + '  <div class="modal-buttons">'
  + '    <button id="payCompany" class="btn btn-secondary">Company Account</button>'
  + '    <button id="payPersonal" class="btn btn-primary">My Card</button>'
  + '  </div>'
  + '</div>';
  document.body.appendChild(overlay);

  document.getElementById('payCompany').onclick = function(){
    try { onChoice && onChoice('company'); } finally { overlay.remove(); }
  };
  document.getElementById('payPersonal').onclick = function(){
    try { onChoice && onChoice('personal'); } finally { overlay.remove(); }
  };
}

function checkoutBasket() {
  if (!state.basket.length) return;
  showPaymentModal(function(method){
    var items = state.basket.map(function(it){
      return { itemName: it.itemName, price: it.price, qty: it.qty };
    });
    postNUI('checkoutBasket', {
      restaurant: state.currentRestaurant,
      items: items,
      payment: method
    });
  });
}

function renderCustomerMenu() {
  var container = document.getElementById('customerMenu');
  if (!container) return;
  if (!state.currentMenu || !state.currentMenu.length) {
    container.innerHTML = '<p class="muted">No menu items available</p>';
    return;
  }
  var html = '';
  for (var i=0;i<state.currentMenu.length;i++){
    var item = state.currentMenu[i] || {};
    html += ''
      + '<div class="customer-menu-item">'
      + '  <div class="menu-item-details">'
      + '    <div class="menu-item-name">' + getFoodEmoji(item.name) + ' ' + (item.name || '') + '</div>'
      + '    <div class="menu-item-description">' + (item.description || ('Delicious ' + String(item.name||'').toLowerCase())) + '</div>'
      + '  </div>'
      + '  <div class="menu-item-price">$' + Number(item.price || 0).toLocaleString() + '</div>'
      + '</div>';
  }
  container.innerHTML = html;
}

function renderStaffInfo() {
  var staffList = document.getElementById('staffList');
  if (!staffList) return;
  staffList.innerHTML = ''
    + '<div class="staff-member"><div class="staff-info">'
    + '<div class="staff-name">John Doe (#1234)</div>'
    + '<div class="staff-status">Online - Head Chef</div>'
    + '</div></div>'
    + '<div class="staff-member"><div class="staff-info">'
    + '<div class="staff-name">Jane Smith (#5678)</div>'
    + '<div class="staff-status offline">Offline - Server</div>'
    + '</div></div>';
}

function setFormTitle(text) {
  var el = document.getElementById('recipeFormTitle');
  if (el) el.textContent = text;
}
function populateIngredientDropdown() {
  var select = document.getElementById('ingredientSelect');
  if (!select) return;
  var sp = state.shopPrices || {};
  var html = '<option value="">Select ingredient...</option>';
  for (var k in sp) {
    html += '<option value="' + k + '">' + k.replace(/_/g,' ') + '</option>';
  }
  select.innerHTML = html;
}
function updateIngredientsDisplay() {
  var c = document.getElementById('ingredientsList');
  if (!c) return;
  var html = '';
  for (var i=0;i<state.selectedIngredients.length;i++){
    var ing = state.selectedIngredients[i];
    html += ''
      + '<span class="tag">'
      + ing.replace(/_/g,' ')
      + ' <button type="button" data-remove="' + ing + '">&times;</button>'
      + '</span>';
  }
  c.innerHTML = html;
  var xs = c.querySelectorAll('[data-remove]');
  for (var j=0;j<xs.length;j++){
    xs[j].onclick = function(){
      var v = this.getAttribute('data-remove');
      state.selectedIngredients = state.selectedIngredients.filter(function(x){ return x !== v; });
      updateIngredientsDisplay();
    };
  }
}
function showCreateRecipeForm() {
  state.editingId = null;
  setFormTitle('Create New Recipe');
  var form = document.getElementById('createRecipeForm');
  if (form) form.style.display = 'block';
  document.getElementById('recipeName').value = '';
  document.getElementById('recipeType').value = 'food';
  document.getElementById('cookTime').value = '10';
  document.getElementById('recipeDescription').value = '';
  state.selectedIngredients = [];
  updateIngredientsDisplay();
}
function cancelRecipeForm() {
  state.editingId = null;
  setFormTitle('Create New Recipe');
  var form = document.getElementById('createRecipeForm');
  if (form) form.style.display = 'none';
  document.getElementById('recipeName').value = '';
  document.getElementById('recipeType').value = 'food';
  document.getElementById('cookTime').value = '10';
  document.getElementById('recipeDescription').value = '';
  state.selectedIngredients = [];
  updateIngredientsDisplay();
}
function startEditRecipe(recipe) {
  if (!recipe) return;
  setFormTitle('Edit Recipe');
  var form = document.getElementById('createRecipeForm');
  if (form) form.style.display = 'block';
  document.getElementById('recipeName').value = recipe.name || '';
  document.getElementById('recipeType').value = recipe.type || 'food';
  var ct = Math.round((recipe.cook_time || recipe.cookTime || 0) / 1000);
  document.getElementById('cookTime').value = String(ct || 10);
  document.getElementById('recipeDescription').value = recipe.description || '';
  try {
    var arr = Array.isArray(recipe.ingredients) ? recipe.ingredients : JSON.parse(recipe.ingredients || '[]');
    state.selectedIngredients = arr || [];
  } catch (e) {
    state.selectedIngredients = [];
  }
  updateIngredientsDisplay();
  state.editingId = Number(recipe.id);
}
function saveRecipe() {
  if (state.saving) return;
  state.saving = true;
  var saveBtn = document.getElementById('saveRecipeBtn');
  if (saveBtn) saveBtn.disabled = true;
  var name = document.getElementById('recipeName').value.trim();
  var type = document.getElementById('recipeType').value;
  var cookTime = Math.max(1, parseInt(document.getElementById('cookTime').value, 10)) * 1000;
  var description = document.getElementById('recipeDescription').value.trim();
  if (!name || !state.selectedIngredients.length) {
    alert('Please fill in recipe name and add at least one ingredient');
    if (saveBtn) saveBtn.disabled = false;
    state.saving = false;
    return;
  }
  if (state.editingId) {
    postNUI('updateRecipe', {
      id: state.editingId,
      restaurant: state.currentRestaurant,
      name: name,
      type: type,
      ingredients: state.selectedIngredients,
      cookTime: cookTime,
      description: description
    });
  } else {
    postNUI('createRecipe', {
      restaurant: state.currentRestaurant,
      name: name,
      type: type,
      ingredients: state.selectedIngredients,
      cookTime: cookTime,
      description: description
    });
  }
  setTimeout(function(){
    postNUI('getRecipes', { restaurant: state.currentRestaurant });
    postNUI('requestFullMenu', { restaurant: state.currentRestaurant });
    if (saveBtn) saveBtn.disabled = false;
    state.saving = false;
  }, 150);
  state.editingId = null;
  cancelRecipeForm();
}
function loadRecipes(){ postNUI('getRecipes', { restaurant: state.currentRestaurant }); }
function showConfirmModal(opts) {
  var overlay = document.createElement('div');
  overlay.className = 'modal-overlay';
  overlay.innerHTML =
    '<div class="modal">'
  + '  <h3>' + (opts.title || 'Confirm') + '</h3>'
  + '  <p>' + (opts.message || '') + '</p>'
  + '  <div class="modal-buttons">'
  + '    <button id="modalConfirmYes" class="btn btn-primary">Yes</button>'
  + '    <button id="modalConfirmNo" class="btn btn-secondary">Cancel</button>'
  + '  </div>'
  + '</div>';
  document.body.appendChild(overlay);
  var yes = document.getElementById('modalConfirmYes');
  var no  = document.getElementById('modalConfirmNo');
  var cleanup = function(){ try { overlay.remove(); } catch(e){} };
  yes.onclick = function(){ try { if (typeof opts.onConfirm === 'function') opts.onConfirm(); } finally { cleanup(); } };
  no.onclick = cleanup;
}
function deleteRecipe(recipeId) {
  showConfirmModal({
    title: 'Delete Recipe',
    message: 'Are you sure you want to delete this recipe?',
    onConfirm: function(){
      postNUI('deleteRecipe', { recipeId: recipeId });
      setTimeout(function(){
        postNUI('getRecipes', { restaurant: state.currentRestaurant });
        postNUI('requestFullMenu', { restaurant: state.currentRestaurant });
      }, 100);
    }
  });
}
function displayRecipes(recipes) {
  state.currentRecipes = recipes || [];
  var container = document.getElementById('recipesList');
  if (!container) return;
  var html = '';
  for (var i=0;i<state.currentRecipes.length;i++){
    var r = state.currentRecipes[i];
    var ingredientsText = '';
    try {
      var arr = Array.isArray(r.ingredients) ? r.ingredients : JSON.parse(r.ingredients || '[]');
      ingredientsText = (arr || []).join(', ').replace(/_/g,' ');
    } catch (e) { ingredientsText = 'Invalid ingredients'; }
    var ct = Math.round((r.cook_time || r.cookTime || 0) / 1000);
    html += ''
      + '<div class="card" style="margin-bottom:12px;">'
      + '  <div class="card-body" style="display:flex;justify-content:space-between;align-items:start;gap:12px;">'
      + '    <div>'
      + '      <h4 style="color:#fff;margin:0 0 4px 0;">' + r.name + ' (' + r.type + ')</h4>'
      + '      <p class="muted" style="font-size:12px;margin:0 0 8px 0;">' + (r.description || 'No description') + '</p>'
      + '      <p style="color:#4a9eff;font-size:12px;margin:0;">Ingredients: ' + ingredientsText + '</p>'
      + '      <p style="color:#10b981;font-size:12px;margin:4px 0 0 0;">Cook Time: ' + ct + 's</p>'
      + '    </div>'
      + '    <div style="display:flex;gap:8px;">'
      + '      <button class="btn btn-secondary" data-edit="' + Number(r.id) + '">Edit</button>'
      + '      <button class="btn btn-primary" style="background:#ef4444" data-del="' + Number(r.id) + '">Delete</button>'
      + '    </div>'
      + '  </div>'
      + '</div>';
  }
  if (!html) html = '<p class="muted">No custom recipes found. Create your first recipe above!</p>';
  container.innerHTML = html;
}
function renderRecipes(){ populateIngredientDropdown(); loadRecipes(); }

function requestStaff() {
  postNUI('getStaff', { restaurant: state.currentRestaurant });
}

function formatGrade(grade) {
  var g = Number(grade || 0);
  return 'G' + g;
}

function renderStaffInfo() {
  var list = document.getElementById('staffList');
  if (!list) return;

  var q = (document.getElementById('staffSearch')?.value || '').toLowerCase().trim();
  var dutyFilter = (document.getElementById('staffFilterDuty')?.value || 'all');
  var gradeFilter = (document.getElementById('staffFilterGrade')?.value || 'all');

  var rows = (state.staff || []).filter(function(u){
    var matchQ = true;
    if (q) {
      matchQ = (String(u.name||'').toLowerCase().includes(q) || String(u.cid||'').includes(q));
    }
    var matchDuty = (dutyFilter === 'all') || (dutyFilter === 'on' ? u.duty === true : u.duty === false);
    var matchGrade = (gradeFilter === 'all') || (String(u.grade) === gradeFilter);
    return matchQ && matchDuty && matchGrade;
  });

  if (!rows.length) {
    list.innerHTML = '<div class="staff-row"><div class="muted">No staff found</div><div></div><div></div><div></div><div></div></div>';
    return;
  }

  var html = '';
  rows.forEach(function(u){
    html += ''
      + '<div class="staff-row" data-cid="' + (u.cid || '') + '">'
      + '  <div><strong>' + (u.name || ('CID ' + u.cid)) + '</strong><div class="muted">#' + (u.cid || '-') + '</div></div>'
      + '  <div><span class="badge badge-gray">' + formatGrade(u.grade) + '</span></div>'
      + '  <div>'
      + '    <span class="status-dot ' + (u.duty ? 'dot-on' : 'dot-off') + '"></span> '
      + '    <span class="muted">' + (u.duty ? 'On Duty' : 'Off Duty') + '</span>'
      + '  </div>'
      + '  <div>' + (u.role || 'Employee') + '</div>'
      + '  <div class="staff-actions">'
      + '    <button class="btn btn-secondary" data-action="toggleDuty" data-cid="' + u.cid + '">' + (u.duty ? 'Set Off' : 'Set On') + '</button>'
      + '    <button class="btn btn-secondary" data-action="promote" data-cid="' + u.cid + '">Promote</button>'
      + '    <button class="btn btn-secondary" data-action="demote" data-cid="' + u.cid + '">Demote</button>'
      + '    <button class="btn btn-primary" style="background:#ef4444" data-action="remove" data-cid="' + u.cid + '">Remove</button>'
      + '  </div>'
      + '</div>';
  });
  list.innerHTML = html;
}


function openUI(data) {
  var r = data.restaurant || {};
  var title = document.getElementById('restaurantTitle');
  if (title) title.textContent = (r.name || 'Restaurant') + ' Management';
  state.currentRestaurant = r.name || r.id || null;
  state.restaurantData = r;
  state.currentMenu = r.menu || [];
  state.shopPrices = data.shopPrices || {};
  state.tabAccess = data.tabAccess || {};
  var rev = document.getElementById('totalRevenue'); if (rev) rev.textContent = '$' + (r.revenue || 0);
  var st = document.getElementById('onlineStaff'); if (st) st.textContent = r.staffCount || 0;
  var tabs = document.querySelectorAll('.nav-tab');
  for (var i=0;i<tabs.length;i++){
    var t = tabs[i];
    var name = (t.dataset && t.dataset.tab) || '';
    if (name && state.tabAccess && state.tabAccess[name] === false) t.style.display = 'none';
    else t.style.display = 'block';
  }
  activateTab('shop');
  var cont = document.getElementById('managementContainer');
  if (cont) cont.style.display = 'flex';
  document.body.style.overflow = 'hidden';
  state.isUIOpen = true;
}
function closeUI() {
  var cont = document.getElementById('managementContainer');
  if (cont) cont.style.display = 'none';
  document.body.style.overflow = 'auto';
  state.isUIOpen = false;
  state.currentRestaurant = null;
  clearBasket();
  postNUI('closeUI', {});
}

window.addEventListener('message', function (event) {
  var data = event.data || {};

  if (data.type === 'openManagementUI') {
    openUI(data);

  } else if (data.type === 'closeManagementUI') {
    closeUI();

  } else if (data.type === 'updateStats') {
    if (typeof data.revenue !== 'undefined') {
      var el1 = document.getElementById('totalRevenue');
      if (el1) el1.textContent = '$' + data.revenue;
    }
    if (typeof data.staffCount !== 'undefined') {
      var el2 = document.getElementById('onlineStaff');
      if (el2) el2.textContent = data.staffCount;
    }

  } else if (data.type === 'recipesData') {
    displayRecipes(data.recipes || []);

  } else if (data.type === 'refreshMenu') {
    state.currentMenu = data.menu || [];
    var menuPanel = document.getElementById('menu-tab');
    if (menuPanel && (menuPanel.classList.contains('active') || menuPanel.style.display === 'block')) {
      renderCustomerMenu();
    }

  } else if (data.type === 'staffData') {
    state.staff = Array.isArray(data.staff) ? data.staff : [];
    renderStaffInfo();

  } else if (data.type === 'clockinData') {
    var box = document.getElementById('clockinInfo');
    if (!box) return;

    var rows = Array.isArray(data.rows) ? data.rows : [];
    if (!rows.length) {
      box.innerHTML = '<p class="muted">No recent clock-ins.</p>';
      return;
    }

    function initial(name) {
      name = String(name || '').trim();
      var parts = name.split(/\s+/);
      return (parts[0]?.[0] || '?') + (parts[1]?.[0] || '');
    }
    function fmt(dt) {
      if (!dt) return '-';
      try { return new Date(dt).toLocaleString(); } catch (e) { return String(dt); }
    }
    function fmtHrs(n) {
      var v = Number(n || 0);
      return v.toFixed(2) + 'h';
    }

    var html = '';
    html += '<div class="clockin-card">';
    html +=   '<div class="clockin-head">';
    html +=     '<div>Employee</div><div>Restaurant</div><div>Clock In</div><div>Clock Out</div><div>Hours</div>';
    html +=   '</div>';

    rows.forEach(function (r) {
      var live = !r.clock_out_time;
      var name = r.player_name || ('CID ' + (r.player_id || '—'));
      var badge = live ? '<span class="badge-live">Live</span>' : '<span class="badge-done">Complete</span>';
      html += '<div class="clockin-row">';
      html +=   '<div class="ci-user"><div class="ci-avatar">' + initial(name) + '</div><div><div>' + name + '</div><div class="ci-id">#' + (r.player_id || '-') + '</div></div></div>';
      html +=   '<div class="ci-restaurant">' + (r.restaurant || '-') + '</div>';
      html +=   '<div><div>' + fmt(r.clock_in_time) + '</div></div>';
      html +=   '<div><div>' + (live ? badge : fmt(r.clock_out_time)) + '</div></div>';
      html +=   '<div>' + fmtHrs(r.hours_worked) + '</div>';
      html += '</div>';
    });

    html += '</div>';
    box.innerHTML = html;

  } else if (data.type === 'staffUpdated') {
    requestStaff();

  } else if (data.type === 'basketResult' || data.type === 'purchaseResult') {
    if (data.ok) {
      clearBasket();
    } else {
      console.warn('[Basket] checkout failed:', data.error);
    }
  }
});


document.addEventListener('keydown', function(e){ if (e.key === 'Escape' && state.isUIOpen) closeUI(); });
document.addEventListener('contextmenu', function(e){ e.preventDefault(); });

var createBtn = document.getElementById('createRecipeBtn'); if (createBtn) createBtn.onclick = showCreateRecipeForm;
var refreshBtn = document.getElementById('refreshRecipesBtn'); if (refreshBtn) refreshBtn.onclick = function(){ loadRecipes(); };
var saveBtn = document.getElementById('saveRecipeBtn'); if (saveBtn) saveBtn.onclick = saveRecipe;
var cancelBtn = document.getElementById('cancelRecipeBtn'); if (cancelBtn) cancelBtn.onclick = cancelRecipeForm;
var addIngBtn = document.getElementById('addIngredientBtn'); if (addIngBtn) addIngBtn.onclick = function(){
  var sel = document.getElementById('ingredientSelect');
  var val = sel ? sel.value : '';
  if (val && state.selectedIngredients.indexOf(val) === -1) {
    state.selectedIngredients.push(val);
    updateIngredientsDisplay();
    sel.value = '';
  }
};

document.addEventListener('click', function(e){
  var editBtn = e.target.closest('[data-edit]');
  if (editBtn && document.getElementById('recipesList') && document.getElementById('recipesList').contains(editBtn)) {
    var id = Number(editBtn.getAttribute('data-edit'));
    var recipe = (state.currentRecipes || []).find(function(x){ return Number(x.id) === id; });
    startEditRecipe(recipe);
    return;
  }
  var delBtn = e.target.closest('[data-del]');
  if (delBtn && document.getElementById('recipesList') && document.getElementById('recipesList').contains(delBtn)) {
    var idd = Number(delBtn.getAttribute('data-del'));
    deleteRecipe(idd);
    return;
  }
});

var basketToggle = document.getElementById('basketToggle'); if (basketToggle) basketToggle.onclick = function(){ toggleBasket(); };
var basketClose = document.getElementById('basketClose'); if (basketClose) basketClose.onclick = function(){ toggleBasket(false); };
var basketClear = document.getElementById('basketClear'); if (basketClear) basketClear.onclick = function(){ clearBasket(); };
var basketCheckout = document.getElementById('basketCheckout'); if (basketCheckout) basketCheckout.onclick = checkoutBasket;

document.addEventListener('click', function(e){
  var rm = e.target.closest('.basket-item-remove');
  if (rm && document.getElementById('basketItems') && document.getElementById('basketItems').contains(rm)) {
    var row = rm.closest('.basket-item');
    var idx = row ? Number(row.getAttribute('data-idx')) : -1;
    basketRemoveAt(idx);
  }
});
document.addEventListener('input', function(e){
  if (e.target.classList && e.target.classList.contains('basket-qty-input')) {
    var row = e.target.closest('.basket-item');
    var idx = row ? Number(row.getAttribute('data-idx')) : -1;
    var v = e.target.value;
    basketSetQty(idx, v);
  } 
  
  if (e.target.id === 'staffSearch') renderStaffInfo();
});

document.addEventListener('change', function(e){
  if (e.target.id === 'staffFilterDuty' || e.target.id === 'staffFilterGrade') renderStaffInfo();
});
var refreshStaffBtn = document.getElementById('refreshStaffBtn');
if (refreshStaffBtn) refreshStaffBtn.onclick = requestStaff;

var closeBtn = document.getElementById('closeBtn');
if (closeBtn) closeBtn.onclick = closeUI;
