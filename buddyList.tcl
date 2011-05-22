#
# Dependancies (standard packages)
#
package require tdom

namespace eval purple::buddyList {
	variable INIT 0
	variable CONTACT_LIST
}

#
# Public procedures
# ===================================================================================

proc purple::buddyList::init {} {
	variable INIT
	variable CONTACT_LIST
	variable SETTINGS

	if {$INIT} {
		return 1
	}

	set CONTACT_LIST(total_count)    0
	set CONTACT_LIST(total_accounts) 0
	set CONTACT_LIST(accounts_list)  [list]
	set SETTINGS(idx)                0

	set INIT 1
}


proc purple::buddyList::getTotalContacts {} {
	variable CONTACT_LIST

	return $CONTACT_LIST(total_count)
}

proc purple::buddyList::getTotalAccoutnts {} {
	variable CONTACT_LIST

	return $CONTACT_LIST(total_accounts)
}

proc purple::buddyList::getAvailAccounts {} {
	variable CONTACT_LIST

	return $CONTACT_LIST(accounts_list)
}


#
# Add a new setting to a given level
#
# _parentID - ID of the parent level
# _level    - Parent level
# _name     - Name of the setting
# _tupe     - Data type of the setting
#
# return    - New Index
#
proc purple::buddyList::addSetting {
	_parentID \
	_level \
	_name \
	_type \
} {
	variable SETTINGS

	set idx [incr SETTINGS(idx)]

	lappend SETTINGS($_level,idxs)         $idx
	set SETTINGS($_level,$idx,names)       $_name
	set SETTINGS($_level,$idx,$_name)      $_value
	set SETTINGS($_level,$idx,$_name,type) $_type

	return $idx
}

proc purple::buddyList::parseContactList {} {

	set fp ""

	if {[catch {
		# Read in the buddy list
		set fp [open "~/.purple/blist.xml" r]
		set fileData [read $fp]
		close $fp
	} errMsg]} {
		_log "Unable to process buddlist: \n $errMsg"
		return [list 0 $errMsg]
	}

	set doc [dom parse -simple $fileData]

	set groups [$doc getElementsByTagName "group"]

	for {set i 0} {$i < [llength $groups]} {incr i} {
		set currGroup [lindex $groups $i]

		_parseSettings $i $currGroup "gp"

		set groupName [$currGroup getAttribute name]

		# Parse all group contacts
		set contacts  [$currGroup getElementsByTagName "contact"]

		for {set j 0} {$j < [llength $contacts]} {incr j} {
			set currContact [lindex $contacts $j]
			set buddyNode   [$currContact getElementsByTagName buddy]
			_parseContact $j $groupName $buddyNode
		}

		set chats [$currGroup getElementsByTagName "chat"]

		for {set j 0} {$j < [llength $chats]} {incr j} {
			set currChat [lindex $chats $j]
			_parseChat $j $currChat $groupName
		}
	}

}

#
# Private procedures
# ===================================================================================


proc purple::buddyList::_parseContact {_id _groupName _buddy} {
	variable CONTACT_LIST
	variable SETTINGS

	set account [$_buddy getAttribute account]
	set proto   [$_buddy getAttribute proto]

	set conName [_nodeValue [$_buddy getElementsByTagName name]]
	set conAlias [_nodeValue [$_buddy getElementsByTagName alias]]

	set CONTACT_LIST($_groupName,$_id,account) $account
	set CONTACT_LIST($_groupName,$_id,proto) $proto
	set CONTACT_LIST($_groupName,$_id,name ) $name
	set CONTACT_LIST($_groupName,$_id,alias) $alias
	lappend CONTACT_LIST($_groupName,indices) $_id

	if {[lsearch $CONTACT_LIST(accounts_list) $proto] == -1} {
		lappend CONTACT_LIST(accounts_list) $proto
		set CONTACT_LIST($proto,groups) [list]
		incr CONTACT_LIST(total_accounts)
	}

	if {[lsearch $CONTACT_LIST($proto,groups) $_groupName] == -1} {
		lappend CONTACT_LIST($proto,groups) $_groupName
	}

	_parseSettings $_id $_buddy "cnt"

	incr CONTACT_LIST(total_count)
}

proc purple::buddyList::_parseChat {_id _chat _groupName} {
	variable CHAT_LIST

	set _currLevel "cht"

	set proto   [$_chat getAttribute proto]
	set account [$_chat getAttribute account]

	_parseSettings $_id $_chat $_currLevel

}

proc purple::buddyList::_parseComps {_id _node {_level bd}} {
	set comps [$_node getElementsByTagname "component"]

	for {set i 0} {$i < [llength $comps]} {incr i} {
		set currComp [lindex $comps $i]
		_parseComp $_id $currComp $_currLevel
	}

}

#
# Parse a component
#
# _id     - ID of the current component
# _comp   - Comp node to parse
# _level  - Parent level
#
# reurn - N/A
#
proc purple::buddyList::_parseComp {_id _comp {_level bd}} {
	variable COMPONENTS

	set compName  [$currComp getAttribute name]
	set compValue [_nodeValue $currComp]

	set COMPONENTS($id,$level,$compName) $compValue
	lappend COMPONETS($id,$level,comps) $compName

}

#
# Parses the any settings and stores them against the level
#
# _parentId - The ID of the parent level
# _settings - The seeting XML node to process
# _level    - The level being processed
#           + bd  [Buddy]
#           + gp  [Group]
#           + cnt [Contact]
#
# return    - List of new settings Indexs
#
proc purple::buddyList::_parseSettings {_parentId _node {_level bd}} {
	set settings [$_node getElementsByTagName "settings"]

	set newIdxs [list]

	for {set i 0} {$i < [llength $settings]} {incr i} {
		set currSetting [lindex $settings $i]
		lappend newIdxs [_parseSetting $_parentId $currSetting $_level]
	}

	return $newIdxs
}

#
# Parse a setting node
#
# _parentId  - The parent level ID
# _setting   - The new setting node
# _level     - Parent level
#
# reurn      - Index of new settings
#
proc purple::buddyList::_parseSetting {_parentId _setting {_level bd}} {
	variable SETTINGS

	set name [$_setting getAttribute name]
	set type [$_setting getAttribute "type"]

	set value [_nodeValue $_setting]

	addSetting $_parentId $_level $_name $_type
}


#
# Gets the value stored in a tDOM xml node
#
# _node      - The node that we want to get value off
# _dataType  - Defaults to asXMl but other valid is nodeValue
#
# return     - Returns the value in a node <node>value</node>
#              or empty string if the node if no data is found
#
proc purple::buddyList::_nodeValue {_node {_data_type asXML}} {
	set fn "purple::buddyList::_nodeValue "

	if {$_node == "" || [$_node selectNodes text()] == ""} {
		return ""
	}

	 return [[$_node selectNodes text()] $_data_type]
}

proc purple::buddyList::_log {_logLine} {
	puts $_logLine
}
