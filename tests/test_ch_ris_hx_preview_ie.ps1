# Run with Windows PowerShell: powershell -NoProfile -STA -File tests/test_ch_ris_hx_preview_ie.ps1
# Uses a private, hidden WebBrowser control. Does not access live RIS pages.
param([string]$EnhancerPath = (Join-Path $PSScriptRoot '../Lib/CH_RIS_HX_enhance.js'))
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$source = [System.IO.File]::ReadAllText((Resolve-Path $EnhancerPath))
$form = New-Object System.Windows.Forms.Form
$browser = New-Object System.Windows.Forms.WebBrowser
try {
    $form.Controls.Add($browser)
    $form.ClientSize = New-Object System.Drawing.Size(800, 600)
    $browser.Dock = [System.Windows.Forms.DockStyle]::Fill
    $browser.ScriptErrorsSuppressed = $true
    $null = $form.Handle
    $null = $browser.Handle
    $browser.DocumentText = '<html><head><meta http-equiv="X-UA-Compatible" content="IE=5"><script>function runTestCode(code){try{return eval(code);}catch(e){return "SCRIPT ERROR: " + e.message;}}</script></head><body><textarea id="memotx"></textarea><div style="height:1800px"></div></body></html>'
    $deadline = (Get-Date).AddSeconds(15)
    do {
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 10
        if ((Get-Date) -gt $deadline) { throw 'Private IE test document did not load.' }
    } until ($null -ne $browser.Document -and $browser.ReadyState -eq 'Complete')
    $null = $browser.Document.InvokeScript('runTestCode', [object[]]@($source))
    $checks = @'
(function(){
  var failures = [];
  function check(ok, message){ if(!ok) failures.push(message); }
  check(document.documentMode === 5, 'expected IE document mode 5');
  window.chRisHxReset();
  var oldBox = document.getElementById('dbrlist');
  if(oldBox) oldBox.parentNode.removeChild(oldBox);
  var memo = document.getElementById('memotx');
  var lines = [], i;
  for(i = 0; i < 160; i++) lines.push('Long memo line ' + i);
  for(var pass = 0; pass < 2; pass++){
    var scroll = pass * 300;
    var height = document.body.clientHeight;
    memo.style.position = 'absolute';
    memo.style.left = '20px';
    memo.style.top = (scroll + height * 0.6) + 'px';
    memo.value = lines.join('\r\n');
    document.body.scrollTop = scroll;
    var originalHeight = document.body.scrollHeight;
    memo.onmouseover();
    var pv = document.getElementById('ch-ris-hx-memo-preview');
    var r = pv.getBoundingClientRect();
    check(r.top >= 0 && r.bottom <= height, 'panel outside viewport: ' + r.bottom + '/' + height);
    check(parseInt(pv.style.height, 10) > 0, 'missing explicit height');
    check(pv.scrollHeight > pv.clientHeight, 'memo is not scrollable');
    check(document.body.scrollHeight === originalHeight, 'panel increased page height');
    var event = {wheelDelta: -120};
    if(typeof pv.onmousewheel === 'function') pv.onmousewheel(event);
    check(pv.scrollTop > 0, 'IE wheel did not scroll memo');
    check(event.cancelBubble && event.returnValue === false, 'wheel leaked to page');
    check(document.body.scrollTop === scroll, 'IE wheel scrolled page');
    memo.value = 'Short memo';
    memo.onmouseover();
    check(pv.offsetHeight < 100 && pv.scrollTop === 0, 'short memo did not shrink/reset');
  }
  var box = document.createElement('div');
  box.id = 'dbrlist';
  box.style.cssText = 'position:absolute;left:20px;width:250px;height:80px;overflow:auto';
  document.body.appendChild(box);
  for(var layout = 0; layout < 2; layout++){
    if(layout){
      box.innerHTML = '<table><tbody><tr id="history-row"><td>branch</td><td>eio</td><td>status</td><td>2026/09/01</td><td>CT</td><td>Study</td><td>signed</td><td>1</td><td>site</td></tr></tbody></table>';
    } else {
      box.innerHTML = '<table id="row_beforereport"><tbody><tr id="history-row"><td></td><td></td><td></td><td>Study</td><td>CT</td><td></td><td>2026/09/01</td><td></td><td></td><td></td><td></td><td><input type="hidden"></td><td></td></tr></tbody></table>';
    }
    var row = document.getElementById('history-row');
    if(layout) row.setAttribute('title', lines.join('\r\n'));
    else row.cells[11].getElementsByTagName('input')[0].value = lines.join('\r\n');
    window.chRisHxBuild();
    for(var reportPass = 0; reportPass < 2; reportPass++){
      var reportScroll = reportPass * 300;
      var viewportHeight = document.body.clientHeight;
      box.style.top = (reportScroll + viewportHeight * 0.6) + 'px';
      document.body.scrollTop = reportScroll;
      var originalReportHeight = document.body.scrollHeight;
      row.onmouseover();
      var reportPanel = document.getElementById('ch-ris-hx-preview');
      var reportRect = reportPanel.getBoundingClientRect();
      check(reportRect.top >= 0 && reportRect.bottom <= viewportHeight, 'old report outside viewport');
      check(reportRect.right <= document.body.clientWidth, 'old report outside viewport width');
      check(reportPanel.scrollHeight > reportPanel.clientHeight, 'old report is not scrollable');
      check(document.body.scrollHeight === originalReportHeight, 'old report increased page height');
      var reportEvent = {wheelDelta: -120};
      reportPanel.onmousewheel(reportEvent);
      check(reportPanel.scrollTop > 0, 'IE wheel did not scroll old report');
      check(reportPanel.style.display === 'block', 'IE wheel hid old report');
      check(reportEvent.cancelBubble && reportEvent.returnValue === false, 'old report wheel leaked to page');
      check(document.body.scrollTop === reportScroll && box.scrollTop === 0, 'old report wheel scrolled page/table');
    }
  }
  return failures.length ? 'FAIL: ' + failures.join('; ') : 'PASS: IE mode 5 memo/report bounds and internal scrolling';
})();
'@
    foreach ($size in @(@(800, 600), @(360, 220))) {
        $form.ClientSize = New-Object System.Drawing.Size($size[0], $size[1])
        [System.Windows.Forms.Application]::DoEvents()
        $result = $browser.Document.InvokeScript('runTestCode', [object[]]@($checks))
        if ($result -notlike 'PASS:*') { throw "IE test failed: $result" }
        Write-Output "$result ($($size[0]) x $($size[1]))"
    }
} finally {
    $browser.Dispose()
    $form.Dispose()
}
