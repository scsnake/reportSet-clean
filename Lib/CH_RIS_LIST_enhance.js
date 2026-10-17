// Environment: IE (IE5 compat document mode), jQuery 1.2.6
// Injected into the C hospital RIS worklist page via AHK execJS.

function ahk_rememberStatus() {
	var field = $('select[name=status]')[0];
	if (!field) return;
	var value = field.value;
	var pathname = window.location.pathname;
	var directory = pathname.substring(0, pathname.lastIndexOf('/')) || '/';
	var parts = pathname.split('/'), path = '', i;
	var expired = 'selected_status=; expires=Thu, 01 Jan 1970 00:00:00 GMT; path=';
	// Native RIS reads the first matching cookie. Remove stale ancestor paths,
	// including IE's trailing-slash variant, before writing one session cookie.
	document.cookie = expired + '/';
	for (i = 1; i < parts.length; i++) {
		path += '/' + parts[i];
		document.cookie = expired + path;
		document.cookie = expired + path + '/';
	}
	document.cookie = 'selected_status=' + encodeURIComponent(value) + '; path=' + directory;
}

function ahk_statusCookieInit() {
	var field = $('select[name=status]')[0];
	if (!field) return;
	if (!field._ahkStatusCookieBound) {
		// Run after the native handler, which writes with an implicit cookie path.
		$(field).change(ahk_rememberStatus);
		$('#ClearAllButton').click(ahk_rememberStatus);
		field._ahkStatusCookieBound = true;
	}
	ahk_rememberStatus();
}

function formatDate(date, del) {
	if (date===undefined) date=new Date();
	if (del===undefined) del='/';

	var d = new Date(date),
		month = '' + (d.getMonth() + 1),
		day = '' + d.getDate(),
		year = d.getFullYear();

	if (month.length < 2) 
		month = '0' + month;
	if (day.length < 2) 
		day = '0' + day;

	return [year, month, day].join(del);
}

function ahk_date_interval(){
	var id = this.id;
	var week = parseInt(id.slice(-3,-2));
	var today = new Date();
	var startDate = new Date(today);
	startDate.setDate(today.getDate() - (week * 7));

	$('#checktimestart').val(formatDate(startDate));
	$('#checktimeend').val(formatDate(today));
}
function ahk_reset_fn(e){
	$('input[name=referno]').val('');
	$('input[name=patno]').val('');
	$('input[name=patidno]').val('');
	$('input[name=mciname]').val('');
	$('select[name=source]').val('').trigger('change').trigger('click');
	$('select[name=gender]').val('');
	$('select[name=hospitalid]').val('');
	
	$('admissiondruserid').val('');
	$('input[name=isreportdate]').attr('checked', false);
	$('select[name=checkdruserid]').val('000000');
	$('select[name=status]').val('00').trigger('change');
	$('select[name=mccid]').val('');
	if (e && e.shiftKey) $('#QueryButton').click();
}
function ahk_us_fn(e){
	ahk_reset_fn();
	$('select[name=mccid]').val('136');
	if (e && !e.shiftKey) $('#QueryButton').click();
}
function ahk_usbx_fn(e){
	ahk_reset_fn();
	$('select[name=mccid]').val('62');
	if (e && !e.shiftKey) $('#QueryButton').click();
}
function ahk_mammo_fn(e){
	ahk_reset_fn();
	$('select[name=mccid]').val('56');
	if (e && !e.shiftKey) $('#QueryButton').click();
}
function ahk_ct_fn(e){
	ahk_reset_fn();
	$('select[name=mccid]').val('54');
	// jQuery 1.2.6 omits altKey when copying the native event properties.
	if (e && (e.altKey || (e.originalEvent && e.originalEvent.altKey))) {
		$('select[name=status]').val('').trigger('change');
		$('select[name=checkdruserid]').val('');
	}
	if (e && !e.shiftKey) $('#QueryButton').click();
}
function ahk_mr_fn(e){
	ahk_reset_fn();
	$('select[name=mccid]').val('55');
	if (e && !e.shiftKey) $('#QueryButton').click();
}
function ahk_xr_fn(e){
	ahk_reset_fn();
	$('select[name=mccid]').val('52');
	if (e && !e.shiftKey) $('#QueryButton').click();
}
function ahk_sp_fn(e){
	ahk_reset_fn();
	$('select[name=mccid]').val('53');
	if (e && !e.shiftKey) $('#QueryButton').click();
}
function ahk_er_fn(e){
	var modality = $('select[name=mccid]').val();
	ahk_reset_fn();
	$('select[name=source]').val('E');
	$('select[name=mccid]').val(modality);
	if (e && !e.shiftKey) $('#QueryButton').click();
}
function ahk_search_chartno_fn(e){
	
	var chartNoDate = $.trim(window.prompt('Chart No to search:', '')).split(',');
	try{
		var chartNo = chartNoDate[0]?$.trim(chartNoDate[0]):'';
		var examDate = chartNoDate[1]?$.trim(chartNoDate[1]):'';
		var now = new Date();
		if(examDate.length==4){
			if(examDate.substring(0,2) <= now.getMonth()+1 && examDate.substring(2,4) <= now.getDate()) examDate = now.getYear() + examDate;
			else examDate = (now.getYear()-1) + examDate;
		}else if(examDate.length==6) examDate = '20' + examDate;
		
		if(chartNo!==''){
		$('input[name=patno]').val(chartNo);
		if(examDate!==''){
			examDate = examDate.substring(0,4) + '/' + examDate.substring(4,6) + '/' + examDate.substring(6,8);
			$('#checktimestart').val(examDate); 
			$('#checktimeend').val(examDate); 
			$('select[name=checkdruserid]').val('');
			$('select[name=status]').val('').trigger('change');
		}else{
			$('#checktimestart').val(formatDate(new Date((new Date()).getTime() - (7*365 * 24 * 60 * 60 * 1000)))); 
			$('#checktimeend').val(formatDate()); 
			$('select[name=checkdruserid]').val('');
			$('select[name=status]').val('').trigger('change');
		}
		}
		if(chartNo!=='') $('#QueryButton').click();
	}catch (ex) {
		console.log(ex);
	}
}


function ahk_getLoginName() {
	var tds = document.getElementsByTagName('td');
	for (var _i = 0; _i < tds.length; _i++) {
		var _t = tds[_i].innerText || '';
		var _m = _t.match(/\d+\(([^\)]+)\)/);
		if (_m && tds[_i].getElementsByTagName('a').length) {
			return _m[1];
		}
	}
	return '';
}

function ahk_getModalityGroup(examType) {
	var upper = examType.toUpperCase();
	if (upper.indexOf('CT') !== -1) return 'CT';
	if (upper.indexOf('MR') !== -1) return 'MR';
	if (upper.indexOf('X-RAY') !== -1) return 'XR';
	if (upper.indexOf('MAMMO') !== -1) return 'MG';
	if (upper.indexOf('US') !== -1) return 'US';
	if (upper.indexOf('BMD') !== -1) return 'BMD';
	return '\u5176\u4ed6';
}

function ahk_getSourceGroup(source) {
	var s = source.replace(/^\s+|\s+$/g, '');
	if (s === '\u6025\u8a3a') return 'E';
	if (s === '\u9580\u8a3a' || s === '\u6574\u7be9') return 'O';
	return 'A';
}

function ahk_trimText(s) {
	return (s || '').replace(/\u00a0/g, ' ').replace(/^\s+|\s+$/g, '');
}

function ahk_cellText(cell) {
	return cell ? ahk_trimText(cell.innerText || cell.textContent || '') : '';
}

function ahk_addClass(el, cls) {
	if (el && (' ' + (el.className || '') + ' ').indexOf(' ' + cls + ' ') < 0) {
		el.className = ahk_trimText((el.className || '') + ' ' + cls);
	}
}

function ahk_findOwnerCol(tbl) {
	var rows = tbl.rows;
	if (!rows || rows.length === 0) return -1;
	var cells = rows[0].cells, i, h;
	for (i = 0; i < cells.length; i++) {
		h = ahk_cellText(cells[i]).replace(/\s+/g, '').toLowerCase();
		if (h === '\u64c1\u6709\u8005' || h === 'owner' || h === 'reportowner') return i;
	}
	for (i = 0; i < cells.length; i++) {
		h = ahk_cellText(cells[i]).replace(/\s+/g, '').toLowerCase();
		if (h.indexOf('\u64c1\u6709\u8005') !== -1 || h.indexOf('owner') !== -1) return i;
	}
	return cells.length > 13 ? 13 : -1;
}

function ahk_findStatusCol(tbl) {
	var rows = tbl.rows;
	if (!rows || rows.length === 0) return -1;
	var cells = rows[0].cells, i, h;
	for (i = 0; i < cells.length; i++) {
		h = ahk_cellText(cells[i]).replace(/\s+/g, '').toLowerCase();
		if (h === '\u72c0\u614b' || h === 'status') return i;
	}
	for (i = 0; i < cells.length; i++) {
		h = ahk_cellText(cells[i]).replace(/\s+/g, '').toLowerCase();
		if (h.indexOf('\u72c0\u614b') !== -1 || h.indexOf('status') !== -1) return i;
	}
	return cells.length > 18 ? 18 : -1;
}

function ahk_studyDateKey(text) {
	var s = ahk_trimText(text);
	var m = s.match(/(\d{2,4})[\/\-\.](\d{1,2})[\/\-\.](\d{1,2})/);
	if (m) {
		return parseInt(m[1], 10) + '/' + parseInt(m[2], 10) + '/' + parseInt(m[3], 10);
	}
	m = s.match(/(^|[^\d])(\d{1,2})[\/\-\.](\d{1,2})(?=([^\d]|$))/);
	if (m) {
		return parseInt(m[2], 10) + '/' + parseInt(m[3], 10);
	}
	m = s.match(/(^|[^\d])(\d{4})(\d{2})(\d{2})(?=([^\d]|$))/);
	if (m) {
		return parseInt(m[2], 10) + '/' + parseInt(m[3], 10) + '/' + parseInt(m[4], 10);
	}
	return '';
}

function ahk_studyDateSortValue(key) {
	var p = (key || '').split('/');
	if (p.length === 3) return parseInt(p[0], 10) * 10000 + parseInt(p[1], 10) * 100 + parseInt(p[2], 10);
	if (p.length === 2) return (new Date()).getFullYear() * 10000 + parseInt(p[0], 10) * 100 + parseInt(p[1], 10);
	return 0;
}

function ahk_findStudyDateCol(tbl) {
	var rows = tbl.rows;
	if (!rows || rows.length === 0) return -1;
	var header = rows[0], cells = header.cells, i, h;
	var exact = {
		'\u6aa2\u67e5\u65e5\u671f': true,
		'\u6aa2\u67e5\u65e5': true,
		'studydate': true,
		'examdate': true
	};
	for (i = 0; i < cells.length; i++) {
		h = ahk_cellText(cells[i]).replace(/\s+/g, '').toLowerCase();
		if (exact[h]) return i;
	}
	for (i = 0; i < cells.length; i++) {
		h = ahk_cellText(cells[i]).replace(/\s+/g, '').toLowerCase();
		if (h.indexOf('\u6aa2\u67e5\u65e5\u671f') !== -1 || h.indexOf('\u6aa2\u67e5\u65e5') !== -1 || h.indexOf('studydate') !== -1 || h.indexOf('examdate') !== -1) {
			return i;
		}
	}
	return ahk_guessStudyDateCol(tbl);
}

function ahk_guessStudyDateCol(tbl) {
	var rows = tbl.rows, maxCol = 0, r, c, cells, score, bestCol = -1, bestScore = 0;
	for (r = 1; r < rows.length && r < 12; r++) {
		if (rows[r].cells && rows[r].cells.length > maxCol) maxCol = rows[r].cells.length;
	}
	for (c = 0; c < maxCol; c++) {
		score = 0;
		for (r = 1; r < rows.length && r < 22; r++) {
			cells = rows[r].cells;
			if (cells && cells.length > c && ahk_studyDateKey(ahk_cellText(cells[c]))) score++;
		}
		if (score > bestScore) {
			bestScore = score;
			bestCol = c;
		}
	}
	return bestScore >= 2 ? bestCol : -1;
}

function ahk_areStudyDatesOrdered(keys) {
	var prev = 0, dir = 0, val, cmp, i;
	for (i = 0; i < keys.length; i++) {
		val = ahk_studyDateSortValue(keys[i]);
		if (!val) continue;
		if (!prev) {
			prev = val;
			continue;
		}
		if (val === prev) continue;
		cmp = val > prev ? 1 : -1;
		if (!dir) dir = cmp;
		else if (cmp !== dir) return false;
		prev = val;
	}
	return true;
}

function ahk_shouldKeepNativeRowStyle(row) {
	return row && row._ahkKeepNativeRowStyle;
}

function ahk_restoreRowsStudyDateBg(rows) {
	var i, row;
	if (!rows) return;
	for (i = 0; i < rows.length; i++) {
		row = rows[i];
		if (ahk_shouldKeepNativeRowStyle(row)) continue;
		if (row) row.style.backgroundColor = row._ahkStudyDateBg || '';
	}
}

var AHK_STATS_SESSION_KEY = 'ahkRISStatsFocusV1';

function ahk_statsClearSessionState() {
	try {
		if (window.sessionStorage) window.sessionStorage.removeItem(AHK_STATS_SESSION_KEY);
	} catch (ex) {}
}

function ahk_statsSaveSessionState(sf) {
	var value;
	if (!sf || !sf.activeKey) {
		ahk_statsClearSessionState();
		return;
	}
	try {
		value = [
			encodeURIComponent(sf.activeKey || ''),
			String(sf.lastRowIdx === undefined ? -1 : sf.lastRowIdx),
			encodeURIComponent(sf.lastRowKey || '')
		].join('|');
		window.sessionStorage.setItem(AHK_STATS_SESSION_KEY, value);
	} catch (ex) {}
}

function ahk_statsLoadSessionState(sf) {
	var value, parts, savedIdx;
	try {
		value = window.sessionStorage.getItem(AHK_STATS_SESSION_KEY);
		if (!value) return;
		parts = value.split('|');
		if (parts.length < 3) return;
		savedIdx = parseInt(parts[1], 10);
		if (isNaN(savedIdx)) savedIdx = -1;
		sf.activeKey = decodeURIComponent(parts[0]);
		sf.idx = savedIdx;
		sf.lastRowIdx = savedIdx;
		sf.lastRowKey = decodeURIComponent(parts[2]);
	} catch (ex) {
		ahk_statsClearSessionState();
	}
}

function ahk_getStatsFocusState() {
	if (!window._ahkSF) {
		window._ahkSF = { rows: [], idx: -1, activeKey: '' };
		ahk_statsLoadSessionState(window._ahkSF);
	}
	if (!window._ahkSF.rows) window._ahkSF.rows = [];
	if (window._ahkSF.idx === undefined) window._ahkSF.idx = -1;
	if (window._ahkSF.activeKey === undefined) window._ahkSF.activeKey = '';
	if (window._ahkSF.lastRowIdx === undefined) window._ahkSF.lastRowIdx = -1;
	if (window._ahkSF.lastOpenIdx === undefined) window._ahkSF.lastOpenIdx = -1;
	if (window._ahkSF.awaitingNextAfterMissing === undefined) window._ahkSF.awaitingNextAfterMissing = false;
	if (window._ahkSF.emptyRebuildCount === undefined) window._ahkSF.emptyRebuildCount = 0;
	return window._ahkSF;
}

function ahk_statsSetFrame(row) {
	var cells, j, c;
	if (!row || !row.cells) return;
	cells = row.cells;
	for (j = 0; j < cells.length; j++) {
		c = cells[j];
		c.style.borderTop = '2px solid #f80';
		c.style.borderBottom = '2px solid #f80';
		if (j === 0) c.style.borderLeft = '2px solid #f80';
		if (j === cells.length - 1) c.style.borderRight = '2px solid #f80';
	}
}

function ahk_statsClearFrame(row) {
	var cells, j, c;
	if (!row || !row.cells) return;
	cells = row.cells;
	for (j = 0; j < cells.length; j++) {
		c = cells[j];
		c.style.borderTop = '';
		c.style.borderBottom = '';
		if (j === 0) c.style.borderLeft = '';
		if (j === cells.length - 1) c.style.borderRight = '';
	}
}

function ahk_statsApplyHighlight(rows) {
	var r;
	if (!rows) return;
	for (r = 0; r < rows.length; r++) {
		if (!rows[r]) continue;
		rows[r]._ahkStatsHighlight = true;
		rows[r].style.backgroundColor = '#ffe8b0';
	}
}

function ahk_statsClearHighlight(rows) {
	var r;
	if (!rows) return;
	for (r = 0; r < rows.length; r++) {
		if (!rows[r]) continue;
		rows[r]._ahkStatsHighlight = false;
		ahk_statsClearFrame(rows[r]);
	}
	ahk_restoreRowsStudyDateBg(rows);
}

function ahk_statsRowKey(row) {
	var cells, preferredCols, parts, i, col;
	if (!row || !row.cells) return '';
	cells = row.cells;
	preferredCols = [4, 7, 8, 9, 10, 11, 12, 13];
	parts = [];
	for (i = 0; i < preferredCols.length; i++) {
		col = preferredCols[i];
		if (cells.length > col) parts.push(ahk_cellText(cells[col]));
	}
	if (parts.length < 3) {
		parts = [];
		for (i = 0; i < cells.length; i++) parts.push(ahk_cellText(cells[i]));
	}
	return parts.join('\u001f');
}

function ahk_statsFindRowIndex(rows, rowKey) {
	var i;
	if (!rows || !rowKey) return -1;
	for (i = 0; i < rows.length; i++) {
		if (ahk_statsRowKey(rows[i]) === rowKey) return i;
	}
	return -1;
}

function ahk_syncRISMasterIndex(row) {
	var fields, value;
	if (!row || !row.cells || row.cells.length <= 2) return '';
	// The native RIS row-click handler copies column 2 into this hidden field.
	// callreport(true) later relies on it to locate the next worklist row.
	value = ahk_trimText(row.cells[2].innerHTML || '');
	if (!value) return '';
	fields = document.getElementsByName('masterindex');
	if (!fields || fields.length === 0) return '';
	fields[0].value = value;
	return value;
}

function ahk_openListRow(row) {
	var expectedMasterIndex, fields;
	if (!row) return;
	expectedMasterIndex = ahk_syncRISMasterIndex(row);
	// Use the browser's native click so Enter follows the same RIS path as a
	// physical mouse click. jQuery's synthetic event can bypass/alter legacy
	// IE handlers that update the worklist after opening a study.
	try {
		if (row.click) {
			row.click();
			// Guard against another legacy handler leaving the next-study cursor
			// stale even though the report popup opened successfully.
			if (expectedMasterIndex) {
				fields = document.getElementsByName('masterindex');
				if (fields && fields.length > 0 && String(fields[0].value) !== expectedMasterIndex) {
					fields[0].value = expectedMasterIndex;
				}
			}
			return;
		}
	} catch (ex) {}
	$(row).trigger('click');
	if (expectedMasterIndex) ahk_syncRISMasterIndex(row);
}

function ahk_statsOpenFocusedRow() {
	var sf = ahk_getStatsFocusState(), row;
	if (sf && sf.awaitingNextAfterMissing && sf.rows && sf.rows.length > 0 && sf.focusRow) {
		sf.focusRow((sf.idx + 1) % sf.rows.length);
	}
	if (!sf || !sf.rows || sf.idx < 0 || sf.idx >= sf.rows.length) return;
	row = sf.rows[sf.idx];
	sf.lastRowKey = ahk_statsRowKey(row);
	sf.lastRowIdx = sf.idx;
	sf.awaitingNextAfterMissing = false;
	ahk_statsSaveSessionState(sf);
	ahk_openListRow(row);
	// The report-opening handler can update the worklist without detaching the
	// selected row, which the heartbeat cannot always detect. Rebuild directly
	// after the click so the focused cursor is reapplied to the updated list.
	ahk_statsScheduleRebuild(300);
}

function ahk_parseStatsKey(key) {
	var p;
	if (!key) return null;
	p = key.indexOf('_');
	if (p < 1) return null;
	return { mod: key.substring(0, p), src: key.substring(p + 1) };
}

function ahk_rowMatchesStatsFilter(row, tbl, myName, mod, src) {
	var cells, ownerCol, statusCol, owner, status, examType, examItem, srcText;
	if (!row || !row.cells || !tbl) return false;
	cells = row.cells;
	if (cells.length < 19) return false;
	ownerCol = ahk_findOwnerCol(tbl);
	statusCol = ahk_findStatusCol(tbl);
	owner = ownerCol >= 0 && cells.length > ownerCol ? ahk_cellText(cells[ownerCol]) : (cells.length > 13 ? ahk_cellText(cells[13]) : '');
	status = statusCol >= 0 && cells.length > statusCol ? ahk_cellText(cells[statusCol]) : (cells.length > 18 ? ahk_cellText(cells[18]) : '');
	if (!myName || owner !== myName) return false;
	if (status !== '\u5c1a\u672a\u8655\u7406') return false;
	examType = ahk_cellText(cells[8]);
	examItem = ahk_cellText(cells[9]);
	srcText = ahk_cellText(cells[11]);
	if (/\u8cc7\u6e90|\u5171\u4eab|\u5916\u9662/.test(examItem)) return false;
	return ahk_getModalityGroup(examType) === mod && ahk_getSourceGroup(srcText) === src;
}

function ahk_statsEnsureHeartbeat() {
	if (window._ahkStatsHeartbeat) return;
	window._ahkStatsHeartbeat = window.setInterval(function() {
		var sf = window._ahkSF, tbl, keyParts, idx, row, rowTbl, needsRebuild;
		if (!sf || !sf.activeKey || !sf.rows || sf.rows.length === 0) return;
		tbl = document.getElementById('row_main');
		if (!tbl) return;
		keyParts = ahk_parseStatsKey(sf.activeKey);
		if (!keyParts) return;
		idx = sf.idx >= 0 && sf.idx < sf.rows.length ? sf.idx : 0;
		row = sf.rows[idx];
		rowTbl = row && row.parentNode ? row.parentNode : null;
		while (rowTbl && ((rowTbl.tagName || '').toUpperCase()) !== 'TABLE') rowTbl = rowTbl.parentNode;
		needsRebuild = (!row || !row.parentNode || rowTbl !== tbl);
		if (!needsRebuild && !ahk_rowMatchesStatsFilter(row, tbl, ahk_getLoginName(), keyParts.mod, keyParts.src)) needsRebuild = true;
		if (needsRebuild) {
			ahk_statsScheduleRebuild(200);
			return;
		}
		ahk_statsApplyHighlight(sf.rows);
		if (!sf.awaitingNextAfterMissing) ahk_statsSetFrame(sf.rows[idx]);
	}, 1000);
}

function ahk_statsScheduleRebuild(delay) {
	if (window._ahkStatsRebuildPending) return;
	window._ahkStatsRebuildPending = true;
	window.setTimeout(function() {
		window._ahkStatsRebuildPending = false;
		ahk_buildStats();
	}, delay || 200);
}

function ahk_scrollPageTop() {
	document.body.scrollTop = 0;
	if (document.documentElement) document.documentElement.scrollTop = 0;
}

function ahk_triggerButton(id) {
	var btn = document.getElementById(id);
	if (!btn) return;
	try {
		$('#' + id).trigger('click');
	} catch (ex) {
		try { btn.click(); } catch (ex2) {}
	}
}

function ahk_applyOneWeekResetPreset() {
	ahk_scrollPageTop();
	ahk_triggerButton('ahk_date_interval_1wk');
	ahk_triggerButton('ahk_reset');
}

function ahk_buildStats() {
	var old = document.getElementById('ahk_stats_div');
	if (old) old.parentNode.removeChild(old);
	var myName = ahk_getLoginName();
	var tbl = document.getElementById('row_main');
	if (!tbl) return;
	var rows = tbl.rows;
	var groups = ['CT', 'MR', 'XR', 'US', 'MG', 'BMD', '\u5176\u4ed6'];
	var stats = {};
	var gi, g;
	for (gi = 0; gi < groups.length; gi++) {
		stats[groups[gi]] = { 'E': [], 'O': [], 'A': [] };
	}
	var studyDateCol = ahk_findStudyDateCol(tbl);
	var ownerCol = ahk_findOwnerCol(tbl);
	var statusCol = ahk_findStatusCol(tbl);
	var prevDateKey = null, useDateAlt = false, dateKeys = [], datedCount = 0, ri = 1;
	var seq = (window._ahkRowEnhanceSeq || 0) + 1;
	window._ahkRowEnhanceSeq = seq;
	if (studyDateCol >= 0) tbl._ahkStudyDateCol = studyDateCol;
	function scanStep() {
		if (window._ahkRowEnhanceSeq !== seq) return;
		var stop = Math.min(ri + 80, rows.length), row, cells, dateKey, dateBg, owner, examType, examItem, srcText, status, mod, src;
		for (; ri < stop; ri++) {
			row = rows[ri];
			cells = row.cells;
			if (!cells) continue;
			status = statusCol >= 0 && cells.length > statusCol ? ahk_cellText(cells[statusCol]) : (cells.length > 18 ? ahk_cellText(cells[18]) : '');
			row._ahkKeepNativeRowStyle = (status === '\u5df2\u767c\u9001' || status === '\u7de8\u8f2f\u4e2d');
			if (row._ahkKeepNativeRowStyle && !row._ahkStatsHighlight) row.style.backgroundColor = '';
			if (studyDateCol >= 0 && cells.length > studyDateCol) {
				row._ahkStudyDateBg = '';
				dateKey = ahk_studyDateKey(ahk_cellText(cells[studyDateCol]));
				if (dateKey) {
					if (prevDateKey !== null && dateKey !== prevDateKey) useDateAlt = !useDateAlt;
					dateBg = useDateAlt ? '#f2f2f2' : '';
					row._ahkStudyDateBg = dateBg;
					if (!row._ahkStatsHighlight && !ahk_shouldKeepNativeRowStyle(row)) row.style.backgroundColor = dateBg;
					prevDateKey = dateKey;
					dateKeys.push(dateKey);
					datedCount++;
				} else if (!row._ahkStatsHighlight && !ahk_shouldKeepNativeRowStyle(row)) {
					row.style.backgroundColor = '';
				}
			}
			owner = ownerCol >= 0 && cells.length > ownerCol ? ahk_cellText(cells[ownerCol]) : (cells.length > 13 ? ahk_cellText(cells[13]) : '');
			if (myName && owner === myName && ownerCol >= 0 && cells.length > ownerCol) {
				ahk_addClass(cells[ownerCol], 'highlight-cell');
				cells[ownerCol].style.fontWeight = 'bold';
				cells[ownerCol].style.backgroundColor = 'lightgray';
			}
			if (cells.length < 19) continue;
			examType = ahk_cellText(cells[8]);
			examItem = ahk_cellText(cells[9]);
			srcText  = ahk_cellText(cells[11]);
			if (!myName || owner !== myName) continue;
			if (status !== '\u5c1a\u672a\u8655\u7406') continue;
			if (/\u8cc7\u6e90|\u5171\u4eab|\u5916\u9662/.test(examItem)) continue;
			mod = ahk_getModalityGroup(examType);
			src = ahk_getSourceGroup(srcText);
			stats[mod][src].push(row);
		}
		if (ri < rows.length) {
			setTimeout(scanStep, 0);
		} else {
			if (datedCount > 1) tbl._ahkStudyDatesOrdered = ahk_areStudyDatesOrdered(dateKeys);
			ahk_renderStatsBar(stats, groups);
		}
	}
	scanStep();
}

function ahk_renderStatsBar(stats, groups) {
	var div = document.createElement('div');
	div.id = 'ahk_stats_div';
	div.style.cssText = 'text-align:center;padding:3px 2px;font-family:Calibri,Arial;background:#eef4ff;border:1px solid #99b;margin:2px 0;';
	var sf = ahk_getStatsFocusState();
	var gi, g;
	function _sfSetFrame(row) {
		ahk_statsSetFrame(row);
	}
	function _sfClearFrame(row) {
		ahk_statsClearFrame(row);
	}
	function _sfFocusRow(idx) {
		var sf = ahk_getStatsFocusState(), focusedKey;
		if (sf.idx >= 0 && sf.idx < sf.rows.length) _sfClearFrame(sf.rows[sf.idx]);
		sf.idx = idx;
		if (idx >= 0 && idx < sf.rows.length) {
			sf.awaitingNextAfterMissing = false;
			_sfSetFrame(sf.rows[idx]);
			focusedKey = ahk_statsRowKey(sf.rows[idx]);
			sf.lastRowKey = focusedKey;
			sf.lastRowIdx = idx;
			if (sf.lastOpenKey && focusedKey !== sf.lastOpenKey) {
				sf.lastOpenKey = '';
				sf.lastOpenIdx = -1;
			}
			ahk_statsSaveSessionState(sf);
			sf.rows[idx].scrollIntoView(false);
		}
	}
	function _sfCancel() {
		var sf = ahk_getStatsFocusState();
		if (sf.idx >= 0 && sf.idx < sf.rows.length) _sfClearFrame(sf.rows[sf.idx]);
		ahk_statsClearHighlight(sf.rows);
		sf.rows = []; sf.idx = -1; sf.activeKey = ''; sf.activeMod = ''; sf.activeSrc = '';
		sf.lastRowKey = ''; sf.lastRowIdx = -1; sf.lastOpenKey = ''; sf.lastOpenIdx = -1;
		sf.emptyRebuildCount = 0;
		sf.awaitingNextAfterMissing = false;
		ahk_statsClearSessionState();
		document.body.scrollTop = 0;
		if (document.documentElement) document.documentElement.scrollTop = 0;
	}
	sf.cancel = _sfCancel;
	sf.focusRow = _sfFocusRow;
	function _sfRestoreActiveSelection() {
		var sf = ahk_getStatsFocusState(), oldIdx = sf.idx, keyParts, rowsRef, foundIdx, cursorIdx;
		if (!sf.activeKey) return;
		keyParts = ahk_parseStatsKey(sf.activeKey);
		if (!keyParts || !stats[keyParts.mod] || !stats[keyParts.mod][keyParts.src] || stats[keyParts.mod][keyParts.src].length === 0) {
			// Opening a study can briefly leave the list without any matching rows.
			// Keep the CT-* selection and retry instead of treating that transient
			// state as the user cancelling stats navigation.
			if (keyParts && stats[keyParts.mod] && stats[keyParts.mod][keyParts.src] && (sf.emptyRebuildCount || 0) < 10) {
				sf.emptyRebuildCount = (sf.emptyRebuildCount || 0) + 1;
				ahk_statsClearHighlight(sf.rows);
				sf.rows = []; sf.idx = -1;
				sf.awaitingNextAfterMissing = true;
				ahk_statsScheduleRebuild(500);
				return;
			}
			ahk_statsClearHighlight(sf.rows);
			sf.rows = []; sf.idx = -1; sf.activeKey = ''; sf.activeMod = ''; sf.activeSrc = '';
			sf.lastRowKey = ''; sf.lastRowIdx = -1; sf.lastOpenKey = ''; sf.lastOpenIdx = -1;
			sf.emptyRebuildCount = 0;
			sf.awaitingNextAfterMissing = false;
			ahk_statsClearSessionState();
			return;
		}
		sf.emptyRebuildCount = 0;
		ahk_statsClearHighlight(sf.rows);
		rowsRef = stats[keyParts.mod][keyParts.src];
		sf.rows = rowsRef;
		sf.activeMod = keyParts.mod;
		sf.activeSrc = keyParts.src;
		ahk_statsApplyHighlight(rowsRef);
		// Restore from the focused cursor. Mouse and Enter must follow the same
		// path here; a separate "opened" cursor made Enter-only navigation lose
		// its selection after the RIS refreshed the row.
		foundIdx = ahk_statsFindRowIndex(rowsRef, sf.lastRowKey);
		if (foundIdx >= 0) {
			_sfFocusRow(foundIdx);
		} else {
			cursorIdx = sf.lastRowIdx >= 0 ? sf.lastRowIdx : oldIdx;
			if (cursorIdx < 0) cursorIdx = 0;
			if (cursorIdx > rowsRef.length) cursorIdx = rowsRef.length;
			sf.idx = cursorIdx - 1;
			if (sf.idx < -1) sf.idx = -1;
			if (sf.idx >= rowsRef.length) sf.idx = rowsRef.length - 1;
			sf.awaitingNextAfterMissing = true;
		}
		ahk_statsEnsureHeartbeat();
	}
	function makeClickHandler(mod2, src2, rowsRef) {
		return function() {
			var sf = ahk_getStatsFocusState();
			var key = mod2 + '_' + src2;
			var sameKeyActive = (sf.activeKey === key && sf.rows && sf.rows.length > 0);
			// Cancel search mode if active
			if (window._ahkSearch) window._ahkSearch();
			// Clear current frame before resetting highlights
			if (sf.idx >= 0 && sf.idx < sf.rows.length) _sfClearFrame(sf.rows[sf.idx]);
			ahk_statsClearHighlight(sf.rows);
			// Toggle: if same key, just clear; otherwise highlight and focus first row
			if (sameKeyActive) {
				sf.rows = []; sf.idx = -1; sf.activeKey = ''; sf.activeMod = ''; sf.activeSrc = '';
				sf.lastRowKey = ''; sf.lastRowIdx = -1; sf.lastOpenKey = ''; sf.lastOpenIdx = -1;
				sf.awaitingNextAfterMissing = false;
				ahk_statsClearSessionState();
			} else {
				sf.activeKey = key;
				sf.activeMod = mod2;
				sf.activeSrc = src2;
				sf.rows = rowsRef;
				ahk_statsApplyHighlight(rowsRef);
				sf.lastOpenKey = ''; sf.lastOpenIdx = -1;
				sf.emptyRebuildCount = 0;
				sf.awaitingNextAfterMissing = false;
				_sfFocusRow(0);
				ahk_statsEnsureHeartbeat();
			}
		};
	}
	var hasAny = false;
	for (gi = 0; gi < groups.length; gi++) {
		g = groups[gi];
		var total = stats[g]['E'].length + stats[g]['O'].length + stats[g]['A'].length;
		if (total === 0) continue;
		hasAny = true;
		var grpSpan = document.createElement('span');
		grpSpan.style.cssText = 'margin:0 8px;white-space:nowrap;';
		var lbl = document.createElement('b');
		lbl.appendChild(document.createTextNode(g + ': '));
		grpSpan.appendChild(lbl);
		var subDefs = [{ key:'E', color:'red' }, { key:'A', color:'blue' }, { key:'O', color:'black' }];
		for (var si = 0; si < subDefs.length; si++) {
			var sk = subDefs[si].key;
			var cnt = stats[g][sk].length;
			if (si > 0) grpSpan.appendChild(document.createTextNode(', '));
			var numSpan = document.createElement('span');
			numSpan.style.cssText = 'font-weight:bold;color:' + subDefs[si].color + ';cursor:pointer;text-decoration:underline;';
			numSpan.title = g + '-' + sk + '=' + cnt;
			numSpan.appendChild(document.createTextNode('\u00a0' + cnt + '\u00a0'));
			numSpan.onclick = makeClickHandler(g, sk, stats[g][sk]);
			grpSpan.appendChild(numSpan);
		}
		div.appendChild(grpSpan);
	}
	if (!hasAny) {
		div.style.display = 'none';
	}
	var listDiv = document.getElementById('list');
	if (listDiv && listDiv.parentNode) {
		listDiv.parentNode.insertBefore(div, listDiv);
	} else {
		document.body.appendChild(div);
	}
	_sfRestoreActiveSelection();
}

function ahk_inpage_search_init() {
	if (document.getElementById('ahk_srch_bar')) return;
	var bar = document.createElement('div');
	bar.id = 'ahk_srch_bar';
	bar.style.cssText = 'position:absolute;right:10px;z-index:9999;background:#fff8dc;border:2px solid #f80;padding:2px 8px;display:none;font-family:Calibri,Arial;white-space:nowrap;';
	var inp = document.createElement('input');
	inp.type = 'text';
	inp.id = 'ahk_srch_inp';
	inp.style.cssText = 'width:80px;border:1px solid #aaa;margin:0 4px;';
	inp.maxLength = 20;
	var lbl = document.createElement('span');
	lbl.id = 'ahk_srch_lbl';
	lbl.style.cssText = 'color:#666;font-size:11px;';
	bar.appendChild(document.createTextNode('/'));
	bar.appendChild(inp);
	bar.appendChild(lbl);
	document.body.appendChild(bar);
	var _active = false, _matches = [], _matchIdx = 0, _savedCells = [];
	function _trim(s) { return (s || '').replace(/^\s+|\s+$/g, ''); }
	function _resetHL() {
		var i;
		for (i = 0; i < _savedCells.length; i++) _savedCells[i].el.innerHTML = _savedCells[i].html;
		_savedCells = [];
		for (i = 0; i < _matches.length; i++) _matches[i].style.outline = '';
		_matches = []; _matchIdx = 0; lbl.innerHTML = '';
	}
	function _clearRowFrame(row) {
		var cells = row.cells, j, c;
		for (j = 0; j < cells.length; j++) {
			c = cells[j];
			c.style.borderTop = '';
			c.style.borderBottom = '';
			if (j === 0) c.style.borderLeft = '';
			if (j === cells.length - 1) c.style.borderRight = '';
		}
	}
	function _setRowFrame(row) {
		var cells = row.cells, j, c;
		for (j = 0; j < cells.length; j++) {
			c = cells[j];
			c.style.borderTop = '2px solid #f80';
			c.style.borderBottom = '2px solid #f80';
			if (j === 0) c.style.borderLeft = '2px solid #f80';
			if (j === cells.length - 1) c.style.borderRight = '2px solid #f80';
		}
	}
	function _updateFocus(idx) {
		var i;
		for (i = 0; i < _matches.length; i++) _clearRowFrame(_matches[i]);
		if (idx >= 0 && idx < _matches.length) {
			_matchIdx = idx;
			_setRowFrame(_matches[idx]);
			_matches[idx].scrollIntoView(false);
			lbl.innerHTML = ' ' + (idx + 1) + '/' + _matches.length;
		}
	}
	function _doSearch(q) {
		_resetHL();
		if (!q) return;
		var tbl = document.getElementById('row_main');
		if (!tbl) return;
		var rows = tbl.rows, i, cells, txt, idx, cell;
		var useCol = 12;
		for (i = 1; i < rows.length; i++) {
			cells = rows[i].cells;
			if (cells.length > 4 && _trim(cells[4].innerText).indexOf(q) !== -1) { useCol = 4; break; }
		}
		for (i = 1; i < rows.length; i++) {
			cells = rows[i].cells;
			if (cells.length <= useCol) continue;
			cell = cells[useCol];
			txt = _trim(cell.innerText);
			idx = txt.indexOf(q);
			if (idx === -1) continue;
			_savedCells.push({el: cell, html: cell.innerHTML});
			cell.innerHTML = txt.substring(0, idx) + '<span style="background:#ff0;color:#000;font-weight:bold;">' + txt.substring(idx, idx + q.length) + '</span>' + txt.substring(idx + q.length);
			_matches.push(rows[i]);
		}
		if (_matches.length > 0) { _updateFocus(0); } else { lbl.innerHTML = ' \u7121'; }
	}
	function _updatePos() {
		var st = document.body.scrollTop || 0;
		bar.style.top = (st + 2) + 'px';
	}
	function _openMatch() {
		if (_matchIdx >= 0 && _matchIdx < _matches.length) $(_matches[_matchIdx]).trigger('click');
	}
	function _exitSearch() {
		_active = false; _resetHL(); bar.style.display = 'none'; inp.value = '';
		document.body.scrollTop = 0;
		if (document.documentElement) document.documentElement.scrollTop = 0;
	}
	window._ahkSearch = _exitSearch;
	inp.onkeydown = function(e) {
		e = e || window.event; var kc = e.keyCode;
		if (kc === 27) { _exitSearch(); e.returnValue = false; return false; }
		if (kc === 9)  { if (_matches.length > 0) _updateFocus((_matchIdx + 1) % _matches.length); e.returnValue = false; return false; }
		if (kc === 13) { _openMatch(); e.returnValue = false; return false; }
	};
	inp.onkeypress = function(e) {
		e = e || window.event;
		var ch = (e.charCode !== undefined && e.charCode > 0) ? e.charCode : e.keyCode;
		if (ch >= 32 && (ch < 48 || ch > 57)) { e.returnValue = false; return false; }
	};
	inp.onkeyup = function(e) {
		e = e || window.event; var kc = e.keyCode;
		if (kc === 27 || kc === 13 || kc === 9) return;
		var q = _trim(inp.value);
		_doSearch(q.length >= 3 ? q : '');
	};
	var _prevDocKD = document.onkeydown;
	var _prevDocKP = document.onkeypress;
	var _prevDocKU = document.onkeyup;
	var _lastRKeyTime = 0;
	var _suppressStatsEnter = false;
	var _statsEnterQueryButton = null;
	var _statsEnterQueryWasDisabled = false;
	var _statsEnterForm = null;
	var _statsEnterPreviousOnSubmit = null;
	function _blockStatsEnterSubmit() {
		_statsEnterQueryButton = document.getElementById('QueryButton');
		if (_statsEnterQueryButton) {
			_statsEnterQueryWasDisabled = !!_statsEnterQueryButton.disabled;
			_statsEnterQueryButton.disabled = true;
		}
		try {
			_statsEnterForm = document.forms.MJB3WForm || document.forms['MJB3WForm'];
			if (_statsEnterForm) {
				_statsEnterPreviousOnSubmit = _statsEnterForm.onsubmit;
				_statsEnterForm.onsubmit = function() { return false; };
			}
		} catch (ex) {
			_statsEnterForm = null;
		}
	}
	function _releaseStatsEnterSubmit() {
		if (_statsEnterQueryButton) {
			_statsEnterQueryButton.disabled = _statsEnterQueryWasDisabled;
		}
		if (_statsEnterForm) {
			_statsEnterForm.onsubmit = _statsEnterPreviousOnSubmit;
		}
		_statsEnterQueryButton = null;
		_statsEnterForm = null;
		_statsEnterPreviousOnSubmit = null;
	}
	function _cancelKeyEvent(e) {
		e = e || window.event;
		if (!e) return false;
		e.returnValue = false;
		e.cancelBubble = true;
		if (e.preventDefault) e.preventDefault();
		if (e.stopPropagation) e.stopPropagation();
		return false;
	}
	document.onkeypress = function(e) {
		e = e || window.event;
		var kc = e ? (e.keyCode || e.which) : 0;
		if (_suppressStatsEnter && kc === 13) return _cancelKeyEvent(e);
		if (_prevDocKP) return _prevDocKP(e);
	};
	document.onkeyup = function(e) {
		e = e || window.event;
		var kc = e ? (e.keyCode || e.which) : 0;
		if (_suppressStatsEnter && kc === 13) return _cancelKeyEvent(e);
		if (_prevDocKU) return _prevDocKU(e);
	};
	document.onkeydown = function(e) {
		e = e || window.event; var kc = e.keyCode;
		var src = e.srcElement || (e.target || null);
		var tag = src ? ((src.tagName || '').toUpperCase()) : '';
		var isInput = (tag === 'INPUT' || tag === 'SELECT' || tag === 'TEXTAREA');
		// Open chart-no search with '/'
		if (!_active && kc === 191 && !isInput) {
			var sf0 = window._ahkSF;
			if (sf0 && sf0.cancel && sf0.rows && sf0.rows.length > 0) sf0.cancel();
			_active = true; _updatePos(); bar.style.display = ''; inp.value = ''; _resetHL(); inp.focus();
			e.returnValue = false; return false;
		}
		// Search-mode ESC (when focus is outside the input)
		if (_active && kc === 27 && !isInput) { _exitSearch(); e.returnValue = false; return false; }
		// Stats-mode keyboard nav (only when search not active, not in a form field)
		if (!_active && !isInput) {
			if (kc === 82) {
				var now = (new Date()).getTime();
				if (_lastRKeyTime && now - _lastRKeyTime < 450) {
					_lastRKeyTime = 0;
					ahk_applyOneWeekResetPreset();
					e.returnValue = false; if (e.preventDefault) e.preventDefault(); return false;
				}
				_lastRKeyTime = now;
			} else {
				_lastRKeyTime = 0;
			}
			var sf = window._ahkSF;
			if (sf && sf.rows && sf.rows.length > 0) {
				if (kc === 9)  { sf.focusRow((sf.idx + 1) % sf.rows.length); e.returnValue = false; return false; }
				if (kc === 13) {
					// Cancel before opening the report. Otherwise the RIS form also
					// handles Enter and reloads the entire worklist document, losing
					// the in-page subgroup selection state.
					if (_suppressStatsEnter) return _cancelKeyEvent(e);
					_suppressStatsEnter = true;
					// Disable the RIS default Query action for the entire Enter event.
					// If it submits, the opener document and its masterindex are replaced,
					// leaving the post-send bridge page unable to call the next study.
					_blockStatsEnterSubmit();
					_cancelKeyEvent(e);
					// Run the click after IE finishes dispatching this Enter sequence.
					// A synchronous click can race the form's implicit-submit handling
					// and replace the opener document after the report window is made.
					window.setTimeout(function() {
						try {
							ahk_statsOpenFocusedRow();
						} finally {
							window.setTimeout(function() {
								_releaseStatsEnterSubmit();
								_suppressStatsEnter = false;
							}, 750);
						}
					}, 0);
					return false;
				}
				if (kc === 27) { sf.cancel(); e.returnValue = false; return false; }
			} else if (kc === 27) {
				// Global ESC: scroll to top
				ahk_scrollPageTop();
				e.returnValue = false; return false;
			}
		}
		if (_prevDocKD) return _prevDocKD(e);
	};
	var _prevWinScroll = window.onscroll;
	window.onscroll = function() {
		if (_active) _updatePos();
		if (_prevWinScroll) _prevWinScroll();
	};
}

function scrollTopButton() {
	// Create the button element and append it to the body
	var $scrollToTopBtn = $('<button>')
		.attr('id', 'scrollToTopBtn')
		.text('→ Top')
		.css({
			position: 'absolute', // Use absolute positioning
			top: $(window).scrollTop() + 10 + 'px', // Set initial position relative to scroll
			right: '10px',
			background: '#007BFF',
			color: '#fff',
			padding: '10px 15px',
			border: 'none',
			borderRadius: '5px', // May not work in older browsers but won't break
			cursor: 'pointer',
			zIndex: 1000,
			display: 'none' // Initially hide the button
		})
		.click(function () {
			// Scroll to top with animation
			$('html, body').animate({ scrollTop: 0 }, 500);
		})
		.hover(
			function () {
				$(this).css('background', '#0056b3');
			},
			function () {
				$(this).css('background', '#007BFF');
			});

	// Append the button to the body
	$('body').append($scrollToTopBtn);

	// Show or hide the button based on scroll position
	$(window).scroll(function () {
		// Update the button's position
		$scrollToTopBtn.css('top', $(window).scrollTop() + 10 + 'px');

		// Show or hide the button
		if ($(window).scrollTop() > 200) {
			$scrollToTopBtn.fadeIn();
		} else {
			$scrollToTopBtn.fadeOut();
		}
	});
}

function ahk_study_dblclick_copy() {
	var sel = '#maindiv2 > table > tbody > tr:nth-child(2) > td > table > tbody > tr:nth-child(3) > td.boxContent > table > tbody > tr:nth-child(1) > td > table td';
	$(sel).css('cursor', 'pointer').dblclick(function() {
		var t = $.trim($(this).text());
		if (!t) return;
		if (window.clipboardData) {
			window.clipboardData.setData("Text", t);
		}
		var $el = $(this);
		var bg = $el.css('backgroundColor');
		$el.css('backgroundColor', 'yellow');
		setTimeout(function(){ $el.css('backgroundColor', bg); }, 200);
	});
}


if(!$('#ahk_enhanced_search_div').length){
	
	$('<div>').attr({'id': 'ahk_enhanced_search_div', 'align': 'center'}).insertBefore($('div#list'));
	$('<input type=button />').attr('id', 'ahk_date_interval_1wk').attr('class', 'ahk_set_date').val('1wk').click(ahk_date_interval).appendTo($('#ahk_enhanced_search_div'));
	$('<input type=button />').attr('id', 'ahk_date_interval_4wk').attr('class', 'ahk_set_date').val('4wk').click(ahk_date_interval).appendTo($('#ahk_enhanced_search_div'));
	$('<input type=button />').attr('id', 'ahk_reset').val('Reset').click(ahk_reset_fn).appendTo($('#ahk_enhanced_search_div'));
	$('<input type=button />').attr('id', 'ahk_brus').val('US').click(ahk_us_fn).appendTo($('#ahk_enhanced_search_div'));
	$('<input type=button />').attr('id', 'ahk_usbx').val('USBx').click(ahk_usbx_fn).appendTo($('#ahk_enhanced_search_div'));
	$('<input type=button />').attr('id', 'ahk_mammo').val('Mammo').click(ahk_mammo_fn).appendTo($('#ahk_enhanced_search_div'));
	$('<input type=button />').attr('id', 'ahk_ct').val('CT').click(ahk_ct_fn).appendTo($('#ahk_enhanced_search_div'));
	$('<input type=button />').attr('id', 'ahk_mr').val('MR').click(ahk_mr_fn).appendTo($('#ahk_enhanced_search_div'));
	$('<input type=button />').attr('id', 'ahk_xr').val('XR').click(ahk_xr_fn).appendTo($('#ahk_enhanced_search_div'));
	$('<input type=button />').attr('id', 'ahk_sp').val('Special').click(ahk_sp_fn).appendTo($('#ahk_enhanced_search_div'));
	$('<input type=button />').attr('id', 'ahk_er').val('ER').click(ahk_er_fn).appendTo($('#ahk_enhanced_search_div'));
	$('<input type=button />').attr('id', 'ahk_search_chartno').val('Chart#').click(ahk_search_chartno_fn).appendTo($('#ahk_enhanced_search_div'));
	
	
}
ahk_statusCookieInit();
ahk_buildStats();
ahk_inpage_search_init();
if(!$('#scrollToTopBtn').length){
	scrollTopButton();
}
ahk_study_dblclick_copy();

$('#ahk_enhanced_search_div > input').css(
	'width', '5%').css( 
	'border', '1px solid black').css(
	'background', '#66ffcc').css(
	'font-weight', "700").css(
	'font-family', "Calibri").css(
	'-moz-border-radius', "2px").css(
	'-webkit-border-radius', "2px").css(
	'border-radius', "2px").css(
	'padding', '2px');
	
$('#ahk_reset').css('background', '#ffcc00');
$('.ahk_set_date').css('background', '#99ccff');
