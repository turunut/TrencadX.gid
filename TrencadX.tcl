#################################################
#      GiD-Tcl procedures invoked by GiD        #
#################################################

proc InitGIDProject { dir } {
    TrencadX::SetDir $dir ;#store to use it later
    TrencadX::ModifyMenus
    gid_groups_conds::open_conditions menu
    
    if { [info procs ReadProblemtypeXml] != "" } {
	#this procedure exists after GiD 11.1.2b
	set data [ReadProblemtypeXml [file join $dir TrencadX.xml] Infoproblemtype {Version MinimumGiDVersion}]                
    } else {
	#TrencadX::ReadProblemtypeXml is a copy of ReadProblemtypeXml to be able to work with previous GiD's
	set data [TrencadX::ReadProblemtypeXml [file join $dir TrencadX.xml] Infoproblemtype {Version MinimumGiDVersion}]
    }
    if { $data == "" } {
	WarnWinText [= "Configuration file %s not found" [file join $dir TrencadX.xml]]
	return 1
    }
    array set problemtype_local $data
    set TrencadX::VersionNumber $problemtype_local(Version)
    
    TrencadX::Splash 1
}

proc ChangedLanguage { language } {
    TrencadX::ModifyMenus ;#to customize again the menu re-created for the new language
}

proc AfterWriteCalcFileGIDProject { filename errorflag } {   
    if { ![info exists gid_groups_conds::doc] } {
	WarnWin [= "Error: data not OK"]
	return
    }    
    set err [catch { TrencadX::WriteCalculationFile $filename } ret]
    if { $err } {       
	WarnWin [= "Error when preparing data for analysis (%s)" $::errorInfo]
	set ret -cancel-
    }
    return $ret
}

namespace eval TrencadX {
    variable current_xml_root
    set current_xml_root ""    
    set com_dict [dict create]
    variable problemtype_dir
    set edges(Triangle)           {{0 1} {1 2} {2 0}}
    set edges(Quadrilateral)      {{0 1} {1 2} {2 3} {3 0}}
    set edges(Tetrahedra)         {{0 1} {1 2} {2 0} {0 3} {1 3} {2 3}}
    set edges(Hexahedra)          {{0 1} {1 2} {2 3} {3 0} {4 5} {5 6} {6 7} {7 4} {0 4} {1 5} {2 6} {3 7}}
    set edges(HexahedraQuadratic) {{8}   {9}   {10}  {11}  {16}  {17}  {18}  {19}  {12}  {13}  {14}  {15}}
    set edges(Prism)              {{0 1} {1 2} {2 0} {3 4} {4 5} {5 3} {0 3} {1 4} {2 5}}
    set edges(Pyramid)            {{0 1} {1 2} {2 3} {3 0} {0 4} {1 4} {2 4} {3 4}}
		            
    set dofs2D_lista [dict create truss       {0 1         } \
		                          beam        {0 1   3     } \
		                          planestress {0 1         } \
		                          planestrain {0 1         } \
		                          shell       {0 1 2 3 4   } \
		                          solid       {0 1 2       } ]
		            
    set dofs3D_lista [dict create truss       {0 1   3     } \
		                          beam        {0 1 2 3 4 5 } \
		                          planestress {0 1         } \
		                          planestrain {0 1         } \
		                          shell       {0 1 2 3 4 5 } \
		                          solid       {0 1 2       } ]
    
    set NumElemNode [dict create Pyramid       {5 13 13} \
		                         Prism         {6 15 18} \
		                         Hexahedra     {8 20 27} \
		                         Tetrahedra    {4 10 10} \
		                         Quadrilateral {4  8  9} \
		                         Triangle      {3  6  6} \
		                         Line          {2  3  3} ]
    
    set allProps [list e11 e22 e33 g12 g13 g23 n12 n13 n23 c11 c12 c13 c14 c15 c16 c22 c23 c24 c25 c26 c33 c34 c35 c36 c44 c45 c46 c55 c56 c66]
    set ctsProps [dict create isotrop   {e11 n12} \
		              orthotrop {e11 e22 e33 g12 g13 g23 n12 n13 n23} \
		              anisotrop {c11 c12 c13 c14 c15 c16 c22 c23 c24 c25 c26 c33 c34 c35 c36 c44 c45 c46 c55 c56 c66} ]
}

#################################################
#      namespace implementing procedures        #
#################################################

proc TrencadX::SetDir { dir } {  
    variable problemtype_dir
    set problemtype_dir $dir
}

proc TrencadX::GetDir { } {  
    variable problemtype_dir
    return $problemtype_dir
}

proc TrencadX::Splash { {self_close 1} } {    
    variable problemtype_dir
    variable VersionNumber
    #set text "Version $VersionNumber"
    #GidUtils::Splash [file join $problemtype_dir images Web_png_COLOR.gif] .splash $self_close [list $text 6 116]   
}

proc TrencadX::About { } {
    set self_close 0
    #TrencadX::Splash $self_close
} 

proc TrencadX::ModifyMenus { } {   
    if { [GidUtils::IsTkDisabled] } {  
	return
    }          
    foreach menu_name {Conditions Interval "Interval Data" "Local axes"} {
	GidChangeDataLabel $menu_name ""
    }       
    GidAddUserDataOptions --- 1    
    GidAddUserDataOptions [= "TrencadX menu"] [list gid_groups_conds::open_conditions menu] 2
    GidAddUserDataOptions [= "Mesh Hexaedra"] [list TrencadX::NormalHexaedraMeshGeneration] 3
    GidAddUserDataOptions [= "Mesh Tetrahedra"] [list TrencadX::NormalTetrahedraMeshGeneration] 4
    GidAddUserDataOptions [= "Mesh Triangle"] [list TrencadX::NormalTriangleMeshGeneration] 5
    GiDMenu::UpdateMenus
}

######################################################################
# example procedures asking GiD_Info and doing things with GiD_Process
proc TrencadX::CreateWindow { } {  
    if { [GidUtils::AreWindowsDisabled] } {
	return
    }
    set w .gid.win_example
    InitWindow $w [= "PROBLEM TYPE TrencadX"] ExampleCMAS "" "" 1
    if { ![winfo exists $w] } return ;# windows disabled || usemorewindows == 0
    ttk::frame $w.top
    ttk::label $w.top.title_text -text [= "  Version 1.0 Fall 2018"]   
    ttk::frame $w.information -relief ridge   
    ttk::label $w.information.help   -text [= "   Bugs errores y demas -> fturon@cimne.upc.edu"] 
    ttk::frame $w.bottom
    ttk::button $w.bottom.start -text [= "Continue"] -command [list destroy $w]
    grid $w.top.title_text -sticky ew
    grid $w.top -sticky new   
    grid $w.information.help -sticky w -padx 6 -pady 6
    grid $w.information -sticky nsew    
    grid $w.bottom.start -padx 6
    grid $w.bottom -sticky sew -padx 6 -pady 6
    if { $::tcl_version >= 8.5 } { grid anchor $w.bottom center }
    grid rowconfigure $w 1 -weight 1
    grid columnconfigure $w 0 -weight 1    
}

proc TrencadX::NormalHexaedraMeshGeneration {} {
    GiD_Process Mescape Meshing ElemType Quadrilateral 1:all escape
    GiD_Process Mescape Meshing ElemType Hexaedra 1:all escape
    GiD_Process Mescape Meshing Structured Volumes Size 1:all escape
    GiD_Process 1:all escape escape
}

proc TrencadX::NormalTetrahedraMeshGeneration {} {
    GiD_Process Mescape Meshing ElemType Triangle 1:all escape
    GiD_Process Mescape Meshing ElemType Tetrahedra 1:all escape
}

proc TrencadX::NormalTriangleMeshGeneration {} {
    GiD_Process Mescape Meshing ElemType Triangle 1:all escape
    GiD_Process Mescape Meshing Structured Surfaces Size 1:all escape
    GiD_Process 1:all escape escape
}
###################################################################################################
########## Procedimeintos para imprimir informacion de las condiciones                   ##########
###################################################################################################

proc TrencadX::GetBlocksList { domNode args containerName } {    
    set x_path {//container[@n=$containerName]}
    set dom_materials [$domNode selectNodes $x_path]
    if { $dom_materials == "" } {
	error [= "xpath '%s' not found in the spd file" $x_path]
    }
    set image $containerName
    set result [list]
    foreach dom_material [$dom_materials selectNodes blockdata] {
	set name [$dom_material @name] 
	lappend result [list 0 $name $name $image 1]
    }
    return [join $result ,]
}

proc TrencadX::GetModelType { domNode args model } {
    set dimen [ TrencadX::GetNodeValue {/TrencadX_customlib_data/value[@n='dimension']} ]
    if { $dimen == "2D" } {
	return truss,beam,shell,planestress,planestrain
    } elseif { $dimen == "3D" } {
	return shell,solid
    }
}

proc TrencadX::GetBounElem { domNode args } {
    set model [ TrencadX::GetNodeValue {/TrencadX_customlib_data/value[@n='model']} ]
    if { $model eq "truss" || $model eq "beam"} {
	return 
    } elseif { $model == "planestress" || $model == "planestrain" || $model == "shell" } {
	return line
    } elseif { $model == "solid" } {
	return surface
    } 
}

proc TrencadX::GetBodyElem { domNode args } {
    set model [ TrencadX::GetNodeValue {/TrencadX_customlib_data/value[@n='model']} ]
    if { $model eq "truss" || $model eq "beam"} {
	return line
    } elseif { $model == "planestress" || $model == "planestrain" || $model == "shell" } {
	return surface
    } elseif { $model == "solid" } {
	return volume
    } 
}

proc TrencadX::HideConditionModel { domNode args } {
    set model [ TrencadX::GetNodeValue {/TrencadX_customlib_data/value[@n='model']} ]
    set prope [get_domnode_attribute $domNode n]
    
    # width
    if { $prope eq "width" } {
	if { $model eq "truss" || $model eq "beam" } { return normal }
	return hidden
    }
    # thickness
    if { $model ne "solid" } { return normal }
    
    return hidden
}

proc TrencadX::CheckDOFs { domNode args } {
    set model [ TrencadX::GetNodeValue {/TrencadX_customlib_data/value[@n='model']} ]
    set dimen [ TrencadX::GetNodeValue {/TrencadX_customlib_data/value[@n='dimension']} ]
    if { $dimen eq "2D" } { set dimen 0 } 
    elseif { $dimen eq "3D" } { set dimen 1 }
    
    set dofs [dict create truss       {2 3} \
		          beam        {3 6} \
		          planestress {2 2} \
		          planestrain {2 2} \
		          shell       {5 6} \
		          solid       {3 3} ]
    
    set nums [lindex [dict get $dofs $model] $dimen]
    
    set value [get_domnode_attribute $domNode v]
    set count [llength [regexp -all -inline {\S+} $value]]
    
    if { $nums ne $count} {
	WarnWin [= "Incorrent number of DOFs should be $nums"]
	return -cancel-
    }
}

proc TrencadX::FilterDOFs { domNode args } {
    variable dofs2D_lista
    variable dofs3D_lista
    set model [ TrencadX::GetNodeValue {/TrencadX_customlib_data/value[@n='model']} ]
    set dimen [ TrencadX::GetNodeValue {/TrencadX_customlib_data/value[@n='dimension']} ]

    set dof [get_domnode_attribute $domNode n]
    #if { [string range $dof 0 end-1] eq "flg" } { 
    #    regsub {^flg} $dof dof result
    #    set dof $result
    #}
    set last [string index $dof end]
    set lastNum [expr {$last + 0}]
	
    if { $dimen eq "2D" } { 
	set diccDOFs $dofs2D_lista 
    } elseif { $dimen eq "3D" } { 
	set diccDOFs $dofs3D_lista 
    }

    set dofs_model [dict get $diccDOFs $model]
    
    if { [lsearch -exact $dofs_model $lastNum] >= 0 } { return normal }

    return hidden
}

###################################################################################################
########## Procedimeintos para imprimir informacion de las bases de datos XML            ##########
###################################################################################################

proc TrencadX::WriteNodeValue { xpath } {
    set document [$::gid_groups_conds::doc documentElement]
    set xml_node [$document selectNodes $xpath]
    if {  [llength $xml_node] == 1 } {
	set value [get_domnode_attribute $xml_node v]
	TrencadX::WriteString $value
    }
}

proc TrencadX::GetNodeValue { xpath } {
    set document [$::gid_groups_conds::doc documentElement]
    set xml_node [$document selectNodes $xpath]
    if {  [llength $xml_node] == 1 } {
	set value [get_domnode_attribute $xml_node v]
    }
    return $value
}

proc TrencadX::WriteDatabaseSimple { xpath } {
    set document [$::gid_groups_conds::doc documentElement]
    set blocks [$document selectNodes $xpath]
    if {$blocks eq ""} {error [= "No blocks found"]}
    foreach block $blocks {
	set block_name [$block @name]
	regsub -all { } $block_name "" block_name
	GiD_WriteCalculationFile puts $block_name
	set dict_nodes [dict create]
	foreach node [$block selectNodes value] {
	    set value [get_domnode_attribute $node v]
	    regsub -all { } $value "" value
	    dict set dict_nodes [$node @n] $value
	}
	dict set dict_blocks $block_name $dict_nodes
	GiD_WriteCalculationFile puts $dict_nodes
    }
}

###################################################################################################
########## Procedimientos sagrados. NO TOCAR!!!                                          ##########
###################################################################################################

proc TrencadX::InitWriteFile {filename} {
    GiD_WriteCalculationFile init $filename ;#initialize writting
    set root [$::gid_groups_conds::doc documentElement] ;#xml document to get some tree data
    TrencadX::SetBaseRoot $root
}

proc TrencadX::EndWriteFile { } {
    GiD_WriteCalculationFile end
}

proc TrencadX::WriteString { str } {
    GiD_WriteCalculationFile puts $str
}

proc TrencadX::SetBaseRoot {root} {
    variable current_xml_root
    set current_xml_root $root
}

proc TrencadX::CopyName { xpath } {
    set document [$::gid_groups_conds::doc documentElement]
    set xml_node [$document selectNodes $xpath]
    foreach blockmaterial $xml_node {
	set value [get_domnode_attribute $blockmaterial name]
	foreach nameNode [$blockmaterial selectNodes value] {
	    $nameNode setAttribute v $value
	}
    }
}

###################################################################################################
########## Aqui se define la impresion usando los procedimientos antes definidos         ##########
###################################################################################################
#print data in the .dat calculation file (instead of a classic .bas template)
proc TrencadX::WriteCalculationFile { filename } {
    
    TrencadX::InitWriteFile $filename    
    
    TrencadX::EndWriteFile ;
    
}

proc TrencadX::InitWriteFile {filename} { 
    
    set len [string length $filename]
    
    set counter 0
    while {[string index $filename [expr $len - $counter]]!="/"} {
	incr counter 1
    }
    
    set directoryName [ string range $filename 0 [expr $len - $counter ] ]
    set problemName [ string range $filename [expr $len - $counter + 1 ] [expr $len - 5] ] 
    
    file mkdir "${directoryName}data"
    
    set root [$::gid_groups_conds::doc documentElement] ;#xml document to get some tree data
    TrencadX::SetBaseRoot $root
    
    set filenameData "${directoryName}data/${problemName}.dat"
    GiD_WriteCalculationFile init $filenameData
    TrencadX::WriteData $filenameData
    GiD_WriteCalculationFile end
    
    set filenameMat "${directoryName}data/${problemName}.mat"
    GiD_WriteCalculationFile init $filenameMat
    TrencadX::WriteMaterials $filenameMat
    GiD_WriteCalculationFile end
    
    set filenameMatSets "${directoryName}data/${problemName}.set"
    GiD_WriteCalculationFile init $filenameMatSets
    TrencadX::WriteSets $filenameMatSets "materials"
    GiD_WriteCalculationFile end
    
    set filenameBC "${directoryName}data/${problemName}.fix"
    GiD_WriteCalculationFile init $filenameBC
    TrencadX::WriteBCs $filenameBC
    GiD_WriteCalculationFile end
    
    set filenameMesh "${directoryName}data/${problemName}.msh"
    GiD_Process Mescape Files WriteMesh $filenameMesh
	
}

proc TrencadX::EndWriteFile { } {
    GiD_WriteCalculationFile end
}

proc TrencadX::WriteString { str } {
    GiD_WriteCalculationFile puts $str
}

proc TrencadX::SetBaseRoot {root} {
    variable current_xml_root
    set current_xml_root $root
}

proc TrencadX::WriteData { filename } {
    
    set document [$::gid_groups_conds::doc documentElement]

    #TrencadX::WriteNodeValue {/TrencadX_customlib_data/value[@n='kind']}
    set kind [ TrencadX::GetNodeValue {/TrencadX_customlib_data/value[@n='kind']} ]
    set model [ TrencadX::GetNodeValue {/TrencadX_customlib_data/value[@n='model']} ]
    
	GiD_WriteCalculationFile puts "type $kind"
	GiD_WriteCalculationFile puts "model $model"
	GiD_WriteCalculationFile puts ""

	GiD_WriteCalculationFile puts "problem_definition"

    if { $kind eq "analysis" } {
	set xpath {/TrencadX_customlib_data/container[@n='stagesAnly']/blockdata[@n='stage']}

	set stages [$document selectNodes $xpath]
	if {$stages eq ""} {error [= "No stages found"]}

	foreach stage $stages {
	    
		GiD_WriteCalculationFile puts "  begin_stage"

	    foreach substage [$stage selectNodes blockdata] {
		
		    GiD_WriteCalculationFile puts "    begin_substage"

		    GiD_WriteCalculationFile puts "      load_increment: [[$substage selectNodes {./value[@n="loadIncrement"]}] @v]"
		    GiD_WriteCalculationFile puts "      steps: [[$substage selectNodes {./value[@n="steps"]}] @v]"
		    GiD_WriteCalculationFile puts "      tolerance: [[$substage selectNodes {./value[@n="tolerance"]}] @v]"

		    GiD_WriteCalculationFile puts "    end_substage"

	    }
	    
		GiD_WriteCalculationFile puts "  end_stage"

	}
	
    } elseif { $kind eq "homogenization" } {
	set xpath {/TrencadX_customlib_data/container[@n='stagesHomo']}
    }

	GiD_WriteCalculationFile puts "end_problem_definition"
    
}

proc TrencadX::WriteSets { filename blockName } {
    
    set address "zones"
    
    set document [$::gid_groups_conds::doc documentElement]
    
    TrencadX::WriteString "mat_definition"
    
    set ID 1
    foreach gNode [$document selectNodes {//condition[@n=$address]/group}] {
    #    set condition_formats ""
    #
    #    set model_node [$gNode selectNodes {./value[@n="model_type"]}]
    #    set model_type [$model_node @v]
    #
    #    set modelFlag [dict get $modelTypeDict $model_type]
    #
    #    set n [$gNode @n]
    #    dict set condition_formats $n "%d $modelFlag $ID \n"
    #    GiD_WriteCalculationFile elements $condition_formats
    #    incr ID 1
	set condition_formats ""
	set n [$gNode @n]
	dict set condition_formats $n "%d $ID \n"
	GiD_WriteCalculationFile elements -unique -sorted $condition_formats
	incr ID 1
    }
    
    TrencadX::WriteString "mat_end"
    
    TrencadX::WriteString "mod_definition"

    # Loop over all elements
    set all_elements [GiD_Info Mesh MaxNumElements]
    set limit [expr {$all_elements + 1}]
    foreach i [range 1 $limit] {
	GiD_WriteCalculationFile puts "$i 1"
    }
    
    TrencadX::WriteString "mod_end"
    
}

proc TrencadX::WriteBoundaryEntities { filename blockName } {
    
    set address "zones_${blockName}"
    
    set document [$::gid_groups_conds::doc documentElement]

    TrencadX::WriteString "set_definition"
    
    set ID 1
    foreach gNode [$document selectNodes {//condition[@n=$address]/group}] {
    
    set condition_name "frameData"
    set condition_formats []
    set formats [customlib::GetElementsFormats $condition_name $condition_formats]
    set number_of_elements [GiD_WriteCalculationFile elements -count -elemtype Linear $formats]
    customlib::WriteConnectivities $condition_name $formats "" activ
    
    }
    
}

proc TrencadX::WriteBCs { filename } {
    
    set document [$::gid_groups_conds::doc documentElement]
    

    set address "dirichlet"
    
    TrencadX::WriteString "dirichlet"

    TrencadX::PrintCondition $document $address
    
    TrencadX::WriteString "end_dirichlet"
    
    
    set address "nodalLD"
    
    TrencadX::WriteString "on_node"

    TrencadX::PrintCondition $document $address
    
    TrencadX::WriteString "end_on_node"
    

    set address "boundaryLD"
    
    TrencadX::WriteString "on_boundary"

    TrencadX::PrintConditionFaces $document $address
    
    TrencadX::WriteString "end_on_boundary"
    

    set address "bodyLD"
    
    TrencadX::WriteString "on_body"

    TrencadX::PrintConditionElements $document $address
    
    TrencadX::WriteString "end_on_body"
    
}

proc TrencadX::WriteMaterials { filename } {
    variable ctsProps
    
    #set document [$::gid_groups_conds::doc documentElement]

    #TrencadX::WriteDatabaseSimple {/TrencadX_customlib_data/container[@n='materials']/blockdata[@n='material']}

    set document [$::gid_groups_conds::doc documentElement]

    set xpath {/TrencadX_customlib_data/container[@n='materials']/blockdata[@n='material']}

	GiD_WriteCalculationFile puts "begin_materials_list"

    set blocks [$document selectNodes $xpath]
    if {$blocks eq ""} {error [= "No blocks found"]}
    
    foreach block $blocks {
	    set block_name [$block @name]

	    GiD_WriteCalculationFile puts "  begin_material"
	
	    #set material [$block selectNodes {./value[@n="type"]}]
	    #set flg_type [get_domnode_attribute [$block selectNodes {./value[@n="type"]}] v]
	    
	    #set material [$block selectNodes {./value[@n="type"]}]
	    set flg_type [[$block selectNodes {./value[@n="type"]}] @v]
	    
	    GiD_WriteCalculationFile puts "    type: $flg_type" 
	    
	    set flg_cttype [[$block selectNodes {./value[@n="cttype"]}] @v]
    
	    set current_props [dict get $ctsProps $flg_cttype]
	    
	    GiD_WriteCalculationFile puts "    ct: $flg_cttype"
	
	foreach prop $current_props {
	    GiD_WriteCalculationFile puts "      $prop--: [[$block selectNodes {./value[@n=$prop]}] @v]"
	}
	    GiD_WriteCalculationFile puts "    end_ct"
	    
	    GiD_WriteCalculationFile puts "  end_material"

    }

	GiD_WriteCalculationFile puts "end_materials_list"
    
}

proc TrencadX::WriteModels { filename } {
    
    set document [$::gid_groups_conds::doc documentElement]

    set xpath {/TrencadX_customlib_data/container[@n='models']/blockdata[@n='model']}

	GiD_WriteCalculationFile puts "begin_models_list"

    set blocks [$document selectNodes $xpath]
    if {$blocks eq ""} {error [= "No blocks found"]}
    
    foreach block $blocks {
	    set block_name [$block @name]

	    GiD_WriteCalculationFile puts "  begin_model"
	
	    set flg_type [[$block selectNodes {./value[@n="modelType"]}] @v]
	    
	    GiD_WriteCalculationFile puts "    type: $flg_type"
	
	    if { $flg_type eq "planestress" } {
		GiD_WriteCalculationFile puts "    thickness: [[$block selectNodes {./value[@n="thickness"]}] @v]"
	} elseif { $flg_type eq "truss" } {
	    GiD_WriteCalculationFile puts "    thickness: [[$block selectNodes {./value[@n="thickness"]}] @v]"
	    GiD_WriteCalculationFile puts "    width: [[$block selectNodes {./value[@n="width"]}] @v]"
	} 
	    
	    GiD_WriteCalculationFile puts "  end_model"

    }

	GiD_WriteCalculationFile puts "end_models_list"
    
}

proc TrencadX::GetListDOFValues { gNode flg } {
    variable dofs2D_lista
    variable dofs3D_lista
    set model [ TrencadX::GetNodeValue {/TrencadX_customlib_data/value[@n='model']} ]
    set dimen [ TrencadX::GetNodeValue {/TrencadX_customlib_data/value[@n='dimension']} ]
	
    if { $dimen eq "2D" } { 
	set diccDOFs $dofs2D_lista 
    } elseif { $dimen eq "3D" } { 
	set diccDOFs $dofs3D_lista 
    }

    set dofs_model [dict get $diccDOFs $model]
	
    set vals [list]
    set dofs [list 0 1 2 3 4 5]
    foreach dof $dofs {
	    if { [lsearch -exact $dofs_model $dof] >= 0 } {
	    set word "${flg}${dof}"
	    set dof_node [$gNode selectNodes {./value[@n=$word]}]
		    set dof_value [$dof_node @v]
		lappend vals $dof_value
	    }
    }
    return $vals
}

proc TrencadX::PrintCondition { document address } {

    foreach gNode [$document selectNodes {//condition[@n=$address]/group}] {
	set condition_formats ""
	set n [$gNode @n]
	set flgs [TrencadX::GetListDOFValues $gNode "flg"]
	set vals [TrencadX::GetListDOFValues $gNode "dof"]
	    
	dict set condition_formats $n "%d $flgs $vals \n"
	GiD_WriteCalculationFile nodes -sorted -unique $condition_formats
    }

}

proc TrencadX::PrintConditionElements { document address } {

    foreach gNode [$document selectNodes {//condition[@n=$address]/group}] {
	set condition_formats ""
	set n [$gNode @n]
	set vals [TrencadX::GetListDOFValues $gNode]
	    
	dict set condition_formats $n "%d $vals \n"
	GiD_WriteCalculationFile elements $condition_formats
    }

}

proc TrencadX::PrintConditionFaces { document address } {
    variable NumElemNodes
    
    set quadIndex [GiD_Info Project Quadratic]

    foreach gNode [$document selectNodes {//condition[@n=$address]/group}] {
	set condition_formats ""
	
	set n [$gNode @n]
	set vals [TrencadX::GetListDOFValues $gNode]

	# Linear|Triangle|Quadrilateral|Tetrahedra|Hexahedra|Prism|Point|Pyramid|Sphere|Circle
    
	dict set condition_formats $n "%d %d %d %d %d\n"
	GiD_WriteCalculationFile elements -elemtype Quadrilateral -elements_faces faces -unique -sorted -print_faces_conecs $condition_formats
    
	dict set condition_formats $n "%d %d %d %d\n"
	GiD_WriteCalculationFile elements -elemtype Triangle -elements_faces faces -unique -sorted -print_faces_conecs $condition_formats
    
	dict set condition_formats $n "%d %d %d\n"
	GiD_WriteCalculationFile elements -elemtype Line -elements_faces faces -unique -sorted -print_faces_conecs $condition_formats
    
    }

}

proc GiD_Event_AfterRunCalculation { basename dir problemtypedir where error errorfilename } {
    
    set dimen [ TrencadX::GetNodeValue {/TrencadX_customlib_data/value[@n='dimension']} ]
    
    if {$dimen eq "2D"} {
    
	set filenameMesh "${dir}/data/${basename}.msh"
    
	set data [GidUtils::ReadFile $filenameMesh]

	GiD_WriteCalculationFile init $filenameMesh

	set data [string map {{dimension 3} {dimension 2}} $data]

	GiD_WriteCalculationFile puts $data

	GiD_WriteCalculationFile end
    
    }

}

proc TrencadX::PrintConditionEdges { kind } {
    set meshType [GiD_Info Project Quadratic]
    set document [$::gid_groups_conds::doc documentElement]
    variable edges
	foreach gNode [$document selectNodes {//container[@n="loadsMEC3D"]/condition[@n="Lines_NF"]/group}] {
	    set condition_formats ""
	    set n [$gNode @n]
	    set value_node [$gNode selectNodes {./value[@n="valueX"]}]
	    set valueX [$value_node @v]
	    regsub -all { } $valueX "" valueX
	    set value_node [$gNode selectNodes {./value[@n="valueY"]}]
	    set valueY [$value_node @v]
	    regsub -all { } $valueY "" valueY
	    set value_node [$gNode selectNodes {./value[@n="valueZ"]}]
	    set valueZ [$value_node @v]
	    regsub -all { } $valueZ "" valueZ
	    dict set condition_formats $n "%d \n"
	    PLCd::WriteString "####################FLAGnewLines_NF########################"
	    PLCd::WriteString "$valueX $valueY $valueZ"
	    set group_nodes_sorted [lsort -integer [GiD_EntitiesGroups get $n nodes]]
	    foreach element_type {Tetrahedra Hexahedra Prism Pyramid} {
		    set element_num_edges [PLCd::GetElementNumEdges $element_type]
		    foreach item [GiD_Info Mesh Elements $element_type -sublist] {
		        set element_id [lindex $item 0]
		        set element_nodes [lrange $item 1 end-1]
		        for {set i_edge 0} {$i_edge<$element_num_edges} {incr i_edge} {
		            set edge_nodes [PLCd::GetEdgeNodes $element_type $element_nodes $i_edge]
		            set edge_match true
		            foreach edge_node_id $edge_nodes {
		                if { [lsearch -sorted -integer $group_nodes_sorted $edge_node_id] == -1 } {
		                    set edge_match false
		                    break
		                }
		            }
		            if { $edge_match } {
		                if { $meshType == 0 } {
		                    PLCd::WriteString "$element_id $edge_nodes"
		                } else {
		                    PLCd::WriteString "$element_id $edge_nodes [lindex $element_nodes [lindex $edges(HexahedraQuadratic) $i_edge]]"
		                }
		            }
		        }
		    }
	    }
	}
}

proc TrencadX::NormalSolidOnly { document address } {
    set model [ TrencadX::GetNodeValue {/TrencadX_customlib_data/value[@n='model']} ]
    if {$model eq "solid"} {
	return normal
    }
    return hidden
}

proc TrencadX::ShowHideVarsCTs { donNode args } {
    variable allProps
    variable ctsProps
    
    set cttype [$donNode @v]
    set matNode [$donNode parentNode]
    
    set current_props [dict get $ctsProps $cttype]
    
    foreach prop $allProps {
    set node [$matNode selectNodes {./value[@n=$prop]}]
    #set value [[$matNode selectNodes {./value[@n=$prop]}] @v]
    if {[lsearch -exact $current_props $prop] >= 0} {
    $node setAttribute state normal
    } else {
    $node setAttribute state hidden
    }
    }
    return
}

proc TrencadX::returnState { donNode args } {
    variable allProps
    variable ctsProps
    
    set n [$donNode @n]
    
    set matNode [$donNode parentNode]
    set node_cttype [$matNode selectNodes {./value[@n="cttype"]}]
    
    set cttype [$node_cttype @v]
    
    set current_props [dict get $ctsProps $cttype]
    if {[lsearch -exact $current_props $n] >= 0} {
    return normal
    } else {
    return hidden
    }
}