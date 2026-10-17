# Called by test_ch_ris_list_status.py --ie. Uses only a localhost fixture.
param([Parameter(Mandatory=$true)][string]$FixtureUrl)
$ErrorActionPreference = 'Stop'
if (([uri]$FixtureUrl).Host -ne '127.0.0.1') { throw 'The IE test requires a localhost fixture.' }
Add-Type -AssemblyName System.Windows.Forms
$form = New-Object System.Windows.Forms.Form
$browser = New-Object System.Windows.Forms.WebBrowser
function Wait-Fixture([string]$PreviousLoad = '') {
    $deadline = (Get-Date).AddSeconds(10)
    do {
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 10
        if ((Get-Date) -gt $deadline) { throw 'IE fixture did not load.' }
        $loaded = $null -ne $browser.Document -and $browser.ReadyState -eq 'Complete' -and $browser.Document.GetElementById('ahk_reset')
        if ($loaded -and $PreviousLoad) {
            $loaded = $browser.Document.GetElementById('fixture-load').GetAttribute('value') -ne $PreviousLoad
        }
    } until ($loaded)
}
function Invoke-Check([string]$Code) {
    $result = $browser.Document.InvokeScript('runTestCode', [object[]]@($Code))
    if ($result -ne 'PASS') { throw "IE test failed: $result" }
}
try {
    $form.Controls.Add($browser)
    $browser.ScriptErrorsSuppressed = $true
    $null = $form.Handle
    $null = $browser.Handle
    $browser.Navigate($FixtureUrl)
    Wait-Fixture
    Invoke-Check @'
(function(){
  if(document.documentMode !== 5) return 'expected IE mode 5';
  document.cookie = 'RIS_TEST_AUTH=keep; path=/';
  document.cookie = 'selected_status=00; path=/';
  document.cookie = 'selected_status=2; path=/webcvis';
  var field = document.getElementsByName('status')[0];
  field.value = '2';
  field.fireEvent('onchange');
  var cookies = document.cookie.match(/(?:^|;\s*)selected_status=/g) || [];
  if(cookies.length !== 1 || $.cookie('selected_status') !== '2') return 'duplicate cookies remain: ' + cookies.length;
  if($.cookie('RIS_TEST_AUTH') !== 'keep') return 'unrelated cookie changed';
  return 'PASS';
})();
'@
    foreach ($value in @('00', '2', '')) {
        Invoke-Check "(function(){var f=document.getElementsByName('status')[0];f.value='$value';f.fireEvent('onchange');return $.cookie('selected_status') === '$value' ? 'PASS' : 'manual change was not saved';})();"
        $oldLoad = $browser.Document.GetElementById('fixture-load').GetAttribute('value')
        $browser.Document.GetElementById('QueryButton').InvokeMember('click')
        Wait-Fixture $oldLoad
        Invoke-Check "document.getElementsByName('status')[0].value === '$value' ? 'PASS' : 'Query lost manual status';"
        $oldLoad = $browser.Document.GetElementById('fixture-load').GetAttribute('value')
        $browser.Refresh([System.Windows.Forms.WebBrowserRefreshOption]::Completely)
        Wait-Fixture $oldLoad
        Invoke-Check "document.getElementsByName('status')[0].value === '$value' ? 'PASS' : 'Refresh lost manual status';"
    }
    Invoke-Check "ahk_reset_fn(); $.cookie('selected_status') === '00' ? 'PASS' : 'Reset was not saved';"
    Invoke-Check "ahk_ct_fn({altKey:true, shiftKey:true}); $.cookie('selected_status') === '' ? 'PASS' : 'Alt+CT was not saved';"
    Invoke-Check "document.getElementById('ClearAllButton').click(); $.cookie('selected_status') === '' ? 'PASS' : 'Clear was not saved';"
    Write-Output 'PASS: IE mode 5 cookie repair, native change, Query/refresh, and presets'
} finally {
    if ($browser.Document) {
        # Remove only localhost fixture cookies.
        try { $browser.Document.Cookie = 'selected_status=; expires=Thu, 01 Jan 1970 00:00:00 GMT; path=/webcvis/MJB' } catch {}
        try { $browser.Document.Cookie = 'RIS_TEST_AUTH=; expires=Thu, 01 Jan 1970 00:00:00 GMT; path=/' } catch {}
    }
    $browser.Dispose()
    $form.Dispose()
}
