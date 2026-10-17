// Environment: IE document mode, jQuery 1.2.x may be present but is not required.
// Injected into the C hospital RIS study page. It enhances both #row_beforereport and
// the reported-page history table under #dbrlist while keeping RIS controls alive.
(function(){
  function trim(s){ return (s || '').replace(/^\s+|\s+$/g, ''); }
  function txt(cell){ return cell ? trim(cell.innerText || cell.textContent || '') : ''; }
  function byName(name){ var e = document.getElementsByName(name); return e && e.length ? e[0] : null; }
  function ensureMobileRequest(){
    var request = document.getElementById('CH-ris-mobile-request');
    if(request) return request;
    request = document.createElement('input');
    request.type = 'hidden';
    request.id = 'CH-ris-mobile-request';
    request.value = '';
    document.body.appendChild(request);
    return request;
  }
  function requestMobileChart(e){
    e = e || window.event;
    var field = byName('patno');
    var chartNo = trim(field ? field.value : '');
    var status = document.getElementById('CH-ris-mobile-status');
    var button = document.getElementById('CH-ris-mobile-open');
    if(!/^\d{1,10}$/.test(chartNo)){
      if(status) status.innerText = 'Chart number unavailable';
      return false;
    }
    while(chartNo.length < 10) chartNo = '0' + chartNo;
    ensureMobileRequest().value = chartNo + '|' + (new Date().getTime());
    if(status) status.innerText = 'Queued ' + chartNo;
    if(button){
      button.disabled = true;
      setTimeout(function(){ button.disabled = false; }, 700);
    }
    if(e.preventDefault) e.preventDefault();
    e.returnValue = false;
    if(e.stopPropagation) e.stopPropagation();
    e.cancelBubble = true;
    return false;
  }
  function plainTextForField(s){
    return (s || '').replace(/\u00a0/g, ' ').replace(/\r\n|\r|\n/g, '\r\n');
  }
  function decodeEntitiesPreserveLines(s, preserveIndent){
    var marker = '___CH_RIS_HX_BR___';
    function markBreaks(v){
      return (v || '')
        .replace(/\r\n|\r|\n/g, marker)
        .replace(/\\r\\n|\\n|\\r/g, marker)
        .replace(/&#(?:13|x0*d);?\s*&#(?:10|x0*a);?/gi, marker)
        .replace(/&#(?:13|x0*d);?/gi, marker)
        .replace(/&#(?:10|x0*a);?/gi, marker)
        .replace(/&lt;br\s*\/?\s*&gt;/gi, marker)
        .replace(/<br\s*\/?\s*>/gi, marker);
    }
    s = markBreaks(s || '');
    s = s.replace(/<[^>]*>/g, '');
    var d = document.createElement('textarea');
    d.innerHTML = s;
    s = typeof d.value === 'string' ? d.value : (d.innerText || d.textContent || s);
    s = markBreaks(s);
    s = s.replace(/<[^>]*>/g, '');
    s = s.split(marker).join('\r\n');
    s = s.replace(/\r\n|\r|\n/g, '\r\n');
    // Report text keeps its spaces, tabs, and leading/trailing blank lines.
    if(preserveIndent) return s;
    s = s.replace(/\u00a0/g, ' ');
    s = s.replace(/[ \t]+\r\n/g, '\r\n');
    return trim(s);
  }
  function textToHtml(s){
    s = (s || '').replace(/\u00a0/g, ' ').replace(/\t/g, '    ');
    s = s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
    s = s.replace(/(^|\r\n|\r|\n)( +)/g, function(all, lineBreak, spaces){
      return lineBreak + spaces.replace(/ /g, '&nbsp;');
    });
    return s.replace(/\r\n|\r|\n/g, '<br/>');
  }
  function historyContext(){
    var box = document.getElementById('dbrlist');
    var tbl = document.getElementById('row_beforereport');
    var reported = false;
    if(!tbl && box){
      var tables = box.getElementsByTagName('table');
      if(tables && tables.length){
        tbl = tables[0];
        reported = true;
      }
    }
    return {
      box: box,
      tbl: tbl,
      reported: reported,
      dateCell: reported ? 3 : 6,
      typeCell: 4,
      examCell: reported ? 5 : 3,
      reportCell: reported ? -1 : 11,
      columnCount: reported ? 9 : 13
    };
  }
  function isHistoryRow(row, ctx){
    if(!row || !row.cells || (' ' + (row.className || '') + ' ').indexOf(' CH-hx-synthetic ') >= 0) return false;
    if(ctx.reported){
      if(row.cells.length < ctx.columnCount) return false;
      return /^\s*\d{4}[\/.-]\d{1,2}[\/.-]\d{1,2}/.test(txt(row.cells[ctx.dateCell]));
    }
    return row.cells.length > ctx.reportCell;
  }
  function ensureStyle(){
    var old = document.getElementById('ch-ris-hx-style');
    if(old && old.parentNode) old.parentNode.removeChild(old);
    var css = ''
      + '#row_beforereport tr.rowMouseOver td{background-color:inherit !important;}\n'
      + '#row_beforereport tr.CH-hx-active td{background-color:#cfe8ff !important;border-top:2px solid #1f6fb2 !important;border-bottom:2px solid #1f6fb2 !important;}\n'
      + '#row_beforereport tr.CH-hx-active td:first-child{border-left:5px solid #1f6fb2 !important;}\n'
      + '#row_beforereport tr.CH-hx-child-active td{background-color:#ffedb5 !important;border-top:2px solid #ad7b00 !important;border-bottom:2px solid #ad7b00 !important;}\n'
      + '#row_beforereport tr.CH-hx-child-active td:first-child{border-left:5px solid #ad7b00 !important;}\n'
      + '.ch-ris-hx-table tr.rowMouseOver td{background-color:inherit !important;}\n'
      + '.ch-ris-hx-table tr.CH-hx-active td{background-color:#cfe8ff !important;border-top:2px solid #1f6fb2 !important;border-bottom:2px solid #1f6fb2 !important;}\n'
      + '.ch-ris-hx-table tr.CH-hx-active td:first-child{border-left:5px solid #1f6fb2 !important;}\n'
      + '.ch-ris-hx-table tr.CH-hx-child-active td{background-color:#ffedb5 !important;border-top:2px solid #ad7b00 !important;border-bottom:2px solid #ad7b00 !important;}\n'
      + '.ch-ris-hx-table tr.CH-hx-child-active td:first-child{border-left:5px solid #ad7b00 !important;}\n'
      + '#ch-ris-hx-preview,#ch-ris-hx-memo-preview{font-family:Verdana,Arial,sans-serif;}\n';
    var st = document.createElement('style');
    st.id = 'ch-ris-hx-style';
    st.type = 'text/css';
    if(st.styleSheet) st.styleSheet.cssText = css;
    else st.appendChild(document.createTextNode(css));
    (document.getElementsByTagName('head')[0] || document.documentElement).appendChild(st);
  }
  function removeClass(el, cls){
    if(el) el.className = trim((' ' + (el.className || '') + ' ').replace(' ' + cls + ' ', ' '));
  }
  function addClass(el, cls){
    if(el && (' ' + (el.className || '') + ' ').indexOf(' ' + cls + ' ') < 0) {
      el.className = trim((el.className || '') + ' ' + cls);
    }
  }
  function clearActive(){
    if(window.chRisHxActiveRow){
      removeClass(window.chRisHxActiveRow, 'CH-hx-active');
      removeClass(window.chRisHxActiveRow, 'CH-hx-child-active');
      window.chRisHxActiveRow = null;
    }
  }
  function hidePreview(){
    clearTimeout(window.chRisHxHideTimer);
    var pv = document.getElementById('ch-ris-hx-preview');
    if(pv) pv.style.display = 'none';
    clearActive();
  }
  function scheduleHide(){
    clearTimeout(window.chRisHxHideTimer);
    window.chRisHxHideTimer = setTimeout(hidePreview, 320);
  }
  function cancelHide(){ clearTimeout(window.chRisHxHideTimer); }
  window.chRisHxHideNow = hidePreview;

  function hideMemoPreview(){
    clearTimeout(window.chRisHxMemoHideTimer);
    var pv = document.getElementById('ch-ris-hx-memo-preview');
    if(pv) pv.style.display = 'none';
  }
  function scheduleMemoHide(){
    clearTimeout(window.chRisHxMemoHideTimer);
    window.chRisHxMemoHideTimer = setTimeout(hideMemoPreview, 180);
  }
  function cancelMemoHide(){ clearTimeout(window.chRisHxMemoHideTimer); }

  function removeSynthetic(){
    var old = document.getElementById('ch-ris-hx-bar');
    if(old && old.parentNode) old.parentNode.removeChild(old);
    var pv = document.getElementById('ch-ris-hx-preview');
    if(pv && pv.parentNode) pv.parentNode.removeChild(pv);
    var mpv = document.getElementById('ch-ris-hx-memo-preview');
    if(mpv && mpv.parentNode) mpv.parentNode.removeChild(mpv);
    var hint = document.getElementById('ch-ris-hx-hint');
    if(hint && hint.parentNode) hint.parentNode.removeChild(hint);
    var ctx0 = historyContext();
    var tbl0 = ctx0.tbl;
    clearActive();
    if(tbl0){
      var rows0 = tbl0.rows;
      for(var i = rows0.length - 1; i >= 0; i--){
        if((' ' + (rows0[i].className || '') + ' ').indexOf(' CH-hx-synthetic ') >= 0){
          rows0[i].parentNode.removeChild(rows0[i]);
        } else if(rows0[i]._chRisHxBound || (' ' + (rows0[i].className || '') + ' ').indexOf(' CH-hx-main-row ') >= 0 || (' ' + (rows0[i].className || '') + ' ').indexOf(' CH-hx-child-row ') >= 0) {
          rows0[i].style.display = '';
          rows0[i].style.backgroundColor = '';
          rows0[i].style.borderLeft = '';
          rows0[i].style.cursor = '';
          rows0[i].onmouseover = rows0[i]._chRisHxOriginalMouseOver || null;
          rows0[i].onmouseout = rows0[i]._chRisHxOriginalMouseOut || null;
          rows0[i]._chRisHxBound = false;
          var liveTitle = rows0[i].getAttribute('title') || '';
          if(liveTitle) rows0[i]._chRisHxNativeTitle = liveTitle;
          else if(rows0[i]._chRisHxRowText !== txt(rows0[i])) rows0[i]._chRisHxNativeTitle = '';
          if(!liveTitle && rows0[i]._chRisHxNativeTitle) rows0[i].setAttribute('title', rows0[i]._chRisHxNativeTitle);
          rows0[i]._chRisHxReport = null;
          removeClass(rows0[i], 'CH-hx-main-row');
          removeClass(rows0[i], 'CH-hx-child-row');
          removeClass(rows0[i], 'CH-hx-active');
          removeClass(rows0[i], 'CH-hx-child-active');
        }
      }
    }
  }
  function typeGroup(examType){
    var t = (examType || '').toUpperCase();
    if(t.indexOf('CT') >= 0 || t.indexOf('MRI') >= 0 || /(^|[^A-Z])MR([^A-Z]|$)/.test(t) || t.indexOf('SPECIAL') >= 0 || examType.indexOf('特殊') >= 0) return 'CTMR';
    if(t.indexOf('MAMMO') >= 0 || /(^|[^A-Z])MG([^A-Z]|$)/.test(t) || examType.indexOf('乳房') >= 0) return 'Mammo';
    if(t.indexOf('US5B') >= 0) return 'US5B';
    if(t.indexOf('US') >= 0 || examType.indexOf('超音波') >= 0) return 'US';
    if(t.indexOf('X-RAY') >= 0) return 'XR';
    if(t.indexOf('BMD') >= 0) return 'BMD';
    return trim(examType) || 'Other';
  }
  function modeFromCurrent(){
    var name = byName('mciname'), v = name ? name.value : '';
    var g = typeGroup(v);
    if(g === 'CTMR') return 'CTMR';
    if(g === 'US5B' || g === 'US' || g === 'Mammo' || /US|Mammo|MG/i.test(v) || v.indexOf('超音波') >= 0 || v.indexOf('乳房') >= 0) return 'USMammo';
    return '';
  }
  function isMainRow(group, mode){
    if(mode === 'CTMR') return group === 'CTMR';
    if(mode === 'USMammo') return group === 'US5B' || group === 'Mammo';
    return true;
  }
  function reportText(row, ctx){
    if(typeof row._chRisHxReport === 'string') return row._chRisHxReport;
    try {
      if(ctx && ctx.reported) return decodeEntitiesPreserveLines(row.getAttribute('title') || row.title || '', true);
      var reportCell = ctx ? ctx.reportCell : 11;
      var inputs = row.cells[reportCell].getElementsByTagName('input');
      return inputs && inputs.length ? decodeEntitiesPreserveLines(inputs[0].value, true) : '';
    } catch(e){ return ''; }
  }
  function suppressNativeTitles(row){
    row.title = '';
    row.removeAttribute('title');
    row.removeAttribute('tooltipText');
    row.removeAttribute('alt');
    var all = row.getElementsByTagName('*');
    for(var i = 0; i < all.length; i++){
      all[i].title = '';
      all[i].removeAttribute('title');
      all[i].removeAttribute('tooltipText');
      all[i].removeAttribute('alt');
    }
  }
  function containsNode(parent, node){
    while(node){
      if(node === parent) return true;
      node = node.parentNode;
    }
    return false;
  }
  function selectedTextInside(el){
    var text = '', sel, range, node, i;
    try {
      if(window.getSelection){
        sel = window.getSelection();
        if(!sel || sel.rangeCount === 0) return '';
        text = sel.toString ? sel.toString() : '';
        if(!trim(text)) return '';
        for(i = 0; i < sel.rangeCount; i++){
          range = sel.getRangeAt(i);
          node = range.commonAncestorContainer;
          if(node && node.nodeType !== 1) node = node.parentNode;
          if(containsNode(el, node)) return text;
        }
        return '';
      }
      if(document.selection && document.selection.type !== 'None'){
        range = document.selection.createRange();
        text = range.text || '';
        if(!trim(text)) return '';
        node = range.parentElement();
        if(containsNode(el, node)) return text;
      }
    } catch(e) {}
    return '';
  }
  function viewportInfo(){
    var de = document.documentElement || {};
    var b = document.body || {};
    var root = document.compatMode === 'BackCompat' ? b : de;
    return {
      left: root.scrollLeft || b.scrollLeft || de.scrollLeft || 0,
      top: root.scrollTop || b.scrollTop || de.scrollTop || 0,
      width: root.clientWidth || window.innerWidth || 800,
      height: root.clientHeight || window.innerHeight || 600
    };
  }
  function scrollPreview(pv, e, cancelHideFn){
    e = e || window.event;
    pv.scrollTop -= (e.wheelDelta || 0) / 120 * 48;
    cancelHideFn();
    e.cancelBubble = true;
    e.returnValue = false;
    if(e.stopPropagation) e.stopPropagation();
    if(e.preventDefault) e.preventDefault();
    return false;
  }
  function positionPreview(pv, x, y, width, v, heightLimit){
    x = Math.max(v.left + 8, Math.min(x, v.left + v.width - width - 12));
    var bottom = v.top + v.height - 8;
    y = Math.max(v.top + 8, Math.min(y, Math.max(v.top + 8, bottom - 164)));
    var height = Math.max(0, bottom - y - 4);
    if(heightLimit) height = Math.min(height, heightLimit);
    pv.style.width = width + 'px';
    // IE document mode 5 ignores max-height. A height gives overflow a real box.
    pv.style.height = height + 'px';
    pv.style.left = x + 'px';
    pv.style.top = y + 'px';
  }
  function showBoundedPreview(pv, textBox){
    pv.style.display = 'block';
    // Measure after showing the bounded panel; short content keeps a compact height.
    var naturalHeight = pv.firstChild.offsetHeight + textBox.offsetHeight + 4;
    if(naturalHeight < parseInt(pv.style.height, 10)) pv.style.height = naturalHeight + 'px';
    pv.scrollTop = 0;
  }
  function ensurePreview(){
    var pv = document.getElementById('ch-ris-hx-preview');
    if(pv) return pv;
    pv = document.createElement('div');
    pv.id = 'ch-ris-hx-preview';
    pv.style.cssText = 'display:none;position:absolute;z-index:99999;width:500px;overflow:auto;background:#fffff8;color:#111;border:2px solid #444;box-shadow:2px 2px 5px #777;padding:0;direction:ltr;text-align:left;font-size:12px;line-height:16px;white-space:normal;';
    pv.innerHTML = '<div id="ch-ris-hx-preview-head" style="background:#263238;color:#fff;padding:4px 6px;font-weight:bold;"><span id="ch-ris-hx-preview-title"></span><button id="ch-ris-hx-append" type="button" style="float:right;font-size:11px;margin-left:6px;">Append to Exam</button></div><div id="ch-ris-hx-preview-text" style="margin:0;padding:7px;font-family:Consolas,monospace;white-space:pre-wrap;word-wrap:break-word;"></div>';
    document.body.appendChild(pv);
    pv.onmouseover = cancelHide;
    pv.onmouseout = scheduleHide;
    pv.onclick = function(e){
      e = e || window.event;
      var src = e.srcElement || e.target;
      if(src && src.id === 'ch-ris-hx-append') return;
      copyText(selectedTextInside(pv) || pv.getAttribute('data-report') || '');
      showHint('Copied');
      if(e.stopPropagation) e.stopPropagation();
      e.cancelBubble = true;
      return false;
    };
    document.getElementById('ch-ris-hx-append').onclick = function(e){
      appendToExam(pv.getAttribute('data-report') || '');
      showHint('Appended to Exam');
      e = e || window.event;
      if(e.stopPropagation) e.stopPropagation();
      e.cancelBubble = true;
      return false;
    };
    pv.onmousewheel = function(e){
      return scrollPreview(pv, e, cancelHide);
    };
    return pv;
  }
  function dockPreview(pv){
    var box = document.getElementById('dbrlist');
    var v = viewportInfo();
    var width = Math.max(0, Math.min(500, v.width - 20));
    var x = v.left + 20, y = v.top + 20;
    try {
      var r = box.getBoundingClientRect();
      x = v.left + r.left - width - 15;
      if(x < v.left + 8) x = v.left + r.right + 8;
      y = v.top + r.top;
    } catch(e) {}
    positionPreview(pv, x, y, width, v, 340);
  }
  function showPreview(row){
    cancelHide();
    hideMemoPreview();
    var ctx = historyContext();
    var report = reportText(row, ctx);
    if(!report){ hidePreview(); return; }
    clearActive();
    window.chRisHxActiveRow = row;
    addClass(row, (' ' + (row.className || '') + ' ').indexOf(' CH-hx-child-row ') >= 0 ? 'CH-hx-child-active' : 'CH-hx-active');
    var pv = ensurePreview();
    var title = txt(row.cells[ctx.dateCell]) + ' ' + txt(row.cells[ctx.typeCell]) + ' - ' + txt(row.cells[ctx.examCell]);
    pv.setAttribute('data-report', report);
    document.getElementById('ch-ris-hx-preview-title').innerText = title;
    var textBox = document.getElementById('ch-ris-hx-preview-text');
    textBox.innerHTML = textToHtml(report);
    dockPreview(pv);
    showBoundedPreview(pv, textBox);
  }
  function ensureMemoPreview(){
    var pv = document.getElementById('ch-ris-hx-memo-preview');
    if(pv) return pv;
    pv = document.createElement('div');
    pv.id = 'ch-ris-hx-memo-preview';
    pv.style.cssText = 'display:none;position:absolute;z-index:100000;width:560px;overflow:auto;background:#fffff8;color:#111;border:2px solid #444;box-shadow:2px 2px 5px #777;padding:0;direction:ltr;text-align:left;font-size:12px;line-height:16px;white-space:normal;';
    pv.innerHTML = '<div style="background:#263238;color:#fff;padding:4px 6px;font-weight:bold;">Memo</div><div id="ch-ris-hx-memo-preview-text" style="margin:0;padding:7px;font-family:Consolas,monospace;white-space:pre-wrap;word-wrap:break-word;"></div>';
    document.body.appendChild(pv);
    pv.onmouseover = cancelMemoHide;
    pv.onmouseout = scheduleMemoHide;
    pv.onmousewheel = function(e){
      return scrollPreview(pv, e, cancelMemoHide);
    };
    return pv;
  }
  function dockMemoPreview(pv, memo){
    var v = viewportInfo();
    var width = Math.max(0, Math.min(560, v.width - 20));
    var x = v.left + 8;
    var y = v.top + 8;
    try {
      var r = memo.getBoundingClientRect();
      x = v.left + r.right + 8;
      y = v.top + r.top;
      if(x + width > v.left + v.width - 8) x = v.left + r.left - width - 8;
      if(x < v.left + 8) x = v.left + 8;
      if(y < v.top + 8) y = v.top + 8;
    } catch(e) {}
    positionPreview(pv, x, y, width, v);
  }
  function showMemoPreview(memo){
    cancelMemoHide();
    hidePreview();
    var text = decodeEntitiesPreserveLines(memo.value || memo.innerText || memo.textContent || '', true);
    if(!text){
      hideMemoPreview();
      return;
    }
    var pv = ensureMemoPreview();
    var textBox = document.getElementById('ch-ris-hx-memo-preview-text');
    textBox.innerHTML = textToHtml(text);
    dockMemoPreview(pv, memo);
    showBoundedPreview(pv, textBox);
  }
  function bindMemoPreview(){
    var memos = [];
    function addMemo(memo){
      if(!memo) return;
      for(var i = 0; i < memos.length; i++) if(memos[i] === memo) return;
      memos.push(memo);
    }
    var byId = document.getElementById('memotx');
    addMemo(byId);
    var byNm = document.getElementsByName('memotx');
    for(var i = 0; byNm && i < byNm.length; i++) addMemo(byNm[i]);
    var textareas = document.getElementsByTagName('textarea');
    for(var j = 0; j < textareas.length; j++){
      var t = (textareas[j].id || textareas[j].name || '').toLowerCase();
      if(t === 'memotx') addMemo(textareas[j]);
    }
    for(var k = 0; k < memos.length; k++){
      var memo = memos[k];
      suppressNativeTitles(memo);
      try {
        if(window.jQuery) window.jQuery(memo).unbind('mouseover').unbind('mouseenter').unbind('mouseout').unbind('mouseleave');
      } catch(e) {}
      memo.onmouseover = memo.onmouseenter = (function(memoRef){ return function(){ showMemoPreview(memoRef); return true; }; })(memo);
      memo.onmouseout = memo.onmouseleave = scheduleMemoHide;
    }
    return memos.length;
  }
  function copyText(text){
    var ta = document.createElement('textarea');
    ta.style.position = 'absolute';
    ta.style.left = '-2000px';
    ta.value = plainTextForField(text);
    document.body.appendChild(ta);
    ta.select();
    try { document.execCommand('copy'); } catch(e) {}
    document.body.removeChild(ta);
  }
  function appendToExam(text){
    var exam = document.getElementById('exam');
    if(!exam || !text) return;
    var old = exam.value || '';
    var sep = old ? '\r\n\r\n' : '';
    exam.value = old + sep + text;
    try { exam.focus(); } catch(e) {}
    try { if(window.replaceReport) window.replaceReport({keyCode:0}, 'exam'); } catch(e2) {}
  }
  function showHint(msg){
    var h = document.getElementById('ch-ris-hx-hint');
    if(!h){
      h = document.createElement('div');
      h.id = 'ch-ris-hx-hint';
      h.style.cssText = 'position:absolute;z-index:100000;background:#222;color:#fff;padding:4px 8px;font-family:Verdana,Arial;font-size:12px;';
      document.body.appendChild(h);
    }
    h.innerHTML = msg;
    var pv = document.getElementById('ch-ris-hx-preview');
    var left = pv ? parseInt(pv.style.left,10) + 12 : 20;
    var top = pv ? parseInt(pv.style.top,10) + 12 : 20;
    h.style.left = left + 'px';
    h.style.top = top + 'px';
    h.style.display = 'block';
    clearTimeout(window.chRisHxHintTimer);
    window.chRisHxHintTimer = setTimeout(function(){ h.style.display = 'none'; }, 900);
  }
  function bindDetailButtons(tbl){
    var buttons = tbl.getElementsByTagName('button');
    var count = 0;
    for(var i = 0; i < buttons.length; i++){
      if(buttons[i].getAttribute('data-CH-hide-bound') === '1') continue;
      buttons[i].setAttribute('data-CH-hide-bound', '1');
      var prev = buttons[i].onclick;
      buttons[i].onclick = (function(oldFn){
        return function(e){
          hidePreview();
          if(oldFn) return oldFn.call(this, e || window.event);
          return true;
        };
      })(prev);
      count++;
    }
    window.chRisHxDetailHideCount = count;
  }
  function insertCell(row, colSpan, html){
    var c = row.insertCell(0);
    c.colSpan = colSpan;
    c.innerHTML = html;
    return c;
  }
  function build(){
    removeSynthetic();
    ensureStyle();
    var ctx = historyContext();
    var box = ctx.box;
    var tbl = ctx.tbl;
    bindMemoPreview();
    if(!box || !tbl || !tbl.rows) return 'missing';
    box.style.direction = 'ltr';
    addClass(tbl, 'ch-ris-hx-table');
    var mode = modeFromCurrent();
    var original = [];
    for(var r = 0; r < tbl.rows.length; r++){
      var row = tbl.rows[r];
      if(isHistoryRow(row, ctx)) original.push(row);
    }
    var mainCount = 0, childCount = 0, groups = 0;
    var bar = document.createElement('div');
    bar.id = 'ch-ris-hx-bar';
    bar.style.cssText = 'direction:ltr;font-family:Verdana,Arial,sans-serif;background:#111;color:#eee;border:1px solid #555;border-bottom:0;padding:4px 6px;font-size:12px;line-height:20px;white-space:nowrap;overflow:hidden;';
    bar.innerHTML = '<span style="float:right;color:#aaa;white-space:nowrap;"><button id="CH-ris-mobile-open" type="button" style="font-size:11px;margin-left:8px;vertical-align:middle;">Open Mobile Chart</button> <span id="CH-ris-mobile-status">Mobile chart ready</span></span><b style="color:#9ee;">C hospital RIS Hx</b> <span id="ch-ris-hx-summary" style="color:#bbb;"></span> <span title="Hover row: preview. Click preview: copy." style="display:inline-block;width:14px;height:14px;line-height:14px;text-align:center;border:1px solid #9aa;border-radius:8px;color:#d7e8f5;font-weight:bold;font-family:Georgia,serif;cursor:help;vertical-align:middle;">i</span>';
    if(tbl.parentNode === box) box.insertBefore(bar, tbl);
    else box.insertBefore(bar, box.firstChild);
    ensureMobileRequest();
    var mobileButton = document.getElementById('CH-ris-mobile-open');
    if(mobileButton) mobileButton.onclick = requestMobileChart;
    var currentRun = null;
    for(var i = 0; i < original.length; i++){
      var row = original[i];
      var examType = txt(row.cells[ctx.typeCell]);
      var group = typeGroup(examType);
      var main = isMainRow(group, mode);
      row.setAttribute('data-CH-hx-group', group);
      row._chRisHxReport = reportText(row, ctx);
      row._chRisHxNativeTitle = row.getAttribute('title') || '';
      row._chRisHxRowText = txt(row);
      if(ctx.reported){
        row.setAttribute('data-CH-hx-native-title', row._chRisHxNativeTitle);
        row.setAttribute('data-CH-hx-row-text', row.innerText || '');
      }
      row._chRisHxOriginalMouseOver = row.onmouseover;
      row._chRisHxOriginalMouseOut = row.onmouseout;
      row._chRisHxBound = true;
      suppressNativeTitles(row);
      row.style.cursor = 'default';
      row.onmouseover = (function(rowRef){ return function(){ showPreview(rowRef); return true; }; })(row);
      row.onmouseout = scheduleHide;
      if(main){
        currentRun = null;
        mainCount++;
        addClass(row, 'CH-hx-main-row');
        row.style.backgroundColor = '#f7fbff';
        row.style.borderLeft = '4px solid #2374ab';
      } else {
        childCount++;
        addClass(row, 'CH-hx-child-row');
        if(!currentRun){
          groups++;
          currentRun = { rows: [], labels: {}, count: 0, groupRow: null };
          var gr = document.createElement('tr');
          row.parentNode.insertBefore(gr, row);
          currentRun.groupRow = gr;
          gr.className = 'CH-hx-synthetic CH-hx-group-row';
          gr.style.cssText = 'background:#293241;color:#fff;cursor:pointer;font-family:Verdana,Arial,sans-serif;';
          gr.setAttribute('data-CH-hx-open', '0');
          insertCell(gr, ctx.columnCount, '<span class="CH-hx-toggle" style="font-weight:bold;color:#ffd166;">+</span> <span class="CH-hx-group-text"></span>');
          (function(groupRow, run){
            groupRow.onclick = function(){
              var open = groupRow.getAttribute('data-CH-hx-open') === '1';
              groupRow.setAttribute('data-CH-hx-open', open ? '0' : '1');
              groupRow.getElementsByTagName('span')[0].innerHTML = open ? '+' : '-';
              for(var k = 0; k < run.rows.length; k++) run.rows[k].style.display = open ? 'none' : '';
              hidePreview();
            };
          })(gr, currentRun);
        }
        currentRun.rows.push(row);
        currentRun.count++;
        currentRun.labels[group] = true;
        row.style.display = 'none';
        row.style.backgroundColor = '#fffdf3';
        row.style.borderLeft = '4px solid #8d99ae';
        var labelParts = [];
        for(var key in currentRun.labels){ if(currentRun.labels.hasOwnProperty(key)) labelParts.push(key); }
        try { currentRun.groupRow.getElementsByTagName('span')[1].innerHTML = labelParts.join(' / ') + ' (' + currentRun.count + ')'; } catch(e){}
      }
    }
    bindDetailButtons(tbl);
    document.getElementById('ch-ris-hx-summary').innerHTML = 'mode=' + (mode || 'all') + ', main=' + mainCount + ', grouped=' + childCount + ', groups=' + groups;
    return 'ok layout=' + (ctx.reported ? 'reported' : 'before-report') + ' rows=' + original.length + ' main=' + mainCount + ' child=' + childCount;
  }
  window.chRisHxBuild = build;
  window.chRisHxReset = removeSynthetic;
  return build();
})();
