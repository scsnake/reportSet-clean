#NoEnv
SendMode Input
SetWorkingDir %A_ScriptDir%
#SingleInstance, Force

argCount = %0%
testMode := false
if (argCount >= 1) {
	arg1 = %1%
	if (arg1 = "test")
		testMode := true
}

if (testMode) {
	XR_FractureRunTests()
	ExitApp
}

#include <Dynamic_Hotstring>

/*
XR fracture dynamic hotstring:
  Trigger: x[side][part]bone[,bone...][bone_part]]
  side: optional l/r/b = left/right/bilateral
  part: optional p/d/m = proximal/distal/middle
  bone_part: optional hd/h=head, sh/s=shaft, ba/b=base, nk/n=neck,
             mc=medial condyle, lc=lateral condyle, mp=medial plateau, lp=lateral plateau,
             gt=greater trochanter, lt=lesser trochanter,
             gb=greater tubercle, lb=lesser tubercle, it=intertrochanteric region
  Examples: xh], xph], xlh], xlph], xrhd], xld2p4,3p4]
*/
Dynamic_Hotstring("i)\bx([a-z0-9,]+)\]", "xrFracture", 3, 0)
return

xrFracture:
result := XR_FractureBuildFromCode($.value(1))
if (result = "") {
	ToolTip, Invalid XR fracture hotstring
	SetTimer, XR_FractureClearTooltip, -1000
	return
}
SendInput % "{BS " StrLen($.value(0)) "}"
SendInput % result
return

XR_FractureClearTooltip:
ToolTip
return

XR_FractureRunTests(){
	out := ""
	fail := 0
	fail += XR_FractureAssert(out, "lph", "fracture at left proximal humerus")
	fail += XR_FractureAssert(out, "lphh", "fracture at left proximal humeral head")
	fail += XR_FractureAssert(out, "rdr,uh", "fracture at right distal radial and ulnar heads")
	fail += XR_FractureAssert(out, "bmfsh", "fracture at bilateral middle femoral shafts")
	fail += XR_FractureAssert(out, "lp2p4ba", "fracture at left proximal 2nd metacarpal base")
	fail += XR_FractureAssert(out, "ld2p4,3p4", "fracture at left distal 2nd and 3rd metacarpal bones")
	fail += XR_FractureAssert(out, "bd2p5,3p5b", "fracture at bilateral distal 2nd and 3rd metatarsal bases")
	fail += XR_FractureAssert(out, "h", "fracture at humerus")
	fail += XR_FractureAssert(out, "ph", "fracture at proximal humerus")
	fail += XR_FractureAssert(out, "lh", "fracture at left humerus")
	fail += XR_FractureAssert(out, "r", "fracture at radius")
	fail += XR_FractureAssert(out, "l", "fracture at fibula")
	fail += XR_FractureAssert(out, "p", "fracture at scapula")
	fail += XR_FractureAssert(out, "2p4", "fracture at 2nd metacarpal bone")
	fail += XR_FractureAssert(out, "rhd", "fracture at radial head")
	fail += XR_FractureAssert(out, "lfn", "fracture at left femoral neck")
	fail += XR_FractureAssert(out, "br,un", "fracture at bilateral radial and ulnar necks")
	fail += XR_FractureAssert(out, "tmc", "fracture at tibial medial condyle")
	fail += XR_FractureAssert(out, "t,flc", "fracture at tibial and femoral lateral condyles")
	fail += XR_FractureAssert(out, "ltmp", "fracture at left tibial medial plateau")
	fail += XR_FractureAssert(out, "btlp", "fracture at bilateral tibial lateral plateaus")
	fail += XR_FractureAssert(out, "fgt", "fracture at femoral greater trochanter")
	fail += XR_FractureAssert(out, "flt", "fracture at femoral lesser trochanter")
	fail += XR_FractureAssert(out, "hgb", "fracture at humeral greater tubercle")
	fail += XR_FractureAssert(out, "hlb", "fracture at humeral lesser tubercle")
	fail += XR_FractureAssert(out, "fit", "fracture at femoral intertrochanteric region")
	fail += XR_FractureAssert(out, "bfit", "fracture at bilateral femoral intertrochanteric regions")
	out := (fail ? "FAIL " fail : "PASS") "`r`n" out
	FileDelete, % A_Temp "\xr_fracture_hotstring_test.txt"
	FileAppend, % out, % A_Temp "\xr_fracture_hotstring_test.txt", UTF-8
	if (fail)
		ExitApp, 1
}

XR_FractureAssert(ByRef out, code, expected){
	actual := XR_FractureBuildFromCode(code)
	if (actual = expected) {
		out .= "OK: x" code "] -> " actual "`r`n"
		return 0
	}
	out .= "BAD: x" code "]`r`n  expected: " expected "`r`n  actual:   " actual "`r`n"
	return 1
}

XR_FractureBuildFromCode(code){
	code := Trim(code)
	sideCandidates := ["l", "r", "b", ""]
	partCandidates := ["p", "d", "m", ""]
	for i, sideCode in sideCandidates {
		if (sideCode != "" && SubStr(code, 1, 1) != sideCode)
			continue
		restAfterSide := (sideCode = "") ? code : SubStr(code, 2)
		for j, partCode in partCandidates {
			if (partCode != "" && SubStr(restAfterSide, 1, 1) != partCode)
				continue
			boneCode := (partCode = "") ? restAfterSide : SubStr(restAfterSide, 2)
			if (boneCode = "")
				continue
			result := XR_FractureBuild(sideCode, partCode, boneCode)
			if (result != "")
				return result
		}
	}
	return ""
}

XR_FractureBuild(sideCode, partCode, boneCode){
	sideMap := Object("l", "left", "r", "right", "b", "bilateral")
	partMap := Object("p", "proximal", "d", "distal", "m", "middle")
	sideCode := Trim(sideCode)
	partCode := Trim(partCode)
	boneCode := Trim(boneCode)
	if (sideCode != "" && !sideMap.HasKey(sideCode))
		return ""
	if (partCode != "" && !partMap.HasKey(partCode))
		return ""
	bonePart := XR_FractureExtractBonePart(boneCode)
	if !XR_FractureBoneListValid(boneCode)
		return ""
	hasBonePart := (bonePart != "")
	pluralNouns := (sideCode = "b")
	phrases := XR_FractureBonePhrases(boneCode, hasBonePart, pluralNouns)
	if !IsObject(phrases) || !phrases.MaxIndex()
		return ""
	boneText := XR_FractureJoinBonePhrases(phrases, !hasBonePart)
	if (boneText = "")
		return ""
	prefix := "fracture at"
	if (sideCode != "")
		prefix .= " " sideMap[sideCode]
	if (partCode != "")
		prefix .= " " partMap[partCode]
	if hasBonePart {
		if (sideCode = "b" || phrases.MaxIndex() > 1)
			bonePart := XR_FracturePluralBonePart(bonePart)
		return prefix " " boneText " " bonePart
	}
	return prefix " " boneText
}

XR_FractureExtractBonePart(ByRef boneCode){
	static suffixes
	if !IsObject(suffixes)
		suffixes := [["hd", "head"], ["sh", "shaft"], ["ba", "base"], ["nk", "neck"], ["mc", "medial condyle"], ["lc", "lateral condyle"], ["mp", "medial plateau"], ["lp", "lateral plateau"], ["gt", "greater trochanter"], ["lt", "lesser trochanter"], ["gb", "greater tubercle"], ["lb", "lesser tubercle"], ["it", "intertrochanteric region"], ["h", "head"], ["s", "shaft"], ["b", "base"], ["n", "neck"]]
	for i, suffix in suffixes {
		code := suffix[1]
		if (SubStr(boneCode, 1 - StrLen(code)) = code) {
			candidate := SubStr(boneCode, 1, StrLen(boneCode) - StrLen(code))
			if (candidate != "" && XR_FractureBoneListValid(candidate)) {
				boneCode := candidate
				return suffix[2]
			}
		}
	}
	return ""
}

XR_FractureBoneListValid(boneCode){
	Loop, Parse, boneCode, `,
	{
		token := Trim(A_LoopField)
		if (token = "" || XR_FractureBonePhrase(token, false, false) = "")
			return false
	}
	return true
}

XR_FractureBonePhrases(boneCode, adjectiveForm, pluralNouns){
	phrases := []
	Loop, Parse, boneCode, `,
	{
		token := Trim(A_LoopField)
		phrase := XR_FractureBonePhrase(token, adjectiveForm, pluralNouns)
		if (phrase = "")
			return ""
		phrases.Push(phrase)
	}
	return phrases
}

XR_FractureBonePhrase(token, adjectiveForm, pluralNoun){
	noun := Object("h", "humerus", "r", "radius", "u", "ulna", "f", "femur", "t", "tibia", "l", "fibula", "c", "clavicle", "p", "scapula", "k", "calcaneus")
	adj := Object("h", "humeral", "r", "radial", "u", "ulnar", "f", "femoral", "t", "tibial", "l", "fibular", "c", "clavicular", "p", "scapular", "k", "calcaneal")
	plural := Object("h", "humeri", "r", "radii", "u", "ulnae", "f", "femurs", "t", "tibias", "l", "fibulas", "c", "clavicles", "p", "scapulae", "k", "calcanei")
	phalanxNoun := Object("p1", "distal phalanx bone", "p2", "middle phalanx bone", "p3", "proximal phalanx bone", "p4", "metacarpal bone", "p5", "metatarsal bone")
	phalanxPlural := Object("p1", "distal phalanx bones", "p2", "middle phalanx bones", "p3", "proximal phalanx bones", "p4", "metacarpal bones", "p5", "metatarsal bones")
	phalanxAdj := Object("p1", "distal phalangeal", "p2", "middle phalangeal", "p3", "proximal phalangeal", "p4", "metacarpal", "p5", "metatarsal")
	if RegExMatch(token, "^([1-5])(p[1-5])$", m) {
		ord := XR_FractureOrdinal(m1)
		if (adjectiveForm)
			return ord " " phalanxAdj[m2]
		return ord " " (pluralNoun ? phalanxPlural[m2] : phalanxNoun[m2])
	}
	if !noun.HasKey(token)
		return ""
	if (adjectiveForm)
		return adj[token]
	return pluralNoun ? plural[token] : noun[token]
}

XR_FractureOrdinal(n){
	return (n = 1) ? "1st" : (n = 2) ? "2nd" : (n = 3) ? "3rd" : n "th"
}

XR_FractureJoinBonePhrases(phrases, pluralizeCompactTail){
	if (phrases.MaxIndex() = 1)
		return phrases[1]
	tail := ""
	ords := []
	canCompact := true
	for i, phrase in phrases {
		if !RegExMatch(phrase, "^(\d+(?:st|nd|rd|th)) (.+)$", m) {
			canCompact := false
			break
		}
		if (tail = "")
			tail := m2
		else if (tail != m2) {
			canCompact := false
			break
		}
		ords.Push(m1)
	}
	if (canCompact) {
		if (pluralizeCompactTail)
			tail := XR_FracturePluralCompactTail(tail)
		return XR_FractureJoinWithAnd(ords) " " tail
	}
	return XR_FractureJoinWithAnd(phrases)
}

XR_FracturePluralCompactTail(tail){
	if (SubStr(tail, -4) = " bone")
		return SubStr(tail, 1, -5) " bones"
	if (SubStr(tail, 0) != "s")
		return tail "s"
	return tail
}

XR_FracturePluralBonePart(part){
	if (part = "base")
		return "bases"
	return part "s"
}

XR_FractureJoinWithAnd(items){
	count := items.MaxIndex()
	if (count = 1)
		return items[1]
	if (count = 2)
		return items[1] " and " items[2]
	str := ""
	for i, item in items {
		if (i = 1)
			str := item
		else if (i = count)
			str .= ", and " item
		else
			str .= ", " item
	}
	return str
}
