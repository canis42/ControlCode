/******************************************************************************
 ** Module Name: Punish
 **
 ** Description:
 **   Punishes the wearer by applying text, animations, sounds, rlv.
 **   ultiple punishments can be defined and are accessible by a name.
 **   he wearer either has to speak a given sentence or the punishment
 **   asts a given number of seconds.
 **   at any time only one punishment may be pending.
 **   The possible RLV restricitons are defined by the OpenCollar RLV mosule:
 **   sendim, readim, hear, talk, touch, stray, rummage, dress, dazzle, daze
 **-----------------------------------------------------------------------------
 ** See
 **-----------------------------------------------------------------------------
 ** Modifications:
 ** Version|date ymd|Author|description
 ** 1.0.0  |18/03/21|cc    |first release
 **-----------------------------------------------------------------------------
 ** Saved parameters using Messages 200 to 2003:
 **     punish_active
 **     punish_default
 **     punish_names
 **     punish_definitions
 **-----------------------------------------------------------------------------
 ** Link Message Catalog (-=unused, R=received, S=send, B=both)
 **     0 R ignore
 **     2 - link authorization
 **     3 R link dialog
 **     4 - link rlv
 **     5 - link database
 **     6 - link animation
 **   -10 - link update
 **   499 - command external
 **   500 R command owner
 **   501 R command trusted
 **   502 R command group
 **   503 R command wearer
 **   504 R command everyone
 **   507 R command rlv
 **   510 R command safeword
 **   511 - command relay safeword
 **   520 R command blocked
 **   600 - authorization request
 **   601 - authorization response
 **   602 - attachment command
 **   610 - attachment forward
 **   620 - wearer lockout
 **   777 S app override
 ** -1000 S system reboot
 **  1001 - dialog popup help
 **  1002 S dialog notify
 **  1003 - dialog notify owners
 **  1004 S dialog say
 ** -1904 - system pin load
 **  2000 S database add
 **  2001 - database select
 **  2002 R database response
 **  2003 S database delete
 **  2004 - database empty
 **  3000 R menu request
 **  3001 S menu add
 **  3003 S menu remove
 **  4000 R execute punishment
 **  4001 R select punishment
 **  4002 S return selected punishment
 **  4003 S timeout
 **  6000 - rlv command
 **  6001 - rlv refresh
 **  6002 - rlv clear
 **  6003 - rlv version
 **  6004 - rlv relay version
 **  6100 - rlv off
 **  6101 - rlv on
 **  6102 - rlv query
 **  6103 - rlv response
 **  7000 S anim start
 **  7001 S anim stop
 **  7002 S anim get list
 **  7003 R anim list
 ** -8888 - lockmeister
 ** -9000 S dialog request
 ** -9001 R dialog response
 ** -9002 R dialog timeout
 ** -9003 - dialog sensor
 ** -9005 - dialog find agent
 ** -9500 - touch request
 ** -9501 - touch cancel
 ** -9502 - touch respons
 ** -9503 - touch expire
 **-10000 - timer event
 ** 20000 - particle
 ** 20001 - leash sensor
 **-----------------------------------------------------------------------------
 ** General Design principles
 **   This module is designed in object oriented programming (OOP). All
 **   functions and variables are grouped by class definitions and their names
 **   start with the name of their class . Higher level OOP principles are not
 **   used because LSL is no object oriented language. Methods are ordered
 **   by their names.
 **   See https://en.wikipedia.org/wiki/Object-oriented_programming
 **   Reusable classes that contain no application specific contents are
 **   Display, String and System.
 **   For the application the Functionality is divided by the MVC paradigm.
 **   See https://en.wikipedia.org/wiki/Model%E2%80%93view%E2%80%93controller
 **   This module is designed to be compatible with OpenCollar SIX.
 **   For storage optimization no variables are used for constants.
 **   For formatting Kernighan&Ritchie format is used ("{" on structure lines)
 **   Global variables start with a "g", parameters start with a "p"
 **   Hungarian notation is not used, because types are handled by the compiler.
 **-----------------------------------------------------------------------------
 ** Copyright (c) 2018, Cans Canning in SecondLife
 ** All rights reserved.
 **
 ** Redistribution and use in source and binary forms, with or without
 ** modification, are permitted provided that the following conditions are met:
 **
 ** Redistributions of source code must retain the above copyright notice, this
 ** list of conditions and the following disclaimer.
 **
 ** THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 ** AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 ** IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 ** ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 ** LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 ** CONSEQUENTIAL DAMAGES(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 ** SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 ** INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 ** CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 ** ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF 
 ** THE POSSIBILITY OF SUCH DAMAGE.
 **
 ** The views and conclusions contained in the software and documentation are
 ** those of the authors and should not be interpreted as representing official
 ** policies, either expressed or implied, of the OpenModule Project.
 ******************************************************************************/

//=====================================================================
// Class Dialog
// Handle dialog windows 
list gDialog_ids; // list of pending dialogs: id, menuid, name
//---------------------------------------------------------------------
// Method Dialog::notify
// Send a notify message to chat console
Dialog_notify(key pAgent, string pMessage, integer pNotifyWearer) {
    string wearerFlag;
    if(pNotifyWearer)
        wearerFlag="1";
    else
        wearerFlag="0";
    llMessageLinked(gSystem_linkDialog, 1002, wearerFlag+pMessage, pAgent);
}
//---------------------------------------------------------------------
// Method Dialog::remove
// Remove a dialog from dialog list.
Dialog_remove(key pAgent) {
    integer dialogIndex = llListFindList(gDialog_ids, [pAgent]);
    if(dialogIndex != -1)
        gDialog_ids = llDeleteSubList(gDialog_ids, dialogIndex - 1, dialogIndex - 2 + 4);
}
//---------------------------------------------------------------------
// Method Dialog::request
// Send dialog requests by link message to the module co_dialog
Dialog_request(key pAgent, key pDialogId, string pPrompt, list pChoices,
        list pUtilityButtons, integer pPage, integer pAuth, string pName,
        integer pMenuFlag) {
    if(gSystem_debugFlag)
        System_debug("DIALOG REQUEST: " + pPrompt);
    if(pDialogId == NULL_KEY)
        pDialogId = llGenerateKey();
    llMessageLinked(gSystem_linkDialog, -9000, (string)pAgent
            + "|" + "\n" + pPrompt
            + "|" + (string)pPage + "|" + llDumpList2String(pChoices, "`")
            + "|" + llDumpList2String(pUtilityButtons, "`") + "|"
            + (string)pAuth, pDialogId);
    integer index = llListFindList(gDialog_ids, [pAgent]);
    if (index != -1)
        gDialog_ids = llListReplaceList(gDialog_ids,
                [pAgent, pDialogId, pName, pMenuFlag], index, index + 2);
    else
        gDialog_ids += [pAgent, pDialogId, pName, pMenuFlag];
}
//=====================================================================
// Class Punishment
// Administrate punishment definitions and execute punishments

// Names is a list of punishment Names
list gPunish_names;

// Definitions is a list of strings. Each string is the definition
// for one punbishment. A punishment consists of comma separated items
// of the form:
//    animation:name
//    sound:name
//    rlv:name (name of restrictions as defined by the rlv module)
//    duration:seconds 
list gPunish_definitions;

// name of currently running punishment or empty string if none running
// this value is not saved into the settings
string gPunish_current;

// sentence to stop current punishment
string gPunish_sentence;

// switch punihment on or off
integer gPunish_active = TRUE;

// name of default punishment, played with punish without name
string gPunish_default;

// open collar RLV restriction names
list RLVOC = [
        "sendim", "readim", "hear", "talk", "touch",
        "stray", "rummage", "dress", "dazzle", "daze"
];                  
//---------------------------------------------------------------------
// Method Punishment::add(name, definitions)
// Add a new punishment of the given name with the given punishment
// definitions.
Punish_add(string pName, string pDefinitions) {
    integer idx = llListFindList(gPunish_names, [pName]);
    if(idx == -1) {
        gPunish_names += pName;
        gPunish_definitions += pDefinitions;
        Settings_set("names", llList2CSV(gPunish_names));
        Settings_set("definitions",
                llDumpList2String(gPunish_definitions, "|"));
        if(llGetListLength(gPunish_names) == 1)
            Punish_setDefault(llList2String(gPunish_names, 0));
    }
    else
        gSystem_error = -2;
}
//---------------------------------------------------------------------
// Method Punishment::change(name, definitions)
// Change an existing  punishment to the given definitions
Punish_change(string pName, string pDefinitions) {
    if(pName != "oc") {
        integer idx = llListFindList(gPunish_names, [pName]);
        if(idx == -1)
            gSystem_error = -2;
        else {
            gPunish_definitions = llListReplaceList(
                    gPunish_definitions, [pDefinitions], idx, idx);
            Settings_set("definitions",
                    llDumpList2String(gPunish_definitions, "|"));
        }
    }
    else
        gSystem_error = -5;
}
//----------------------------------------------------------------------
// check the punishment end sentence
// set the sentence to end the current punishment
integer Punish_checkSentence(string pSentence) {
    return (pSentence == gPunish_sentence);
}
//---------------------------------------------------------------------
// Method Punishment::delete(name)
Punish_delete(string pName) {
    if(pName != "oc") {
        integer idx = llListFindList(gPunish_names, [pName]);
        if(idx == -1)
            gSystem_error = -2;
        gPunish_names = llDeleteSubList(gPunish_names, idx, idx);
        gPunish_definitions = llDeleteSubList(gPunish_definitions, idx, idx);
        Settings_set("names", llList2CSV(gPunish_names));
        Settings_set("definitions",
                llDumpList2String(gPunish_definitions, "|"));
        if(pName == gPunish_default) {
            if(llGetListLength(gPunish_names) == 0)
                Punish_setDefault("");
            else
                Punish_setDefault(llList2String(gPunish_names, 0));
        }
    }
    else
        gSystem_error = -5;
}   
//---------------------------------------------------------------------
// Method Punishment::enable
// Enable/disable the punishments
Punish_enable(integer pPunishmentOn) {
    gPunish_active = pPunishmentOn;
    if(! gPunish_active) {
        if(gPunish_current != "")
            Punish_stop();
    }
    Settings_set("active", (string) gPunish_active);
}
//---------------------------------------------------------------------
// Method Punishment::setDefault(name, definitions)
// set the default punishment
Punish_setDefault(string pDefault) {
    integer idx = llListFindList(gPunish_names, [pDefault]);
    if(idx == -1)
        gSystem_error = -2;
    else {
        gPunish_default = pDefault;
        Settings_set("default", pDefault);
    }
}
//---------------------------------------------------------------------
// Method Punishment::start(agent, name)
// Globals:
//     gPunish_current
//     gPunish_names
//     gPunish_definitions
//     gSystemError (-1=not found, -2=already running
Punish_start(string pName, integer pUseDefault) {
    if(gPunish_current != "")
        gSystem_error = -3;
    else {
        float duration;
        integer idx = llListFindList(gPunish_names, [pName]);
        if(idx == -1) {
            if(pName == "default" || 
                    (pUseDefault && gPunish_default != "")) {
                idx = llListFindList(gPunish_names, [gPunish_default]);
                pName = gPunish_default;
            }
            if(idx == -1)
                gSystem_error = -2;
        }
        if(gSystem_error == 0) {
            list punishs = llCSV2List(llList2String(
                    gPunish_definitions, idx));
            integer i;
            for(i=llGetListLength(punishs)-1; i>=0; --i) {
                list tokens = llParseString2List(
                        llList2String(punishs, i), [":"], []);
                string command = llToUpper(llList2String(tokens, 0));
                string value = llList2String(tokens, 1);
                if(command == "ANIM")
                    llMessageLinked(gSystem_linkAnim,
                            7000, value, ""); // anim start
                else if(command == "SOUND")
                    llLoopSound(value, 1.0);
                else if(command == "RLV") {
                    string rlvCommand = llToLower(value);
                    if(llListFindList(RLVOC, [rlvCommand]) != -1) {
                        if(value != "daze" && value != "dazzle")
                            rlvCommand = "forbid " + rlvCommand;
                        llMessageLinked(LINK_THIS,
                                500, rlvCommand, "");
                    }
                    else
                        gSystem_error = -4;
                }
                else if(command == "SENTENCE")
                    gPunish_sentence = value;
                else if(command == "DURATION")
                    duration = (float)value;
                else if(command == "SAY") {
                    value = String_replace(value, "%s",
                            llGetDisplayName(llGetOwner()));
                    llSay(0, value);
                }
            }
            if(duration == 0) {
                if(gPunish_sentence != "")
                    duration = 120;
                else
                    duration = 5;
            }
            gPunish_current = pName;     
            llSetTimerEvent(duration);
        }
    }
}
//---------------------------------------------------------------------
// Method Punishment::stop(agent)
// Stop the currently running punishment. Ignore if punishment does not
// run or does not exist.
// Globals:
//     gPunish_current
//     gPunish_names
//     gPunish_definitions
Punish_stop() { 
    llSetTimerEvent(0);
    if(gPunish_current != "") {
        integer idx = llListFindList(gPunish_names, [gPunish_current]);
        if(idx != -1) {
            list punishs = llCSV2List(llList2String(
                    gPunish_definitions, idx));
            integer i;
            for(i=llGetListLength(punishs)-1; i>=0; --i) {
                list tokens = llParseString2List(
                        llList2String(punishs, i), [":"], []);
                string command = llToUpper(llList2String(tokens, 0));
                string value = llToUpper(llList2String(tokens, 1));
                if(command == "ANIM")
                    llMessageLinked(gSystem_linkAnim, 7001, value, "");
                else if(command == "SOUND")
                    llStopSound();
                else if(command == "RLV") {
                    string rlvCommand = llToLower(value);
                    if(llListFindList(RLVOC, [rlvCommand]) != -1 ) {
                        if(rlvCommand == "daze" || rlvCommand == "dazzle")
                            rlvCommand = "un" + rlvCommand;
                        else
                            rlvCommand = "allow " + rlvCommand;
                        llMessageLinked(LINK_THIS, 500, rlvCommand, "");
                    }
                }
            }
            gPunish_current = "";     
        }
        else {
            llStopSound();
        }
    }
}
//=====================================================================
// Class PunishController
// Process inputs and control the processing of the Punishment class.

//---------------------------------------------------------------------
// Method PunishController::evaluate
// message: key agent|string message||integer auth|integer dialog
PunishController_evaluateDialogResponse(key pDialogId, string pCommand) {
    integer dialogIndex = llListFindList(gDialog_ids, [pDialogId]);
if (dialogIndex != -1) {
        if(gSystem_debugFlag)
            System_debug("DIALOG RESPONSE: "+pCommand);
        list commandParams = llParseString2List(pCommand, ["|"], []);
        key agent = llList2Key(commandParams, 0);
        string message = llList2String(commandParams, 1);
        integer auth = llList2Integer(commandParams, 3);
        string dialogName=llList2String(gDialog_ids, dialogIndex + 1);
        integer dialogFlag = llList2Integer(gDialog_ids, dialogIndex + 2);
        integer dialog = llList2Integer(commandParams, 4);
        Dialog_remove(pDialogId);
        if (dialogName=="PunishMenu") {
            if (message == "BACK")
                llMessageLinked(LINK_ROOT, auth, "menu apps", agent);
            else 
                PunishController_processCommand(auth, agent,
                        "punish "+message, dialogFlag);
            return;
        } else if(dialogName == "PunishSelect") {
            if(message != "BACK")
                llMessageLinked(LINK_SET, 4002, message, pDialogId);
        } else if(dialogName == "rmpunish") {
            if(message == "Yes") {
                llMessageLinked(LINK_ROOT, 3002,
                        gSystem_menuParent+"|"+gSystem_menuSub, "");
                llMessageLinked(LINK_THIS, 777, gSystem_menuSub, "off");
                Dialog_notify(pDialogId, gSystem_menuSub+" App has been removed."
                        , TRUE);
                if(llGetInventoryType(llGetScriptName()) == INVENTORY_SCRIPT)                       llRemoveInventory(llGetScriptName());
            } else
                Dialog_notify(agent, gSystem_menuSub+" App remains installed.",
                        FALSE);
        } 
        else if(message == "BACK" || message == " ")
            PunishView_showPunishMenu(agent, auth);
        else {
            if(PunishController_processCommand(auth, agent,
                    llToLower(dialogName + " " + message), dialogFlag) && dialogFlag)
                PunishView_showPunishMenu(agent, auth);
        }
    }
}
//---------------------------------------------------------------------
// Method PunishView::handleMessage
// Handle the incoming messages.
PunishController_handleMessage(integer pSender, integer pNum,
        string pMessage, key pId) {
    if(pNum >= 500 && pNum <= 503) // command with different authorization
        PunishController_processCommand(pNum, pId, pMessage, FALSE);
    else if(pNum == 510)  // safe word issued
        Punish_stop();
    else if(pNum == 2002) // settings set request
        Settings_load(pMessage);
    else if(pNum == 3000 && pMessage == gSystem_menuParent) // menu entry request
        llMessageLinked(pSender, 3001,
                gSystem_menuParent+"|"+gSystem_menuSub, "");
    else if(pNum == 4000) // start a punishment
        Punish_start(pMessage, TRUE);
    else if(pNum == 4001) // request a punishment name (answer with 4002)
        PunishView_selectPunishment(pId, pMessage, 500, FALSE);
    else if(pNum == -9001) // answer to a dialog
        PunishController_evaluateDialogResponse(pId, pMessage);
    else if(pNum == -9002) // timeout of a dialog
        Dialog_remove(pId);
    else if(pNum == -10) // set link number request
        System_setLink(pMessage, pSender);
    else if(pNum == -1000 && pMessage == "reboot")
        llResetScript();
}
//---------------------------------------------------------------------
// Method PunishmentControl::processCommand
// The commandLine has the form: module command parameters. It does not
// matter if the command line originates from the chat, from other modules
// or from the answer to a dialog.
integer PunishController_processCommand(integer pAuthorization, key pAgent,
        string pLineStr, integer pMenuFlag) {
    integer showMenu;
    pLineStr = llStringTrim(pLineStr,STRING_TRIM);
    
    // parse line string to list
    string CR = llUnescapeURL("%0D"); // carriage return character    
    list line = llParseString2List(pLineStr, [" ", "\n", CR], []);
    integer lineLength = llGetListLength(line);
    
    // extract module and command
    string module = llToLower(llList2String(line, 0));
    string command;
    if(lineLength > 1)
        command = llToLower(llList2String(line, 1));
    // check for menu command
    if(module == "menu" && (command == "punish" || command == "pu")) {
        if(gSystem_debugFlag)
            System_debug("MENU: "+pLineStr);

        if (pAuthorization != 500)
            Dialog_notify(pAgent, "%NOACCESS%", FALSE);
        else
            PunishView_showPunishMenu(pAgent, pAuthorization);
    }
    else if(module == "punish" || module == "pu") {
        if(gSystem_debugFlag)
            System_debug("COMMAND: "+pLineStr);

        if(lineLength == 1) {
            if (pAuthorization != 500)
                Dialog_notify(pAgent, "%NOACCESS%", FALSE);
            else
                PunishView_showPunishMenu(pAgent, pAuthorization);
        }
        else {
            if(command == "add")
                showMenu = PunischmentView_displayAdd(
                        pAuthorization, pAgent, line, pMenuFlag);
            else if(command == "change")
                showMenu = PunishViewl_displayChange(
                        pAuthorization, pAgent, line, pMenuFlag);
            else if(command == "delete")
                showMenu = PunishView_displayDelete(
                        pAuthorization, pAgent, line, pMenuFlag);
            else if(command == "start")
                showMenu = PunishView_displayStart(
                        pAuthorization, pAgent, line, pMenuFlag);
            else if(command == "stop") {
                Punish_stop();
                showMenu = TRUE;
            }
            else if(command == "default")
                showMenu = PunishView_displayDefault(
                        pAuthorization, pAgent, line, pMenuFlag);
            else if(command == "punish") {
                string name;
                if(lineLength > 2)
                    name = llList2String(line, 2);
                Punish_start(name, TRUE);
                showMenu = TRUE;
            }
            else if(command == "on" 
                    || command == llToLower(PunishView_OFF)) {
                Punish_enable(TRUE);
                showMenu = TRUE;
            }
            else if(command == "off" 
                    || command == llToLower(PunishView_ON)) {
                Punish_enable(FALSE);
                showMenu = TRUE;
            }
        }
    }
    return showMenu;
}
//---------------------------------------------------------------------
// Method System::manageListen
// Activate listening if module is enabled and there are conditions to check
// deactivate listening otherwise.
PunishController_manageListen() {
    if(gPunish_current != "" && gPunish_sentence != "-")
        gSystem_listenHandle = llListen(0, "", llGetOwner(), "");
    else
        llListenRemove(gSystem_listenHandle);
}
//=====================================================================
// Class PunishView
// View of the punishment class. Dialogs are realized using the external
// Dialog component with message -9000. The answers will be send form the
// Dialog module using message -9001. If Dialogs are sent, then the
// dialogs get a name according to the corresponding chat line command.
string PunishView_OFF = "☐Active"; // speakwell deavtivated
string PunishView_ON = "☑Active"; // speakwell activated
string PunishView_ENTER =
        "\n\nPlease enter a list of comma-separated punishments in the form name:value with name being one of say, anim, sound, rlv, sentence, duration\nrlv may be: endim, readim, hear, talk, touch, stray, rummage, dress, dazzle, daze";
list PunishView_ERRORTEXT = [
    "General Error",
    "Punishment name not found.",
    "No current punishment",
    "Unknown RLV name",
    "Can not change \"oc\""
];
//---------------------------------------------------------------------
// Method PunishView::displayAdd
// Display the dialog to request the name of the punishment to be
// added or if given the dialog to enter the parameters.
integer PunischmentView_displayAdd(integer pAuthorization, key pAgent,
        list pLine, integer pMenuFlag) {
    integer lineLength = llGetListLength(pLine);
    integer showMenu;
    if(lineLength == 2)
        Dialog_request(pAgent, NULL_KEY,
                "Please enter a name for the new punishment.",
                [], [], 0, pAuthorization, "punish add", pMenuFlag);
    else if(lineLength == 3) {
        if(llListFindList(gPunish_names, [llList2String(pLine, 3)]) != -1)
            Dialog_request(pAgent, NULL_KEY,
                "Punishment exists."
                + " Please enter another name for the new punishment.",
                [], [], 0, pAuthorization, "punish add", pMenuFlag);
        else                     
            Dialog_request(pAgent, NULL_KEY,
                    "Punishment: " + llList2String(pLine, 2)
                    + PunishView_ENTER,
                    [], [], 0, pAuthorization, "punish add "
                    + llList2String(pLine, 2), pMenuFlag);
    }
    else {
        Punish_add(llList2String(pLine, 2),
            llDumpList2String(llList2List(pLine, 3, -1), " "));
        showMenu = TRUE;
    }
    return showMenu;
}
//---------------------------------------------------------------------
// Method PunishView::displayChange
// Display the dialog to request the name of the punishment to be
// changed or if given the dialog to enter the new parameters.
integer PunishViewl_displayChange(integer pAuthorization, key pAgent,
        list pLine, integer pMenuFlag) {
    integer lineLength = llGetListLength(pLine);
    integer showMenu;
    if(lineLength == 2) {
        list names = llList2List(gPunish_names, 1, -1);
        Dialog_request(pAgent, NULL_KEY,
                "Please select a punishment name",
                names, ["BACK"], 0, pAuthorization,
                "punish change", pMenuFlag);
    } else if(lineLength == 3) {
        string name = llList2String(pLine,2);
        if(name == "oc") {
            gSystem_error = -5;
            return TRUE;
        }
        integer idx = llListFindList(gPunish_names, [name]);
        Dialog_request(pAgent, NULL_KEY,
            "Old punishments:\n" + llList2String(gPunish_definitions, idx)
            + PunishView_ENTER,
            [], [], 0, pAuthorization, "punish change " + name, pMenuFlag);
    }
    else {
        Punish_change(llList2String(pLine, 2),
            llDumpList2String(llList2List(pLine, 3, -1), " "));
        showMenu = TRUE;
    }
    return showMenu;
}
//---------------------------------------------------------------------
// Method PunishView::displayDefault
// Display the dialog to request the name of the punishment that
// should be the default.
integer PunishView_displayDefault(integer pAuthorization, key pAgent,
        list pLine, integer pMenuFlag) {
    integer lineLength = llGetListLength(pLine);
    integer showMenu;
    if(lineLength == 2)
        Dialog_request(pAgent, NULL_KEY,
                "Please select a default punishment name",
                gPunish_names, ["BACK"], 0, pAuthorization,
                "punish default", pMenuFlag);
    else {
        Punish_setDefault(llList2String(pLine, 2));
        showMenu = TRUE;
    }
    return showMenu;
}
//---------------------------------------------------------------------
// Method PunishView::displayDelete
// Display the dialog to request the name of the punishment to be deleted.
integer PunishView_displayDelete(integer pAuthorization, key pAgent,
        list pLine, integer pMenuFlag) {
    integer lineLength = llGetListLength(pLine);
    integer showMenu;
    if(lineLength == 2) {
        list names = llList2List(gPunish_names, 1, -1);
        Dialog_request(pAgent, NULL_KEY,
                "Please select a punishment name",
                names, ["BACK"], 0, pAuthorization,
                "punish delete", pMenuFlag);
    }
    else {
        Punish_delete(llList2String(pLine, 2));
        showMenu = TRUE;
    }
    return showMenu;
}
//---------------------------------------------------------------------
// Method PunishView::displayError
// Display an error message depending on the value of the global system
// error variable. If the error is zero nthing is displayed.
PunishView_displayError() {
    if(gSystem_error < 0)
        llSay(0, llList2String(PunishView_ERRORTEXT, -gSystem_error-1));
}

//---------------------------------------------------------------------
// Method PunishView::displayStart
// Display a dialog name for a punishment to be startet if the
// name is not given.
integer PunishView_displayStart(integer pAuthorization,
        key pAgent, list pLine, integer pMenuFlag) {
    integer lineLength = llGetListLength(pLine);
    integer showMenu;
    if(lineLength == 2)
        Dialog_request(pAgent, NULL_KEY,
                "Please select a punishment name",
                gPunish_names, ["BACK"], 0, pAuthorization,
                "punish start", pMenuFlag);
    else {
        Punish_start(llList2String(pLine, 2), FALSE);
        showMenu = TRUE;
    }
    return showMenu;
}

//---------------------------------------------------------------------
// Method DialogView::selectPunishment
// Show a dialog to select a punishment from a list of known
// punishments. This function is requested b other modules by
// message 4001. The result of the selection will be sent
// with message 4002. The dialog id is used to distinguish
// multiple requests.
PunishView_selectPunishment(key pDialogId, string pMessage,
        integer pAuthorization, integer pMenuFlag) {
    key agent = (key) pMessage;
    list punishments = gPunish_names + "default";
    Dialog_request(agent, pDialogId,
            "Please select a punishment name",
            punishments, ["BACK"], 0, pAuthorization,
                    "PunishSelect", pMenuFlag);
}
//---------------------------------------------------------------------
// Method DialogView::showPunishMenu
// Show the main punish menu.
PunishView_showPunishMenu(key pAgent, integer pAuth) {
    list lButtons = ["Add", "Change", "Delete", "Start", "Stop",
            "Punish", "Default"];
    if(gPunish_active)
        lButtons += PunishView_ON;
    else
        lButtons += PunishView_OFF;
    string text = "\n[https://github.com/canis42/ControlCode/wiki/Sinsations-CC-Punish"
            + " Sinsations CC Punish]\t"+gSystem_applicationVersion+"\n"
            + "\nDefault: " + gPunish_default
            + "\n\n- Select a punishment option";
    Dialog_request(pAgent, NULL_KEY, text, lButtons, ["BACK"],0, pAuth,
            "PunishMenu", TRUE);
}
//=====================================================================
// Class Settings
// Save and load settings to database. The syntax is name=value. The name
// is constructed by a module specific prefix and a value specific name.
string SETTINGS_PREFIX = "punish_";

//---------------------------------------------------------------------
// Method Settings::load
// Load setting send by database. At program start we expect all settings
// to be sent.
Settings_load(string pCommand) {
    list params = llParseString2List(pCommand, ["="], []);
    string token = llList2String(params, 0);
    string value = llList2String(params, 1);
    integer idx = llSubStringIndex(token, "_");
    if(pCommand == "settings=sent" && llGetListLength(gPunish_names) == 0)
            Punish_add("oc", "say:%s failed,anim:~shock,sound:sndhum");
    if(llGetSubString(token, 0, idx) == SETTINGS_PREFIX) {
        token = llGetSubString(token, idx+1, -1);
        if(token == "active")
            gPunish_active = (integer) value;
        if(token == "names")
            gPunish_names = llCSV2List(value);
        else if(token == "definitions")
            gPunish_definitions = llParseStringKeepNulls(value, ["|"],[]);
        else if(token == "default")
            gPunish_default = value;
    }
}
//---------------------------------------------------------------------
// Method Settings::set
Settings_set(string pVariable, string pValue) {
    string setStr = SETTINGS_PREFIX+pVariable+"="+pValue;
    if(gSystem_debugFlag)
            System_debug("SET: " + setStr);
    llMessageLinked(gSystem_linkSave, 2000, setStr, "");
}
//=====================================================================
// class String
//---------------------------------------------------------------------
// Method String::replace
string String_replace(string pOld, string pSearch, string pReplace) {
    return llDumpList2String(
            llParseStringKeepNulls((pOld = "") + pOld, [pSearch], []), pReplace);
}
//=====================================================================
// Class System
// Perform general system specific tasks
integer gSystem_error; // 0=ok, <0=error, >0=information
integer gSystem_linkDialog;
integer gSystem_linkRlv;
integer gSystem_linkSave;
integer gSystem_linkAnim;
integer gSystem_listenHandle;
string gSystem_menuParent;
string gSystem_menuSub;
integer gSystem_moduleEnabled=0;
string gSystem_applicationVersion;
integer gSystem_debugFlag;
//---------------------------------------------------------------------
// Method System::debug
// This function should only be called if the variable 
// gSystem_debugFlag is TRUE to minimize processing overhead.
System_debug(string debugString) {
    llOwnerSay(llGetScriptName()
            + "(" + (string)llGetFreeMemory() + "): "
            + debugString);
}
//---------------------------------------------------------------------
// Method System::enable
System_enable(key pAgent, integer pAuth, integer pEnableFlag) {
    if(pEnableFlag) {
        gSystem_moduleEnabled = 1;
        Settings_set("on", "1");
        Dialog_notify(pAgent, gSystem_menuSub + " enabled", FALSE);
        llMessageLinked(LINK_THIS, 777, gSystem_menuSub, "on");
    }
    else {
        gSystem_moduleEnabled = 0;
        Settings_set("on","0");
        Dialog_notify(pAgent, gSystem_menuSub + " disabled", FALSE);
        llMessageLinked(LINK_THIS, 777, gSystem_menuSub, "off");
    }
}
//----------------------------------------------------------------------
// Method System::remove
// Removes this application from the system
System_remove(key pAgent, integer pAuth) {
     if(pAgent != llGetOwner() && pAuth !=500)
        Dialog_notify(pAgent, "%NOACCESS%", FALSE);
else
        Dialog_request(pAgent, NULL_KEY, "\nDo you really want to uninstall the "
                +gSystem_menuSub+" App?", ["Yes","No", "Cancel"], [], 0, pAuth,
                "rmpunish",TRUE);
}
//---------------------------------------------------------------------
// Method System::setLink
// The system is divided into several parts that reside in different
// prims. This allows to reset the scripts in one prim to be resetted
// without affecting scripts in other prims. SO we have to give the
// link for sending messages. The links are reported by the modules
// in the prims.
System_setLink(string pCommand, integer pSender) {
    if (pCommand == "LINK_ANIM")
        gSystem_linkAnim= pSender;
    else if (pCommand == "LINK_DIALOG")
        gSystem_linkDialog = pSender;
    else if (pCommand == "LINK_RLV")
        gSystem_linkRlv = pSender;
    else if (pCommand == "LINK_SAVE")
        gSystem_linkSave = pSender;
}
//=====================================================================
// State Default
// All processing is done in state default.
// we expect to get database responses (2002) for all variables
default {
    state_entry() {
        if(gSystem_debugFlag)
            System_debug("INITIALIZE");
        // initialize system variables
        gSystem_menuParent = "Apps";
        gSystem_menuSub = "Punish";
        gSystem_applicationVersion = "V1.0.0"; // version.modification.correction
        gSystem_debugFlag = FALSE;
        // stop punishment    
        llStopSound();
    }
    link_message(integer pSender, integer pNum, string pCommand, key pAgent) {
        gSystem_error = 0;
        PunishController_handleMessage(pSender, pNum, pCommand, pAgent);
        PunishView_displayError();
    }
    listen(integer pChannel, string pName, key pAgent, string pMessage) {
        if(gSystem_debugFlag)
            System_debug("LISTEN: " +  (string) pChannel + " | " + pMessage);

        if (~llSubStringIndex(pMessage, "remspeakwell")) {
            return;
        }
        else { // sentence entered by sub
            gSystem_error = 0;
            Punish_checkSentence(pMessage);
            PunishView_displayError();
        }
    }
    on_rez(integer iParam) {
        Punish_stop();
    }
    timer() {
        Punish_stop();
    }
}
