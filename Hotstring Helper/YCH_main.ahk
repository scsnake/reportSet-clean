#InstallKeybdHook
#MaxHotkeysPerInterval 999999
#include <risimpax>
#include <EBMViewer>
#include <Edit>
#include <hash>
#include <WM_COPYDATA>
#include <getFocusedHwnd>
#include <dcm4che>
#include <RadiologyReportTemplate>
#include <resetHotstringBuffer>
#include <showToolTip>
#include <OpText>
#include <portallib>
#include <RegexSplit>
#include <ReportImpression>
#Hotstring, SI
SendMode Input
;~ *.::
;~ *numpaddot::
;~ send {.}
;~ return

;~ $-::
;~ if winactive("放射線資訊管理系統") || winactive("ahk_class SleipnirMainWindow") || winactive("ahk_class SciTEWindow") || winactive("ahk_exe simpleRIS.exe")
	;~ send %a_space%{left}{right}
;~ else
	;~ send '
;~ return


;~ ^-::
;~ if winactive("放射線資訊管理系統") || winactive("ahk_class SleipnirMainWindow") || winactive("ahk_class SciTEWindow") || winactive("ahk_exe simpleRIS.exe")
	;~ send '
;~ else
	;~ send "
;~ return



RisGroup:
groupadd,RisGroup,放射線資訊管理系統(Radiology Information System)
groupadd,RisGroup,simple RIS ahk_class AutoHotkeyGUI
;~ groupadd,RisGroup,ahk_exe simpleRIS.exe
return

recentSent:
recentSent:=false
return


/*
^!t::
ifwinexist,Convert first word
	return
gui,font,s10 Verdana
gui,add,edit,w800 h600 vreport
gui,add,edit,r1 w20 vfirstword,>
gui,add,button,x+5 yp,Convert

gui,show,w850 h650,Convert first word
return
*/

Buttonconvert:
gui,submit,NoHide
firstword:=trim(firstword)
if firstword=>
{
	report:=regexreplace(report,"\r?\n\d.\s*","`r`n" firstword " ")
	;~ report:=regexreplace(report,"\r?\n(\d.\s*|\w\s+)([^\n]+\n*)","`r`n" firstword " $2")
	;~ report:=regexreplace(report,"\r?\n(\d.\s*|\w\s+)(\w+)$",firstword " $2",1)
}
guicontrol,,report,% report
guicontrol,focus,report
controlsend,Scintilla1,{home}+^{end},Convert first word
return

~!q::
exitapp
return

^!x::suspend


;~ ^!e::
;~ inputbox,addahk
;~ if addahk!=
	;~ fileappend,% addahk,% A_ScriptFullPath
;~ reload
;~ return


#ifwinactive,Radiology Information System
+enter::
+numpadenter::
send {enter}%bullet%
return
#ifwinactive

#ifwinactive,ahk_class SleipnirMainWindow
~+enter::
~+numpadenter::
send %bullet%
return
#ifwinactive



; 健檢中文區
:*:n-::無顯著異常
:*:rs-::腎結石
:*:r-::右側
:*:l-::左側
:*:b-::雙側
:*:d-::退行性變化


; history
::hx::History:
::sp::status post
::r/t::radiotherapy
::c/t::chemotherapy
::lcl::localization
:o:hfn::History: for navigation.`n`n
:o:hfc::History: for cyberknife.`n`n


; exam title
examTitle:
if ($.value(1)=""){
	;~ send % $.value(2) "="
	return
}

	;~ send % "{bs " StrLen($.value(0))
value2:=returnStr?partValue:$.value(2)

if(value2<3)
	exam:="CT"
else if(value2<6)
	exam:="MRI"

if(mod(value2,3)=0)
	contrast:="without/with"
else if(mod(value2,3)=1)
	contrast:="without"
else if(mod(value2,3)=2)
	contrast:="with"

part:=""
if instr($.value(1),"b")
	part.="brain, "
if instr($.value(1),"n")
	part.="neck, "
if instr($.value(1),"c")
	part.="chest, "
if instr($.value(1),"a")
	part.="abdomen, "
if instr($.value(1),"p")
	part.="pelvis, "
if instr($.value(1),"d")
	part.="C-spine, "
if instr($.value(1),"t")
	part.="T-spine, "
if instr($.value(1),"l")
	part.="L-spine, "
if instr($.value(1),"u")
	part.="upper extremity, "
if instr($.value(1),"v")
	part.="lower extremity, "
;~ part:=regexreplace(part,", $")
;~ StringReplace, part, part,% ", ",% ", ", UseErrorLevel
;~ if errorlevel=1
	;~ stringreplace,part,part,% ", ",% " and "
RegExMatch(part,"is)^(.*?)(,?)([\w -]+), $",match)
if (match2="")
	part:=match3
else
	part:=match1 " and" match3

;~ bs:=strlen($.value(1))+strlen(value2)
;~ loop % bs+1
	;~ send {bs}
if(returnStr){
	returnStr=%exam% of the %part% %contrast% contrast enhancement shows:
	returnStr.=" `r`n" bullet
	partValue:=""
	return
}
Sleep 50
str:=exam " of the " part " " contrast " contrast enhancement shows:`r`n" bullet
if (contrast="without" && regexmatch($.value(1),"[cap]") && value2<3)
	str.="Low sensitivity and specificity of non-contrast CT.`r`n" bullet
send % "{bs " strlen($.value(0)) "}"
send % str
;~ sendByClipboard(str, StrLen($.value(0)))
$:=""
return

:o:y0::
sendAndNextLine("This study shows:")
return

newline:
if a_endchar=`n
	send {enter}%bullet%
else
	send %a_endchar%
return

sendAndNextLine(txt){
	global bullet
	sendbyclipboard(txt "`r`n" bullet, -1)
}

::xx::(非正式報告，僅供參考。){enter}


;modality

:*:cta0::
sendAndNextLine("CT angiography and perfusion scan of brain shows:")
return
:*:cta1::
sendAndNextLine("CT angiography of brain shows:")
return
:*:cta2::
sendAndNextLine("CT angiography of neck shows:")
return
::ctp::CT perfusion shows
::ce::contrast enhancement
::ang::angiography
::us::ultrasound
::emer::emergency
::ctd::the estimated radiation dose (mSv) of this study is:

;direction
::qa::anterior aspect of
;~ ::qal::antero-lateral aspect of
;~ ::qam::antero-medial aspect of
::qc::cephalic aspect of
::qcc::caudal aspect of
::qd::distal aspect of
::qi::inferior aspect of
::ql::lateral aspect of
::qm::medial aspect of
::qp::posterior aspect of
;~ ::qpl::postero-lateral aspect of
;~ ::qpm::postero-medial aspect of
::qpp::proximal aspect of
::qs::superior aspect of


::cen::central
::ant::anterior
;~ ::antl::antero-lateral
;~ ::antm::antero-medial
;~ ::anti::antero-inferior
;~ ::ants::antero-superior
::pos::posterior
;~ ::posl::postero-lateral
;~ ::posm::postero-medial
;~ ::posi::postero-inferior
;~ ::poss::postero-superior
::sup::superior
::inf::inferior
::lgt::longitudinal
::prt::portion
::dcb::decubitus
::mid::middle


aspect:
;~ loop % strlen($1)+strlen($2)+1
	;~ send {bs}

a:=$.value(1),last:="", str:=""
loop,parse,a
{
	if (a_loopfield="a")
		str.="antero-"
	else if (a_loopfield="p")
		str.="postero-"
	else if (a_loopfield="s")
		str.="supero-"
	else if (a_loopfield="i")
		str.="infero-"
	else if (a_loopfield="m")
		str.="medio-"
	else if (a_loopfield="l")
		str.="latero-"
	last:=a_loopfield
}
str:=SubStr(str,1,-2)
if last in m,l
	str.="al"
else
	str.="ior"
if strlen($.value(2))
	str.=" aspect of"
send % "{bs " strlen($.value(0)) "}"
send % str
;~ sendByClipboard(str, StrLen($.value(0)))
$:=""
return

::spf::superficial
::prp::peripheral

:c:I::I
:*:i,::I,
:*:i.::I.
:*:i;::I;
::i::in
:*:i\::i
:*:e\::e
:*:o\::o
:*:l\::l
:*:r\::r
:*:b\::b
:*:m\::m
:*:f\::f


::e::at
;~ ::o::of
:*:n\::n
::n::and
:*:t\::t
::t::the
:*:r-::
send % "右側"
return
::r::right
:*:l-::
send % "左側"
return
::l::left
::o::of
::u/::upper
::v/::lower
::med::medial
::lat::lateral
::pro::proximal
::dis::distal

::bi::bilateral
::b::bilateral
::trs::transverse

::1ry::primary
::2ry::secondary

;程度
::sut::size up to
::dif::difficult
::lg::large
:*:lg1::larger
::mss::massive
::ti::tiny
::sm::small
::ss::tiny (<6mm)
::mm::small (<10mm)
;~ ::ssn::(Solid nodule(s) smaller than 6 mm do not require routine follow-up in patients at low risk, according to MacMahon, Heber, et al. "Guidelines for management of incidental pulmonary nodules detected on CT images: from the Fleischner Society 2017." Radiology (2017): 161659.)
:*:sm1::smaller
::str::strong
::int::intermediate
::sig::significant
::siy::significantly
::mi::minimal
::miy::minimaly
::sli::slight
::sly::slightly
;~ ::mil::mild
:*:m-::
send % "輕度"
return
::m::mild

::my::mildly

:*:mo-::
send % "中度"
return
::mo::moderate
::moy::moderately

:*:sv-::
send % "重度"
return
::sv::severe
::bri::bright
::ext::extensive
::lim::limited
::abn::abnormal
::aby::abnormality
::nor::normal
::nap::normal appearance of
::st::unchanged
:*:stml::unchanged but malignancy can not be excluded.
:*:stns::unchanged, probably non-specific
::prog::in progression
::inc::increased
::dec::decreased
::ifl::infiltrative
:*:ifl1::infiltration
::wed::well-defined
::ild::ill-defined
::mu::multiple
::rec::recurrent
::prm::prominent
:*:prm1::more prominent
:*:prm2::less prominent
::evi::evident
:*:evi1::more evident
:*:evi2::less evident
:*:evi3::most evident
::acu::acute
::chr::chronic
::ju::junction
::wnr::within normal range
::mor::predominant on the right side
::mol::predominant on the left side
::prs::persistent
::dil::dilatation
:*:dil1::dilated
::seg::segmental
::sg::segment
:*:sg1::segments
::frq::frequent
::smo::smoothly


;介係詞 句首 句尾
::w/::with
::x/::without
::y/::without/with
::comp::as compared with previous study on
::com::as compared with last similar study.

::icl::including
::su::suspect
::sus::suspected
::suo::suspicious of
::ifa::is favored
::sug::suggestive of
;~ ::ido::indicative of
::sgg::suggest
::nde::no definite
::df::definite
::nob::no obvious
::nev::no evidence of
:*:ico1::are considered
::ico::is considered
:*:icf1::are considered first
::icf::is considered first
::isg::is suggested
::iss::is suspected
::isn::is noted
::isd::is done
::unr::unremarkable
::cow::consistent with
::sbe::should be excluded first.
::cnx::can not be excluded.
:*:mcnx::malignancy can not be excluded.
::prev::previous
::prb::probably
::psb::possible
::esp::especially
::usu::usually
::awa::as well as
;~ ::thr::through
::trh::through
;image character
::hyv::hypervascular
::hov::hypovascular

::hom::homogeneous
::het::heterogeneous

::den::density
:*:den1::densities
::ro::radiopaque
:*:ro1::radiopaque density
:*:ro2::radiopaque densities
::rl::radiolucent
:*:rl1::radiolucency
:*:rl2::radiolucencies
::hy::hyperdense
:*:hy1::hyperdensity
:*:hy2::hyperdensities
::hyi::hyperintense
:*:hyi1::hyperintensity
:*:hyi2::hyperintensities
::ho::hypodense
:*:ho1::hypodensity
:*:ho2::hypodensities
::hoi::hypointense
:*:hoi1::hypointensity
:*:hoi2::hypointensities

::opac::opacification
::opf::opacified
::nen::non-enhancing
::enh::enhancing
::enn::enhancing nodule
:*:enn1::enhancing nodules
::enm::enhancing mass
:*:enm1::enhancing masses
::ens::enhancing lesion
:*:ens1::enhancing lesions
::ent::enhancing tumor
:*:ent1::enhancing tumors


:*:enhc::enhancement
::hoe::hypoenhancing
::hye::hyperenhancing
:*:hoec::hypoenhancement
:*:hyec::hyperenhancement


::extv::extravasation

::si::SI
::sii::signal intensity

::t2w::T2WI
::t1w::T1WI
::stir::T2 STIR
::flar::T2 FLAIR

pigtail:
digits:=$.value(1)
stringleft,fr,digits,% strlen(digits)-2
StringRight,cm,digits,2
send % fr "Fr " cm "cm pigtail catheter" $.value(2)
$:=""
return

catheter:
send % "{bs " StrLen($.value(0))  "}"
send % substr($.value(1),1,1) (strlen($.value(1))>1?"." substr($.value(1),2):"") "Fr " $.value(2) "cm " ($.value(1)>10?"micro":"") "catheter" $.value(3)
$:=""
return

specifyImage:
;~ bs:=strlen($1)+strlen($2)+strlen($3)+strlen($4)
;~ loop % bs+2
	;~ send {bs}
if InStr(thisPlace, "C hospital")
	sestr:="Srs", Imstr:="Img"
else
	seStr:="SE", imstr:="IM"
if ($.value(1)="."){
	send % "{bs " strlen($.value(0)) "}"
	send % "(" seStr $.value(2) " " imstr $.value(3) ")" $.value(4)
}
	;~ sendByClipboard("(SE" $.value(2) " IM" $.value(3) ")" $.value(4), strlen($.value(0)))
else{
	send % "{bs " strlen($.value(0)) "}"
	send % $.value(1) seStr $.value(2) " " imstr $.value(3) $.value(4)
}
	;~ sendByClipboard($.value(1) "SE" $.value(2) " IM" $.value(3) $.value(4), strlen($.value(0)))
$:=""
return
;general term
:c:nj::injury
:*:spcm::smooth passage of contrast media
:*:obs0::no definite obstructive lesion.
:*:lap0::no definite lymphadenopathy.
::mmp::mammoplasty
::eqv::equivocal
::ktz::Please refer to key image series for possible transition zone.
::tzn::transition zone
::pav::patent major arteries and veins.
::ama::as mentioned above
::geo::geographic
::ns::no significant findings in this study.
::sct::scattered
::ids::indiscernible
::mj::major
::mn::minor
::rct::recent
::stu::structure
:*:stu1::structures
::cpn::component
:*:cpn1::components
::wl::wall
::sgm::sigmoid
::ctn::contents
::mat::material
::vas::vascular
::cls::clustered
::fbd::fibrous dysplasia
;~ ::xz::
;~ send % "`r`n(Only major findings are mentioned above; please contact the radiologist if detailed formal report is required.)"
;~ return
::ncc::necrotic change
::ncm::necrotic mass
::lpd::lymphoproliferative disease
::ewt::edematous wall thickening
::pdc::peduncle
:*:pdc1::peduncles
::bna::benign appearance
::wba::with benign appearance
::ape::appearance
::hoc::hypodense change
::fhc::focal hypodense change
::tt::total
::ren::rim-enhancing
::itn::internal
::etn::external
::mal::mass lesion
:*:mal1::mass lesions
::pow::posterior wall
::anw::anterior wall
::law::lateral wall
::mew::medial wall
::inw::inferior wall
::suw::superior wall
::flo::floor
::hh::high
::bld::blood
::clc::collection
::rsd::residual
::thw::thin-walled
::amr::amorphous
::trt::treated
::eln::enlarged lymph node
:*:eln1::enlarged lymph nodes
::stas::some soft tissue around the sutures
::bkg::background
::itr::intrathoracic
::cor::coronal
::sag::sagittal
::ax::axial
::boi::non-specific sclerotic foci.
:*:boi1::non-specific sclerotic focus at
::vsb::visible bones
::arn::around
::srr::surrounding
::sev::several
::nm::numerous
::crc::circulation
::ipm::if proven malignancy
::fxa::fixation
::psf::Please see the images and findings.
::edc::edematous change
::col::collateral
:*:col1::collaterals
::ank::ankylosing spondylitis
::fos::fossa
::cau::causing
::blg::bulging
::hi::hilar
::hl::hilum
::ndo::nodular opacity
:*:ndo1::nodular opacities
::mlo::mass-like opacity
:*:mlo1::mass-like opacities
::msl::mass-like
::arp::arthroplasty
::fnd::finding
:*:fnd1::findings
::rst::roughly unchanged
:*:rstm::roughly unchanged but malignancy can not be excluded.
::rf::roughly
::mll::mass-like lesion
::bod::bony defect
::coi::coiling

::dpr::disappearance
:*:dpr1::disappeared

::ndl::nodular lesion
:*:ndl1::nodular lesions
::ndd::nodular density
:*:ndd1::nodular densities
::ndp::nodular opacity
:*:ndp1::nodular opacities

::nth::nodular thickening

::wdg::wedge
::nut::neurogenic tumor
::skk::sclerotic focus
::ski::sclerotic foci
::ctl::cartilage
::rta::retraction
::pvc::perivascular
::sft::soft tissue
::sue::subcutaneous emphysema
::bfr::bone fragment
:*:bfr1::bone fragments
::cyl::cystic lesion
:*:cyl1::cystic lesions
::cyc::cystic change
::fis::fistula
::g1::grade 1
::g2::grade 2
::g3::grade 3
::g4::grade 4
::rcn::reconstruction
::ldc::low density change
::sti::soft tissue thickening
::pau::penetrating atherosclerotic ulcer
::pvn::previously noted
::psg::parasagittal
::mur::mural
::mtr::mural thrombus
::sol::space-occupying lesion
::swe::swelling
::swo::swollen
::aor::and/or
::bos::borderline sized
::rfy::roughly
::abt::about
::pst::positive
::neg::negative
::xps::expansile
::vz::of varying sizes
::def::deformity
::orf::orifice
::aan::aortic aneurysm
::aaa::abdominal aortic aneurysm
::adl::aneurysmal dilatation
::ac::acute
::sak::subacute
::mub::multiple bilateral
::cas::calcification or stone
::ed::edema
::num::number
::slx::subluxation
::dlk::dislocation
::vt::vertebra
:*:vt1::vertebrae
::vtb::vertebral
::api::apical
::res::resolution
::rs::resolved
:*:rs1::resolving
::hmt::hematoma
:*:hmt1::hematomas
::pc::space
:*:pc1::space
::wen::well-enhancing
::inn::is not noted
::rpm::replacement
::rp::replaced
::cnn::cannula
:*:cnn1::cannulas
::sys::system
::cav::cavitary
::pdm::predominant
:*:pdm1::predominance
::stg::staging
::bd::border
::fk::focus
::fi::foci
::fkl::focal
::sk::sclerotic
::sks::sclerosis
::tst::tentative radiology staging
::oth::other
::ano::another
::rtr::reticular
::dss::dissection
::aod::aortic dissection
::imh::intramural hematoma
:*:ns=::is not seen in this study
::obv::obvious
::djd::degenerative change of spine
::djcf::degenerative change of spine with compression fracture
:*:djcf1::degenerative change of spine with compression fractures
:*:djop::degenerative and post-operative change of spine
::nal::normal alignment
::muc::mucus
::mre::mucus retention
:*:met0::no evidence of metastatic lesions.
:*:met00::no evidence of metastatic lesions or lymphadenopathy.
::sem::subcutaneous emphysema
::clp::collapse
:*:clp1::collapsed
::cpm::cardiovascular implantable electronic device
::pgc::pigtail catheter
::pgc1::pigtail catheters
::flt::flattening
::prv::previous
::cfl::confluent
::lnr::linear
::prr::prior
::gri::granulomatous infection
::spi::spiculated
::sed::seedings
:*:sed0::seeding
::crs::coarse
::ple::pleomorphic
::bnn::benign
::mlg::malignancy
:*:slgr::slow-growing
::sym::symmetric
::asy::asymmetric
::prn::prolonged
::acc::accessory
::nv::nerve
:*:nv1::nerves
::ms::muscle
:*:ms1::muscles
::bn::bone
:*:bns::bones
:*:lore::loco-regional
::pt::patchy
::ecc::eccentric
::ccc::concentric
::ki::(Please refer to key image series.)
::ref::Please refer to the text above for detailed findings.
::isa::in short axis
::igd::in greatest dimension
::ch::change
:*:ch1::changes
::bo::both
::wid::widening
::thew::abnormal thickening and enhancing wall
::vpt::vertebroplasty
::unk::unknown (unavailable) history in N hospital
::ty::typical
::aty::atypical
:*:tstc::too small to characterize
::tsc::tuberous sclerosis complex
::std::soft tissue density
:*:std1::soft tissue densities
::sot::soft tissue
::sw::shadow
::scem::subcutaneous emphysema
::sch::sclerotic change
::skf::sclerotic foci
::scl::surgical clips
::pr::partial
::py::partially
::pob::partial obstruction
::pq::plaque
:*:pq1::plaques
::plq::pleural plaque
:*:plq1::pleural plaques
::ovr::overriding
::ocm::oral contrast media
::nrt::no evidence of recurrent tumor.
:*:nrtl::no evidence of recurrent tumor or lymphadenopathy.
:*:nrt1::no evidence of residual tumor.
:*:nrt2::no evidence of residual/recurrent tumor.

:*:opnrt::post-operative changes. no evidence of recurrent tumor.
:*:oprtn::post-operative and post-radiation changes. no evidence of recurrent tumor.


::nse::no solid or enhancing part is noted
::bog::bowel gas
::nic::no significant interval change.
::nfl::no definite focal lesion
::mob::more obvious
::mk::marked
:*:mk1::markedly
::mxd::maximal diameter
::lbu::lobulated
::lcu::loculated
::vn::vein
:*:vn1::veins
::vsl::vessel
:*:vsl1::vessels
::vsc::vasculatures
::its::in this study
::isf::is found
::ixp::infectious process
::ifp::inflammatory process
::fxp::inflammatory/infectious process
:*:fxp1::inflammatory/infectious process of lung, suggest clinical correlation and follow up.
:*:fxp2::inflammatory/infectious process of lung, more prominent, suggest clinical correlation and follow up.
:*:fxp3::inflammatory/infectious process of lung, less prominent, suggest clinical correlation and follow up.
::fxc::inflammatory/infectious change
::ifc::inflammatory change
;~ ::ioh::in other hospital
::ndt::indentation
::inci::incidentally
::idn::identified
::isi::is identified
::hm::hemorrhagic
::grt::granulation tissue
::fsf::fusiform
::foc::focal lesion
::fpl::fat plane
::ffl::fluid-fluid level
::ff::fluid-fluid layering
::eva::evaluation
::fev::further evaluation
::fct::fat-containing tumor
::fcn::fat-containing nodule
::fcm::fat-containing mass
::fla::fluid accumulation
::flr::fluid retention
::eti::The etiology should be further evaluated.
::sfe::suggest further evaluation.
::emf::emphysematous
:c:eca::encasement
:c:Eca::Encasement
::ECA::ECA
::ele::elevated
::drt::drainage tube
:*:drt1::drainage tubes
::dst::distended
:*:dst1::distention
::dlg::dislodgement
::dfs::diffuse
::dfy::diffusely
::dao::details are obscured
::des::destruction
::dep::dependent
:*:cn1::cancerous
::stn::stenting
::cm::contrast media
::cir::circumferential
::cli::clinical
::rr::on the right side
::ll::on the left side
::bb::on both sides
::bnt::blunting
::asw::associated with
::att::attenuation
::pft::perifocal fat stranding
::mfs::mesenteric fat stranding
::aph::arterial phase
::pvp::portal venous phase
::vph::venous phase
::ap::air pockets
::amo::amount of
::ana::anastomosis
:*:ana1::anastomotic
::prc::parenchyma
::prc1::parenchymal
::tnn::thinning
::rel::relative
::eng::engorged
::vsz::variable-sized
::ifx::infection
::tbx::tuberculous infection
::sos::suboptimal study
::sos1::suboptimal study due to motion artifact
::sos2::suboptimal study due to malpositioning.
::prl::probably related to
::prx::pre-existing
::nva::normal variant
::AFL::air-fluid level
::mae::mass effect
::oprt::post-operative and post-radiation changes
::rtc::post-radiation change
::txc::post-treatment changes
::abc::post-ablation changes
::nec::necrosis
:*:nec1::necrotic
::yre::hyperemia
::yrc::hyperemic change
::flc::fluid collection
::dev::deviation
::rco::reconstitution
::ivs::invasion
::ltz::lateralization
::mdz::medialization
::dz::disease
::inv::involving
::ivm::involvement
::sh::showing
::yd::showed
::ys::shows
::haz::haziness
::owu::otherwise unremarkable
::reg::region
:*:reg1::regions
:*:reg2::regional
::asp::aspect
:*:asp1::aspects
::fid::filling defect
:*:fid1::filling defects
::xtn::extension
::wxt::with extension to
::hop::hypoplastic
:*:hop1::hypoplasia
::tor::tortuous
::psc::presence
::ifn::infarction
:*:ifn1::infarctions
::ifr::infarct
:*:ifr1::infarcts
::isc::ischemic change
:*:isca::ischemia
::dia::diameter
::hrn::hernia
:*:hrn1::herniation
::cmp::compression
:*:cmp1::compressed
::bif::bifurcation
::ter::territory
:*:mcat::MCA territory
:*:acat::ACA territory
:*:pcat::PCA territory
:*:mcat1::MCA territories
:*:acat1::ACA territories
:*:pcat1::PCA territories
:*:ter1::territories
::ede::edema
::pfc::perifocal
::pfe::perifocal edema
::dire::diffusion restriction
::aln::alignment
::rcr::recurrence
::anu::aneurysm
::anu1::aneurysms
::ret::retention
::hpt::hypertrophy
::ptn::patent
::emb::embolism
::teb::thromboembolism
::ar::artery
:*:ar1::arteries
::obl::obliterated
:*:obl1::obliteration
::obc::obscured
::lao::the largest one measured
::ldi::in largest dimension
::ut::up to
::mulv::multiple varied-size
::ef::effusion
::flu::fluid
::msa::magnetic susceptibility artifacts
::bha::beam-hardening artifacts
::bha0::There is beam-hardening artifacts and obscuration of adjacent structure.
::fca::fibrotic change
::fcc::fibrocalcified change
::fcl::fibrocalcified lesions
::fnl::fibronodular lesions
::nat::nature to be determined
::nt::with indeterminate nature
::moa::motion artifacts
:*:moa0::motion artifacts are noted, which may obscure small lesions.
::les::lesion
:*:les1::lesions
::abs::abscess
:*:abs1::abscesses
::lap::lymphadenopathy
:*:lap1::lymphadenopathies
::opc::post-operative change
:*:opc1::post-operative changes
::ca::calcification
::cal::calcified
::ca1::calcifications
::ath::atherosclerotic change
:*:ath1::atherosclerotic changes
::caca::Calcified atherosclerotic plaques in the coronary arteries.
::atc::atherosclerotic calcification
::atca::atherosclerotic calcification of the aorta.
:*:atcac::atherosclerotic calcification of the aorta and coronary arteries.
:*:atccc::calcification of the aorta, coronary arteries and cardiac valve.
::gca::cardiomegaly. atherosclerotic calcification of the aorta.
:*:mgca::mild cardiomegaly. atherosclerotic calcification of the aorta.
:*:gcac::cardiomegaly. atherosclerotic calcification of the aorta and coronary arteries.
::gcc::cardiomegaly. atherosclerotic calcification of the aorta and coronary arteries.
:*:mgcc::mild cardiomegaly. atherosclerotic calcification of the aorta and coronary arteries.
:*:gccc::cardiomegaly. calcification of the aorta, coronary arteries and cardiac valve.
:*:mgccc::mild cardiomegaly. calcification of the aorta, coronary arteries and cardiac valve.
::met::metastasis
:*:met1::metastases
::mets::metastatic lesions
:*:met2::metastatic
:*:bon0::
sendAndNextLine("no obvious focal bone lesion.")
return
::fas::fat stranding
::adj::adjacent
::sts::soft tissue swelling
::lb::lobe
:*:lb1::lobes
:*:lb2::lobar
::ste::stenosis
::ocl::occlusion
:*:stoc::steno-occlusion
::gl::gland
:*:gl1::glands
::arti::artifacts
::ln::lymph node
:*:ln1::lymph nodes
:*:mth-::
send % "黏膜增厚"
return
::mth::mucosal thickening
::wth::wall thickening
::thi::thickening
::irn::irregular narrowing
::irr::irregular
:*:irr1::irregularity
::le::level
:*:le1::levels
::hem::hemorrhage
::nar::narrowing
::nmx::
sendAndNextLine("no definite metastatic lesion in visible field. (Mx)")
return
;~ ::dis::distended
::obs::obstruction
:*:obs1::obstructive
::lig::ligament
:*:lig1::ligaments
::tdn::tendon
:*:tdn1::tendons
::ma::mass
::mle::mass lesion
:*:ma1::masses
::tu::tumor
:*:tu1::tumors
::tu2::tumoral
:*:nd-::
send % "結節"
return
::nd::nodule
:*:nd1::nodules
:*:nd2::nodular
::nod::nodularity
:*:nod1::nodularities
::nos::non-specific
:*:pbns::probably non-specific
::plc::placement of
::ett::an endotracheal tube
::dlc::a double-lumen catheter
::rcvc::a right central venous catheter
::lcvc::a left central venous catheter
::rpor::a right implantable venous access port
::lpor::a left implantable venous access port
::ppo::placement of implantable venous access port.
::ngt::a nasoenteric tube
::pdt::a peritoneal dialysis tube
::fol::a Foley catheter
::cath::catheter
::pig::pigtail
:*:pig1::pigtails
::enl::enlarged
:*:enl1::enlargement
;~ ::subc::subcutaneous
::thm::thrombosis
:*:thm1::thrombosed
::ptr::partially thrombosed
::thr::thrombus
::tmy::thrombectomy
:*:thr1::thrombi
::atr::atrophy
::atrc::atrophic change
:*:atrc1::atrophic changes
::atk::atrophic change of bilateral kidneys.
:*:atrk::atrophic change of the right kidney.
:*:atlk::atrophic change of the left kidney.
::ddx::differential diagnosis including
::ind::indeterminate


;brain
::cist::cistern
:*:cist1::cisterns

::corr::corona radiata

:*:obsf::obliterated sulci and fissures

:*:idem::intradural extramedullary
::imd::intramedullary
::idl::intradural
::xdl::extradural

::swi::SWI shows
:*:swip::
sendAndNextLine("SWI shows hypointensities in bilateral posterolateral putamina. ")
return
:*:swiq::
sendAndNextLine("SWI shows mild hypointensities in bilateral posterolateral putamina. ")
return
:*:swi0::
sendAndNextLine("SWI shows no significant micorbleeds  ")
return

:*:swi1::SWI shows some micorbleeds


::mcb::microbleed
:*:mcb1::microbleeds

:*:cffx::craniofacial fracture
:*:desh::disproportionately enlarged subarachnoid space hydrocephalus

:*:prfc::parafalcine
::otk::optic chiasm

:*:sptn::supratentorial
:*:iftn::infratentorial

:o:ash::asymmetric hypodense area at , which could be leukoaraiosis or recent cerebrovascular event.{Left 63}
:*:stcp::striatocapsular region
::brl::brain atrophy, leukoaraiosis.
::mba::mild brain atrophy
:*:brli::brain atrophy, leukoaraiosis, old insult(s).
:*:brlo::brain atrophy, leukoaraiosis, old lacune(s).
::cnp::clinoid process
:*:cnp1::clinoid processes
::ppb::preserved posterior pituitary bright T1 signal.
::cbp::cerebellar peduncle
:*:cbp1::cerebellar peduncles


::mgt::meningitis

::ina::intracranial arteries
:*:dssa::dissecting aneurysm
::dth::dural thickening
::fcr::falx cerebri
::ten::tentorium
:*:ten1::tentorial
::ftn::falcotentorial
::slw::sphenoid lesser wing
::sgw::sphenoid greater wing
::srd::sphenoid ridge
:*:plsf::planum sphenoidale

:*:etym::epitympanum
:*:mtym::mesotympanum
:*:htym::hypotympanum

::cah::caudate head
::gp::globus pallidus
:*:gp1::globus pallidi
::lgp::left globus pallidus
::rgp::right globus pallidus
::bgp::bilateral globus pallidi
::ptm::putamen
:*:ptm1::putamina
::isl::insula
:*:isl1::insular

:c:orn::osteoradionecrosis

::bnm::brain metastases
::ach::arachnoid
::acha::anterior choroidal artery
::pcha::posterior choroidal artery
::dmy::demyelinating
::tea::transependymal absorption
::psp::paraspinal
:*:psp0::
sendAndNextLine("clear paraspinal soft tissue.")
return
::pnc::pneumocephalus
::eib::EC-IC bypass
:*:tsc0::
(
Multifocal ill-defined hyperintensity change on FLAIR images at bilateral cortical/subcortical junction without enhancement. Tuberous sclerosis with cortical/subcortical tubers is compatible.
- Multiple tiny subependymal nodules with variable enhancement.
)
::hmv::hematoventricle
::cbn::cyberknife
::pmj::ponto-medullary junction
::brm::brainstem
::mdo::medulla oblongata
:*:sel0::MRI of the sella without/with contrast enhancement shows:`r`n-
;~ ::mca1::MCA M1
;~ ::mca2::MCA M2
;~ ::aca1::ACA A1
;~ ::aca2::ACA A2
;~ ::pca1::PCA P1
;~ ::pca2::PCA P2
::rbg::right basal ganglion
::lbg::left basal ganglion
::bbg::bilateral basal ganglia

::rth::right thalamus
::lth::left thalamus
::bth::bilateral thalami

::rfl::right frontal lobe
::lfl::left frontal lobe
::bfl::bilateral frontal lobes
::rpl::right parietal lobe
::lpl::left parietal lobe
::bpl::bilateral parietal lobes
::rol::right occipital lobe
::lol::left occipital lobe
::bol::bilateral occipital lobes
::rtl::right temporal lobe
::ltl::left temporal lobe
::btl::bilateral temporal lobes

::dub::dural-based
::acf::anterior cranial fossa
::mcf::middle cranial fossa
::pcf::posterior cranial fossa
::iac::internal auditory canal
::eac::external auditory canal
::cmc::chronic mastoiditis change
::vmg::ventriculomegaly
::sbd::subdural
::epd::epidural
::sar::subarachnoid
::bl::
send % "Brain atrophy with dilated sulci, fissures and ventricles.`r`n- "
if InStr(getRisExamItemsAll()[1], "MR"){
	send % "Multiple nonspecific hyperintensities over bilateral cerebral white matter on T2 FLAIR, suggestive of leukoaraiosis.`r`n- "
}else{
	send % "Low densities at bilateral periventricular white matter, suggestive of leukoaraiosis.`r`n- "
}
return
::htr::hemorrhagic transformation
:*:bo0::no definite intracranial organic lesion.
::pvs::perivascular spaces
::skh::scalp hematoma
::skp::scalp
::cx::cortex
:*:cx1::cortical
::scx::subcortical
::scw::subcortical
::gy::gyrus
:*:gy1::gyri
::ssr::suprasellar
::isr::infrasellar
::psr::parasellar
:*:sslr::sellar-suprasellar
::esa::empty sella
::lesa::enlarged and empty sella
:*:sku0::no definite abnormal focal bony change. The sella is intact. No definite change in the vascular groove and the sutures.
::hpp::hippocampus
::clnc::cortical laminar necrosis
::rof::foramen rotundum
::ovf::foramen ovale
::juf::jugular foramen
::hyc::hypoglossal canal
::cvs::cavernous sinus
::cvn::cavernous
::mvm::medullary venous malformation
::dbs0::status post bilateral deep brain stimulator wire insertion.
:*:dbs00::placement of deep brain stimulator at bilateral subthalamic nuclei from bilateral frontal regions, which causing artifacts on images.
::skl::skull
::mtd::mastoid
::moya::reaching brain surface with regional neovasculature
::csi::centrum semiovale
::b0::no definite acute intracranial hemorrhage.
:*:b00::
sendAndNextLine("no definite acute intracranial hemorrhage.")
return
:*:b/::
sendAndNextLine("no definite acute intracranial hemorrhage. \")
return
::vps::ventriculo-peritoneal shunt
::lai::lacunar infarcts
::cvsp::cavum septum pellucidum
::cvvi::cavum velum interpositum
:*:orb=::CT of the orbits without contrast enhancement shows:`r`n-
:*:tem=::HRCT of the temporal bones without contrast enhancement shows:`r`n-
:*:sin=::CT of the paranasal sinuses without contrast enhancement shows:`r`n-
:*:sel=::MRI of the sella without/with contrast enhancement shows:`r`n-
::mng::meningioma
:*:mng1::meningiomas
:*:evdd::extra-ventricular drainage
:*:incp::internal capsule
:*:excp::external capsule
::ifd::infundibulum
::coc::corpus callosum
::lpm::leptomeningeal
::lmcc::leptomeningeal carcinomatosis
::cpa::cerebellopontine angle
::cis::3D T2WI CISS shows
:*:csr0::possible contact of right AICA loop with right facial nerve root exit zone.
:*:csl0::possible contact of left AICA loop with left facial nerve root exit zone.
:*:csr1::contact of right AICA loop with right facial nerve root exit zone.
:*:csl1::contact of left AICA loop with left facial nerve root exit zone.
::hdc::hydrocephalus
::iax::intra-axial
::xax::extra-axial
::cvx::convexity
:*:cvx1::convexities
::sin::sinus
:*:sin1::sinuses
:*:sela0::normal size of sellar fossa.
:*:sten0::Stenver's view showed normal size of bilateral internal auditory canals.
:*:mast0::Well pneumatization of bilateral mastoid bone.
:*:bm/::bilateral mastoid effusion.
:*:rm/::right mastoid effusion.
:*:lm/::left mastoid effusion.
::mos::mastoiditis
:*:c2c::cervicocranial arteries
::cro::craniotomy
::cre::craniectomy
::bur::burr hole
:*:bur1::burr holes
::pal::parenchyma loss
:*:pit0::No evidence of pituitary tumor.`r`n- No deviation of pituitary stalk.`r`n- The posterior pituitary bright SI is preserved.`r`n- The optic chiasm is not displaced.
:*:pit1::preserved physiologic high signal intensity on T1WI at the posterior pituitary gland
::hump::humping of the diaphragma sella, compatible with peripubertal changes
:*:orb0::There is no definite abnormality nor enhancement of bilateral globes, periseptal soft tissue, optic nerves and complex, extraorcular muscles and the bony orbit.
:*:or0::intact orbits.
::pit::pituitary
::ptg::pituitary gland
::cb::cerebrum
:*:cb1::cerebral
::crb::cerebellum
:*:crb1::cerebellar
::wm::white matter
::gm::gray matter
::gwj::gray-white matter junction
:*:pvwm::periventricular white matter
:*:pwvm::periventricular white matter
::pvw::periventricular
:*:leu-::
send % "非特異性腦白質變化"
return
::leu::leukoaraiosis
::lue::leukoaraiosis
::bra::brain atrophy
::epm::encephalomalacia
:*:csf0::
sendAndNextLine("normal appearance of sulci, fissures and ventricles. ")
return
:*:BRA0::
sendAndNextLine("Mild brain atrophy with dilated sulci, fissures and ventricles. ")
return
:*:BRA1::
sendAndNextLine("Brain atrophy with dilated sulci, fissures and ventricles. ")
return
:*:BRA2::
sendAndNextLine("Prominent brain atrophy with dilated sulci, fissures and ventricles. ")
return
::clu::
sendAndNextLine("Low densities at bilateral periventricular white matter, suggestive of leukoaraiosis. ")
return
:*:clu1::
sendAndNextLine("Low densities at bilateral periventricular white matter, suggestive of mild leukoaraiosis. ")
return
:*:clu2::
sendAndNextLine("Confluent low densities at bilateral periventricular white matter, suggestive of leukoaraiosis. ")
return
::mlu::
sendAndNextLine("Multiple nonspecific hyperintensities over bilateral cerebral white matter on T2 FLAIR, suggestive of leukoaraiosis. ")
return
:*:mlu1::
sendAndNextLine("Some hyperintensities over bilateral cerebral white matter on FLAIR, suggestive of mild leukoaraiosis. ")
return
:*:mlu2::
sendAndNextLine("Confluent nonspecific hyperintensities over bilateral cerebral white matter on T2 FLAIR, suggestive of extensive leukoaraiosis. ")
return
::VAU::
sendAndNextLine("normal appearance of the cranial vault and skull base. ")
return
::vua::
sendAndNextLine("normal appearance of the cranial vault and skull base. ")
return
:*:VAU1::
sendAndNextLine("normal appearance of the skull base. ")
return
:*:Vua1::
sendAndNextLine("normal appearance of the skull base. ")
return
:*:DWI0::
sendAndNextLine("no definite focal restriction of diffusion on DWI and ADC map. ")
return
:*:diw0::
sendAndNextLine("no definite focal restriction of diffusion on DWI and ADC map. ")
return
:*:dw0::
sendAndNextLine("no definite focal restriction of diffusion on DWI and ADC map. ")
return
:*:TOF0::
sendAndNextLine("TOF MRA of circle of Willis appears normal. ")
return
:*:MRA0::
sendAndNextLine("TOF and contrast enhanced MRA shows no significant abnormality of major cervicocranial vessels. ")
return
:*:MRA1::
sendAndNextLine("TOF MRA shows no significant abnormality of major cervicocranial vessels. ")
return
:*:MRA2::
sendAndNextLine("Contrast enhanced MRA shows no significant abnormality of major cervicocranial vessels. ")
return
:*:MAS0::
sendAndNextLine("Clear bilateral mastoid air cells. ")
return
:*:MAS1::Decreased pneumatization of mastoid air cells. {left 19}
:*:MAS2::
sendAndNextLine("Bilateral small amount mastoid effusion. ")
return
::mas::mastoid air cells
::NBE::
sendAndNextLine("no abnormal enhancing lesion in the brain parenchyma. ")
return
::NBA::
sendAndNextLine("no abnormal attenuation in the brain parenchyma. ")
return
:*:NBA1::
sendAndNextLine("no abnormal SI in the brain parenchyma. ")
return
::NBAE::
sendAndNextLine("no abnormal signal change or enhancing lesion in the brain parenchyma. ")
return
:*:NBAE1::
sendAndNextLine("no abnormal attenuation or enhancing lesion in the brain parenchyma. ")
return
::oi::old insult
:*:oi1::old insults
::rif::recent ischemia/infarct
:*:rif1::recent infarct
::ric::recent ischemic change
::fro::frontal
::par::parietal
::occ::occipital
::tem::temporal

upToSize:
send % "{bs " StrLen($.value(0))  "}"
send % "up to " $.value(1) "mm" $.value(2)
$:=""
return


brainLobe:
;~ loop % strlen($1)+1
    ;~ send {bs}
a:=$.value(1), str:=""
;~ MsgBox % $
loop,parse,a
{
    if (a_loopfield="f")
       str.="fronto-"
    else if (a_loopfield="t")
       str.="temporo-"
    else if (a_loopfield="p")
       str.="parieto-"
	else if (a_loopfield="o")
       str.="occipito-"
	else if (A_LoopField = "i")
		str.="insulo-"
}
;~ MsgBox % str
send % "{bs " StrLen($.value(0))  "}"
send % SubStr(str,1,-2) "a" (str~="i)insulo-$"?"r":"l")
$:=""
return
::th::thalamus
:*:th1::thalami
::bath::
sendAndNextLine("atherosclerotic calcification of the intracranial vessels.")
return
:*:bath0::
sendAndNextLine("mild atherosclerotic calcification of the intracranial vessels.")
return
::bnc::atherosclerotic calcification of cervicocranial arteries.
:*:scwm::subcortical white matter
::mx::maxillary
:*:MAX0::Mucus retention in maxillary sinus.{left 16}
:*:MAX1::Mucosal thickening in maxillary sinus.{left 16}
:*:MAX2::Retention cyst in maxillary sinus.{left 16}
::bg::basal ganglion
:*:bg1::basal ganglia
::intc::intracranial
::vnt::ventricle
:*:vnt1::ventricles
:*:vnt2::ventricular
::vnd::ventricular device
::hemi::hemisphere
:*:hemi1::hemispheres
::cbh::cerebral hemisphere
:*:cbh1::cerebral hemispheres
:*:cbh2::cerebellar hemisphere
:*:cbh3::cerebellar hemispheres
::cab::carotid bulb
:*:cab1::carotid bulbs
::sfn::carotid siphon
:*:sfn1::carotid siphons
:*:ccaa::common carotid artery
:*:ccaa1::common carotid arteries
:*:scaa::subclavian artery
:*:scaa1::subclavian arteries
:*:scvv::subclavian vein
:*:scvv1::subclavian veins

:*:icaa::internal carotid artery
:*:icaa1::internal carotid arteries
:*:scvv::subclavian vein
:*:scvv1::subclavian veins
::paic::paraclinoid ICA
:*:ecaa::external carotid artery
:*:ecaa1::external carotid arteries
:*:acma::anterior communicating artery
:*:acom::AComA
:*:pcom::PComA
:*:pcma::posterior communicating artery
:*:pcma1::posterior communicating arteries
:*:mcaa::middle cerebral artery
:*:acaa::anterior cerebral artery
:*:pcaa::posterior cerebral artery
:*:picaa::posterior inferior cerebellar artery
:*:aicaa::anterior inferior cerebellar artery
:*:vaa::vertebral artery
:*:vaa1::vertebral arteries
:*:baa::basilar artery
:*:vbaa::vertebrobasilar artery
:*:lac-::
send % "微細梗塞"
return
::lac::lacune
:*:lac1::lacunes
::ol::old lacune
:*:ol1::old lacunes
::aol::an old lacune
:*:ctp0::CT perfusion shows symmetric cerebral perfusion.
:*:ctp1::CT perfusion shows decreased CBF and prolonged MTT
::ptnb::patent bilateral ICA, MCA, ACA, PCA, VA, and BA.
:*:cow0::TOF MRA shows no definite vascular abnormality of the Willis circle of arteries.
::toma::TOF MRA shows
::cema::Contrast-enhanced MRA shows
::tcma::TOF MRA and contrast-enhanced MRA show
::pds::patent dural sinuses.
::tsn::transverse sinus
:*:tsn1::transverse sinuses
::ssn::sigmoid sinus
:*:ssn1::sigmoid sinuses
:*:tssn::transverse-sigmoid sinus


:*:tra0::no evidence of traumatic brain injury nor cervical fracture.
:*:tem0::
(
HRCT for temporal bones without contrast enhancement shows:
- Normal appearance of bilateral external ear canal and middle ear ossicles.
- Normal appearance of bilateral inner ear bony labyrinthes.
- Well pneumatization of bilateral mastoids.
)
:*:forp::fetal origin of the right PCA
:*:folp::fetal origin of the left PCA
::fobp::fetal origin of bilateral PCA
::tsh::trans-sphenoid hypophysectomy
:*:tsh1::Post-operative change in the sella turcica with evidence of prior trans-sphenoid hypophysectomy.
:*:tsh2::Post-operative changes of trans-sphenoid hypophysectomy with increased SI in the sphenoid sinus and bony defect at the sellar floor.
::ocd::downward herniation of the optic chiasm due to post-operative change.
:*:ocd1::Mild downward herniation of the optic chiasm due to post-operative change.
:*:mlsr::midline shift to right side
:*:mlsl::midline shift to left side
::mls::midline shift
:*:lpic::left vertebral artery ending at PICA
:*:rpic::right vertebral artery ending at PICA


;neck
::bnl::bilateral neck lymph nodes

::bpx::brachial plexus
:*:bpx1::brachial plexi

::mlm::myelomalacia

::ggb::gingivobuccal
:*:bcab::bilateral carotid bulbs
:*:rcab::right carotid bulb
:*:lcab::left carotid bulb

:*:bsfn::bilateral carotid siphons
:*:rsfn::right carotid siphon
:*:lsfn::left carotid siphon


::kkb::concha bullosa
:*:rcrm::retention cyst in right maxillary sinus.
:*:rcrm1::retention cysts in right maxillary sinus.
:*:rclm::retention cyst in left maxillary sinus.
:*:rclm1::retention cysts in left maxillary sinus.
:*:rcbm::retention cysts in bilateral maxillary sinuses.

:*:mtrm::mucosal thickening in right maxillary sinus.
:*:mtlm::mucosal thickening in left maxillary sinus.
:*:mtbm::mucosal thickening in bilateral maxillary sinuses.

:*:mrrm::mucus retention in right maxillary sinus.
:*:mrlm::mucus retention in left maxillary sinus.
:*:mrbm::mucus retention in bilateral maxillary sinuses.

:*:art1::Beam-hardening artifacts from dental prosthesis obscure the image details in oral cavity.
:*:art2::Magnetic susceptibility artifacts from dental prosthesis obscure the image details in oral cavity.
::omt::osteomucosal thickening
::zyg::zygomatic
::trg::pterygoid
::vcc::vocal cord
::mdb::mandible
:*:mdb1::mandibular
::scb::scleral buckling
::nnl::no definite neck lymphadenopathy.
::lrg::laryngectomy
::tlg::total laryngectomy
::msp::masticator space
::crp::carotid space
::crt::carotid
::ppp::parapharyngeal space
::rpp::retropharyngeal space
::bcp::buccal space
::buc::buccal
::itf::infratemporal fossa
::ptp::parotid space
::skb::skull base

::por::periorbital
::orb::orbital
::orw::orbital wall

::snc::sinonasal cavity
:*:snc1::sinonasal cavities

::rms::right maxillary sinus
::lms::left maxillary sinus
::bms::bilateral maxillary sinuses

::rps::right sphenoid sinus
::lps::left sphenoid sinus
::bps::bilateral sphenoid sinuses

::rfs::right frontal sinus
::lfs::left frontal sinus
::bfs::bilateral frontal sinuses

::res::right ethmoid sinus
::les::left ethmoid sinus
::bes::bilateral ethmoid sinuses

::rmx::retromaxillary
::adt::aerodigestive tract
::rpx::retropharyngeal
:*:rpx1::retropharynx
:*:dllp::dehiscence of left lamina papyracea.
:*:drlp::dehiscence of right lamina papyracea.
:*:thyd::thyroidectomy
:*:lart::laryngectomy
:*:trko::tracheostomy
::nlc::nuchal ligament calcification.
:*:npcy-::
send % "鼻咽囊腫"
return
::npcy::nasopharyngeal cyst
:*:aoas::atlanto-occipital assimilation
::pys::pyriform sinus
:*:pys1::pyriform sinuses
::exf::exophthalmos
::gof::Graves' ophthalmopathy
::oca::oral cavity
::nca::nasal cavity
:*:nca1::nasal cavities
::gst::glossectomy
::tym::tympanic membrane
::tye::thyroidectomy
::aef::aryepiglottic fold
::nst::nasal septum
;~ ::omc::ostiomeatal complex
::ppf::pterygopalatine fossa
:*:rcy-::
send % "鼻竇滯留囊腫"
return
::rcy::retention cyst
:*:rcy1::retention cysts
::faf::fissula ante fenestram
::mps::mucosal thickening in paranasal sinuses.
::rmr::retromolar
::tg::tongue
::ig::eyeglobe
:*:ig1::eyeglobes
::nk::neck
::msad::Magnetic suceptibility artifacts from dental prosthesis obscure the image details in oral cavity.
:*:eye0::phthisis bulbi
:*:eye1::status post phacoemulsification
::oph::ophthalmic
::djdc::degenerative change of cervical spine
:*:cs0::normal alignment of cervical spine.
:*:ts0::normal alignment of thoracic spine.
:*:ls0::normal alignment of lumbar spine.
:*:tls0::normal alignment of thoracolumbar spine.
::mpo::mucoperiosteal
::pnm::pneumatization
:*:pns-::
send % "鼻竇"
return
::pns::paranasal sinuses
:*:pns1::paranasal sinusitis
::sns::sinusitis
::npx::nasopharynx
::np::nasopharyngeal
:*:npx1::nasopharyngeal
::opx::oropharynx
:*:opx1::oropharyngeal
::lx::larynx
:*:lx1::laryngeal
::ppx::parapharyngeal
::px::pharynx
:*:px1::pharyngeal
::hpx::hypopharynx
:*:hpx1::hypopharyngeal
:*:ijvv::internal jugular vein
:*:ijvv1::internal jugular veins
::mxy::maxillary
::mxs::maxillary sinus
:*:mxs1::maxillary sinuses
:*:mxs2::maxillary sinusitis
::ets::ethmoid sinus
:*:ets1::ethmoid sinuses
:*:ets2::ethmoid sinusitis
::eth::ethmoid
::sph::sphenoid
::sps::sphenoid sinus
:*:sps1::sphenoid sinuses
:*:sps2::sphenoid sinusitis
::frs::frontal sinus
:*:frs1::frontal sinuses
:*:frs2::frontal sinusitis
:*:thy-::
send % "甲狀腺"
return
::thy::thyroid
::thg::thyroid gland
:*:thg1::thyroid glands
::etg::enlarged thyroid gland
:*:etgn::enlarged thyroid gland with nodule(s).
:*:thyc::thyroid calcification(s)
::pvst::prevertebral soft tissue
:*:rtc0::
sendAndNextLine("post-radiation edematous change of the retropharyngeal space and bilateral neck interstitium as well as fatty change in the C spine. ")
return
:*:rtc1::
sendAndNextLine("post-radiation edematous change of bilateral neck interstitium as well as fatty change in the C spine. ")
return
:*:rtc2::
sendAndNextLine("post-radiation fatty change in the C spine. ")
return
:*:rtc3::
sendAndNextLine("post-radiation edematous change of bilateral neck interstitium. ")
return
::cerv::cervical
:*:pns0::
sendAndNextLine("Clear paranasal sinuses. ")
return
:*:ph0::
sendAndNextLine("Clear nasopharynx and parapharyngeal space. ")
return
::sbm::submandibular
::sbg::submandibular gland
:*:sbg1::submandibular glands
::sln::sublingual
::slg::sublingual gland
:*:slg1::sublingual glands
::ptd::parotid
::pdg::parotid gland
:*:pdg1::parotid glands
::scv::supraclavicular
::icv::infraclavicular
::nln::no definite enlarged (>1cm) neck lymph node.{enter}-
:*:nln0::
sendAndNextLine("small lymph nodes (<1cm) in bilateral neck. ")
return
:*:nlap1::Enlarged lymph nodes in bilateral neck, the largest one () at {left 5}
:*:br0::no SI change nor abnormal enhancing lesion of visible brain parenchyma.
:*:tn-::
send % "甲狀腺結節"
return
:*:tn/::thyroid nodule(s).
:*:tn1::thyroid nodules
::btn::bilateral thyroid nodules.
::tn::thyroid nodule
:*:thn1::thyroid nodules
:*:n1/::
(
- Post-RT fatty change of the C spine bone marrow and flattened mucosa at nasopharynx.
- No obvious local recurrent tumor.
- No obvious abnormality at skull base and visible brain.
- No evidence of abnormally enlarged (>1cm) lymph nodes.
- Clear paranasal sinuses and mastoids.
)
:*:n0/::
(
- Clear nasopharynx and parapharyngeal space.
- No obvious abnormality at skull base and visible brain.
- No evidence of abnormally enlarged (>1cm) lymph nodes.
- Clear paranasal sinuses and mastoids.
)


;ortho
::mtp::medial tibial plateau
::ltp::lateral tibial plateau

:*:mpar::medial patellar retinaculum
:*:lpar::lateral patellar retinaculum

:*:chll::coracohumeral ligament
:*:roii::rotator interval
:*:rcii::rotator cuff interval
:*:ritt::rotator interval tear
::bts::biceps tendon sheath
::pli::periligamentous
::mso::mixed sclerotic/osteolytic

:*:frz0::thickening of the axillary recess joint capsule
::frz::adhesive capsulitis

::ije::increased joint effusion
::ahi::acromio-humeral interval
:*:tnlg::intact tendons and ligaments.
:*:lgtn::intact ligaments and tendons.
:*:tn0::intact tendons.
:*:lg0::intact ligaments.
:*:mn0::intact meniscus.

::lum::lumbar
:*:prnc::perineural cyst(s)
::tlv::Tarlov cyst
:*:tlv1::Tarlov cysts
:*:stlv::sacral Tarlov cyst(s).

:*:fd0::no obvious displaced fracture. (Small bone fracture may not be detected by images.)
:*:acet::acetabulum
::scp::scapula
::mrl::marrow-replacing lesion
:*:mrl1::marrow-replacing lesions
::nvr::nerve root
:*:nvr1::nerve roots
::ceq::cauda equina
:*:spst::spinal stenosis
:*:ss0::no significant spinal stenosis.
::bom::bone metastases
:*:bomc::bone metastases with compression fracture.
:*:bomf::bone metastases with fracture.
:*:sbom::sclerotic bone metastases.
:*:obom::osteolytic bone metastases.
::hum::humerus
:*:hum1::humeral
::fem::femur
:*:fem1::femoral
::tbi::tibia
:*:tbi1::tibial
::fbu::fibula
:*:fbu1::fibulal
::rad::radius
:*:rad1::radial
::un::ulna
:*:un1::ulnar
::sld::shoulder
::bme::bone marrow edema
::pop::popliteal artery
:*:pop1::popliteal arteries
::clv::clavicle
:*:clv1::clavicles
:*:clv2::clavicular
::opk::osteopoikilosis
::ACLL::anterior cruciate ligament
:*:crl0::intact cruciate ligaments.
:*:crl1::cruciate ligaments
::ACL1::grade 1 ACL injury (intraligamentous injury)
::ACL2::grade 2 ACL tear (suggesting partial tear)
::ABN1::type I accessory navicular bone
::ABN2::type II accessory navicular bone
::ACLAM::anteromedial bundle
;~ ::LPL::posterolateral bundle
::ACR::acromion
::AHLM::anterior horn of lateral meniscus
::AHMM::anterior horn of medial meniscus
::ACO::accessory ossicle
:*:ACO1::accessory ossicles
::ARS::articular-side
::ASS::multilevel syndesmophytoses, ligamentous ossifications, bamboo-appearance of spine, and ankylosis of bilateral sacroiliac joints, compatible with ankylosing spondylitis

::AVN::avascular necrosis
::AVN2::subchondral geographic lesion with serpigeous sclerotic margin
::AVN3::subchondral geographic lesion with serpigeous sclerotic margin and subchondral collapse
::AVNMRR::geographic subchondral lesion, of intermediate to low SI on T1WI, mixed SI on T2WI, and marginal enhancement on post-contrast T1WI, with serpiginous sclerotic margin at the right femoral head; mild ill-defined area of hyperemic or edematous bone marrow at the adjacent region of right femoral neck to right trochanteric area; partial collapse with subchondral fracture at the right femoral head; abnormal increased effusion and synovial enhancement in the right hip joint space.
::AVNMRL::geographic subchondral lesion, of intermediate to low SI on T1WI, mixed SI on T2WI, and marginal enhancement on post-contrast T1WI, with serpiginous sclerotic margin at the left femoral head; mild ill-defined area of hyperemic or edematous bone marrow at the adjacent region of left femoral neck to left trochanteric area; partial collapse with subchondral fracture at the left femoral head; abnormal increased effusion and synovial enhancement in the left hip joint space.
::B1::epiphysis
::B12::epimetaphysis
::B2::metaphysis
::B23::diametaphysis
::B3::diaphysis
::BAKERS::loculated cystic lesion, with communicating tract to the synovial cavity and between the medial head of gastrocnemius muscle and semimenbranosus tendon, at posterior medial aspect of knee joint.
::BFG::femoral greater trochanteric region
::BFI::femoral intertrochanteric region
::BFIS::femoral inter- to subtrochanteric region
;~ ::BFL::femoral lesser trochanteric region
;~ ::BFS::femoral subtrochanteric region
::BGD::bulging disc
:*:BGD1::bulging discs
::BGC::concentric bulging disc
:*:BGC1::concentric bulging discs
::BGE::eccentric bulging disc
:*:BGE1::eccentric bulging discs
::BGG::bulging disc(s) with adjacent thecal sac indentation
::BGM::mild bulging disc(s) with mild adjcent thecal sac indentation
::bpd::bulging-protruding disc
:*:bpd1::bulging-protruding discs
::BHG::humeral greater tubercle
::BHN::humeral surgical neck
::BIP::biphalangism at the little toe
::BIP2::biphalangism at the little and 4th toes
::BIS::bone island(s) (enostosis)
:*:BLC1::biceps-labral complex
::BTT::tibial tuberosity
::BUS::bursal-side
::COP::cord compression
::CID::cortical indistinctness
::CDHL::shallowing of acetabulum with superior lateral subluxation of the deformed femoral head and joint space narrowing and subchondral sclerosis, suggestive of congenital dysplasia of left hip joint.
::CDHR::shallowing of acetabulum with superior lateral subluxation of the deformed femoral head and joint space narrowing and subchondral sclerosis, suggestive of congenital dysplasia of right hip joint.
::CFAA::common femoral artery
::CFAA1::common femoral arteries
::CFF::wedge deformity and decreased height, suggestive of compression fracture, at
::CFH::compression fracture with decreased vertebral height at
;~ ::CFHH::decreased vertebral height(s), sugg. of compression fracture, at
::CFP::pathological compression fracture
::CFW::compression fracture with wedge deformity at
;~ ::CFWW::wedge deformity, sugg. of compression fracture, at
::CJ::in conjunction with
::CJJ::in conjunction with bilateral facet joint arthroses and hypertrophic ligamenta flava, causing
::CJ1::with hypertrophic ligamenta flava, causing
::CJ2::with bilateral facet joint arthroses and hypertrophic ligamenta flava, causing
::CMP0::chondromalacia patella
;~ ::CMP1::swelling and softening with increased SI on fat-suppressed PD images at grade I chondromalacia patella (Shahriaree grading system)
::CMP2::small cartilage fissure (involving less than 50% thickness) at grade II chondromalacia patella (Shahriaree grading system)
::CMP3::irregular cartilage thinning and fissuring (involving more than 50% thickness) at grade III chondromalacia patella (Shahriaree grading system)
::CMP4::full-thickness cartilage defect with exposure of overlying bone at grade IV chondromalacia patella (Shahriaree grading system)
::CPPD::CPPD (Calcium Pyrophosphate Dihydrate Deposition Disease)
::DA::degenerative arthroses
::DAC::degenerative arthrosis of the anterior atlantoaxial joint
::DAW::degenerative arthroses of the distal radioulnar, ulnocarpal and radiocarpal joints
::DBF::displaced bone fragment
:*:DBF1::displaced bone fragments
::DBP::distal bone part
:*:DBP1::distal bone parts
::DC::degenerative change
:*:DC1::degenerative changes
::DDD::degenerative disc disease
::DDH::developmental dysplasia of hip
::DDH1::shallowing of the acetabulum
::DDH2::mild lateral positioning of femoral head
::DDHB::shallowing of the acetabulum with relative lateral subluxated femoral head on both sides, suggesting developmental dysplasia of both hips
::DDHL::shallowing of the acetabulum with relative lateral subluxated femoral head on left side, suggesting developmental dysplasia of hip
::DDHR::shallowing of the acetabulum with relative lateral subluxated femoral head on right side, suggesting developmental dysplasia of hip
::DEH::dehydrated disc
:*:dend::dehydrated narrowed disc
::DHB::degenerative arthroses of both hip joints
::DHL::degenerative arthroses of left hip joint
::DHR::degenerative arthroses of right hip joint
::DISH::flowing ossification of anterior longitudinal ligament at lower thoracic to upper lumbar spine, diffuse idiopathic skeletal hyperostosis (DISH) is suspected
::DISI::dorsal intercalated-segmental instability
::DLL::decreased lordosis of the lumbar spine
::DPAA::dorsalis pedis artery
::DS::degenerative change of spine
::DSD::degenerative spinal and disc disease
::DSI::degenerative arthroses of bilateral sacroiliac joints
::DSIH::degenerative arthroses of bilateral sacroiliac and hip joints
::DSIHL::degenerative arthroses of left sacroiliac and hip joints
::DSIHR::degenerative arthroses of right sacroiliac and hip joints
::DSIL::degenerative arthroses of left sacroiliac joint
::DSIR::degenerative arthroses of right sacroiliac joint
::DSSI::lumbar spondylosis and degenerative arthroses of bilateral sacroiliac joints
::DSSIH::lumbar spondylosis and degenerative arthroses of bilateral sacroiliac and hip joints
;~ ::DSS::degenerative change of spine and both shoulders
::EC::endplate change
::ECD::degenerative endplate change
::ECM::Modic type
::EH::edema/hyperemia
::EFS::increased suprapatellar effusion
::EFSB::effusion in the bilateral suprapatellar pouches
::EFSBB::effusion in the bilateral suprapatellar pouches and knee joint spaces
::EFSL::effusion in the left suprapatellar pouch
::EFSLL::effusion in the left suprapatellar pouch and knee joint space
::EFSR::effusion in the right suprapatellar pouch
::EFSRR::effusion in the right suprapatellar pouch and knee joint space
;~ ::ENT::enthesopathic change
::EXO::exostosis
::EXEC::except for degenerative endplate change
::EXD::extruding disc
::F2::index (2nd) finger
::F3::middle (third) finger
::F4::ring (4th) finger
::F5::little (5th) finger
::FA::angulation of distal fragment
::FAA::anterior angulation of distal bone part
::FAD::dorsal angulation of distal bone part
::FAI::femoro-acetabular impingement
::FAL::lateral (valgus) angulation of distal bone part
::FAM::medial (varus) angulation of distal bone part
::FAP::posterior angulation of distal bone part
::FAV::volar angulation of distal bone part
::FC::comminuted fracture
::FCAS::femoral condylar articular surface
::FCD::comminuted displaced fracture
::FCDI::comminuted displaced impacted fracture
::FCDIA::comminuted displaced intra-articular fracture
::FCDIIA::comminuted displaced intra-articular fracture
::FCI::comminuted impacted fracture
::FCIA::comminuted intraarticular fracture
::FCIIA::comminuted impacted intra-articular fracture
::FCLL::fibular collateral ligament
::FCP::complex fracture
::FD::displaced fracture
::FDA::anterior displacement of distal bone part
::FDD::dorsal displacement of distal bone part
::FDI::displaced impacted fracture
::FDIA::displaced intra-articular fracture
::FDIS::distraction of bone parts
::FDIIA::displaced impacted intra-articular fracture
::FDL::lateral displacement of distal bone part
::FDM::medial displacement of distal bone part
::FDP::posterior displacement of distal bone part
::FDV::volar displacement of distal bone part
::FE::neural foraminal encroachment
::FEL::encroachment to the left neural foramen
::FER::encroachment to the right neural foramen
::FH::healed fracture
::FHH::healing fracture
::FHO::healed oblique fracture
::FHS::healed spiral fracture
::FHT::healed transverse fracture
;~ ::FI::impacted fracture
::FIA::intra-articular fracture
::FIIA::impacted intraarticular fracture
::FJA::facet joint arthroses
::FJAL::facet joint arthroses at lower levels
::FN::neural foraminal narrowing
::FO::previous oblique fracture
::FOVER::overriding of fracture ends
::FP::pathological fracture
::FR::rotation of distal fragment
;~ ::FS::previous spiral fracture
::FSI::fat-supressed images
::FT::previous transverse fracture
::HLF::hypertrophic ligamenta flava
::HV::hallux valgus
::IXT::intraarticular extention to
::IBFU::interbody fusion
::IFAR::inflammatory arthritis
::IMP::shoulder impingement
::IMPL::lateral downsloping and lowlying of left acromion with subacromial spur formation and narrowed subacromial space, suggestive of shoulder impingment.
::IMPR::lateral downsloping and lowlying of right acromion with subacromial spur formation and narrowed subacromial space, suggestive of shoulder impingment.
::TSI::adjacent thecal sac indentation
::INJ::multiple calcified injection granulomas over bilateral buttocks
::ISB::intrasubstance
::ISTT::infraspinatus tendon
::JAC::acromioclavicular joint
:*:JAC1::acromioclavicular joints
::JCA::patellofemoral joint compartment
:*:JCA1::patellofemoral joint compartments
::JCAA::all joint compartment
:*:JCAA1::all joint compartments
::JCAL::patellofemoral and lateral joint comparment
:*:JCAL1::patellofemoral and lateral joint comparments
::JCAM::patellofemoral and medial joint compartment
:*:JCAM1::patellofemoral and medial joint compartments
::JCB::all joint compartments of both knee joints
::JCC::calcaneocuboid joint
:*:JCC1::calcaneocuboid joints
::JCL::lateral joint compartment
:*:JCL1::lateral joint compartments
::JCM::medial joint compartment
:*:JCM1::medial joint compartments
::JCMC::carpometacarpal joint
:*:JCMC1::carpometacarpal joints
::JCML::medial and lateral joint compartment
:*:JCML1::medial and lateral joint compartments
::JD::junction of middle and distal thirds of
::JDIP::distal interphalangeal joint
:*:JDIP1::distal interphalangeal joints
::JFT::femorotibial joint
:*:JFT1::femorotibial joints
::JGH::glenohumeral joint
:*:JGH1::glenohumeral joints
::JHR::humeroradial joint
:*:JHR1::humeroradial joints
::JHU::humeroulnar joint
:*:JHU1::humeroulnar joints
::JIP::interphalangeal joint
:*:JIP1::interphalangeal joints
::JIPF::interphalangeal joint(s) of thumb(s) and some distal interphalangeal joint(s) of finger(s)
::JIPFF::interphalangeal joint(s) of thumb(s) and some distal interphalangeal and proximal interphalangeal joint(s) of finger(s)
::JIPT::interphalangeal joint(s) of big toe(s) and some distal interphalangeal joint(s) of toe(s)
::JIPTT::interphalangeal joint(s) of big toe(s) and some distal interphalangeal and proximal interphalangeal joint(s) of toe(s)
::JK::knee joint
:*:JK1::knee joints
::JKB::both knee joint
:*:JKB1::both knee joints
::JKL::left knee joint
::JKR::right knee joint
::JMC::mid-carpal joint
:*:JMC1::mid-carpal joints
::JMP::metacarpophalangeal joint
:*:JMP1::metacarpophalangeal joints
::JMT::metatarsophalangeal joint
:*:JMT1::metatarsophalangeal joints
::JJ::no obvious bony fracture; no evidence of joint subluxation or dislocation; suggest clinical correlation.
::JO::no obvious bony fracture or destructive lesion; no evidence of joint subluxation or dislocation; suggest clinical correlation.
::JOO::no obvious bony fracture or destructive lesion; no evidence of joint subluxation or dislocation; however, small bone fracture or lesion may not be detected by the plain radiography.
::JP::junction of proximal and middle thirds of
::JPF::patellofemoral joint
:*:JPF1::patellofemoral joints
::JPIP::proximal interphalangeal joint
:*:JPIP1::proximal interphalangeal joints
::JRC::radiocarpal joint
:*:JRC1::radiocarpal joints
::JRU::radioulnar joint
:*:JRU1::radioulnar joints
::druj::distal radioulnar joint
:*:druj1::distal radioulnar joints
::pruj::proximal radioulnar joint
:*:pruj1::proximal radioulnar joints

::ptl::patella
::lpt::lateral patellar tilt

::JSI::sacroiliac joint
:*:JSI1::sacroiliac joints
::JST::subtalar joint
:*:JST1::subtalar joints
::JT::joint
:*:JT1::joints
::JTTS::trapzium-trapzoid-scaphoid joint
:*:JTTS1::trapzium-trapzoid-scaphoid joints
::JTM::temporomandibular joint
:*:JTM1::temporomandibular joints
::JTMT::tarsometatarsal joint
:*:JTMT1::tarsometatarsal joints
::JTN::talonavicular joint
:*:JTN1::talonavicular joints
::JTT::tibiotalar joint
:*:JTT1::tibiotalar joints
::JUC::ulnocarpal joint
:*:JUC1::ulnocarpal joints
::KSC::kyphoscoliosis
::KY::kyphosis
::LANK::anterior talofibular ligament, posterior talofibular ligament, and calcaneofibular ligament
::LATF::anterior talofibular ligament
::LPTF::posterior talofibular ligament
:*:aitfl::anterior inferior tibiofibular ligament
:*:pitfl::posterior inferior tibiofibular ligament
::LBD::loose body
::LBD1::loose bodies
::LCF::calcaneofibular ligament
::LCPD::Legg-Calve-Perthes disease
::LEX::lower extremities
::LHBT::long head of biceps tendon
::LRS::lateral recess stenosis
::MAM::medial malleolus
::leom::medial malleolus
::leol::lateral malleolus
;~ ::MAL::distal fibula lateral malleolus
::MCLL::medial collateral ligament
::MCL1::grade 1 signal (suggesting sprain or minimal tear) of the MCL
::MCL2::grade 2 signal (suggesting partial tear) of the MCL
::MCL3::grade 3 signal (suggesting complete tear) of the MCL
::MD1::bulging disc at posterior central aspect of L4-5 and causes intentation of the adjacent thecal sac
::MD2::protruding disc at posterior central aspect of the L4-5 and causes indentation of the adjacent thecal sac
::MDD::degenerative change with dehydrated discs at multi-levels
::MENM::medial meniscus
::MENL::lateral meniscus
::MENB::medial and lateral meniscii
::MEN1::short intrasubstance linear (or nodular) high SI on coronal GRE T2WI without extention to the capsular periphery or the articular surface at grade 1 signal (suggesting early intrasubstance degeneration)
::MEN2::horizontal linear high SI on coronal GRE T2WI with extention to the capsular periphery and without involvement of the articular surface at grade 2 signal (suggesting intrasubstance degeneration)
::MENT::meniscal tear
:*:MENT1::meniscal tears
::MF::multifocal
::MHE1::small well-defined lesion of homogeneous high SI on both T1WI and T2WI at L4, considered vertebral hemangioma first.
::vth::vertebral hemangioma
:*:vth1::vertebral hemangiomas
::MHE2::several varying-sized well-defined lesions of homogeneous high SI on both T1WI and T2WI at lumbar vertebrae, considered vertebral hemangiomas first.
::mi3::middle third
;~ ::MLL::multilevel
;~ ::MLS::multiple levels
:*:MNB0::
sendAndNextLine("no evidence of abnormal SI at the visible bony structures.")
return
:*:MNB1::
sendAndNextLine("no evidence of abnormal SI or enhancing lesion at the visible bony structures.")
return
:*:MNBM::
sendAndNextLine("no evidence of abnormal SI or enhancing lesion at bony or muscular structures.")
return
:*:MNC0::
sendAndNextLine("no evidence of abnormal SI at visible part of the spinal cord.")
return
:*:MNC00::
sendAndNextLine("no evidence of abnormal SI at the spinal cord.")
return
:*:MNC1::
sendAndNextLine("no evidence of abnormal SI or enhancing lesion at visible part of the spinal cord.")
return
:*:MNC11::
sendAndNextLine("no evidence of abnormal SI or enhancing lesion at the spinal cord.")
return
:*:MNM0::
sendAndNextLine("no evidence of abnormal SI at the muscular structures.")
return
:*:MNM1::
sendAndNextLine("no evidence of abnormal SI or enhancing lesion at the muscular structures.")
return
::MRMET::multifocal varying-sized patchy and nodular marrow lesions of abnormal SI and enhancement at
::MYELO::Myelography of the lumbar spine with injection of non-ionic contrast medium via L2-3 level was performed smoothly and it shows:
::MYELOCT::Myelo-CT study of lumbar spine with intrathecal injection of non-ionic contrast shows:>
::FBA::fine bony alignment
::NDH::fine disc hydration
::NF::no obvious bony fracture
::NDS::the disc spaces are acceptable
::NJS::the joint spaces are within normal limit
::NL::no evidence of joint subluxation or dislocation
::NRC::nerve root compression
::NSI::normal morphology of the bilateral sacroiliac joints
::NUV::negative ulnar variance
::OA::osteoarthritis
::OAA::osteoarthritic change
::OA1::minimal osteoarthritis
::OA12::minimal to mild osteoarthritis
::OA2::mild osteoarthritis
::OA23::mild to moderate osteoarthritis
::OA3::moderate osteoarthritis
::OA34::moderate to severe osteoarthritis
::OA4::severe osteoarthritis
::OA11::minimal osteoarthritis with tiny marginal osteophyte(s) at
::OA122::mild osteoarthritis with tiny or small marginal osteophyte(s) at
::OA22::mild osteoarthritis with small marginal osteophyte(s) at
::OA233::mild to moderate osteoarthritis with marginal osteophyte(s) and mild joint space narrowing at
::OA33::moderate osteoarthritis with marginal osteophyte(s) and joint space narrowing at
::OA344::moderate to severe osteoarthritis with marginal osteophyte(s), joint space narrowing, and mild uneven articular surface at
::OAA4::severe osteoarthritis with large marginal osteophyte(s), joint space narrowing, and uneven articular surface at
::OAANK::osteoarthritis at the tibiotalar joint, subtalar joint, and midtarsal joints
::OAF1::osteoarthritis at interphalangeal joint(s) of thumb(s) and some distal interphalangeal joint(s) of finger(s)
::OAF2::osteoarthritis at interphalangeal joint(s) of thumb(s) and some distal interphalangeal and proximal interphalangeal joint(s) of finger(s)
::OAT1::osteoarthritis at interphalangeal joint(s) of big toe(s) and some distal interphalangeal joint(s) of toe(s)
::OAT2::osteoarthritis at interphalangeal joint(s) of big toe(s) and some distal interphalangeal and proximal interphalangeal joint(s) of toe(s)
;~ ::OAB::osteoarthritic change at all joint compartments of both knee joints
::OABA::osteoarthritic change at all joint compartments, more at patellofemoral joint compartments, of both knee joints
::OACL::status post anterior cruciate ligament reconstruction with presence of tibial and femoral tunnels and metallic prostheses at distal femur and proximal tibia; fine alignment of the femorotibial joint and postOP change around the knee joint; suggest follow up study.
::OAH::osteoarthritic change of both hip joints
::OAHR::osteoarthritic change of right hip joint
::OAHL::osteoarthritic change of left hip joint
::OAL::osteoarthritic change at all joint compartments of left knee joint
::OALA::osteoarthritic change at all joint compartments, more at patellofemoral joint compartment, of left knee joint
::OALB::the joint spaces are more narrowed at both lateral joint compartments and cause valgus deformity of both knee joints
::OALL::the joint space is more narrowed at lateral joint compartment and causes valgus deformity of left knee joint
::OALR::the joint space is more narrowed at lateral joint compartment and causes valgus deformity of right knee joint
::OAMB::the joint spaces are more narrowed at both medial joint compartments and cause varus deformity of both knee joints
::OAML::the joint space is more narrowed at medial joint compartment and causes varus deformity of left knee joint
::OAMR::the joint space is more narrowed at medial joint compartment and causes varus deformity of right knee joint
::OAP::osteoarthritic change at the patellofemoral joint
::OAR::osteoarthritic change at all joint compartments of right knee joint
::OARA::osteoarthritic change at all joint compartments, more at patellofemoral joint compartment, of right knee joint
::OBG::bone grafting
::OBI::external immobilization
::OBP::status post blade plate and screw fixation
::OC::external cast or splint application
::OC1::status post external cast or splint application; the detail of bones is obliterated by artifacts of the cast or splint
::OCD::osteochondral
::OCDD::osteochondrosis
::OCI::patchy sclerotic change over lower poles of bilateral sacroiliac joints, suggesting osteitis condensans ilii
;~ ::OCP::status post calcaneal lengthening and 1st toe interphalangeal fusion
::ODDH1::acetabuloplasty
::ODDH2::varus osteotomy
::ODP::status post dynamic compression plate and screw fixation
::ODS::status post dynamic compression screw fixation
::OE::status post external fixator application
::OEB::status post external bandage with radiopaque artifacts and some detail of bones is obliterated
::OEI::status post external immobilization
::OFC::status post calcaneal lengthening
::OFN::posterior tibialis tendon transfer
::OFS::status post subtalar arthroereisis
::OFT::talonavicular stapling
::OHB::status post arthroplasty at both hip joints
::OHHB::status post hemiarthroplasty at both hip joints
::OHHL::status post hemiarthroplasty at left hip joint
::OHHR::status post hemiarthroplasty at right hip joint
::OHL::status post arthroplasty at left hip joint
::OHR::status post arthroplasty at right hip joint
::OII::status post internal (metallic) fixation
::OIB::interbody fusion at
::OIF::status post interbody fusion at
::OIN::status post intramedullary nail and interlocking screw fixation
::OIP::status post metallic pin fixation
::OIR::status post intramedullary rod insertion
::OKB::status post total knee arthroplasty at both knee joints
::OKBB::status post total knee arthroplasty at both knee joints with fine alignment and soft tissue swelling at anterior aspects; suggest clinical correlation.
::OKL::status post total knee arthroplasty at left knee joint
::OKLL::status post total knee arthroplasty at left knee joint with fine alignment and soft tissue swelling at anterior aspect; suggest clinical correlation.
::OKR::status post total knee arthroplasty at right knee joint
::OKRR::status post total knee arthroplasty at right knee joint with fine alignment and soft tissue swelling at anterior aspect; suggest clinical correlation.
::OKSL::status post limb salvage at left distal femur with long stem knee arthroplasty at left knee joint
::OKSR::status post limb salvage at left distal femur with long stem knee arthroplasty at right knee joint
::OKW::status post K-wire fixation
::OMP::status post metallic plate and screw fixation
::OMS::status post metallic screw fixation
::OMW::metallic wire fixation
::ONN::intravertebral vacuum, suggesting osteonecrosis
::ONS::decreased height(s) with suspect intravertebral vacuum, suggesting osteonecrosis, at
::OPV::osteopenic change of visible bones
::OPCL::status post posterior cruciate ligament reconstruction with presence of tibial and femoral tunnels; fine alignment of the femorotibial joint and postOP change around the knee joint; suggest follow up study.
::OPD::osteopenic change at distal aspects of fracture site, suggestive of disuse osteopenia
;~ ::OPLL::ossification of posterior longitudinal ligament (OPLL)
::OPM::marked osteopenic change of visible bones
::OPP::periarticular osteopenia
::OPV1::suspected osteopenic change of visible bones
::ORE::removal of the implant
::ORP::status post reconstruction plate and screw fixation
::OSAL::status post soft tissue anchor fixation over the left humeral greater tuberosity
::OSAR::status post soft tissue anchor fixation over the right humeral greater tuberosity
::OSB::osteoblastic lesion
:*:OSB1::osteoblastic lesions
::OSG::irregularity and fragmentation at the tibial tuberosity with adjacent soft tissue swelling, Osgood-Schlatter disease is considered first
::OSL::status post posterior decompression and posterior instrumentation at
::OSLL::status post laminectomy and posterior decompression, lateral bony fusion, transpedicle screw insertion and posterior instrumentation at
::OSLLL::status post laminectomy and posterior decompression, lateral bony fusion, transpedicle screw insertion and posterior instrumentation, and interbody fusion at
;~ ::OSP::external splinting
::OTB::status post intramedullary pin and tension band wire fixation
;~ ::P1::distal phalanx bone(s)
;~ ::P2::middle phalanx bone(s)
::P3::proximal phalanx bone
:*:P31::proximal phalanx bones
::P4::metacarpal bone
:*:P41::metacarpal bones
::P5::metatarsal bone
:*:P51::metatarsal bones
::P11::distal phalangeal
::P22::middle phalangeal
::P33::proximal phalangeal
::P44::metacarpal
::P55::metatarsal
::PAOD::peripheral arterial occlusive disease
::PAODQ::atherosclerosis with wall calcifications at the abdominal aorta and bilateral common iliac arteries as well as multifocal varying-sized calcified wall plaques on the wall of arteries in both lower limbs.
::PARS::pars interarticularis
::PCLL::posterior cruciate ligament
::PD::posterior decompression
::PDFS::fat-suppressed PD images
::PERA::periprosthetic radiolucency
::PERI1::osteolysis
::PERI2::osteolysis or prosthetic loosening
::PERI3::prosthetic loosening
::PERIF::periprosthetic fracture
::pla::pes planus
::plaa::small calcaneal inclination angle (calcaneal pitch), suggestive of pes planus
::PF::previous fracture
:*:PF1::previous fractures
::PFF::previous fracture or osteotomy
::PHLM::posterior horn of lateral meniscus
::PHMM::posterior horn of medial meniscus
::PI::posterior instrumentation/fixation
::PLF::posterior lateral fusion
::sac0::the sacrum is obliterated by the bowel gas
::PRD::protruding disc
:*:pcnt::paracentral
::frm::foramen
:*:frm1::foramina
:*:frm2::foraminal

::pvb::pelvic bone
:*:pvb1::pelvic bones

::PROB::broad-based protruding disc
:*:PROB1::broad-based protruding discs
::PROL::eccentric protruding disc(s) at left posterior aspect
::PROR::eccentric protruding disc(s) at right posterior aspect
::PUV::positive ulnar variance
::PVNS::pigmented villonodular synovitis
::R3MT::right 3rd metatarsal
::R4MT::right 4th metatarsal
::R5MT::right 5th metatarsal
;~ ::RA::rheumatoid arthritis
::RM1::hematopoietic (red) marrow
::RM2::heterogeneous marrow signal change of mild hypointensity on T1WI but no abnormal hyperintensity on fat-suppressed T2WI at sacrum, bilateral pelvic bones and proximal femurs, hematopoietic (red) marrow is considered first.
::TSI1::thecal sac indentation and potential spinal stenosis
::RPC::retropulsed posterior cortex
::ftr::full-thickness rupture
;~ ::ptr::partial-thickness rupture
::SAL::straightening alignment
::SACB::lumbar sacralization of L5 on both sides
::SACL::partial lumbar sacralization of L5 on left side
::SACR::partial lumbar sacralization of L5 on right side
::SASD::subacromion-subdeltoid bursa
::sbcb::subcoracoid bursa
::sbf::spina bifida
::SCOB::scoliosis with main (fixed) curvature at mid-thoracic spine and compensatory (correctable) curvature at the lumbar spine
::SCOL::scoliosis with convexity of the thoracic spine to left side
::SCOLR::scoliosis of spine with convexity of the thoracic spine to left side and convexity of the lumbar spine to right side
::SCOR::scoliosis with convexity of the thoracic spine to right side
::SCORL::scoliosis of spine with convexity of the thoracic spine to right side and convexity of the lumbar spine to left side
::SCTL::scoliosis of the thoracolumbar spine
::SD::decreased disc space and end-plate change
::SDS::decreased disc space and sclerotic end-plate change
::SEC::sclerotic endplate change
::eec::edematous endplate change
::SEQ::sequestrated disc
:*:SEQ1::sequestrated discs

::SH0::the glenohumeral joint appear normal; no obvious fracture line; no evidence of joint subluxation or dislocation.
::SH1::lateral down-sloping
::SH2::subacromial spur
::SH3::inferior marginal spur
::SHD::lateral down-sloping of the acromion
::SHDL::down-sloping and low-lying of the acromion
::SHL::low-lying
::SHN::subacromial space narrowing
::SHP::synovial herniation pit
:*:SHP1::synovial herniation pits
::SHS::subacromial spur formation
::SLAC::SLAC (superior labrum anterior cuff) lesion
::SLAPP::superior labral anterior-posterior (SLAP) lesion
::SLAP2::linear high SI on T2WI and GRE T2WI in the superior labrum with anterior and posterior extension.
::SLAP3::large irregular high SI on T2WI and GRE T2WI in the superior labrum with anterior and posterior extension with bucket-handle like split and susp. extension into the biceps root.
::SMN::Schmorl's node
::SONK::spontaneous osteonecrosis of the knee (SONK)
::SONKL::osteochondral defect with sclerotic margin at left medial femoral condylar articular surface, suggesting osteonecrosis.
::SONKR::osteochondral defect with sclerotic margin at right medial femoral condylar articular surface, suggesting osteonecrosis.
::SST::supraspinatus tendon
::SSTT::subscapularis tendon
::ST1::mild stenosis
::ST12::mild to moderate stenosis
::ST2::moderate stenosis
::ST23::moderate to severe stenosis
::ST3::severe stenosis
::ST4::nearly-total occlusion
::ST5::total occlusion
;~ ::ST::spinal stenosis
::STC::soft tissue calcification
:*:STC1::soft tissue calcifications
::cat::calcific tendinitis
::cabt::calcific bursitis or tendinosis
::STH::increased heterogeneous soft tissue density
::STI::increased soft tissue density
::STIRR::fat-suppressed T2WI
::STL::soft tissue lesion
::STM::soft tissue mass
::STOS::soft tissue ossification
:*:STOS1::soft tissue ossifications
::STSA::adjacent soft tissue swelling
::STSP::periarticular soft tissue swelling
::STT::soft tissue tumor
::SUBC::subchondral
::SUC::subcutaneous
:*:suc1::subcutis
::cu::cutaneous
:*:cu1::cutis

::mtj::musculotendinous junction

;~ ::SUC1::subcutaneous swelling and fat stranding
;~ ::SUC2::subcutaneous swelling and edema
;~ ::T121::T12-L1
;~ ::T122::T12-L2
;~ ::T123::T12-L3
;~ ::T124::T12-L4
;~ ::T125::T12-L5
;~ ::T111::T11-L1
;~ ::T112::T11-L2
;~ ::T113::T11-L3
;~ ::T114::T11-L4
;~ ::T115::T11-L5
;~ ::T101::T10-L1
;~ ::T102::T10-L2
;~ ::T103::T10-L3
;~ ::T104::T10-L4
;~ ::T105::T10-L5
:*:T00::T1-2
::TAF::torn annulus fibrosus
::TE::traction enthesophyte formation at
::TECB::traction enthesophyte formation at bilateral calcaneal posterior processes
::TECL::traction enthesophyte formation at left calcaneal posterior process
::TECR::traction enthesophyte formation at right calcaneal posterior process
::TEHB::traction enthesopathy at bilateral humeral greater tuberosities
::TEHL::traction enthesopathy at left humeral greater tuberosity
::TEHR::traction enthesopathy at right humeral greater tuberosity
::TEPB::traction enthesophyte formation at bilateral patellar bases
::TEPL::traction enthesophyte formation at left patellar base
::TEPR::traction enthesophyte formation at right patellar base
::TIS::tibial intercondylar spine
::tie::tibial intercondylar eminance
::TLJ::thoracolumbar junction
::TLS::thoracolumbar spondylosis
::TLS1::thoracolumbar spondylosis with marginal osteophyte formation
::TLSF::thoracolumbar spondylosis with marginal osteophyte formation and facet joint arthroses
::TLSS::thoracolumbar scoliosis and spondylosis
;~ ::TLSS1::thoracolumbar scoliosis and spondylosis with marginal osteophyte formation
::TEC::traction enthesopathic change
::TECH::traction enthesopathic change at the humeral greater tubercle
::TECC::subchondral cyst(s) at the humeral head which may relate to traction enthesopathic change.
::TS::thoracic spondylosis
;~ ::TS1::thoracic spondylosis with marginal osteophyte formation
::TSP::traction spur at patellar base
::TSS::thoracic scoliosis and spondylosis
;~ ::TSS1::thoracic scoliosis and spondylosis with marginal osteophyte formation
::UC::callus formation
::UD::suggestive of delayed union
::UDN::radiolucent gap at fracture cleft, suggesting radiological delayed or non-union
::UAO::a small bony focus near the ulnar styloid process which is probably related to accessory ossicle or old fracture
::UOP::ulnar olecranon process
::USP::ulnar styloid process
::UUC::unilateral callus formation
::UW::well union of fracture cleft
::UWC::well union and callus formation
::VP0::status post vertebroplasty with bone cement in position
::VWC::vascular wall calcifications
::vld::valgus deformity
::vrd::varus deformity
::WD::wedge deformity
::XC::subchondral cyst
:*:XC1::subchondral cysts
::XD::disc space narrowing
::XE::subchondral erosion
:*:XE1::subchondral erosions
::XEP::periarticular erosion
:*:XEP1::periarticular erosions
::XJ::joint space narrowing
::XJJ::joint space widening
::XJA::asymmetrical joint space narrowing
::XJL::localized joint space narrowing
::XJO::marginal spur formation and joint space narrowing at
::XJS::symmetrical joint space narrowing
::XO::marginal osteophyte
:*:XO1::marginal osteophytes
::XP::posterior spur
:*:XP1::posterior spurs
::XPP::disc space narrowing and posterior spur(s) with potential spinal stenosis
::XR::subchondral radiolucencies
::XS::subchondral sclerosis
::XU::uneven articular surface
;~ ::XX::joint space narrowing and margnial osteophytes formation
::ZJA::zygapophyseal joint arthrosis
::z0::remainder of the exam is unremarkable
::ZSA::subarticular zone


:*:lscf::lumbar spondylosis with compression fracture
:*:cscf::cervical spondylosis with compression fracture
:*:tscf::thoracic spondylosis with compression fracture
:*:tlscf::thoracolumbar spondylosis with compression fracture

:*:lsop::lumbar spondylosis with post-operative changes
:*:csop::cervical spondylosis with post-operative changes
:*:tsop::thoracic spondylosis with post-operative changes
:*:tlsop::thoracolumbar spondylosis with post-operative changes
::ops::post-operative changes of the spine.

:*:csst::cervical spondylosis with spinal stenosis.
:*:tsst::thoracic spondylosis with spinal stenosis.
:*:lsst::lumbar spondylosis with spinal stenosis.
:*:tlsst::thoracolumbar spondylosis with spinal stenosis.

::CS::cervical spondylosis
;~ ::CS1::cervical spondylosis with marginal osteophyte formation
;~ ::CS2::cervical spondylosis with marginal osteophyte formation and facet joint arthroses
::CSL::cervical spondylosis with marginal osteophyte formation at lower levels
::CSM::mild cervical spondylosis with small marginal osteophyte formation
::CSP::fine alignment; no obvious fracture line; no abnormal retropharyngeal soft tissue;
::CSS::cervical scoliosis and spondylosis
;~ ::CSS1::cervical scoliosis and spondylosis with marginal osteophyte formation
;~ ::CSS2::cervical scoliosis and spondylosis with marginal osteophyte formation and facet joint arthroses
::CSSL::cervical scoliosis and spondylosis with marginal osteophyte formation at lower levels
::CSSM::cervical scoliosis and spondylosis with small marginal osteophyte formation
::LS::lumbar spondylosis
;~ ::LS1::lumbar spondylosis with marginal osteophyte formation
;~ ::LS2::lumbar spondylosis with marginal osteophyte formation and facet joint arthroses
;~ ::LS3::lumbar spondylosis with marginal osteophyte formation at multiple levels and facet joint arthroses at lower levels
::LSL::lumbar spondylosis with marginal osteophyte formation at lower lumbar levels
::LSM::mild lumbar spondylosis with small marginal osteophyte formation
::LSS::lumbar scoliosis and spondylosis
;~ ::LSS1::lumbar scoliosis and spondylosis with marginal osteophyte formation
;~ ::LSS2::lumbar scoliosis and spondylosis with marginal osteophyte formation and facet joint arthroses
::LSSL::lumbar scoliosis and spondylosis with marginal osteophyte formation at lower lumbar levels
::LSSM::lumbar scoliosis and spondylosis with small marginal osteophyte formation
::LSK::lumbar kyphoscoliosis and spondylosis
;~ ::LSK1::lumbar kyphoscoliosis and spondylosis with marginal osteophyte formation
;~ ::LSK2::lumbar kyphoscoliosis and spondylosis with marginal osteophyte formation and facet joint arthroses
::LSKL::lumbar kyphoscoliosis and spondylosis with marginal osteophyte formation at lower lumbar levels
::LSKM::lumbar kyphoscoliosis and spondylosis with small marginal osteophyte formation
::LSTV::lumbosacral transitional vertebrae
::LSTVB::lumbosacral transitional vertebrae with pseudoarticulation on both sides
::LSTVR::lumbosacral transitional vertebrae with pseudoarticulation on right side
::LSTVL::lumbosacral transitional vertebrae with pseudoarticulation on left side


::lhar::lipohemoarthrosis
::mof::marginal osteophyte formation
::pmof::posterior marginal osteophyte formation
;~ ::wdg::wedge deformity
::dch::decreased height
::dcl::decreased lordosis
::cf::compression fracture
:*:cf1::compression fractures
::iar::intra-articular
::cmn::comminuted
::dsp::displaced
::ndsp::non-displaced
::dpm::displacement
::fx::fracture
:*:fx1::fractures
::spc::cervical spine
::spt::thoracic spine
::spl::lumbar spine
::sptl::thoracolumbar spine
::spct::cervicothoracic spine
::spls::lumbosacral spine
::spd::spondylosis
::LI::spondylolisthesis
::LI2::spondylolisthesis at L2-3
::LI3::spondylolisthesis at L3-4
::LI4::spondylolisthesis at L4-5
::LI5::spondylolisthesis at L5-S1
::LID::degenerative spondylolisthesis
::LID2::degenerative spondylolisthesis at L2-3
::LID3::degenerative spondylolisthesis at L3-4
::LID4::degenerative spondylolisthesis at L4-5
::LID5::degenerative spondylolisthesis at L5-S1
::LIL::spondylolytic spondylolisthesis
::LIL2::spondylolytic spondylolisthesis at L2-3
::LIL3::spondylolytic spondylolisthesis at L3-4
::LIL4::spondylolytic spondylolisthesis at L4-5
::LIL5::spondylolytic spondylolisthesis at L5-S1
::LIA::anterolisthesis
::lir::retrolisthesis
::fx0::no obvious bony fracture
::cst::spinal canal narrowing
:*:spca::spinal canal
::doc::disc osteophyte complex

;~ ::L11::T12-L1
;~ ::L12::L1-L2
;~ ::L23::L2-L3
;~ ::L34::L3-L4
;~ ::L45::L4-L5
;~ ::L41::L4-L5-S1
;~ ::L51::L5-S1
;~ ::L35::L3-L4-L5
;~ ::L31::L3-L4-L5-S1

;~ ::C12::atlantoaxial joint

:*:sfaa::superficial femoral artery
:*:sfaa1::superficial femoral arteries
:*:ataa::anterior tibial artery
:*:ataa1::anterior tibial arteries
:*:ptaa::posterior tibial artery
:*:ptaa1::posterior tibial arteries

::bfn::bilateral neural foraminal narrowing
::rfn::right neural foraminal narrowing
::lfn::left neural foraminal narrowing
:*:cst1::mild spinal canal narrowing
:*:cst2::moderate spinal canal narrowing
:*:cst3::severe spinal canal narrowing

spine:
send % "{bs " strlen($.value(0)) "}"
send % spineLevel($)
return

spineLevel($){
	if ($.value(0)="")
		strMode:=true

str:=""

if(strMode)
	RegExMatch($, "^\D+", sg)
	,RegExMatch($, "\d+$", lvl)
else
	sg:=$.value(1)
	,lvl:=$.value(2)
if StrLen(lvl)=4 {
	if(sg!="t")
		goto nonSpine
	else
		match1:=SubStr(lvl,1,2), match2:=SubStr(lvl,3,2)
	if(match1>match2)
		goto Nonspine
}else if StrLen(lvl)=3 {
	if(sg="t"){
		match1:=SubStr(lvl,1,2), match2:=SubStr(lvl,3,1)
		if(match1>12)
			match1:=SubStr(lvl,1,1), match2:=SubStr(lvl,2,2)
	}
	else if (sg="c")
		match1:=SubStr(lvl,1,1), match2:=SubStr(lvl,2,2)
	else
		goto nonSpine
}else{
	regexmatch(lvl,"^(\d)(\d)$",match)
}

stringupper,sg,sg
if (strlen(lvl)=1) || (StrLen(lvl)=2 && lvl<13 && sg="t") {
	if(sg="t")
		str:=sg lvl
	else if ((sg="C" && lvl<9) || (sg="L" && lvl<6) || (sg="S" && lvl<5))
		str:=sg lvl
	else
		goto nonSpine
}else if (sg="c") {
	;~ if(lvl="12")
		;~ str:="atlantoaxial joint"
	if (match1>match2)
		str:="C" match1 "-T" match2
	else if (match1<match2)
		str:="C" match1 "-" (StrLen(match2)=2?"T":"") match2
}else if (sg="t") {
	if (match1>match2)
		str:="T" match1 "-L" match2
	else if (match1<match2)
		str:="T" match1 "-" match2
}else if (sg="l") {
	if (match1>match2)
		str:="L" match1 "-S" match2
	else if (match1<match2)
		str:="L" match1 "-" match2
}else if (sg="s") {
	if (match1<match2)
		str:="S" match1 "-" match2
	else
		goto nonSpine
}


vb:="", cf:=""
if InStr($.value(3), "b"){
	vb:=InStr(str, "-")?" vertebral bodies":" vertebral body"
}else if InStr($.value(3), "c"){
	cf:=InStr(str, "-")?"compression fractures at ":"compression fracture at "
}else if InStr($.value(3), "e"){
	cf:="bone marrow edema at "
	,vb:=InStr(str, "-")?" vertebral bodies":" vertebral body"
}


Sleep 50
if (str="")
	return
else{
	return % cf str vb $.value(4)
}
	;~ sendByClipboard(str $.value(3), strlen($.value(0)))
$:=""
return
nonSpine:
;~ send % $.value(0)
$:=""
return
}
;~ spineName(segment,from,to=""){
	;~ if (to="")
		;~ to:=segment="c"?7:segment="t"?12:segment="l"?5:segment="s"?4:0
	;~ str:=""
	;~ while to>from
		;~ str.="
;~ }

::sco::scoliosis
::lor::lordosis
;~ ::dgc::degenerative change(s)
::nsc::no abnormal prevertebral soft tissue swelling
::vb::vertebral body
:*:vb1::vertebral bodies
::nfn::neural foraminal narrowing
::oly::osteolytic
::oba::osteoblastic
::olma::odontoid-lateral mass interval asymmetry

;pediatric
::intus::intussusception


;body
::rhc::right hemicolectomy
::lhc::left hemicolectomy
::hct::hemicolectomy

::gbw::gallbladder wall
::ppv::patent portal vein
::whp::status post Whipple operation.

:c:aml::AML
::amls::AMLs

::oab::post-operative change in abdomen.

::rcx::renal calyx
:*:rcx1::renal calyces

::nab::
sendAndNextLine("no definite abdominal lymphadenopathy.")
return
:*:pao1::
sendAndNextLine("small para-aortic lymph nodes.")
return

::bma::biloma
:*:bma1::bilomas

::dbj::double-J catheter
:*:dbj1::double-J catheters

::utm::uterine mass
:*:utm1::uterine masses
::pss::porto-systemic shunts
::hia::hiatal hernia
:*:schm::subcapsular hematoma

:*:pclv::polycystic liver
:*:pclk::polycystic liver and kidney
::pck::polycystic kidney

::oco::post-operative changes of colon
::olv::post-operative changes of liver
::osp::post-operative changes of spine
::umb::umbilical
::clt::celiac trunk

::plv::pelvic
:*:atbk::atrophic change of bilateral kidneys
:*:atkc::atrophic change of bilateral kidneys with cysts
:*:atrk::atrophic change of right kidney
:*:atlk::atrophic change of left kidney
:*:atpn::atrophic change of pancreas
::rsc::rectosigmoid colon
::rcm::rectum
::rcl::rectal

::pht::portal hypertension with collaterals
::rpv::renal pelvis
:*:rpv1::renal pelvises
::adg::adrenal gland
:*:adg1::adrenal glands
::pgb::perigallbladder
::ppn::peripancreatic
::prl::perirenal
:*:prl1::pararenal
::ptt::prostate
::ils::ileus
:c:hys::hysterectomy
:*:bx/::bilateral adnexal cystic lesions
:*:lx/::left adnexal cystic lesion
:*:rx/::right adnexal cystic lesion
::xcl::adnexal cystic lesion
::abw::abdominal wall
:*:dc0::degenerative change of spine.`r`n- atherosclerotic calcification of the aorta.`r`n-
::aov::ampulla of Vater
::hcc::HCC
::hccs::HCCs
:*:app0::the appendix is not well-identified.
:*:msn1::mesenteric
::msn::mesentery
::aba::abdominal aorta
:*:hc/::hypodense lesion(s) in liver, probably cyst(s).
:*:rc/::hypodense lesion(s) in kidney(s), probably cyst(s).
::hrc::hepatic and renal cysts.
:*:hrc0::hypodense lesions in liver and kidneys, cysts are favored.
::cos::collecting system
::nft::nephrectomy
:*:spln::splenectomy
:*:adrn::adrenectomy
::sbi::small bowel ileus
::ffs::focal fatty sparing
::hmp::hemoperitoneum
::hrp::hemoretroperitoneum
::adn::adnexal
::cds::cul-de-sac
:*:taec::post-TAE change
::txl::post-treatment change of the liver.
:*:txl1::post-TAE change of the liver.
:*:txl2::post-RFA change of the liver.
:*:txl3::post-TAE and post-RFA change of the liver.
:*:uvjj::ureterovesical junction
:*:upjj::ureteropelvic junction
::amm::adenomyomatosis
::djj::duodenojejunal junction
::gej::gastroesophageal junction
::tpt::transplantation
::hp::hepatic
::hpc::hepatic calcification
:*:hpc1::hepatic calcifications

::git::gastrointestinal tract
:*:git1::gastrointestinal tracts
::gt::gastric
::gtb::gastric body
::gta::gastric antrum
::gtc::gastric cardia
::sfr::subphrenic
::panu::pseudoaneurysm
:*:panu1::pseudoaneurysms
:*:iiavc::IVC interruption with azygos vein continuation
::hmn::hemangioma
:*:hmn1::hemangiomas
;~ :*:rc/::Bilateral renal cysts.
:*:br/::bilateral renal cysts.
:*:rr/::right renal cyst(s).
:*:lr/::left renal cyst(s).
;~ :*:hc/::hepatic cyst(s).
::ifll::indeterminate focal liver lesions
::pnp::pneumoperitoneum
:*:abd0::no definite focal lesions in the GI tract, liver, spleen, pancreas, both adrenal glands and kidneys.
::lspak::
sendAndNextLine("no definite focal lesions in the liver, spleen, pancreas, both adrenal glands and kidneys")
return
::lspa::
sendAndNextLine("no definite focal lesions in the liver, spleen, pancreas and both adrenal glands")
return
::lsp::
sendAndNextLine("no definite focal lesions in the liver, spleen and pancreas")
return
::spak::
sendAndNextLine("no definite focal lesions in the spleen, pancreas, both adrenal glands and kidneys")
return
::spa::
sendAndNextLine("no definite focal lesions in the spleen, pancreas, both adrenal glands")
return
::gb::gallbladder
::sto::stomach
:*:cbdd::common bile duct
:*:ihdd::intrahepatic duct
:*:ihdd1::intrahepatic ducts
:c:lv::liver
:c:Lv::Liver
::llv::left lobe of liver
::rlv::right lobe of liver
::blv::both lobes of liver
::kd::kidney
:*:kd1::kidneys
::lk::left kidney
::rk::right kidney
::bk::bilateral kidneys
::duo::duodenum
:*:duo1::duodenal
::jej::jejunum
:*:jej1::jejunal
::ilm::ileum
:*:ilm1::ileal
::icj::ileocecal junction
::icvv::ileocecal valve
::ad::adrenal
:*:ad1::adrenals
::ag::adrenal gland
:*:ag1::adrenal glands
::ab::abdomen
:*:ab1::abdominal
::pel::pelvic
::pev::pelvic cavity
::pao::para-aortic
::aoc::aorto-caval
::asc::ascites
:*:sp0::spondylosis of the lumbar spine with marginal osteophyte formation.
::ph::phlebolith
:*:ph1::phleboliths
::gs::gallstone
:*:gs1::gallstones
::div::diverticulum
:*:div1::diverticulosis
:*:div2::diverticulitis
::pan::pancreas
:*:pan1::pancreatic
::pnh::pancreatic head
::pnb::pancreatic body
::pnt::pancreatic tail
::pnd::pancreatic duct
::ub::urinary bladder
::per::peritoneum
:*:pers::peritoneal seedings
:*:pert::peritoneal thickening
:*:per1::peritoneal
:*:pecr::peritoneal carcinomatosis
::ptc::peritoneal cavity
::rpr::retroperitoneum
:*:rpr1::retroperitoneal
::app::appendix
:*:gi0::
sendAndNextLine("no definite obstructive lesion of the gastrointestinal tracts.")
return
::chs::cholecystitis
:*:chs1::acute cholecystitis
::lvpr::hypremic change of the surrounding liver parenchyma
::aps::appendicitis
:*:aps1::acute appendicitis
::pas::pancreatitis
:*:pas1::acute pancreatitis
:*:pas2::chronic pancreatitis
::djdl::degenerative change of lumbar spine
::acol::ascending colon
::tcol::transverse colon
::dcol::descending colon
::sigc::sigmoid colon
::rect::rectum
:*:pro1::enlarged prostate with calcification.
:*:pro2::enlarged prostate with nodular enhancement and calcification.
:*:pro3::enlarged prostate with intravesical protrusion.
::ipp::intravesical protrusion
::cr::cirrhosis
:*:cr1::cirrhotic change
:*:cr0::Uneven surface and coarse architecture of liver, cirrhosis is considered.
::cct::cholecystectomy
:*:cct0::status post cholecystectomy with mild dilatation of bile ducts.
::cy::cyst
:*:cy1::cysts
::clg::cholangiocarcinoma
::fl::fatty liver
::ftc::fatty change
::rc::renal cyst
::rrc::right renal cyst
::lrc::left renal cyst
:*:rc1::renal cysts
:*:rrc1::right renal cysts
:*:lrc1::left renal cysts
::hc::hepatic cyst
:*:hc1::hepatic cysts
;~ ::lrc::liver and renal cysts
;~ :*:rcy0::Bilateral renal cysts.
:*:lc0::Multiple small cysts in both hepatic lobes.
:*:lc1::liver cysts
:*:rcy1::renal cysts
::sn::spleen
:*:sn1::splenic
:*:snn::splenic nodule
:*:snn1::splenic nodules
::hdn::hydronephrosis
::smg::splenomegaly
::hmg::hepatomegaly
::hsmg::hepatosplenomegaly
::acs::accessory spleen
::LNI::nonspecific lymph node(s) at bilateral inguinal areas.
::UPH::urolithiasis or phlebolith
::UL::urolithiasis
::nhpd::normal hepatic perfusion defect
:*:nhpd0::normal hepatic perfusion defect at S4b adjacent to the fissure of the ligamentum teres.
::fm::fecal material
::pba::pneumobilia
::chila::Hepatodiaphragmatic interposition of the colon (Chilaiditi syndrome).
::gev::gastroesophageal varices
::gav::gastric varices
::esv::esophageal varices
::srs::splenorenal shunts
::vrc::varices
::ing::inguinal
::inga::inguinal area
::unc::uncinate process
::ampv::Periampullary lesions can not be totally excluded by the CT or MR study.
::anc::acute necrotic collection
::apfc::acute peripancreatic fluid collection
::apn::acute pyelonephritis
::apt::arterioportal shunt
::apc::appendicolith
:*:apslv::a small irregular nodule is noted at the , only identified in the arterial phase; a small arterioportal shunt is considered.^{left 15}
:*:brcy::Bartholin cyst
::biha::biliary hamartoma (von Meyenburg complex)
::bnk1::Bosniak category 1 of renal cystic neosplasm is considered.
::bp0::The bile ducts and the pancreatic duct are not dilated.
::bti::biliary tract infection
::bit::biliary tracts
:*:bit0::no definite filling defect in the biliary tracts.
::cvtr::cavernous transformation
:*:ciaa::common iliac artery
:*:ciaa1::common iliac arteries
:*:eiaa::external iliac artery
:*:eiaa1::external iliac arteries
:*:iiaa::internal iliac artery
:*:iiaa1::internal iliac arteries
:*:civv::common iliac vein
:*:civv1::common iliac veins
:*:eivv::external iliac vein
:*:eivv1::external iliac veins
:*:iivv::internal iliac vein
:*:iivv1::internal iliac veins





::cnd::cirrhotic nodule
:*:crn1::cirrhotic nodules
::dnd::dysplastic nodule
:*:dnd1::dysplastic nodules
::rnd::regenerative nodule
:*:rnd1::regenerative nodules
::pts::peritonitis
::crt::capsular retraction
::wav::washout on venous phase
:*:hcc0::hypodense lesion on precontrast, hyperdensity on arterial phase and rapid washout on venous phase; compatible with typical HCC.
:*:hem0::hypodense lesion on precontrast, peripheral dot-like enhancement on arterial phase, and progressive filling-in on venous phase; compatible with liver hemangioma.
:*:hem1::isodense lesion on precontrast, global enhancement on arterial phase, and persistent enhancement on venous phase; compatible with liver hemangioma.
:*:ctap0::CTAP was performed with tip in the SMA orifice, 2ml/sec, delayed 30 sec, total 50 ml:
::ctss::(Non-enhanced CT study is not sensitive and specific for the detection of focal lesions in the abdominal organs)
::ctst::NECT and CECT of abdomen and pelvis with air and water distention of the stomach for evaluation:
::ctco::NECT and CECT of abdomen and pelvis for colon cancer with air distention:
::dud::duodenal diverticulum.
::fra::free air
::ety::enterostomy
;~ ::pys::pyelonephritis
::sep::sclerosing encapsulating peritonitis
;~ ::fcl::falciform ligament
:*:mrfl::Heterogeneous decreased signal of the liver on out-of-phase images as compared with in-phase images, suggestive of fatty liver.
::fga::focal type of the gallbladder adenomyomatosis
::gc::greater curvature
::lc::lesser curvature
::gcs::greater curvature side
::lcs::lesser curvature side
;~ ::ggb::Gamna-Gandy bodies (splenic siderotic nodules)
::ghll::gastrohepatic ligament
::hmc::hemorrhagic cyst
::hdll::hepatoduodenal ligament
::hfx::hepatic flexure
::sfx::splenic flexure
::hhl::hepatic hilum
::owrs::Osler-Weber-Rendu syndrome
::htu::hepatic tumor
:*:htu1::hepatic tumors
:*:hv0::Hepatic veins and portal veins are patent.
;~ :c:iac::interaortocaval region
;~ :c:Iac::Interaortocaval region
::itpi::status post intrathecal pump implantation
::jjy::jejunostomy
::ily::ileostomy
::cny::colostomy
::amll::angiomyolipoma
::lsg::lateral segment
::msg::medial segment
::crsm::cirrhosis with splenomegaly
::lcy::Multiple small low density nodules are noted in the liver; liver cysts are considered in current status.
:*:lcy1::A small low density nodule in the liver; liver cyst is considered in current status.
::hon::hypodense nodule
:*:hon1::hypodense nodules
:*:lrst::left renal stone
:*:lrss::left renal stones
:*:rrss::right renal stones
:*:rrst::right renal stone

::rne::renal stone
:*:rne1::renal stones
::ne::stone
:*:ne1::stones

:*:brst::bilateral renal stones
:*:mrcp0::MRCP reveals no evidence of bile ducts or pancreatic duct dilatation; no anomalous pancreaticobiliary union.
:*:mrcn::Cirrhotic nodules in both lobes of liver, mixed with regenerative nodules and dysplastic nodules, presenting as hyperintensity on T1WI, hypointensity on T2WI, and no enhancement.
:*:mrdn::with increased hyperintensity on T1WI, isointensity to hypointensity on T2WI and no definite enhancement after contrast media injection; dysplastic nodules are favored.
:*:mrfnh::slight hypointensity on T1WI, slight hyperintensity on T2WI, and global enhancement on early arterial phase, near isointensity on delayed enhanced images; compatible with FNH.
:*:mrhcc::hypointensity on T1WI, slight hyperintensity on T2WI, and global enhancement on early arterial phase, rapid washout on delayed enhanced images; compatible with HCC.
:*:mrhem::hypointensity on T1WI, hyperintensity on T2WI, and peripheral patches enhancement on dynamic contrast-enhanced study, persistent enhancement on delayed contrast-enhanced images; compatible with liver hemangioma.
:*:mrprca::with hypointensity on T2WI, diffusion restriction on DWI/ADC, and early enhancement in early dynamic study; compatible with prostate cancer.
::umy::uterine myoma
::uma::uterine mass
:*:uma1::uterine masses
::utn::uterine nodule
:*:utn1::uterine nodules
::utr::uterus
:*:utr1::uterine

::umx::uterine mass(es) and bilateral adnexal cystic lesions
::net::neuroendocrine tumor
::nfla::no definite focal lesion in the abdomen.
::nflp::no definite focal lesion in the pelvis.
::ncl::nodular and contracted liver contour
::notae::The imaging pattern hints the limited effect of embolization and increased/aggravated liver cirrhosis if embolization; clinical follow up or local treatment is more favored. Liver transplantation is also considered.
::oble::obstructive level
::opcolon::operative change of the colon; no evidence of local recurrence is noted; non-specific bowel gas distribution is noted.
::opgyn::status post operative change of the gynecological organs; no evidence of local recurrence is noted.
::opkidney::operative change of the kidney; no evidence of local recurrence is noted;
::opstomach::operative change of the stomach; no evidence of local recurrence is noted; non-specific bowel gas distribution is noted.
::paa::porcelain abdominal aorta
::pcs::portocaval space
::phs::perihepatic space
::pnin::pneumatosis intestinalis
::pjsy::Peutz-Jeghers syndrome
::pmf::peripheral mass-forming type of cholangiocarcinoma
::primo:: Primovist MR study may be considered in next followed study (liver specific MR contrast medium; specially arranged; please call MR room 62540 for arrangement; or Dr. A 51685 or Dr. B 53315).
::psco::phlebosclerotic colitis
::pv::portal vein
::pvt::portal vein thrombosis
::cz::central zone
::tz::transitional zone
::pz::peripheral zone
::sa1::Study: monophasic abdominal CT, without contrast enhancement
::sa2::Study: 2 phases of abdominal CT, without and with contrast enhancement
::sa3::Study: 3 phases of abdominal CT, without and with (arterial and portal venous phases) contrast enhancement
::sa4::Study: 4 phases of abdominal CT, without and with (arterial and portal venous and delayed phases) contrast enhancement
::co::colon
::sb::small bowels
::sbo::small bowel obstruction
::sbtae::The small bowel embolization is still a risky issue and the long-term follow-up evidence is still scant. Possible short term and long term of complications (perforation, stenosis, etc.) should be followed and alerted.
::sbt::Sengstaken-Blakemore tube
::bgh::Brunner gland hyperplasia
::seml::subepithelial mass lesion
::sml::submucosal lesion
::sfci::suprapubic foley catheter insertion
::stece::suspected stenosis of the celiac axis and IMA with dilated arc of Buhler, arc of Riolan, and marginal artery of Drummond.
::seve::seminal vesicle
::thad::THAD (transient hepatic attenuation differences)
::tei::terminal ileum
::tnmrec::
(
Rectal cancer: distal rectum.
---T: T3, abnormal thickening and enhancing wall with increased fatty strandings in the perirectal space.
---N: N1c, small LNs in the perirectal space; there is no evidence of paraaortic LAPs in abdomen; there is no evidence of LAPs in pelvic cavity and bilateral inguinal areas.
---M: M0, multiple liver cysts; no definite mets; but slightly increased fatty strandings in the omentum should be followed.
---The local staging is favored as cT3N1cM0.
)
::tnmkd::
(
Renal cancer: right kidney.
---T: T1b, right kidney; a well-defined renal mass 46.3 mm is noted at the right kidney without definite fat density or calcifications; the tumor is solid but heterogeneous enhancement; the pattern should exclude the RCC (such as chromophobe type) first; the differential diagnosis includes the fat-paucity of renal angiomyolipoma. Accorrding the imaging pattern, partial or total nephrectomy is first considered even though the AML is differentiated.
---N: N0, no regional LNs.
---M: M0, no definite distant metastases.
---The local staging is favored as cT3N1cM0.
)
::tnmsto::
(
---T: T3, abnormal thickening and enhancing wall with increased fatty strandings;
---N: N2, small LNs (3-6) in the regional areas and lesser omentum;
---M: M0, no definite metastases in the abdomen;
---The local staging is favored as cT3N2M0.
)
:*:smcy::The size of cysts is too small to be differentiated. Clinical follow-up or correlation is suggested.
::uca::uterine cavity
::ur::ureter
:*:lush::left ureter stone causing hydronephrosis
:*:rush::right ureter stone causing hydronephrosis
:*:bush::bilateral ureter stones causing hydronephrosis
:*:ur1::ureteral
::urs::ureter stone
:*:urs1::ureter stones
:*:utii::urinary tract infection
::vcugg::voiding cystourethrography
::iab::intraabdominal
:*:ivu0::
insertTemplate("
(
KUB and IVU shows:
- Bilateral clear psoas shadows.
- Bilateral functioning kidneys with normal size, shape and axis.
- Bilateral normal collecting system without definite filling defect or obstruction.
- Well-distended urinary bladder with smooth contour.
- Phlebolith at pelvic cavity.
- The postvoiding film reveals small residual urine.

The lateral film reveals marked indentation on the bladder floor. There is also hooking of bilateral ureters on the delayed films. All of these pictures are compatible with enlarged prostate gland.
)","
(
No evidence of obstructive uropathy.
)")
return

insertTemplate(finding, impression){
	global editHwnds, RisReports, thisPlace

	if InStr(thisPlace, "N hospital"){
	gosub renewReportHwnd
	str1:=RegExReplace(finding, "\r?\n","`r`n")
	,str2:=RegExReplace(impression, "\r?\n","`r`n")
	;~ ,changeLineBreak(str1)
	;~ ,changeLineBreak(str2)
	,Edit_SetText(editHwnds[2], str1)
	,Edit_SetText(editHwnds[1], str1)
	,Edit_SetText(RisReports[1,1], str1)
	,Edit_SetText(RisReports[1,2], str2)
}else{
	send % trim(finding) "`n`nImpression: `n" impression
}

}


;chest
::opl::post-operative changes of lung.
:*:blggo::which could be insufficient inspiration or pulmonary infection.

::sili::silicone granulomas

:*:hr0::no obvious structural cardiac abnormality.

::ldm::left deviation of mediastinal structures
::rdm::right deviation of mediastinal structures
:*:hpec::hemopericardium
::htx::hemothorax
::cry::coronary
:*:crst::coronary stent
:*:crst1::coronary stents
::put::pulmonary trunk
::mpa::main pulmonary artery
::lpa::left pulmonary artery
::rpa::right pulmonary artery
:*:lpa1::left pulmonary arteries
:*:rpa1::right pulmonary arteries

:*:lucn::lung cancer
:*:rlca::right lung cancer
:*:llca::left lung cancer
:*:escn::esophageal cancer
:*:brcn::breast cancer
:*:lbca::left breast cancer
:*:rbca::right breast cancer

::ite::intrathoracic extension
::mim::mucus impaction
::mpg::mucus plug
:*:mpg1::mucus plugs
::enb::endobronchial
::bks::bronchiectasis, peribronchial tiny (<6mm) nodules and bronchial wall thickening
;~ ::pfd::perifissural nodule
;~ :*:pfd1::perifissural nodules
::pfd::juxtapleural nodule
:*:pfd1::juxtapleural nodules
::bwt::bronchial wall thickening
::pls::pleural seedings
::plm::pleural metastasis
:*:plm1::pleural metastases
::blm::bilateral lung metastases
:*:blml::bilateral lung metastases, larger.
:*:blms::bilateral lung metastases, smaller.
::lbm::bilateral lung and bone metastases.
:*:blpm::bilateral lung, pleural and bone metastases.
:*:rulb::RUL lobectomy
:*:rmlb::RML lobectomy
:*:rllb::RLL lobectomy
:*:lulb::LUL lobectomy
:*:lllb::LLL lobectomy
:*:ruls::RUL segmentectomy
:*:rmls::RML segmentectomy
:*:rlls::RLL segmentectomy
:*:luls::LUL segmentectomy
:*:llls::LLL segmentectomy
:*:rulw::RUL wedge resection
:*:rmlw::RML wedge resection
:*:rllw::RLL wedge resection
:*:lulw::LUL wedge resection
:*:lllw::LLL wedge resection

::blc::bilateral lung consolidation
::blo::bilateral lung opacities
::rmi::status post right mastectomy with breast implant.
::lmi::status post left mastectomy with breast implant.
::bmi::status post bilateral mastectomy with breast implant.
:*:rtrm::post-radiation change at right medial lung.
:*:rtlm::post-radiation change at left medial lung.
:*:rtbm::post-radiation change at bilateral medial lung.
::stf::unchanged thoracic findings.
::sf::unchanged findings.
::osf::other unchanged findings.
::rsf::roughly unchanged findings.
::bln::bilateral lung nodules
::tbln::tiny bilateral lung nodules
:*:tblns::tiny bilateral lung nodules, unchanged.
::tln::tiny lung nodules
:*:tlns::tiny lung nodules, unchanged.
::lns::lung nodules, unchanged.
::psn::part-solid nodule
::ssl::sub-solid nodule
:*:segt::segmentectomy
:*:pnut::pneumectomy
:*:ldct/::(Low dose CT is incompetent for soft tissue lesion detection.)
::tpm::temporary pacemaker
::tef::tracheoesophageal fistula
:*:lbrc::left breast cancer
:*:rbrc::right breast cancer
::lbr::left breast
::rbr::right breast
::bbr::bilateral breasts
::lcw::lateral chest wall
::acw::anterior chest wall
::rbn::right breast nodule
::lbn::left breast nodule
::bbn::bilateral breast nodules
::rbc::right breast calcification(s)
::lbc::left breast calcification(s)
::bbc::bilateral breast calcifications
::brc::breast calcification
:*:brc1::breast calcifications
::brn::breast nodule
:*:brn1::breast nodules
::bim::breast implant
:*:bim1::breast implants


::apw::aortopulmonary window
::hnx::hydropneumothorax
::slf::unchanged lung findings.
::llu::left lung
::rlu::right lung
::blu::bilateral lungs
::plu::pleura
::plb::pleura-based
::moz::mosaic attenuation
::thc::thoracic
::ido::ill-defined opacities
:*:lmet::Multiple bilateral lung nodules of varying sizes, suggestive of metastases
::ip::interstitial pneumonitis
::hnc::honeycombing

::cvr::status post cardiac valve replacement.
;~ :*:card::cardiac
;~ ::cdv::cardiac valve
;~ :*:cdv1::cardiac valves
::prh::perihilar
::avv::aortic valve
::pvv::pulmonary valve
::mvv::mitral valve
::tvv::tricuspid valve
::vv::valve
:*:vv1::valves
::cvv::cardiac valve
:*:cvv1::cardiac valves
::mbn::multiple bilateral lung nodules
::plr::pleural retraction
::ibl::in bilateral lungs
::irl::in the right lung
::ill::in the left lung
::ral::right apical lung
::lal::left apical lung
:*:iral::at right apical lung
:*:ilal::at left apical lung
::ith::interstitial thickening
::chw::chest wall
::scr::subcarinal
::pbk::peribronchial
::pbt::peribronchial thickening
::ptk::paratracheal
::peo::paraesophageal
:*:ggos::GGOs
:*:mggo::multiple GGOs
::ilg::ill-defined GGO
:*:ilg1::ill-defined GGOs
:*:milg::multiple ill-defined GGOs
:*:ggns::GGNs
:*:mggn::multiple GGNs
::ggo::GGO
::ggn::GGN
::rml::RML
::rul::RUL
::rll::RLL
::lul::LUL
::lll::LLL
:*:irml::in the RML
:*:irul::in the RUL
:*:irll::in the RLL
:*:ilul::in the LUL
:*:illl::in the LLL
:*:ilin::at the lingular LUL
::lnl::lung nodule
::brll::basal RLL
::blll::basal LLL
::tln::tiny lung nodule.
:*:tln1::tiny lung nodules.
:*:lnl1::lung nodules
:*:nd0::other tiny or probably non-specific lung nodules and minor or non-specific parenchymal changes of bilateral lung, suggest clinical correlation.
::aos::acute aortic syndrome
::brk::bronchus
:*:brk1::bronchial
:*:brk2::bronchi
::lmb::left main bronchus
::rmb::right main bronchus
::tib::tree-in-bud
::tin::tree-in-bud nodules
::ttn::tiny (<=4mm) tree-in-bud nodules
::rma::respiratory motion artifacts
:*:rma0::respiratory motion artifacts are noted, which may obscure small lesions.
::bpe::bilateral pleural effusion
::rpe::right pleural effusion
::lpe::left pleural effusion
:*:lpet::left pleural effusion with pleural thickening
:*:rpet::right pleural effusion with pleural thickening
:*:bpet::bilateral pleural effusion with pleural thickening
::pfl::previous fracture at left rib(s).
::pfr::previous fracture at right rib(s).
::pflc::previous fracture at left rib(s) and left clavicle.
::pfrc::previous fracture at right rib(s) and right clavicle.
::pfb::previous fractures at bilateral ribs.

::bll::bilateral lower lungs
::bul::bilateral upper lungs
::bal::bilateral apical lungs
::bml::RML and lingular LUL
::em::emphysema
;~ ::prf::perifissural
::prf::juxtapleural
::arsa::aberrant right subclavian artery
::alsa::aberrant left subclavian artery
::br::breast
:*:br1::breasts
::fs::fissure
:*:fs1::fissures
:*:fs2::fissural

::mjf::major fissure
::mif::minor fissure

::axi::axillary
::pco::patchy consolidation
:*:pco1::patchy consolidations
::aoa::aortic arch
::ata::ascending aorta
::dta::descending thoracic aorta
::tbc::tracheobronchial calcifications
::pna::pneumonia
;~ ::bpa::bronchopneumonia
::ppq::pleural plaque
:*:ppq1::pleural plaques
:*:mmph::multifocal micronodular pneumocyte hyperplasia (MMPH)
::lmcr::lymphangitic carcinomatosis
::cfa::costophrenic angle
:*:cfa1::costophrenic angles
:*:cfa2::cardiophrenic angle
;~ :*:ly/::(YCH/Dr.A)
;~ :*:lj/::(YCH/Dr.B)
;~ :*:lw/::(YCH/Dr.C)
;~ :*:lt/::(YCH/Dr.E)
;~ :*:lc/::(YCH/Dr.F)
;~ :*:lh/::(YCH/Dr.H)
::bcv::brachiocephalic vein
::bca::brachiocephalic artery
:*:ad0::no definite abnormality of both adrenals.
::bdl::bilateral dependent lungs
::sbp::subpleural
::pl::pleural
::fss::fissural
:*:plfs::pleural/fissural
::pth::pleural thickening
::tho::thoracic
::pul::pulmonary
::lu::lung
:*:lu1::lungs
::lin::lingular LUL
::eso::esophagus
:*:eso1::esophageal
:*:nl0::no obvious worrisome lung nodule.
:*:nl1::minor or non-specific lung parenchymal change.
:*:nl2::tiny or probably non-specific nodules and minor or non-specific lung parenchymal change.
:*:nl3::minor or non-specific lung findings.
:*:onl1::other minor or non-specific lung parenchymal change.
:*:onl2::other tiny or probably non-specific nodules and minor or non-specific lung parenchymal change.
:*:onl3::other minor or non-specific lung findings.

:*:l0/::no definite detectable lung abnormality.
::nh::normal heart size
::cmg::cardiomegaly
::pec::pericardial
::pef::pericardial effusion
:*:peft::pericardial effusion with pericardial thickening
:*:peth::pericardial thickening
:*:ggoo::ground glass opacity
:*:ggo1::ground glass opacities
:*:ggnn::ground glass nodule
:*:ggn1::ground glass nodules
::ggl::ground glass lesion
:*:ggl1::ground glass lesions
::pso::part-solid
::sso::sub-solid
::opa::opacity
:*:opa1::opacities
:*:comch::CT of the chest without and with contrast enhancement is read and compared with previous study dated . This CT study shows:{left 22}
::corl::Please correlate with the imaging findings and report of the abdominal/pelvic CT study.
:*:comc2::CT of the chest without and with contrast enhancement is read without prior CT for comparison. This CT study shows:
:*:comc1::CT of the chest with contrast enhancement is read and compared with previous study dated . This CT study shows:{left 22}
:*:comc0::CT of the chest without contrast enhancement is read and compared with previous study dated . This CT study shows:{left 22}
::wdgr::wedge resection
::ssa::subsegmental atelectasis
:*:ssab::subsegmental atelectasis in bilateral lungs.
:*:sa0::subsegmental atelectasis at bilateral basal lungs.
::ate::atelectasis
:*:atco::atelectasis/consolidation
::lte::linear atelectasis
::brs::bronchiectasis
::tbr::tractional bronchiectasis
::pe::pleural effusion
::mdi::mediastinum
;~ :*:mdi1::mediastinal
::md::mediastinal
::ptx::pneumothorax
::pmd::pneumomediastinum
::con::consolidation
:*:con1::consolidations
:*:con2::consolidative
::emc::emphysematous change
:*:emc0::emphysematous change in bilateral lungs.
:*:emc1::emphysematous change in bilateral upper lungs.
::efc::emphysematous and fibrotic change
::bbl::bilateral basal lungs
::rull::right upper lobe
::rlll::right lower lobe
::rmll::right middle lobe
::lull::left upper lobe
::llll::left lower lobe
::djdt::degenerative change of the thoracic spine
::djdtl::degenerative change of the thoracolumbar spine
::bpk::bilateral apical pleural thickening
::cora::coronary artery
:*:cora1::coronary arteries
:*:cln0::no definite mediastinal or hilar lymphadenopathy.
:*:ml0::non-specific small mediastinal lymph nodes.
::tlap::thoracic lymphadenopathy.
::ntl::no definite thoracic lymphadenopathy.
:*:esre::status post esophagectomy and reconstruction.
::lbt::lobectomy
::smt::segmentectomy
::mst::mastectomy
::ap/::the appendix is not clearly demonstrated.
::ist::interlobular septal thickening
::pbv::peribronchovascular
::cln::centrilobular nodules
::msw::metallic sternal wires
::ao::aorta
:*:ao1::aortic
::dph::diaphragm
::hdp::hemidiaphragm
::tra::a tracheostomy tube
::trm::tracheostomy
:*:mi/::subendocardial hypoenhancement of LV, suspicious of ischemic change.

;intervention
::fld::flow diverter
:*:note0::
(
Procedure name:
Indication:
Anesthesia: Lidocaine HCL (Xylocaine 2%, 20 mg/mL) 200 mg local injection.
Route: Right femoral artery approach.
Equipment:
Complication: nil.

Procedure:
-
)
::gel::Gelfoam particles
:*:gel1::Gelfoam fine particles
:*:gel2::Gelfoam coarse particles
::prer::pre-RFA TAE
::sl10::1.7Fr microcatheter (SL-10; Boston Scientific)
::prgr::a 2.7Fr microcatheter (Progreat; Terumo)
::rene::a 2.5Fr microcatheter (Renegade; Boston Scientific)
::rpy::retrograde pyelography
::pegj::Decreased peristalsis of the stomach is noted; prominent colon gas, indicating ileus. A 5Fr H1 insertion into the stomach first; then 150 cm guidewire was delivered and this 5Fr H1 was adjusted into the duodenum. Therefore, the gastrojejunal tube (12Fr in 24Fr) was delivered smoothly with tip in the proximal jejunum. Prevention from tube occlusion was educated. Please give peristalsis-stimulating drugs (such as Motilin or Mopride; 1# tid); local wound care ointment (such as Bacitracin Neomycin Ointment; Zinc oxide ointment).
::jtub::The yellow port is for feeding; the red port is for decompression. Please give the ointments for wound care and peristalsis stimulating drug.
::embz::Embozene particles (400 micrometer, CeloNova Bioscience)
::dtvn::a 5Fr, 15cm DTVN drainage tube (Cook)
::apy::antegrade pyelography
::emz::embolization
::lpo::lipiodol
::lpr::lipiodol retention
:*:lhaa::left hepatic artery
:*:lhvv::left hepatic vein
:*:mhaa::middle hepatic artery
:*:mhvv::middle hepatic vein
:*:rhaa::right hepatic artery
:*:rhvv::right hepatic vein
:*:phaa::proper hepatic artery
:*:chaa::common hepatic artery
:*:smaa::superior mesenteric artery
:*:ipaa::inferior phrenic artery
:*:spda::superior pancreaticoduodenal artery
:*:rgea::right gastroepiploic artery
:*:lgea::left gastroepiploic artery
:*:lgaa::left gastric artery
::rep::replaced
::bch::branch
:*:bch1::branches
::rev::revision
:*:rev1::revised
::rem::remove
::badi::balloon dilatation
::seh::sheath
::sty::stylet
::ish::introducer sheath
::exc::exchange
::adv::advance
::gw::guidewire
::mgw::microguidewire
::mcth::microcatheter
::nav::navigate
::ins::insert
:*:ins1::insertion
::vi::via
::f::from
::proc::procedure
::gdaa::gastroduodenal artery
::wbao::will be arranged on
::wwcf::We were consulted for
::rfa::RFA
::tae::TAE
::aspi::aspiration
::drn::drainage
::bx::biopsy
::ctg::CT-guided
::abl::ablation
::mcw::microwave
::cox::contrast extravasation
:*:cox0::no definite active contrast extravasation
::ufg::under fluoroscopic guidance
::uug::under ultrasound guidance
::ucg::under CT guidance
::obj::obstructive jaundice
::ja::jaundice
::obu::obstructive uropathy
::apr::approach
::chg::cholangiogram
pcn:
tmp:=$.value(3)
if tmp not in l,r,b
{
	send % $.value(0)
	return
}
post=
(

No obvious discomfort was complained after the procedure.
Post-procedure vital signs: stable.
)
arr:={l:"left",r:"right",b:"bilateral"}
side:=arr[tmp]
if($.value(4)=""){  ;new PCN
exam=
(
History:

Indication: obstructive uropathy, for %side% PCN.
Catheter: 6Fr 25cm pigtail.

Findings:

Procedure:
- Patient in prone position. Skin disinfection. Place sterile drapes.
- Fentanyl 0.05 mg IV for pain control.
- Place sterile cover on ultrasound transducer. Visualize dilated renal calyces. Local anesthesia with lidocaine 2`% 10 ml.
- Advance 18G chiba needle into renal calyx under ultrasound guidance.
- Remove needle stylet; aspirate some pus-like urine; inject contrast for antegrade nephrogram.
- Advance 0.035" guidewire into renal collecting system under fluoroscopic guidance.
- Nick skin with `#11 blade. Remove chiba needle.
- Advance the pigtail catheter; remove inner stiffener; position catheter in renal pelvis.
- Confirm position with contrast injection.
- Skin suture to fix the catheter.

)
	imp:="status post " side " PCN."
}else if ($.value(4)=1){ ;revision
exam=
(
History:

Indication: obstructive uropathy, for %side% PCN revision.
Catheter: 6Fr 25cm pigtail.

Procedure:
- Patient in prone position. Skin disinfection. Place sterile drapes.
- Antegrade nephrogram via previous PCN shows
- Local anesthesia with lidocaine 2`% 10 ml.
- Advance 0.035" guidewire into renal collecting system under fluoroscopic guidance.
- Advance a new pigtail catheter; remove inner stiffener; position catheter in renal pelvis.
- Confirm position with contrast injection.
- Skin suture to fix the catheter.

)
	imp:="status post " side " PCN revision."
}
if tmp=b
	exam.="- Same steps for contralateral side."
send % exam post "`t" imp
$:=""
return
ptcd:
tmp:=$.value(3)
if tmp not in l,r,b
{
	send % $.value(0)
	return
}
post=
(

No obvious discomfort was complained after the procedure.
Post-procedure vital signs: stable.
)
arr:={l:"left",r:"right",b:"bilateral"}
side:=arr[tmp]
if($.value(4)=""){  ;new ptcd
exam=
(
History:

Indication: obstructive jaundice, for %side% PTCD.
Catheter: 6Fr 25cm pigtail.

Findings:

Procedure:
- Patient in supine position. Skin disinfection. Place sterile drapes.
- Fentanyl 0.05 mg IV for pain control.
- Place sterile cover on ultrasound transducer. Visualize dilated %side% IHD. Local anesthesia with lidocaine 2`% 10 ml.
- Advance 21G chiba needle into dilated S3 IHD under ultrasound.
- Remove needle stylet; inject small contrast aliquots under fluoroscopy to opacify the IHD.
- Advance 0.018" guidewire into IHD and exchange needle for dilator-sheath under fluoroscopy.
- Remove guidewire and dilator; perform cholangiogram via sheath.
- Advance and navigate 0.035" guidewire to CBD.
- Nick skin with `#11 blade; remove sheath.
- Advance the pigtail catheter; remove inner stiffener; position catheter in CBD.
- Confirm position and drainage function with contrast injection.
- Skin suture to fix the catheter.

)
	imp:="status post " side " PTCD."
}else if ($.value(4)=1){ ;revision
exam=
(
History:

Indication: obstructive jaundice, for %side% PTCD revision.
Catheter: 6Fr 25cm pigtail.

Procedure:
- Patient in supine position. Skin disinfection. Place sterile drapes.
- Cholangiogram via previous PTCD shows
- Advance and navigate 0.035" guidewire to CBD.
- Remove previous pigtail catheter.
- Advance a new pigtail catheter; remove inner stiffener; position catheter in %side% IHD.
- Confirm position and drainage function with contrast injection.
- Skin suture to fix the catheter.

)
	imp:="status post " side " PTCD revision."
}
if tmp=b
	exam.="- Same steps for contralateral side."

send % exam post "`t" imp
$:=""
return
::lbx::We will evaluate the feasibility of CT guided biopsy for this patient. Please discuss and inform this patient and the family for the possible complications, such as pneumothorax, hemoptysis, hemorrhage, air embolism, etc.
:*:lubx::
d:=a_now
d+=1,days
if (a_wday=6)
	d+=2,days
d:=substr(d,1,4) "/" substr(d,5,2) "/" substr(d,7,2)
send,
(
CT guided biopsy will be arranged on %d% AM on call.
Please reassure the following things:
1. Informed consent. Family accompany. Please discuss and inform this patient and the family for the possible complications, such as pneumothorax, hemoptysis, hemorrhage, air embolism, etc.
2. Prepare O2 bottle, nasal canula, on IV cath, surgical bed and clothes.
3. Check PLT>80k, INR< 1.5.
4. Discontinue anticoagulant or antiplatelet drugs for at least 5 days if used.
5. 電腦斷層導引切片術需自費 NTD.2000 元
Thanks for your consultation.
)
return
:*:lulo::
d:=a_now
d+=1,days
if (a_wday=6)
	d+=2,days
d:=substr(d,1,4) "/" substr(d,5,2) "/" substr(d,7,2)
send,
(
CT guided localization will be arranged on %d% AM on call.
Please reassure the following things:
1. Informed consent. Family accompany. Please discuss and inform this patient and the family for the possible complications, such as pneumothorax, hemoptysis, hemorrhage, air embolism, etc.
2. Prepare O2 bottle, nasal canula, on IV cath, surgical bed and clothes.
3. Check PLT>80k, INR< 1.5.
4. Discontinue anticoagulant or antiplatelet drugs for at least 5 days if used.
5. 電腦斷層導引切片術需自費 NTD.2000 元
Thanks for your consultation.
)
return
:*:bobx::
d:=a_now
d+=1,days
if (a_wday=6)
	d+=2,days
d:=substr(d,1,4) "/" substr(d,5,2) "/" substr(d,7,2)
send,
(
CT guided biopsy will be arranged on %d% PM on call.
Please reassure the following things:
1. Informed consent. Family accompany. Please discuss and inform this patient and the family for the possible complications, such as hemorrhage, bowel perforation, etc.
2. Prepare O2 bottle, nasal canula, on IV cath, surgical bed and clothes.
3. Check PLT>80k, INR< 1.5.
4. Discontinue anticoagulant or antiplatelet drugs for at least 5 days if used.
5. 電腦斷層導引切片術需自費 NTD.2000 元
Thanks for your consultation.
)
return
:*:bodr::
d:=a_now
d+=1,days
if (a_wday=6)
	d+=2,days
d:=substr(d,1,4) "/" substr(d,5,2) "/" substr(d,7,2)
send,
(
CT guided drainage will be arranged on %d% PM on call.
Please reassure the following things:
1. Informed consent. Family accompany. Please discuss and inform this patient and the family for the possible complications, such as hemorrhage, bowel perforation, transient bacteremia/sepsis or septic shock , etc.
2. Prepare O2 bottle, nasal canula, on IV cath, surgical bed and clothes.
3. Check PLT>80k, INR< 1.5.
4. Discontinue anticoagulant or antiplatelet drugs for at least 5 days if used.
Thanks for your consultation.
)

return


::fesh::The femoral artery sheath is not removed. Please remove it in 48 hours if no further indication of angiographic intervention.


;conclusion
:*:un0::negative or unremarkable radiological findings of the unmentioned organs.
:*:rd0::
quicksendFunc("rd0", "no obvious radiological abnormality noted. Suggest clinical correlation.")
return
::yy::Reported by YCH (#00000).
::nonc::(Low sensitivity and specificity of non-contrast CT.)
:*:noncmet::(Low sensitivity of non-contrast CT for metastatic lesions.)
:*:ld=::(Low dose CT is inferior for soft tissue lesion detection.)
::sc::suggest clinical correlation.
::scf::suggest clinical correlation and follow up.
::sfu::suggest follow up.
:*:sfu1::suggest short term follow up.
::fu::follow up
::crr::correlation
::mmc::suggest mammography correlation.
::mrc::suggest MRI correlation.
::ctc::suggest CT correlation.
::enc::suggest endoscope correlation.
::cec::suggest contrast enhanced study if indicated.
::lfc::suggest correlation with local findings.
:*:enc2::suggest coloscope correlation.
:*:enc1::suggest bronchoscope correlation.
::usc::suggest ultrasound correlation.
::guc::suggest gynecologic ultrasound correlation.
::sci::suggest clinical correlation for possible infectious process.
::nn::no significant lesion. Suggest clinical correlation.
::zlf::suggest correlation with local finding.
::stp::suggest tissue proof.
::reas::
send % "(This study is reassigned to current radiologist on " A_YYYY "/" a_mm "/" a_dd ".)"
return
::othp::
send % "(Please correlate with the report of other body parts.)"
return

;medical abbreviation
:*:taee::transarterial embolization
:*:avmm::arteriovenous malformation
:*:avff::arteriovenous fistula
::vam::vascular malformation
:*:tbil::T-bil
::htn::hypertension
:*:ca/::ca
::cn::cancer
::adc::adenocarcinoma
::car::carcinoma


;~ #x::
PostMessage,0x2020,,,,ahk_exe EBMpreload.exe
s:="TECHNIQUE: "  formatExamName(RisState[2]) "`r`n"
,s.="FINDINGS: `r`n-  "
,setReportText(s, "Please see the images and findings.", getRisReports(RisState[2]))
if (simpleRis:=winexist("simple RIS ahk_class AutoHotkeyGUI")){
	editHwnds:=getSimpleRisEditHwnds()
	Edit_SetText(editHwnds[2], s)
	,Edit_SetText(editHwnds[1], s)
	,Edit_SetSel(editHwnds[2],cursorPoint:=StrLen(s),cursorPoint)
	,Edit_SetSel(editHwnds[1],cursorPoint,cursorPoint)
	,Edit_ScrollCaret(editHwnds[2])

}
winactivate,ahk_id %simpleRis%
resetHotstringBuffer(-1)
return

;VS templates

:*:ct/::
checkRis(RisState)
gosub renewRisReports
chestCTtemplate:
lastChestCTtemplateAccNo:=getRisAccNo(risHwnd)
winactivate,% "ahk_id " RisState[2]
studyOpened:=0,RisHwnd:=RisOpened()[2]
,ExamItems:=parseRisExamItems(getRisExamItems(RisHwnd))

clinicalHx:=getClinicalInfo(RisHwnd)
, withCount:=withoutCount:=withwithoutCount:=0
if instr(ExamItems[1,1],"With/Without") || InStr(ExamItems[1,1], "有&無造影劑")
	withwithoutCount+=1
else if instr(ExamItems[1,1],"Without") || (ExamItems[1,1]~="i)low dose|lung cancer screen|ldct|低劑量|(無造影劑)")
	withoutCount+=1
else
	withCount+=1
if (ldct:=regexmatch(ExamItems[1,1],"i)low dose|lung cancer screen|ldct|低劑量"))
	withwithout:="without"
otherCT:=ExamItems[2].maxindex()>ExamItems[1].maxindex()
, otherParts:=[]
if ExamItems[1].maxIndex()>1
	for k,v in ExamItems[1]
		if  !regexmatch(v,"is)chest|lung|(low dose)|EPS"){
			;~ otherCT:=true

			RegExMatch(v, "i)-+([a-z \(\)]+)$", part)
			StringLower,part1,part1
			otherParts[InStr(part1, "neck")?"neck":part1]:=1

			if instr(v,"With/Without")
				withwithoutCount+=1
			else if instr(v,"Without") || (v~="i)low dose|lung cancer screen|ldct")
				withoutCount+=1
			else
				withCount+=1

		}

RisHistoryAcc:=acc_ObjectFromWindow(getRisHistoryId(RisHwnd))
,priorDate:=""
controlfocus,,% "ahk_id " risreporthwnd:=RisReports[1,1]
;~ if (getRisChartNo(RisHwnd)!=getImpaxChartNo(ImpaxOpened()[2,1])
	;~ && getRisChartNo(RisHwnd)!=getEBMChartNo()) {
;~ if !RisChartNoMatchPacs(RisState, ImpaxState){
	;~ simpleRISBlack()
	;~ ,risOpenStudyImpax(risHwnd)
	;~ ,studyOpened:=1
;~ }

examDate:=getRisExamDate(RisState[2])
,thisAccNo:=getRisAccNo(RisState[2])



;open old film
for k,v in rows:=acc_children(RisHistoryAcc){
	if(k=1){
		for x,y in cells:=acc_children(v) {
			if (y.accValue="照會單號"){
				AccNoCol:=x
			}else if (y.accValue="檢查日"){
				examDateCol:=x
			}else if (y.accValue="檢查名稱"){
				examNameCol:=x
			}
		}
	}else if regexmatch(acc_children(v)[examNameCol].accValue,"is)CT.+Contrast-Chest|Low dose") {
		_priorDate:=acc_children(v)[examDateCol].accValue
		if RegExReplace(_priorDate,"\W","")>=SubStr(RegExReplace(examDate,"\W",""),1,8){
			continue
		}
		priorDate:=_priorDate
		,v.accSelect(ComObj(3,3),0)

		if(impaxContextServerHwnd:=ImpaxContextServer_Init()){
		;~ if(0){
			sendStr:="SYNC_DISPLAY || " thisAccNo " || "
			,sendStr.="ADD_TO_DISPLAY_LIST || " Trim(acc_children(v)[AccNoCol].accValue) " || "
			Loop {
				if !(RegExReplace(priorDate,"\W","")=RegExReplace(test:=(nearRow:=acc_children(rows[k-A_Index]))[examDateCol].accValue,"\W","") && InStr(test2:=nearRow[examNameCol].accValue,"CT"))
					break
				sendStr.="ADD_TO_DISPLAY_LIST || " Trim(nearRow[AccNoCol].accValue) " || "
			}
			Loop {
				if !(RegExReplace(priorDate,"\W","")=RegExReplace((nearRow:=acc_children(rows[k+A_Index]))[examDateCol].accValue,"\W","") && InStr(nearRow[examNameCol].accValue,"CT"))
					break
				sendStr.="ADD_TO_DISPLAY_LIST || " Trim(nearRow[AccNoCol].accValue) " || "
			}
			sendStr.="ADD_TO_DISPLAY_LIST_WITH_PRIORS || " thisAccNo " || "
			;~ ,SetTimerF("cmdContextServer", -3000, [sendStr, impaxContextServerHwnd])
		}else{
			sleep 200
			loc:=Acc_Location(v)
			mouseclick,r,% loc.x+50,% loc.y+5,1,0
			sleep 200
			mouseclick,l,10,10,1,0,,R
		}
		break
	}
}
settimer,updateSimpleRISoldHx,-500

withwithout:=withwithoutCount>0?"without/with":withoutCount>0?"without":"with"
,AllParts:=""
,otherParts["chest"]:=1
,otherPartsList:=""
otherPartDefaultFinding:=(ClinicalHx~="i)neoplasm|cancer|malignancy|carcinoma|metasta")?{brain: "no abnormal enhancing lesion in the brain parenchyma. "
	, neck: "no definite enlarged (>1cm) neck lymph node. "
	, abdomen: "no definite lymphadenopathy or metastatic lesions. "}:[]
for k,v in ["brain", "neck", "chest", "abdomen", "pelvis", "C spine", "T spine", "L spine", "upper extremities", "lower extremities"]
	if otherParts.HasKey(v)
		AllParts.=InStr(v,"spine")?(StringUpper(SubStr(v,1,1)) "-" SubStr(v,3)):v ", "
		, otherParts.delete(v)
		, otherPartsList.=v~="i)chest|spine|extremit"?"":bullet StringUpper(SubStr(v,1,1)) SubStr(v,2) ": " otherPartDefaultFinding[v] "`r`n"
for k,v in otherParts
	AllParts.=v ", "
AllParts:=RegExReplace(AllParts, ", $", "")
,AllParts:=RegExReplace(AllParts, ", (\w+)$", " and $1")

text:=""
__ind:=RegExReplace(trim(getIndicationText(risHwnd)), "[\.\r\n]+$","")

if !__is_CH && !(__ind="") && !(__ind="N/A") 
	text.="INDICATION: " __ind ". `r`n`r`n"
text.="TECHNIQUE: " (ldct&&withwithout="without"?"Low dose ":"") "CT of the " AllParts " " withwithout " intravenous contrast.`r`n"
if priorDate
	text.="COMPARISON: " priorDate ".`r`n"
text.="FINDINGS:`r`n"
,text.=ifbreast:=RegExMatch(ClinicalHx,"is)(neoplasm|malignan|cancer|carcinoma)[^\r\n]+breast|breast[^\r\n]+(neoplasm|malignan|cancer|carcinoma)")?bullet "Breast: `r`n":""
if ifbreast
	cursorPoint:=strlen(text)-2
text.=bullet "Lung/airway: `r`n  -- `r`n"
if !ifbreast
	cursorPoint:=strlen(text)-2
text.=bullet "Pleura: no pleural effusion. `r`n"
,text.=(instr(ClinicalHx,"lymphoma")||instr(ClinicalHx,"leukemia"))?bullet "Thoracic lymph node: small mediastinal and supraclavicular lymph nodes. `r`n":ifbreast?bullet "Mediastinum: small mediastinal and axillary lymph nodes. `r`n":bullet "Mediastinum: small mediastinal lymph nodes. `r`n"
,text.=bullet "Other: `r`n"
,text.=bullet "Heart/great vessel: `r`n"
,text.=bullet "Bone: spondylosis with marginal spur formation. `r`n"
,Text.=otherPartsList
if withwithout=without
	text.="(Low sensitivity and specificity of non-contrast CT.)`r`n"
if (ldct || (ClinicalHx~="i)小部位[^\r\n]+(LDCT|low\W*dose)"))
	text.="(Low dose CT is incompetent for soft tissue lesion detection.)`r`n"
if otherCT
	text.="(Please correlate with the report of other body parts.)`r`n"
;~ text.="(YCH/)"
text:=SubStr(text,1, -2)
;~ changeLineBreak(Text)


;; lung op
if OpText:=chestCTtemplateAddOpText(Text)
	controlsettext,,% "Post-operative changes of lung.`r`n",% "ahk_id " RisReports[1,2]

if !ifbreast
	cursorPoint+=StrLen(OpText)

;;;;; breast op text
if RegExMatch(oldReportText:=ControlGetText(RisReports[2,1]), "i)[^\r\n\.:\-\)\*>=]+mast?ectomy[^\r\n\.:]*\.?", ms)
	|| RegExMatch(oldReportText getRisClinicalInfoText(RisState[2]), "i)(bilateral|right|left) *(partial)? *mast?ectomy", m){
	breast_optext:=ms?StringLowerFirst(RegExReplace(Trim(ms), "masectomy", "mastectomy")):"status post " m1 " mastectomy. "
	if i:=RegExMatch(Text, "i)- Breast: ")
		Text:=SubStr(Text,1,i+9) breast_optext SubStr(Text, i+10)
		,cursorPoint+=StrLen(breast_optext), ifbreast:=false
	else if i:=RegExMatch(Text, "i)- Others?: ", m)
		Text:=SubStr(Text,1,i+StrLen(m)-1) breast_optext SubStr(Text, i+StrLen(m)), ifbreast:=false
	else if i:=RegExMatch(Text, "i)Findings: *\r?\n", m)
		breast_optext.="`r`n"
		,Text:=SubStr(Text,1,i+StrLen(m)-1) breast_optext SubStr(Text, i+StrLen(m))
		,cursorPoint+=StrLen(breast_optext), ifbreast:=false
}

;;; old lung change
for k,v in RegExMatchAll(oldReportText, "i)[\w, ]*(fibro|emphyse)[^.\r\n]+").list {
	Text:=RegExReplace(Text, "i)(- Lung[^\r\n]+\r?\n( *--[^\r\n]*\r?\n)*( *--[^\r\n]))", "$1" Trim(v[0]) ". `r`n  -- ")
}

;;; eso op text
if RegExMatch(oldReportText, "i)esophagectomy|gastric tube") {
	Text:=RegExReplace(Text, "i)Mediastinum:[^\r\n]*", "Mediastinum: status post esophagectomy and reconstruction.")
}

bulletRE:="(?:(?:[\-\*>]+|\d+\.?) *)?"

;; pleural findings
ophx:=""
for k,v in RegExMatchAll(oldReportText, "i)(?:[\w ,\/\-]|\d+\.\d+)*(pleural)[^\r\n\.]*").list {
	if !(Trim(v[0])~="i)^" bulletRE "(?:there(?:\'s|\'re| +is| +are| +was| +were) +)? ?(?:no|unr|ne)") && !InStr(v[0], "subpleur") && !(v[0]~="i)pleural retraction|pleural tail")
		ophx.=regexreplace(Trim(v[0]) ". ", "^" bulletRE, "")
}
if(ophx!="")
	Text:=RegExReplaceSeq(text, ["i)(Pleural?:) *(no pleural effusion.)?", "i)(Other:)"], "$1 " StringLowerFirst(ophx))

;;; abdominal hx
ophx:=""
for k,v in RegExMatchAll(oldReportText, "i)(?:[\w ,\/\-]|\d+\.\d+)*(splenectomy|cholecystectomy|nephr\w+tomy|gastrectomy|whipple|bypass|ostomy|RFA|TAE|TACE|cirrho|fatty)[^\r\n\.]*").list {
	if !(Trim(v[0])~="i)^" bulletRE "(?:there(?:\'s|\'re| +is| +are| +was| +were) +)? ?(?:no|unr|ne)")
		ophx.=regexreplace(RegExReplace(Trim(v[0]), "i)s\/p", "status post") ". ", "^" bulletRE, "")
}
if(ophx!="")
	Text:=RegExReplaceSeq(text, ["i)(Abdomen:)", "i)(Other:)"], "$1 " StringLowerFirst(ophx))

;;; pelvic hx
ophx:=""
for k,v in RegExMatchAll(oldReportText, "i)(?:[\w ,\/\-]|\d+\.\d+)*(\bTURP\w+|prostat|bladder|hyster|adnex|ovar)[^\r\n\.]*").list {
	if !(Trim(v[0])~="i)^" bulletRE "(?:there(?:\'s|\'re| +is| +are| +was| +were) +)? ?(?:no|unr|ne)")
		ophx.=regexreplace(RegExReplace(Trim(v[0]), "i)s\/p", "status post") ". ", "^" bulletRE, "")
}
if(ophx!="")
	Text:=RegExReplaceSeq(text, ["i)(Pelvis:)", "i)(Other:)"], "$1 " StringLowerFirst(ophx))

;;; neck op hx
ophx:=""
for k,v in RegExMatchAll(oldReportText, "i)(?:[\w ,\/\-]|\d+\.\d+)*(thyroidectomy)[^\r\n\.]*").list {
	if !(Trim(v[0])~="i)^" bulletRE "(?:there(?:\'s|\'re| +is| +are| +was| +were) +)? ?(?:no|unr|ne)")
		ophx.=regexreplace(RegExReplace(Trim(v[0]), "i)s\/p", "status post") ". ", "^" bulletRE, "")
}
if(ophx!="")
	Text:=RegExReplaceSeq(text, ["i)(Neck:)", "i)(Other:)"], "$1 " StringLowerFirst(ophx))

;;;; metastasis text
if RegExMatch(oldReportText, "i)" bulletRE "(?:(?:there(?:\'s|\'re| +is| +are| +was| +were) +)? ?(no|unr|ne)?[ \w]+)?(bone|bony|spinal|vertebral|skull) metasta", mets) && (mets1="") {
	Text:=RegExReplaceSeq(text, ["i)(Bone:[^\r\n]*)", "i)(Other:[^\r\n]*)"], "$1 bone metastases. ")
}
if RegExMatch(oldReportText, "i)\W? *((?:(?:there(?:\'s|\'re| +is| +are| +was| +were) +)? ?(?:no|unr|ne))[ \w]+)?(liver|hepatic) metasta", mets) && (SubStr(Trim(mets1),1,1)!="n") {
	Text:=RegExReplace(text, "i)Abdomen: no definite lymphadenopathy or metastatic lesions. *", "Abdomen:", "", 1)
	Text:=RegExReplaceSeq(text, ["i)(Abdomen:[^\r\n]*)", "i)(Other:[^\r\n]*)"], "$1 liver metastases. ")
}

;;; bone finding
ophx:=""
for k,v in RegExMatchAll(oldReportText, "i)(?:[\w ,\/\-]|\d+\.\d+)*(fracture)[^\r\n\.]*").list {
	if !(Trim(v[0])~="i)^" bulletRE "(?:there(?:\'s|\'re| +is| +are| +was| +were) +)? ?(?:no|unr|ne)")
		ophx.=regexreplace(Trim(v[0]) ".", "^" bulletRE, "")
}
if(ophx!="")
	Text:=RegExReplaceSeq(text, ["i)(Bone:[^\r\n]*)", "i)(Other:[^\r\n]*)"], "$1 " StringLowerFirst(ophx))

Text:=RegExReplace(Text, "i) *\(? *(?:SE|S) *\d+[^\w\)\r\n]*(?:IM|I) *\d+(,? *(?:IM|I) *\d+)* *\)?", "")

PostMessage,0x2023,1,0,,simpleRIS_main ahk_class AutoHotkeyGUI

if InStr(ExamItems[1,1], "Low dose lung cancer screening CT for employee(N hospital)"){
	if FileExist(path:=A_ScriptDir "\LDCTreport\LDCTreport.exe") || FileExist(path:=A_ScriptDir "\LDCTreport.exe")
		run,% path
}else{

	controlsettext,,% text,% "ahk_id " RisReports[1,1]

	if (ifbreast)
		i:=RegExMatch(Text, "i)- Breast: [^\r\n]*", m)
		,cursorPoint:=i+StrLen(m)-1
	else
		i:=RegExMatch(Text, "i)- Lung[^\r\n]+\r?\n( *--[^\r\n]*\r?\n)+", m)
		,cursorPoint:=i+StrLen(RegExReplace(m, "[\r\n]+$", ""))-1

	Edit_SetSel(RisReports[1,1],cursorPoint,cursorPoint)
	,Edit_ScrollCaret(RisReports[1,1])
	if (simpleRis:=winexist("simple RIS ahk_class AutoHotkeyGUI")){
		winactivate,ahk_id %simpleRis%
		editHwnds:=getSimpleRisEditHwnds()
		,Edit_SetText(editHwnds[2], Text)
		,Edit_SetSel(editHwnds[2],cursorPoint,cursorPoint)
		,Edit_SetText(editHwnds[1], Text)
		,Edit_SetSel(editHwnds[1],cursorPoint,cursorPoint)
		,Edit_ScrollCaret(editHwnds[2])

	}
}
;~ if !studyOpened
	;~ settimer,moveToSeriesList,-2000
;~ if(ldct)
	;~ settimer,showLungCAD,-3000
return

chestCTtemplateAddOpText(ByRef Text){
	global RisReports, RisState, cursorPoint
	ClinicalHx:=getRisClinicalInfoText(RisState[2])
	optext:=OpText(ControlGetText(RisReports[2,1]) "`r`n" ControlGetText(RisReports[2,1]) "`r`n" ClinicalHx)

	if (OpText!="")
		Text:=RegExReplace(Text, "(- Lung\/airway: \r?\n  -- )", "$1" OpText " `r`n  -- ")
		,cursorPoint+=8

	return OpText
}


updateSimpleRISoldHx:
PostMessage,0x1124,1,0,,simpleRIS_main ahk_class AutoHotkeyGUI
return

moveToSeriesList:
Impax:=impaxOpened()
for k,v in (impaxControls:=getcontrols(Impax[2,1])){
	if v.text="BMP_VIRTUAL_SCREEN_BUTTON" && instr(v.ClassNN,"WindowsForms10.BUTTON") {
		controlclick,,% "ahk_id " v.hwnd
		controlgetpos,x,y,,,,% "ahk_id " v.hwnd
		mousemove,% x+a_screenwidth+300,% y+300,0
		break
	}
}
winactivate,% "ahk_id " ImpaxState[2,1]

return

::cyyb::
(
Brain CT without/with contrast enhancement shows:
- Hemorrhage: None
- CSF spaces: Normal in size and morphology for the patient's age
- Cerebral parenchyma: Normal
- Cerebellum: Normal
- Brainstem: Normal
- Calvarium: Normal
- Vascular system: Unremarkable
- Visualized paranasal sinuses: Clear
- Visualized orbits: Normal
- Visualized cervical spine: Normal
- Sella and skull base: Normal
)
::cyyn::
(
Neck CT without/with contrast enhancement shows:
- Orbits/Sinonasal Cavities/Skull Base: Mild sinusitis change.
- Nasopharynx: Normal.
- Suprahyoid Neck: Normal.
- Infrahyoid Neck: Normal.
- Thyroid: Normal.
- Lymph Nodes: Normal.
- Vascular Structures: Normal.
)


^!r::
reload
return


joinAnd(arr,del=", ",lastDel="and"){
	str:="",ind:=arr.maxindex()
	for k,v in arr
		str.=v del

	if (lastDel="" || k=1)
		return substr(str,1,strlen(str)-strlen(del))
	else
		return substr(str,1,strlen(str)-strlen(del)*2-strlen(v)) " " lastDel " " v

}

parseAhk(path){
	arr:=[],hotstring:="",str:=""
	fullScript:=JoinScript(path)

	loop,parse,fullscript,`r`n
	;~ loop,read,% path
	{
		if RegExMatch(a_loopfield,"is)^:[^:]*?:(.+):[^:]?:([^\n\r]*)",match) {
			if match2
				arr["" match1]:=match2
			else
				hotstring:=match1

			continue
		}

		if (hotstring!="") {
			if(a_loopfield=")" || trim(a_loopfield)="return") {
				arr["" hotstring]:=str
				,hotstring:="",str:=""
			}else if (a_loopfield!="(") {
				str.=a_loopfield "`r`n"
			}

		}
	}
	return arr

}

combineHotstring:
sendlevel,1
send % $.value(1) ($.value(1)="b"?"i ":" ")
sleep 100
send % $.value(2) " "
sleep 100
if $.value(3) {
	if regexmatch(substr($.value(2),0,1),"[xsz]")
		send {bs}es
	else if regexmatch(substr($.value(2),-1,2),"ch|sh")
		send {bs}es
	else if substr($.value(2),0,1)="y"
		send {bs 2}ies
	else
		send {bs}s
}
$:=""
return


::facetblock::
send,
(
The study was for CT-guided facet block. The patient had right low back pain
> Image findings: lumbar spondylosis. Mild spondylolisthesis at L4-L5 level. Hypertrophy and calcified ligamentum flavum.
> Four 26G needles were inserted from bilateral posterior approach with tip into the bilateral L4-5, L5-S1 facet joint region. Total 5ml mixture of steroid (Triamcinolone suspension 1amp=40mg=1ml), 2`% xylocaine (3ml) and contrast medium (Omnipaque 1ml) was injected slowly through the needles.
> F/U CT showed well dispersion of the contrast medium in the facet joint regions.
> The patient tolerated the procedure well.
)
send {tab}
send,
(
Status post facet joint injection at bilateral L4-5 and L5-S1 levels.
)
return

::qq::
:*:qqq::
_qq:

RisReports:=getRisReports(risHwnd:=RisOpened()[2])
if InStr(A_ThisLabel, "qqq")

	controlsettext,,% "Radiological images from outside hospital had been uploaded into the PACS (Picture Archiving and Communication System) server as a baseline or for comparison. Please check the original formal report of these images from the source hospital. Brief (but not detailed) findings: `r`n" bullet,% "ahk_id " risReports[1,1]
else
	controlsettext,,% "Radiological images from outside hospital had been uploaded into the PACS (Picture Archiving and Communication System) server as a baseline or for comparison. Please check the original formal report of these images from the source hospital.",% "ahk_id " risReports[1,1]
winactivate,ahk_id %rishwnd%
ControlFocus,,% "ahk_id " RisReports[1,1]
controlsend,,^{end},% "ahk_id " RisReports[1,1]

if !InStr(A_ThisLabel, "qqq")
	getNetAcc(risHwnd,"cmdRunVerifySend","WindowsForms10.BUTTON").accDoDefaultAction()
return


loadAbbr(){
	fileread,abbr,% a_scriptdir "\YCH_abbr.txt"
	arr:=[]
	loop,parse,abbr,`n,`r
	{
		if regexmatch(a_loopfield,"^\s*\;") || (trim(a_loopfield)="")
			continue
		if regexmatch(a_loopfield,"^\s*([^=]+)=\s*([^\n]+)",match)
			if isobject(arr[match1])
				arr[match1].push(match2)
			else
				arr[match1]:=array(match2)
	}
	return arr
}
appendAbbr(){
	global abbr,risReports,RisState,editHwnds, thisPlace, CH_RIS, __is_CH
	checkRis(RisState)
	gosub renewRisReports
	;~ risReport:=getRisReports(risopened()[2])
	if !RisState[2] && !InStr(thisPlace, "C hospital")
		fullText:=ControlGetText(editHwnds[2])
	else if __is_CH
		fullText:=CH_RIS.report
	else
		fullText:=controlgettext(risReports[1,1]) "`r`n" controlgettext(risReports[1,2])
	fullReport:=RegExReplace(fullText,"is)^History[^\r\n]+","")
	,fullReport:=RegExReplace(fullReport,"is)^INDICATION:[^\r\n]+","")
	,fullReport:=RegExReplace(fullReport,"(\r?\n)+\(([A-Z]+: [^;\.]+(\.|; ))+\)","")
	,ind:=0,outText:="("
	,abbrLog:=","
	,output:=[]
	,fullReport:=RegExReplace(fullReport, "^[^\r\n]+\r?\n", "")
	while ind:=regexmatch(fullReport,"\b(D[Rr]\.? *)?([A-Z]{2,})s?\b",match,ind+1) {
		if match1
			continue
		if match2 in CT,MR,MRI,YCH,INDICATION,TECHNIQUE,EXAMINATION,COMPARISON,FINDINGS,PACS,HMC,II,III,IV,VI,VII,VIII,IX,XI,XII,CCRT,POSTERIOR,FOSSA,MRCP,BRAIN,NECK,SPINE,ABDOMEN,CONT,WITH,WITHOUT
			continue
		;~ else if (fullReport~=match2 " *\/(D[Rr].?)? *YCH")
			;~ continue
		else if isobject(a:=abbr[match2]) && !instr(abbrLog,"," match2 ",") {
			if (a.maxIndex()=1)
				;~ outText.=match2 ": " a.1 "; "
				output["" match2]:=a.1
			else {
				prompt:=""
				for k,v in a
					prompt.=k ": " v "`r`n"
				inputBox,choice,% """" match2 """ means ?",% prompt
				choice:=choice?(choice+0):1
				;~ outText.=match2 ": " a[choice] "; "
				output["" match2]:=a[choice]
			}

		}else if !instr(abbrLog,"," match2 ",") {
			inputbox,choice,% "What do you mean """ match2 """ ?"
			if (choice) {
				;~ outText.=match1 ": " choice "; "
				output["" match2]:="" choice
				abbrLog.=match2 ","
				clipboard:=match2 "=" choice
				if !winexist("YCH_abbr")
					run % a_scriptdir "\YCH_abbr.txt"
			}
		}
		abbrLog.=match1 ","
	}
	for k,v in output
		outText.=k ": " v "; "
	outText:=substr(outText,1,-2) ".)"
	;~ msgbox % outtext
	;~ outText.=")"
	;~ StringReplace,outText,outText,% "; )",% ".)"
	if (outText=".)")
		outText:=""
	else{

		if __is_CH
		{
			report:=new ReportImpression(CH_RIS.Report)
			,report:=new ReportImpression(report.exam "`r`n`r`n" outText, report.impression)
			,report.set_text(getSimpleRisEditHwnds()[1])
			,CH_RIS.report:=report.combine()
			,CH_RIS.exam:=report.exam
			,CH_RIS.impression:=report.impression
			,CH_RIS.flush()
		}else

		outText:=RegExReplace(controlgettext(editHwnds[2]),"(\r?\n$)|((\r?\n)+\(([A-Z]+: [^;\.]+(\.|; ))+\))","") "`r`n`r`n" outText
		,Edit_SetText(risReports[1,1], outText)
		,Edit_SetText(editHwnds[2], outText)
		,Edit_SetText(editHwnds[1], outText)

	}

	return outText
}
moveText(text){
	str:="",other:=0
	loop,parse,text,`n,`r
	{
		if instr(a_loopfield,"- Other")=1 || (instr(a_loopfield,"  -- ")=1 && other) {
			temp.=(temp?"`r`n":"") A_LoopField, other:=1
		}else if instr(a_loopfield,"- ")=1 || instr(a_loopfield,"  -- ")=1 {
			report:=1, other:=0
			str.=a_loopfield "`r`n"
		}else{
			str.=(report&&temp?(temp "`r`n"):"") a_loopfield "`r`n",report:=0,temp:=""
		}
	}
	if temp
		str.=temp
	return str
}


TrimConvert(t){
	return Trim(RegExReplace(t, "\r?\n", "`r`n"))
}

copyToRis:
if __is_N
	PostMessage,0x2020,,,,simpleRIS_main ahk_class AutoHotkeyGUI
checkRis(RisState)
gosub renewRisReports
risReport:=risReports[1,1]
,editHwnds:=getSimpleRisEditHwnds()
,simpleRisError:=false
if (simpleRis:=winexist("simple RIS ahk_class AutoHotkeyGUI")) || WinExist("simpleRIS_main ahk_class AutoHotkeyGUI")   {
	if (__is_CH){
		Text:=ControlGetText(editHwnds[1])
		,oText:=new ReportImpression(text)
		,oText.add_impression(ControlGetText((RisReports:=getRisReports())[1,2]))
		,oText.set_text(RisReports[1,1], RisReports[1,2])
		,oText.set_text(editHwnds[1])


	}else if !WinExist("simpleRISsimpleEdit ahk_class AutoHotkeyGUI") {
		Loop {
			Text:=TrimConvert(ControlGetText(editHwnds[1]))
			,Text2:=TrimConvert(controlgettext(editHwnds[2]))
			,oText:=new ReportImpression(text)
			,oText2:=new ReportImpression(text2)
			if(oText.combine()="")
				text:=Text2, otext:=oText2
			else if (oText2.combine()="")
				Text2:=text, oText2:=oText

			if InStr(thisPlace, "C hospital")
				text3:=text, oText3:=oText
			else
				text3:=TrimConvert(controlgettext(risReport))
				, oText3:=new ReportImpression(ControlGetText(getRisReports()[1,1]), ControlGetText(getRisReports()[1,2]))

			if(!oText.is_equal(oText2)) || (!oText.is_equal(oText3))
				Sleep 100
			else
				break
			if A_Index>4
				break
		}

		if !controlexists(risReport) || !controlexists(editHwnds[1]) || !controlexists(editHwnds[2]) || (Text!=Text2) || (Text!=text3) {
			simpleRisError:=true
			clipboard:=text "`n----------------------`n" Text2 "`n----------------------`n" text3
			MsgBox % "Simple RIS text error"
			return
		}
		;~ Edit_SetText(editHwnds[1], Text)
		;~ controlsettext,,% text,% "ahk_id " RisReports[1,1]
	}else{
		Text:=TrimConvert(ControlGetText(editHwnds[2])), oText:=new ReportImpression(text)
	}
}else{
	;~ msgbox % simpleRis "," text "," editHwnd
	text:=controlgettext(risReport)
	, oText:=new ReportImpression(ControlGetText(getRisReports()[1,1]), ControlGetText(getRisReports()[1,2]))
}

if __is_N && (InStr(reportHint:=getReportHint(RisState[2]),"請於impression輸入中文診斷") && Trim(ControlGetText(RisReports[1,2]))="" )
	ControlSetText,,% "無顯著異常。",% "ahk_id " RisReports[1,2]
return

renewRisReports:
;~ if !(isobject(risReports) && controlexists(RisReports[1,1]))
	RisReports:=getRisReports(RisState[2])
	,editHwnds:=getSimpleRisEditHwnds()
return
openSimpleRis:
if !winexist("simpleRIS_main ahk_class AutoHotkeyGUI") {
	;~ PostMessage,0x10101,,,,simpleRIS_main ahk_class AutoHotkeyGUI
	taskkill("simpleRIS_patch.exe")
	;~ ,taskkill(WinGet("PID", "simpleRIS__main ahk_class AutoHotkeyGUI"))
	,taskkill(WinGet("PID", "simpleRIS_main ahk_class AutoHotkeyGUI"))
	try
		run, % commands(A_ScriptDir "\AutoHotkey.exe", a_scriptdir "\PacsIE\simpleRIS.ahk"),% a_scriptdir "\PacsIE"
}
;~ winwait,% "simpleRIS__main ahk_class AutoHotkeyGUI",,2
;~ Sleep 1000
editHwnds:=getSimpleRisEditHwnds()
;~ if(!editHwnds.length()){
	;~ WinClose,% "simple RIS ahk_class AutoHotkeyGUI"
	;~ Sleep 100
	;~ run % a_scriptdir "\PacsIE\simpleRIS.exe"
	;~ winwait,% "simple RIS ahk_class AutoHotkeyGUI",,2
	;~ editHwnds:=getSimpleRisEditHwnds()
;~ }

WinFocus(getSimpleRisGuiHwnds()[2], editHwnds[2])
return


;~ staging
::npcst::
run,RadTemplate.exe .\staging\AJCC8_Nasopharyngeal_cancer.txt,% a_scriptdir "\RadTemplate"
return
::oralst::
run,RadTemplate.exe .\staging\AJCC8_Oral_cavity_cancer.txt,% a_scriptdir "\RadTemplate"
return
::larst1::
run,RadTemplate.exe .\staging\AJCC8_Laryngeal_cancer_supraglottis.txt,% a_scriptdir "\RadTemplate"
return
::larst2::
run,RadTemplate.exe .\staging\AJCC8_Laryngeal_cancer_glottis.txt,% a_scriptdir "\RadTemplate"
return
::larst3::
run,RadTemplate.exe .\staging\AJCC8_Laryngeal_cancer_subglottis.txt,% a_scriptdir "\RadTemplate"
return
::hypst::
run,RadTemplate.exe .\staging\AJCC8_Hypopharyngeal_cancer.txt,% a_scriptdir "\RadTemplate"
return
::orost2::
run,RadTemplate.exe .\staging\AJCC8_Oropharyngeal_cancer_with_p16.txt,% a_scriptdir "\RadTemplate"
return
::orost1::
run,RadTemplate.exe .\staging\AJCC8_Oropharyngeal_cancer_without_p16.txt,% a_scriptdir "\RadTemplate"
return
::lust::
run,RadTemplate.exe .\staging\AJCC8_Lung_cancer.txt,% a_scriptdir "\RadTemplate"
return
::esst::
run,RadTemplate.exe .\staging\AJCC8_Esophageal_cancer.txt,% a_scriptdir "\RadTemplate"
return


::tavi/::
run,RadTemplate.exe .\Procedure\TAVI.txt,% a_scriptdir "\RadTemplate"
return
::tavip/::
run,RadTemplate.exe ".\Procedure\TAVI post.txt",% a_scriptdir "\RadTemplate"
return

renewReportHwnd:
RisState:=RisOpened()
gosub renewRisReports
editHwnds:=getSimpleRisEditHwnds()
return

::hmctem::
ToolTip,
(
hmcbn0: no TOF, minimal leukoaraiosis
hmcbn1: no TOF, normal
hmcbn2: no TOF, +DWI, normal
hmcbn3: +TOF, normal
hmccmri: chest
hmcbmri: body
)
settimer,ToolTip,-3000
return
;~ HMC template
:*:hmcbn3::
insertTemplate("
(
MRI of head without contrast enhancement was performed including axial FLAIR, 3-D T1-weighted images for brain, T2-weighted images for neck, diffusion-weighted imaging for brain and neck and 3-D TOF MRA of cervicocranial arteries.

Radiological findings:
- No focal signal change in the brain parenchyma on FLAIR.
- Normal sized sulci, fissures and ventricles.
- No definite abnormality at the cervical portion of carotid and vertebral arteries as well as the circle of Willis portion of intracranial arteries.
- Normal appearance of the cranial vault and skull base.
- Clear paranasal sinuses.
- No obvious large neck mass or enlarged lymph nodes. However, mucosal lesion and small mass would be hard to detect in this study.
- No abnormal bright lesion on DWI.
)","
(
No obvious intracranial abnormality. 無明顯顱內異常
No obvious neck mass. 無明顯頸部腫塊
Normal MRA. 磁振血管造影無異狀
)")
return

:*:hmcbn1::
insertTemplate("
(
MRI of brain and neck without contrast enhancement was performed including 3-D T1WI, axial FLAIR images of brain and axial T2WI for neck.

Radiological findings:
- No focal signal change in the brain parenchyma on FLAIR.
- Normal sized sulci, fissures and ventricles.
- No obvious intracranial space taking lesion.
- Normal appearance of the cranial vault and skull base
- Clear paranasal sinuses.
- No obvious large neck mass or enlarged lymph nodes. However, mucosal lesion and small mass would be hard to detect in this study.
)","
(
No obvious intracranial abnormality. 無明顯顱內異常
No obvious neck mass. 無明顯頸部腫塊
)")
return


:*:hmcbn0::
insertTemplate("
(
MRI of brain and neck without contrast enhancement was performed including 3-D T1WI, axial FLAIR images of brain and axial T2WI for neck.

Radiological findings:
- Bilateral multiple tiny nonspecific hyperintensities over cerebral white matter on FLAIR.
- Normal sized sulci, fissures and ventricles.
- No obvious intracranial space taking lesion.
- Normal appearance of the cranial vault and skull base
- Clear paranasal sinuses.
- No obvious large neck mass or enlarged lymph nodes. However, mucosal lesion and small mass would be hard to detect in this study.
)","
(
Minimal nonspecific cerebral white matter change. 輕微非特異性腦白質變化.
No obvious neck mass. 無明顯頸部腫塊
)")
return

:*:hmcbn2::
insertTemplate("
(
MRI of brain and neck without contrast enhancement was performed including 3-D T1WI, axial FLAIR images of brain, axial T2WI for neck and diffusion weighted imaging for brain and neck

Radiological findings:
- No focal signal change in the brain parenchyma on FLAIR.
- Normal sized sulci, fissures and ventricles.
- No obvious intracranial space taking lesion.
- Normal appearance of the cranial vault and skull base
- Clear paranasal sinuses.
- No obvious large neck mass or enlarged lymph nodes. However, mucosal lesion and small mass would be hard to detect in this study.
- No abnormal bright lesion on DWI.
)","
(
No obvious intracranial abnormality. 無明顯顱內異常
No obvious neck mass. 無明顯頸部腫塊
)")
return

:*:hmccmri::
insertTemplate("
(
MRI of the chest with multiple pulse sequences (coronal, axial and sagittal T2 HASTE, axial turboFLASH T1, axial and coronal diffusion weighted images) is read with comparison of low dose chest CT on 20160615. This study shows:
- No definite mediastinal or hilar lymphadenopathy.
- No definite focal abnormality in bilateral lung parenchyma. However, there is limitation of evaluating tiny lung parenchymal abnormality in MRI. Correlation with low dose chest CT is suggested.
- No definite abnormal focal signal change on DWI.
)","
(
No definite abnormality in the screening chest MRI study. Suggest clinical correlation and follow up.
胸部磁振造影檢查無異常發現。建議臨床評估對照與追蹤。
)")
return

:*:hmcbmri::
insertTemplate("
(
MRI of abdomen and pelvis without contrast enhancement for health examination shows:
- Liver: unremarkable.
- MRCP: unremarkable.
- Spleen: unremarkable.
- Pancreas: unremarkable.
- Kidneys: unremarkable.
- Adrenal glands: unremarkable.
- Great vessels: unremarkable.
- Uterus: unremarkable.
- Ovaries: unremarkable.
- Urinary bladder: unremarkable.
(MRI is not sensitive for small gastrointestinal lesions, urolithiasis, small ureteral tumors without hydronephrosis, small cervical and endometrial cancers.)
)","
(
No definite abnormality in the screening abdominal/pelvic MRI study. Suggest clinical correlation and follow up.
腹部磁振造影檢查無異常發現，建議臨床評估對照與追蹤。肝水泡。腎水泡。子宮肌瘤。
)")
return


;~ cmdContextServer(str,hwnd=""){
	;~ DetectHiddenWindows,on
	;~ if !hwnd && !hwnd:=winexist("ahk_exe ImpaxContextServer.exe")
		;~ return 1
	;~ loop,parse,str
	;~ {
		;~ PostMessage,0x10303,,% asc(a_loopfield),,ahk_id %hwnd%
		;~ sleep 20
	;~ }
	;~ PostMessage,0x10303,,0x0,,ahk_id %hwnd%

;~ }
;~ cmdContextServer(str,hwnd=""){
	;~ oldDetectHiddenWindows:=A_DetectHiddenWindows
	;~ DetectHiddenWindows,on

	;~ Send_WM_COPYDATA(hwnd, 0, str)

	;~ DetectHiddenWindows,% oldDetectHiddenWindows
;~ }



showLungCAD:
if WinExist("ahk_exe autorun.exe"){
	SendMessage,0x8100,,,,showLungCAD_main ahk_class AutoHotkeyGUI
	;~ MsgBox % ErrorLevel
	return
}
ip:="http://10.0.0.1:8042/"
chartNo:=getRisChartNo(RisState[2])

dateStr:=SubStr(examDate,1,4) SubStr(examDate,6,2) SubStr(examDate,9,2)
;~ examDate:=getRisExamDate(RisOpened()[2])


httprequest(url:=ip "patients/" SHA1dash(chartNo),post:="",header:="","charset: utf-8")
if !post
	goto fail

patient:=json_from(post)
url:="",processed:=0
Loop % patient.studies.maxindex() {
	httprequest(ip "studies/" patient.studies[A_Index],post:="",header:="","charset: utf-8")
	if !post
		continue
	study:=json_from(post)
	if(study.MainDicomTags.StudyDate=dateStr){
		Loop % study.series.maxindex() {
			httprequest(ip "series/" study.series[A_Index],post:="",header:="","charset: utf-8")
			if(!post)
				continue
			series:=json_from(post)
			;~ else if ()
			if(series.MainDicomTags.SeriesDescription="Evidence Documents MM Oncology Reading"){
				processed:=1
			}else if(series.MainDicomTags.SeriesDescription="Results MM Oncology Reading" || series.MainDicomTags.SeriesDescription="Hologic R2 ImageChecker CAD SC"){
				clipboard:=url:=ip "web-viewer/app/viewer.html?series=" study.series[A_Index]
				break 2
			}

		}
	}
}
if(url=""){
	if(processed)
		goto noResult
	else
		goto fail
}


;~ test:
;~ clipboard:=url:=ip:="http://www.yahoo.com.tw/"

ifwinexist,ahk_class MozillaWindowClass
	winactivate
else ifwinexist,ahk_class Chrome_WidgetWin_1
	WinActivate
else
	goto openNewChromeOrFirefox

winwaitactive,,,2
if(ErrorLevel)
	return

if !InStr(activeUrl:=GetActiveBrowserURL(),ip) && activeUrl!="" {
	send ^t
	Sleep 100
}
send !d
sleep 100
send ^v
sleep 100
send {enter}
recoverClip:
return
openNewChromeOrFirefox:
appPath:=""
Loop,% a_desktop "\*.lnk"
	if InStr(A_LoopFileName, "firefox"){
		FileGetShortcut,% A_LoopFileFullPath, appPath
		break
	}
if(appPath!=""){
	run % """" appPath """ """ url """"
	return
}
Loop,% A_DesktopCommon "\*.lnk"
	if InStr(A_LoopFileName, "firefox"){
		FileGetShortcut,% A_LoopFileFullPath, appPath
		break
	}
if(appPath!=""){
	run % """" appPath """ """ url """"
	return
}
Loop,% a_desktop "\*.lnk"
	if InStr(A_LoopFileName, "chrome"){
		FileGetShortcut,% A_LoopFileFullPath, appPath
		break
	}
if(appPath!=""){
	run % """" appPath """ """ url """"
	return
}
Loop,% A_DesktopCommon "\*.lnk"
	if InStr(A_LoopFileName, "chrome"){
		FileGetShortcut,% A_LoopFileFullPath, appPath
		break
	}
if(appPath!=""){
	run % """" appPath """ """ url """"
	return
}
MsgBox % "Please open Firefox or Chrome first!"
return

noResult:
MsgBox,,,% "No lesion found by CAD",3
goto recoverClip
return

fail:
if !InStr(A_ScriptName, "mammo")
	settimer,dcmqr,-1
goto recoverClip
return


dcmqr:
if !IsObject(dcmRAID)
	dcmRAID:=new dcm4che(), dcmSyngovia:= new dcm4che("SYNGOVIA")
;~ MsgBox % dcmRAID.root "," dcmRAID.dcmqrPath
seriesInfoSyngovia:=dcmSyngovia.getSeriesInfo(thisAccNo:=getRisAccNo((RisState:=RisOpened())[2]))
;~ MsgBox % seriesInfo.maxindex()
if(seriesInfoSyngovia.maxindex()>0){
	MsgBox,,,Not processed yet in Syngovia!,3
	return
}

seriesInfo:=dcmRAID.getSeriesInfo(thisAccNo)
if(seriesInfo.maxindex()<1){
	msgbox,,,Not found in RAID!,3
	return
}
gui,dcmqr:Default
gui,destroy
for k,v in seriesInfo {
	;~ MsgBox % v.SeriesDescription
	gui,Add,Checkbox,% "vdcmqrCb" k " w400 " (v.InstanceCount>300?"checked":""),% v.SeriesDescription " (" v.InstanceCount ")"
}
gui,Add,button,gdcmqrSubmit,to Syngovia
gui,show,AutoSize,Select series
return

dcmqrSubmit:
gui,Submit
for k,v in seriesInfo {
	if (dcmqrCb%k%)
		dcmRAID.Move([v.SeriesUID], "SYNGOVIA")
}

return


SHA1dash(str){
	str:=SHA(str)
	stringlower,str,str
	return substr(str,1,8) "-" substr(str,9,8) "-" substr(str,17,8) "-" substr(str,25,8) "-" substr(str,33,8)
}


#z::
KeyWait,lwin,t1
KeyWait,z,t1
checkRis(RisState)
;~ PostMessage,0x2021,,,,ahk_exe simpleRIS.exe
gosub renewRisReports
ExamItems:=parseRisExamItems(getRisExamItems(RisOpened()[2]))
,str:=""
,cChartNo:=getRisChartNo(RisState[2])
,cAccNo:=getRisAccNo(RisState[2])
if InStr(ExamItems[1,1], "requesting"){
	goto _qq
}
risOpenOldStudy(RisState[2],false,true)
	;~ ToolTip % cChartNo
;~ if (cChartNo~="^(H|Y)" && WinExist("ahk_exe EBMpreload.exe"))
	PostMessage,0x2021,,,,EBM Preload ahk_class AutoHotkeyGUI
;~ else
	;~ openRisStudy()
;~ PostMessage,0x2026,,,,simple RIS ahk_class AutoHotkeyGUI

for k,ExamName in ExamItems[1]
	str.=examName "; "
report:="Chart No: " cChartNo ".`r`nEXAMINATION: " SubStr(str,1,-2) ".`r`nFindings: `r`n- "
,setReportText(report, "", RisReports,1)
;~ Sleep 1000
;~ winactivate,simple RIS ahk_class AutoHotkeyGUI
PostMessage,0x10103,,,,HotstringHintMain ahk_class AutoHotkeyGUI
return

#c::
checkRis(RisState)
;~ PostMessage,0x2021,,,,ahk_exe simpleRIS.exe
gosub renewRisReports

ExamItems:=parseRisExamItems(getRisExamItems(RisOpened()[2]))
,hasChest:=false
for k,ExamName in ExamItems[1]
	if (ExamName~="is)CT.+Chest|lung|EPS"){
		hasChest:=true
		break
	}else if (examName=""){
		RisState:=RisOpened()
		return
	}

;~ cChartNo:=getRisChartNo(RisState[2])
;~ if (cChartNo!=getImpaxChartNo()){
if !RisChartNoMatchPacs(RisState, ImpaxState, cChartNo){
	if (isChartNo(cChartNo).pacsViewer="EBM" && WinExist("EBM Preload ahk_class AutoHotkeyGUI"))
		PostMessage,0x2020,,,,EBM Preload ahk_class AutoHotkeyGUI
	else
		openRisStudy()
}

if(!hasChest){
	cChartNo:=getRisChartNo(RisState[2])
	;~ ToolTip % cChartNo

	return
}

;~ RisReports:=getRisReports(RisState[2])

thisReport:=controlgettext(RisReports[1,1])
if(Trim(thisReport)=""){
	;~ HideImpax(true)
	goto chestCTtemplate
}else if !(thisReport~="INDICATION:[\w\W]+?TECHNIQUE:[\w\W]+?(COMPARISON:[\w\W]+?)?FINDINGS:") {
	;~ if (cChartNo!=getImpaxChartNo()){
		;~ openRisStudy()
	;~ }
	return
}

priorReport:=chestTemplateSplit(controlgettext(RisReports[2,1]))
,thisReport:=chestTemplateSplit(thisReport)
,copiedReport:=RegExReplace(thisReport[1] priorReport[2] thisReport[3],"(\r\n){2,}","`r`n")

,regexmatch(priorReport[2],"\s*[-\*] [^\r\n]+(\r?\n\s*([-\*]+ |\d+\W+)[^\r\n]+)?",match)
,copiedReport:=RegExReplace(copiedReport, "\(<=?5mm|\(<=?4mm", "(<6mm")

controlsettext,,% text:=RegExReplace(copiedReport,"i) *\([\d\.\,mc ]*?((SE|IM)[^\)]+)[\d\.mc ]*?\)",""),% "ahk_id " risreports[1,1]

controlsettext,,% controlgettext(RisReports[2,2]),% "ahk_id " RisReports[1,2]
Edit_SetSel(RisReports[1,1],sel:=strlen(thisReport[1] match),sel)
Edit_ScrollCaret(RisReports[1,1])

if simpleRis:=winexist("simple RIS ahk_class AutoHotkeyGUI") {
	editHwnds:=getSimpleRisEditHwnds()
	,Edit_SetText(editHwnds[2], text)
	,Edit_SetSel(editHwnds[2],sel,sel)
	,Edit_SetText(editHwnds[1], text)
	,Edit_SetSel(editHwnds[1],sel,sel)
	,Edit_ScrollCaret(editHwnds[2])
}
;~ HideImpax(false)
return

openRisStudy(){
	PostMessage,0x2026,,,,simpleRIS_main ahk_class AutoHotkeyGUI
	;~ SendLevel,2
	;~ winactivate,simple RIS ahk_class AutoHotkeyGUI.exe
	;~ WinWaitActive,simple RIS ahk_class AutoHotkeyGUI,,3
	;~ send {F5}
}

HideImpax(toggle){
	if !WinExist("ahk_exe AntiImpaxFlash.exe"){
		run % A_ScriptDir "\AntiImpaxFlash.exe"
		Loop
			Sleep 50
		until WinExist("ahk_exe AntiImpaxFlash.exe") || (A_Index>100)
	}
	PostMessage,0x10305,,% toggle=""?"":!!toggle,,AntiImpaxFlash ahk_class AutoHotkey
}

chestTemplateSplit(text){
	arr:=[],mid:=0
	loop,parse,text,`n,`r
	{
		if regexmatch(a_loopfield,"is)^\s*([-\*]+ |\d+\W+).*",match)
			arr.2:=arr.2 match "`r`n",mid:=1
		else
			arr[1+mid*2]:=arr[1+mid*2] a_loopfield "`r`n"
	}
	return arr
}

resetSimpleRis(){
	PostMessage,0x2024,1,,,simpleRIS_main ahk_class AutoHotkeyGUI
}
simpleRISBlack(){
	PostMessage,0x2029,1,,,simpleRIS_main ahk_class AutoHotkeyGUI
}
PauseSimpleRis(){
	PostMessage,0x2023,3000,1,,simpleRIS_main ahk_class AutoHotkeyGUI
}


^!y::
editCCTAreport:
FocusedHwnd:=getFocusedHwnd()
,pText:=Edit_GetText(FocusedHwnd)
,pText:=RegExReplace(pText, "(\r?\n)\* ", "$1- ")
,Edit_SetText(FocusedHWND, pText)
return


ribNo:
if($.value(1)="l")
	str:="left"
else if($.value(1)="r")
	str:="right"
else if($.value(1)="b")
	str:="bilateral"

str.=" " $.value(2)

if (SubStr($.value(2),0,1)="1")
	str.="st"
else if (SubStr($.value(2),0,1)="2")
	str.="nd"
else if (SubStr($.value(2),0,1)="3")
	str.="rd"
else
	str.="th"

str.=" rib" ($.value(1)="b"?"s":"")
send % "{bs " StrLen($.value(0))  "}"
;~ Sleep 50
send % str $.value(3)
$:=""
return


degenerativeSpine($){
	static spinekylorsco:={k:"kyphosis",l:"lordosis",s:"scoliosis"}
	, spine_findings:=["marginal osteophyte formation", "dehydrated disc", "dehydrated narrowed disc", "facet joint arthroses", "hypertrophic ligamenta flava"]
	send % "{bs " StrLen($.value(0))  "}"
	ret:=spineParts($.value(1))
	,ret.=" spondylosis"
	k:=$.value(2)
	Loop,parse,k
		if spinekylorsco.HasKey(A_LoopField)
			ret.="/" spinekylorsco[A_LoopField]
	ret.=" "
	,k:=$.value(3)

	,_findings_str:=""
	Loop,parse,k
		_findings_str.=spine_findings[A_LoopField] ", "
	ret.=(_findings_str=""?"":"with " RegExReplace(SubStr(_findings_str,1,-2), ", ([^,]+)$", " and $1")) $.value(4)
	send % ret
	$:=""

}

spineParts(str, delim="-"){
	static arr:={c: "cervical", c_:"cervico"
		,t: "thoracic", t_: "thoraco"
		,l: "lumbar", l_: "lumbo"
		,s: "sacral", s_: "sacro"}
	ret:=""
	Loop,parse,str
	{
		if arr.HasKey(A_LoopField)
			ret.=arr[(last:=A_LoopField) "_"] delim
	}
	return SubStr(ret,1,-2 - StrLen(delim)) SubStr(arr[last],-2)
}

ToolTip:
ToolTip
return

;abbr
:c:ica::ICA
:c:aca::ACA
:c:mca::MCA
:c:icas::ICAs
:c:acas::ACAs
:c:mcas::MCAs
:c:sca::SCA
:c:m1::M1
:c:m2::M2
:c:a1::A1
:c:a2::A2
:c:p1::P1
:c:p2::P2
:c:pca::PCA
:c:pcas::PCAs
:c:eca::ECA
:c:ecas::ECAs
:c:mma::MMA
:c:mmas::MMAs
:c:cca::CCA
:c:ccas::CCAs
:c:pica::PICA
:c:aica::AICA
:c:va::VA
:c:picas::PICAs
:c:aicas::AICAs
:c:vsa::VAs
:c:ba::BA
:c:sov::SOV
:c:ccf::CCF
:c:avf::AVF
:c:avm::AVM
:c:tof::TOF
:c:flair::FLAIR
:c:mri::MRI
:c:ct::CT
:c:mtt::MTT
:c:cbf::CBF
:c:cbv::CBV
:c:ich::ICH
:c:ichs::ICHs
:c:sah::SAH
:c:sahs::SAHs
:c:sdh::SDH
:c:sdhs::SDHs
:c:edh::EDH
:c:edhs::EDHs
:c:ijv::ijv

:c:ihds::IHDs
:c:cbd::CBD

:c:rv::RV
:c:la::LA
:c:ra::RA

:c:svc::SVC


;~ getFocusedHwnd(){
	;~ static GuiThreadInfoSize = 48
	;~ VarSetCapacity(GuiThreadInfo, GuiThreadInfoSize)
	;~ NumPut(GuiThreadInfoSize, GuiThreadInfo, 0)
	;~ DllCall("GetGUIThreadInfo", uint, 0, str, GuiThreadInfo)
	;~ return FocusedHWND := NumGet(GuiThreadInfo, 12)
;~ }

;~ focusedEditBS(bs, hwnd=""){
	;~ sendByClipboard("", bs, hwnd)
;~ }



sendByEdit(byref str, bs="", hwnd=""){
	; global __HotstringEnhancer_pClipboard
	; sendlevel,0
	; !!assumption: no selection range!!
	static focused, focused_p, sci, cached:=[]
	return sendbyclipboard(str, StrLen(bs))
	if(hwnd!="" && WinExist("ahk_id " hwnd))
		focused:=hwnd
	else
		focused:=getFocusedHwnd()

	;~ Edit_InsertText(focused, str)
	;~ if(bs!="")
	;~ {
		;~ KeyWait, % SubStr(bs,-1,1),t0.2
		;~ send % "{bs " StrLen(bs) "}"
	;~ }
		;~ Edit_DeleteText(focused, "", StrLen(bs))

	wingetclass,class,ahk_id %focused%
	if(class="Scintilla"){
		if(focused_p!=focused)
			sci:=new RemoteScintilla(focused)
		if(bs!=""){
			if (StrLen(bs)>=sci.GetTextLength()) {
				resetSimpleRis()
				Sleep 50
			}else{
				KeyWait, % SubStr(bs,0,1),T0.2
				bsLen:=StrLen(bs)
				sci.DeleteRange(sci.getCurrentPos()-bsLen, bsLen)
			}
		}
		if(str!="")
			sci.AddText(str)
		focused_p:=focused
	}else{
		;~ t:=ControlGetText(focused), Edit_GetSel(focused, s, e)
		;~ ,bsLen:=StrLen(bs)
		;~ if(bsLen)
			;~ s:=e:=s-bsLen>=0?s-bsLen:0
		;~ t:=(s>=0?SubStr(t, 1, s):"") str SubStr(t, s+bs+1)
		;~ ,Edit_SetText(focused, t)
		;~ ,e:=(s+=StrLen(str))
		;~ ,Edit_SetSel(focused, s, e)
		if(bs!=""){
			KeyWait, % SubStr(bs,0,1),T0.2
			send % "{bs " StrLen(bs) "}"
		}
		Sleep 20
		Send % str

	}
	blockinput,mousemove
	resetHotstringBuffer(-1)
	blockinput,mousemoveoff
}


AppsKey & z::
ToolTip,
(



1 2 3
T H R

A F G
S C B

W E Q
Z
)
settimer, ToolTip, -5000
return


; for feedRIS
::imp::
send % "`n-=-=-=-=-`n"
return





; CCTA

::cpq::calcified plaque
:*:cpq1::calcified plaques
::npq::noncalcified plaque
:*:npq1::noncalcified plaques
::mpq::mixed plaque
:*:mpq1::mixed plaques

:*:ds1::minimal (<25%) stenosis
:*:ds2::mild (25%-49%) stenosis
:*:ds3::moderate (50%-69%) stenosis
:*:ds4::severe (70%-99%) stenosis
:*:ds5::total occlusion

:C*:plad::pLAD
:C*:mlad::mLAD
:C*:dlad::dLAD
:C*:plcx::pLCX
:C*:mlcx::mLCX
:C*:dlcx::dLCX
:C*:prca::pRCA
:C*:mrca::mRCA
:C*:drca::dRCA

::ccta::
run,RadTemplate.exe ".\Procedure\ccta.txt",% a_scriptdir "\RadTemplate\"
return

;----------------------------------------------------------------------------------
;0 No detectable calcified plaque
;1-10 Minimal detectable calcified plaque
;11-100 Mild atherosclerotic plaque burden
;101-400 Moderate atherosclerotic plaque burden
;>400 Extensive atherosclerotic plaque burden

:*:cstem::
report=
(
Agatston calcium score:
- LM: 0
- LAD: 0
- LCX: 0
- RCA: 0
- Total: 0 (No detectable calcified plaque)

Other findings:
- No obvious abnormality in visible lung.
- Degenerative change of spine.
)
imp=
(
Calcium score: 0
)
setReportText(report, imp, getRisReports(RisState[2]))
return

::cals::
;~ sendbyclipboard("", 4)
WinGet, active_id, ID, A
InputBox, CCS,,Calcium score:,,200,120
;~ clipboard=%CCS%

Rank=Error

if (CCS = 0)
{
 Rank=No detectable calcified plaque
}
if (CCS >0)
{
 Rank=Minimal detectable calcified plaque
}
if (CCS >10)
{
 Rank=Mild atherosclerotic plaque burden
}
if (CCS >100)
{
 Rank=Moderate atherosclerotic plaque burden
}
if (CCS >400)
{
 Rank=Extensive atherosclerotic plaque burden
}


WinActivate, ahk_id %active_id%
WinWaitActive,ahk_id %active_id%,,3
;~ SendPlay %CCS% (%Rank%)%A_EndChar%
if(Rank="error")
	return
sendbyclipboard(CCS " (" Rank ")")
return



:*:ld0::肺部：無異常。
:*:ld1::肺部：無異常。請詳閱影像報告。
:*:ld2::肺部：無顯著異常。請詳閱影像報告。
:*:ld3::肺部：有異常。請詳閱影像報告。
:*:ld4::肺部：明顯異常。請詳閱影像報告。
:*:ld5::肺部：疑似惡性腫瘤。請詳閱影像報告。


RisStateChange(){
    global RisState
    RisState:=risopened()
}



bodyCysts:
cysts_parts := $.value(1)
,str:="hypodense lesions in "
,parts:=[]
,parts_ref:={h: "liver", r: "kidney", s: "spleen", p: "pancreas"}
for k,v in ["h", "k", "s", "p"]
	if InStr(cysts_parts,v)
		parts.push(parts_ref[v])
for k,v in parts
	str.= v (k==parts.length()-1?" and ":", ")
str:=SubStr(str,1,-2) ", cysts are considered first."
send % "{bs " StrLen($.value(0))  "}"
send % str
$:=""
return

:*:epsct::
setReportText("Indication: this study is for CT image integration of electroanatomical mapping. `r`nFindings: `r`n" bullet,"This study is for CT image integration of electroanatomical mapping. ")
return



reportReplace(Text){
	Text:=RegExReplace(Text, "i)a (stable|stationary) *(\W)", "an unchanged$2")
	,Text:=RegExReplace(Text, "i)(stable|stationary) *(\W)", "unchanged$2")
	,Text:=RegExReplace(Text, "(\r?\n[ \t]*){2,}$", "`r`n`r`n")
	, Text:=RegExReplace(Text, "i)phayngeal", "phayrngeal")
	, Text:=RegExReplace(Text, "i)no enlarge ", "no enlarged ")
	, Text:=RegExReplace(Text, "LAPs?", "lymphadenopathy")
	, Text:=RegExReplace(Text, "i)\bsusp\.?\b", "suspicious")
	, Text:=RegExReplace(Text, "i)\bLt\.?\b", "left")
	, Text:=RegExReplace(Text, "i)\bRt\.?\b", "right")
	, Text:=RegExReplace(Text, "i)BI-RAD", "B_I_R_A_D")
	, Text:=RegExReplace(Text, "i)\bBil?\.?\b", "bilateral")
	, Text:=RegExReplace(Text, "B_I_R_A_D", "BI-RAD")
	return Text
}


:*:gtran::
send % "（本翻譯結果由Google Translate提供，請務必與專業醫師討論本報告內容）"
return



/*
dynamic_hotstring(
	trigger:
		A string or a regular expression to trigger the hotstring. (If you use a regex here, the mode should be 3 for the regex to work)

	label:
		A string to replace the trigger / A label to go to / A function to call when the hotstring is triggered.
		If you used a regular expression as the trigger and mode was set to three, backreferences like $0, $1 would work.
		If a function name was passed, the function will be called with the phrase that triggered the hotstring(If the trigger was a string)
			or the Match object(If the trigger was a regex & mode equals 3).
		If this parameter was a label, the global variable '$' will contain the string/match object.
		If you wish to remove a hotstring, Pass the trigger with this parameter empty.

	Mode:
		A number between 1 and 3 that determines the properties of the hotstring.
		If Mode == 1 then the hotstring is case insensitive.
		If Mode == 2 then the hostrings is case sensitive.
		If Mode == 3 then you can use regex in the trigger.

		1 is the defualt.

	clearTrigger:
			Determines if the trigger is erased after the hotstring is triggered.

	cond:
			A name of a function that allows the conditional trigerring of the hotstring.

)
*/
dynamic_hotstring(trigger, label, mode := 1, clearTrigger := 1, cond := "", forceBreak:=false){
	global $

	;symbols exclude ' \ for special use in this script
	static keysBound := false,hotkeyPrefix := "~$", dynamic_hotstrings := {}, typed := "", keys := {"symbols": "!""#$%&()*+,-.:;<=>?@[/]^_``{|}~", "num": "0123456789", "alpha":"abcdefghijklmnopqrstuvwxyz", "other": "BS,Return,Tab,Space", "breakKeys":"Left,Right,Up,Down,Home,End,RButton,LButton,LControl,RControl,AppsKey,LAlt,RAlt,Lwin,Rwin,WheelDown,WheelUp,f1,f2,f3,f4,f5,f6,f7,f8,f9,f6,f7,f9,f10,f11,f12", "numpad":"Numpad0,Numpad1,Numpad2,Numpad3,Numpad4,Numpad5,Numpad6,Numpad7,Numpad8,Numpad9,NumpadDot,NumpadDiv,NumpadMult,NumpadAdd,NumpadSub,NumpadEnter"}, effect := {"Return" : "`n", "Tab":A_Tab, "Space": A_Space, "Enter":"`n", "Dot": ".", "Div":"/", "Mult":"*", "Add":"+", "Sub":"-"}

	if(forceBreak){
		typed := ""
		return
	}

	if (!keysBound){
		;Binds the keys to watch for triggers.
		for k,v in ["symbols", "num", "alpha"]
		{
			;alphanumeric/symbols
			v := keys[v]
			Loop,Parse, v
				Hotkey,%hotkeyPrefix%%A_LoopField%,__dynamic_hotstring
		}

		v := keys.alpha
		Loop,Parse, v
			Hotkey, %hotkeyPrefix%+%A_Loopfield%,__dynamic_hotstring
		for k,v in ["other", "breakKeys", "numpad"]
		{
			;comma separated values
			v := keys[v]
			Loop,Parse, v,`,
				Hotkey,%hotkeyPrefix%%A_LoopField%,__dynamic_hotstring
		}
		keysBound := true ;keysBound is a static varible. Now, the keys won't be bound twice.
	}
	if (mode == "CALLBACK"){
		; Callback for the hotkey.s
		Hotkey := SubStr(A_ThisHotkey,3)
		if (StrLen(Hotkey) == 2 && Substr(Hotkey,1,1) == "+" && Instr(keys.alpha, Substr(Hotkey, 2,1))){
			Hotkey := Substr(Hotkey,2)
			if (!GetKeyState("Capslock", "T")){
				StringUpper, Hotkey,Hotkey
			}
		}

		shiftState := GetKeyState("Shift", "P")
		uppercase :=  GetKeyState("Capslock", "T") ? !shiftState : shiftState
		;If capslock is down, shift's function is reversed.(ie pressing shift and a key while capslock is on will provide the lowercase key)
		if (uppercase && Instr(keys.alpha, Hotkey)){
			StringUpper, Hotkey,Hotkey
		}
		if (Instr("," . keys.breakKeys . ",", "," . Hotkey . ",")){
			typed := ""
			return
		} else if Hotkey in Return,Tab,Space
		{
			typed .= effect[Hotkey]
		} else if (Hotkey == "BS"){
			; trim typed var if Backspace was pressed.
			StringTrimRight,typed,typed,1
			return
		} else if (RegExMatch(Hotkey, "Numpad(.+?)", numKey)) {
			if (numkey1 ~= "\d"){
				typed .= numkey1
			} else {
				typed .= effects[numKey1]
			}
		} else {
			typed .= Hotkey
		}
		matched := false
		;~ ToolTip % "." typed "."
		for k,v in dynamic_hotstrings
		{
			matchRegex := (v.mode == 1 ? "Oi)" : "")  . (v.mode == 3 ? RegExReplace(v.trigger, "\$$", "") : "\Q" . v.trigger . "\E") . "$"

			if (v.mode == 3){
				if (matchRegex ~= "^[^\s\)\(\\]+?\)"){
					matchRegex := "O" . matchRegex
				} else {
					matchRegex := "O)" . matchRegex
				}
			}
			if (RegExMatch(typed, matchRegex, local$)){
				matched := true
				if (v.cond != "" && IsFunc(v.cond)){
					; If dynamic_hotstring has a condition function.
					A_LoopCond := Func(v.cond)
					if (A_LoopCond.MinParams >= 1){
						; If the function has atleast 1 parameters.
						A_LoopRetVal := A_LoopCond.(v.mode == 3 ? local$ : local$.Value(0))
					} else {
						A_LoopRetVal := A_LoopCond.()
					}
					if (!A_LoopRetVal){
						; If the function returns a non-true value.
						matched := false
						continue
					}
				}
				if (v.clearTrigger){
					;Delete the trigger
					SendEvent % "{BS " . StrLen(local$.Value(0))  . "}"
					;~ focusedEditBs(StrLen(local$.Value(0)))
				}
				if (IsLabel(v.label)){
					$ := v.mode == 3 ? local$ : local$.Value(0)
					gosub, % v.label
				} else if (IsFunc(v.label)){
					callbackFunc := Func(v.label)
					if (callbackFunc.MinParams >= 1){
						callbackFunc.(v.mode == 3 ? local$ : local$.Value(0))
					} else {
						callbackFunc.()
					}
				} else {
					toSend := v.label

					;Working out the backreferences
					Loop, % local$.Count()
						StringReplace, toSend,toSend,% "$" . A_Index,% local$.Value(A_index),All
					toSend := RegExReplace(toSend,"([!#\+\^\{\}])","{$1}") ;Escape modifiers
					SendEvent,%toSend%
				}

			}
		}
		if (matched){
			typed := ""
		} else if (StrLen(typed) > 350){
			StringTrimLeft,typed,typed,200
		}
	} else {
		if (dynamic_hotstrings.HasKey(trigger) && label == ""){
			; Removing a dynamic_hotstring.
			dynamic_hotstrings.Delete(trigger)
		} else {
			; Add to dynamic_hotstrings object.
			dynamic_hotstrings[trigger] := {"trigger" : trigger, "label":label, "mode":mode, "clearTrigger" : clearTrigger, "cond": cond}
		}

	}
	return

	__dynamic_hotstring:
	; This label is triggered every time a key is pressed.
	dynamic_hotstring("", "", "CALLBACK")
	return
}





insertDate($){
	send % "{bs " StrLen($.value(0))  "}"
	s:=$.value(1)
	if ($.value(2))
		s:=substr(s,5,strlen(s)-4) substr(s,1,4)


	if strlen(s)=6
		if substr(s,1,2)<80
			s:="20" s
		else
			s:="19" s
	if (substr(s,5,2)>12 || substr(s,7,2)>31) {
		send % $.value(0)
		return
	}

	Sleep 50
	send % substr(s,1,4) $.value(3) substr(s,5,2) $.value(3) substr(s,7,2)
}

:*:im/::
if WinActive("simple RIS ahk_class AutoHotkeyGUI")
	txt:=RegExReplace(Edit_GetText(activeHwnd:=getFocusedHwnd()), "im\/?(\r?\n)", "$1")
	,txt:=RegExReplace(txt, "\s*(- \r?\n?)*\s*$", "")
	,Edit_SetText(activeHwnd, txt.="`r`n`r`nImpression:`r`n")
	,Edit_SetSel(activeHwnd, l:=StrLen(txt), l)
	,Edit_ScrollCaret(activeHwnd)
else{
	__str:="impression:`r`n"
	send % __str
}
return

::pm0::通報臨床醫師0
::pm1::通報臨床醫師1
::pm2::通報臨床醫師(急)
::pmtb::疑似肺結核

::dbs::placement of implantable electronic stimulation devices.
::mnf::minor or non-specific findings.

:*:mlss::spinal stenosis at multiple levels
:*:mlse::spinal stenosis at multiple levels, most evident at
::lsms::
quicksendFunc("lsms", "lumbar spondylosis. spinal stenosis at multiple levels. suggest clinical correlation.")
return
::csms::
quicksendFunc("lsms", "cervical spondylosis. spinal stenosis at multiple levels. suggest clinical correlation.")
return
::vcu::vacuum phenomenon

quicksendFunc(trigger, hotstring){
	global thishotkey, __win11__

	if (__win11__){
		focusedHwnd:=getFocusedHwnd()
		txt:=Edit_GetText(focusedHwnd)
		l:=strlen(trigger)
		txt:=substr(txt,1,-1*l)
		edit_setText(focusedHwnd, txt:=txt hotstring ".")
		;~ sendinput % hotstring

		sleep 300
		gosub quicksend
	}
	focusedHwnd:=getFocusedHwnd()
	,triggerRegex:=""
	,Edit_GetSel(focusedHwnd,s,e)
	loop,parse,trigger
		triggerRegex.=((A_LoopField~="\W")?"\":"") A_LoopField (A_Index=1?"":"?")
	RegExMatch(SubStr(t:=Edit_GetText(focusedHwnd), 1, e), "i)" triggerRegex "$", match)
	Edit_SetText(focusedHwnd, t:=SubStr(t,1,e-StrLen(match)) Hotstring SubStr(t,1+e))
	thishotkey:="F3"
	gosub quicksend
}


brainAging($){
	send % "{bs " strlen($.value(0)) "}"

	atrophyLevel:=$.value(1)
	,leuLevel:=$.value(2)
	,ending:=$.value(3)
	,str:=""

	switch atrophyLevel {
		case 1:
			str:="Mild brain atrophy with dilated sulci, fissures and ventricles. "
		case 2:
			str:="Brain atrophy with dilated sulci, fissures and ventricles. "
		case 3:
			str:="Prominent brain atrophy with dilated sulci, fissures and ventricles. "
	}
	str.="`r`n- "

	if InStr(getRisExamItemsAll()[1], "MR"){
		switch leuLevel {
			case 0:
				str.="Some hyperintensities over bilateral cerebral white matter on FLAIR, suggestive of minimal leukoaraiosis. "
			case 1:
				str.="Some hyperintensities over bilateral cerebral white matter on FLAIR, suggestive of mild leukoaraiosis. "
			case 2:
				str.="Multiple nonspecific hyperintensities over bilateral cerebral white matter on T2 FLAIR, suggestive of leukoaraiosis. "
			case 3:
				str.="Confluent nonspecific hyperintensities over bilateral cerebral white matter on T2 FLAIR, suggestive of extensive leukoaraiosis. "
		}
	}else{
		switch leuLevel {
			case 0:
				str.="Low densities at bilateral periventricular white matter, suggestive of minimal leukoaraiosis. "
			case 1:
				str.="Low densities at bilateral periventricular white matter, suggestive of mild leukoaraiosis. "
			case 2:
				str.="Low densities at bilateral periventricular white matter, suggestive of leukoaraiosis. "
			case 3:
				str.="Confluent low densities at bilateral periventricular white matter, suggestive of leukoaraiosis. "
		}
	}
	str.="`r`n- "

	send % str
}


:*:abus0::
t=
(
Ultrasongraphic examination of abdomen:

Liver: Homogeneous echopattern without focal lesions.
Intrahepatic Bile Duct: Negative.
Common Bile Duct: Negative.
Portal Vein: Negative.
Gall Bladder: No stone.
Pancreas: Negative.
Spleen: Negative.
Kidneys: No stone or hydronephrosis.

Impression:
No abnormal findings in the abdomen.
)
send % t
return

:*:cyss::
t=
(
Cystography shows:
- Moderate distention of urinary bladder with smooth contour.
- No evidence of urine leakage.
- Failed urination during the procedure.

Impression:
No significant radiological abnormality.
)
send % t
return
:*:vcugg::
t=
(
Voiding urethrocystography
- Well distended urinary bladder with smooth contour.
- No evidence of vesicoureteral reflux.
- No congenital anomalies or stricture of urethra.

Impression:
No evidence of vesicoureteral reflux.
)
send % t
return


:*:bct0::
t=
(
CT of the brain without contrast enhancement shows:
- normal appearance of sulci, fissures and ventricles. 
- no definite acute intracranial hemorrhage.
- normal appearance of the cranial vault and skull base. 

Impression:
no definite acute intracranial hemorrhage. 
)
send % t
thisHotkey:="F3"
gosub quicksend
return 


::outhos::I concur with the report generated by the radiologist at the medical facility where the patient underwent this diagnostic imaging study. The initial report is presented below:`n
::othhos::I concur with the report generated by the radiologist at the medical facility where the patient underwent this diagnostic imaging study. The initial report is presented below:`n
