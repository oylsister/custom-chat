#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "Retro, Oylsister"
#define PLUGIN_VERSION "1.1"

#include <sourcemod>
#include <scp>
#include <multicolors>
#include <customchat>

#pragma newdecls required

#define MAX_MESSAGE_LENGTH 250

Database g_hDatabase;

Menu g_mColorsMenu, g_mNameMenu, g_mAvailbleColorsMenu;

public Plugin myinfo = 
{
	name = "Custom Chat", 
	author = PLUGIN_AUTHOR, 
	description = "Allows you to customize your chat color, name color, and set a custom tag.", 
	version = PLUGIN_VERSION, 
	url = "https://steamcommunity.com/id/R3TROATTACK/"
};

char g_sColorDisplay[][] =
{
	"Default",
	"Darkred",
	"Green",
	"Team Color",
	"Light Green",
	"Lime",
	"Red",
	"Grey",
	"Yellow",
	"Orange",
	"Bluegrey",
	"Blue",
	"Darkblue",
	"Grey2",
	"Orchid",
	"Lightred"
};

char g_sColorNames[][] =  {
	"default", 
	"darkred", 
	"green", 
	"team", 
	"lightgreen", 
	"lime", 
	"red", 
	"grey", 
	"yellow", 
	"orange", 
	"bluegrey", 
	"blue", 
	"darkblue", 
	"bluegrey", 
	"orchid", 
	"lightred"
};
char g_sColorCodes[][] =  {
	"\x01", 
	"\x02", 
	"\x04", 
	"\x03", 
	"\x05", 
	"\x06", 
	"\x07", 
	"\x08", 
	"\x09", 
	"\x10", 
	"\x0A", 
	"\x0B", 
	"\x0C", 
	"\x0D", 
	"\x0E", 
	"\x0F"
};

enum struct ChatData 
{
	int Chat; 
	int Name;
	char ChatHex[16];
	char NameHex[128];
	char Tag[64];
}

ChatData g_iPlayerInfo[MAXPLAYERS + 1];
bool g_bLate = false;

bool g_bChatActive[MAXPLAYERS + 1] = false;
bool g_bNameActive[MAXPLAYERS + 1] = false;
bool g_bTagActive[MAXPLAYERS + 1] = false;

bool g_bForced[MAXPLAYERS + 1] = false;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] err, int len)
{
	g_bLate = late;

	CreateNative("CC_SetClientChatColor", Native_SetClientChatColor);
	CreateNative("CC_SetClientNameColor", Native_SetClientNameColor);
	CreateNative("CC_SetClientTag", Native_SetClientTag);
	CreateNative("CC_ForceClientAccess", Native_ForceClientAccess);
	CreateNative("CC_IsClientForced", Native_IsClientForced);

	return APLRes_Success;
}

public void OnPluginStart()
{	
	DB_Load();
	RegAdminCmd("sm_chatcolor", Command_MainMenu, ADMFLAG_CUSTOM1);
	RegAdminCmd("sm_chatcolors", Command_Colors, ADMFLAG_CUSTOM1);
	RegAdminCmd("sm_namecolors", Command_NameColors, ADMFLAG_CUSTOM1);
	RegAdminCmd("sm_namecolor", Command_NameColors, ADMFLAG_CUSTOM1);

	RegAdminCmd("sm_settag", Command_SetTag, ADMFLAG_CUSTOM1);
	RegAdminCmd("sm_tag", Command_SetTag, ADMFLAG_CUSTOM1);
	
	if (g_bLate)
	{
		for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i))
			OnClientPostAdminCheck(i);
	}
}

public Action Command_MainMenu(int client, int args)
{
	if (0 >= client > MaxClients)
		return Plugin_Handled;
	
	if (!IsClientInGame(client))
		return Plugin_Handled;
		
	Menu menu3 = new Menu(MenuHandler_Main);
	menu3.SetTitle("[Custom Chat Colors] Menu Setting\n");
	menu3.AddItem("chatcolors", "Chat Colors");
	menu3.AddItem("namecolors", "Name Colors");
	menu3.AddItem("settag", "Set Tag");
	menu3.ExitButton = true;
	menu3.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public int MenuHandler_Main(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		if (param2 == 0)
		{
			g_mColorsMenu.Display(param1, MENU_TIME_FOREVER);
		}
		else if (param2 == 1)
		{
			g_mNameMenu.Display(param1, MENU_TIME_FOREVER);
		}
		else
		{
			DemoSettag(param1);
		}	
	}
	else if(action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public Action Command_Colors(int client, int args)
{
	if (0 >= client > MaxClients)
		return Plugin_Handled;
	
	if (!IsClientInGame(client))
		return Plugin_Handled;
	
	g_mColorsMenu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public Action Command_NameColors(int client, int args)
{
	if (0 >= client > MaxClients)
		return Plugin_Handled;
	
	if (!IsClientInGame(client))
		return Plugin_Handled;
	
	g_mNameMenu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public Action Command_SetTag(int client, int args)
{
	if (0 >= client > MaxClients)
		return Plugin_Handled;
	
	if (!IsClientInGame(client))
		return Plugin_Handled;
	
	if (args == 0)
	{
		DemoSettag(client);
		return Plugin_Handled;
	}
	if(args == 1)
	{
		char arg[MAX_TARGET_LENGTH];
		GetCmdArg(1, arg, sizeof(arg));
		if(StrEqual("off", arg, false))
		{
			Format(g_iPlayerInfo[client].Tag, 64, "");
			PrintToChat(client, " \x06[CustomChat] \x01You have cleared you custom tag.");
			DB_UpdateColors(client);
			return Plugin_Handled;
		}
	}
	char arg_string[MAX_MESSAGE_LENGTH];
	GetCmdArgString(arg_string, sizeof(arg_string));
	Format(g_iPlayerInfo[client].Tag, 64, "%s", arg_string);
	char msg[MAX_MESSAGE_LENGTH];
	Format(msg, sizeof(msg), " \x06[CustomChat] \x01You have set your chat tag to %s", arg_string);
	ProcessColors(msg, sizeof(msg));
	PrintToChat(client, "%s", msg);
	DB_UpdateColors(client);
	return Plugin_Handled;
}

public void DemoSettag(int client)
{
	Menu menu4 = new Menu(MenuHandler_Tag);
	menu4.SetTitle("[Custom Tag] Menu\n\nExample of Usage: sm_tag {red}[{green}Best Man{red}]\n ");
	menu4.AddItem("example", "Example");
	menu4.AddItem("coloravailable", "Color that available");
	menu4.ExitButton = true;
	menu4.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Tag(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		if (param2 == 0)
		{
			CPrintToChat(param1, "\x07[{green}Best Man\x07]{default} {lime}Yourname{default}: This is message Example.");
			DemoSettag(param1);
		}
		else if (param2 == 1)
		{
			g_mAvailbleColorsMenu.Display(param1, MENU_TIME_FOREVER);
		}
	}
	else if(action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public void OnClientPostAdminCheck(int client)
{
	g_iPlayerInfo[client].Chat = 0;
	g_iPlayerInfo[client].Name = 3;
	Format(g_iPlayerInfo[client].Tag, 64, "");
	CreateTimer(1.5, Timer_LoadDelay, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

public void OnClientDisconnect(int client)
{
	g_bChatActive[client] = false;
	g_bNameActive[client] = false;
	g_bTagActive[client] = false;

	g_bForced[client] = true;
}

public Action Timer_LoadDelay(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	if (0 > client > MaxClients && !IsClientInGame(client))
		return Plugin_Handled;
	
	bool n = CheckCommandAccess(client, "sm_namecolor", ADMFLAG_CUSTOM1);
	bool chat = CheckCommandAccess(client, "sm_chatcolor", ADMFLAG_CUSTOM1);
	bool tag = CheckCommandAccess(client, "sm_settag", ADMFLAG_CUSTOM1);
	if (!n && !chat && !tag)
		return Plugin_Handled;
		
	char sQuery[256], steamid[64];
	if (!GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid)))
		return Plugin_Handled;
	int count = 0;
	if (n) { count++; }
	if (chat) { count++; }
	if (tag) { count++; }
	if (count > 1)
		Format(sQuery, sizeof(sQuery), "SELECT %s%s%s FROM customchat WHERE steamid='%s';", n ? "namecolor, " : "", chat ? "chatcolor, " : "", tag ? "tag" : "", steamid);
	else
		Format(sQuery, sizeof(sQuery), "SELECT %s%s%s FROM customchat WHERE steamid='%s';", n ? "namecolor" : "", chat ? "chatcolor" : "", tag ? "tag" : "", steamid);
	g_hDatabase.Query(DB_LoadColors, sQuery, userid);
	return Plugin_Handled;
}

public void DB_LoadColors(Database db, DBResultSet results, const char[] error, any data)
{
	if (db == null || results == null)
	{
		LogError("DB_LoadColors returned error: %s", error);
		return;
	}
	
	int client = GetClientOfUserId(data);
	if (0 > client > MaxClients && !IsClientInGame(client))
		return;
		
	if(results.RowCount <= 0)
		return;
		
	int chatcol, namecol, tagcol;
	bool chat = results.FieldNameToNum("chatcolor", chatcol);
	bool name = results.FieldNameToNum("namecolor", namecol);
	bool tag = results.FieldNameToNum("tag", tagcol);
	results.FetchRow();
	
	if(chat)
	{
		g_iPlayerInfo[client].Chat = results.FetchInt(chatcol);
		g_bChatActive[client] = true;
	}
	if(name)
	{
		g_iPlayerInfo[client].Name = results.FetchInt(namecol);
		g_bNameActive[client] = true;
	}
	if(tag)
	{
		results.FetchString(tagcol, g_iPlayerInfo[client].Tag, 64);
		g_bTagActive[client] = true;
	}
		
	else if(!chat && !name && !tag)
	{
		g_iPlayerInfo[client].Name = 4;
		g_iPlayerInfo[client].Chat = 0;
		Format(g_iPlayerInfo[client].Tag, 64, "%s", "{orange}[VIP]");
		DB_UpdateColors(client);
	}
}

void DB_Load()
{
	Database.Connect(DB_Connect, "chatcolors");
}

public void DB_Connect(Database db, const char[] error, any data)
{
	if (db == null)
	{
		LogError("DB_Connect returned invalid Database Handle");
		return;
	}
	
	g_hDatabase = db;
	db.Query(DB_Generic, "CREATE TABLE IF NOT EXISTS customchat (steamid varchar(64) NOT NULL, chatcolor INT DEFAULT 0, namecolor INT DEFAULT 4, tag varchar(64) DEFAULT NULL, PRIMARY KEY(steamid));");
}

public void DB_UpdateColors(int client)
{
	if (g_hDatabase == null)
		return;
	
	char sQuery[256], steamid[64];
	if (!GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid)))
		return;
	Format(sQuery, sizeof(sQuery), "INSERT INTO customchat (steamid, chatcolor, namecolor, tag) VALUES ('%s', %d, %d, '%s') ON DUPLICATE KEY UPDATE chatcolor=VALUES(chatcolor), namecolor=VALUES(namecolor), tag=VALUES(tag);", steamid, g_iPlayerInfo[client].Chat, g_iPlayerInfo[client].Name, g_iPlayerInfo[client].Tag);
	g_hDatabase.Query(DB_Generic, sQuery);
}

public void DB_Generic(Database db, DBResultSet results, const char[] error, any data)
{
	if (db == null || results == null)
	{
		LogError("DB_Generic returned error: %s", error);
		return;
	}
}

public void OnMapStart()
{
	Menu menu = new Menu(MenuHandler_ChatColor);
	menu.SetTitle("[ChatColors] Select your chat color!");
	for (int i = 0; i < sizeof(g_sColorDisplay); i++)
	{
		char info[16];
		IntToString(i, info, sizeof(info));
		menu.AddItem(info, g_sColorDisplay[i]);
	}
	menu.ExitButton = true;
	g_mColorsMenu = menu;
	
	Menu menu2 = new Menu(MenuHandler_NameColor);
	menu2.SetTitle("[NameColors] Select your name color!");
	for (int i = 0; i < sizeof(g_sColorDisplay); i++)
	{
		char info[16];
		IntToString(i, info, sizeof(info));
		menu2.AddItem(info, g_sColorDisplay[i]);
	}
	menu2.ExitButton = true;
	g_mNameMenu = menu2;
	
	Menu menu4 = new Menu(MenuHandler_AvailableColor);
	menu.SetTitle("[ChatColors] Select chat color! to see example");
	for (int i = 0; i < sizeof(g_sColorDisplay); i++)
	{
		char info[16];
		IntToString(i, info, sizeof(info));
		menu.AddItem(info, g_sColorDisplay[i]);
	}
	menu.ExitButton = true;
	g_mAvailbleColorsMenu = menu4;
}

public void OnMapEnd()
{
	CloseMenu(g_mColorsMenu);
	CloseMenu(g_mNameMenu);
	CloseMenu(g_mAvailbleColorsMenu);
}

stock void CloseMenu(Menu& menu)
{
	if(menu != null)
	{
		CloseHandle(menu);
	}
	menu = null;
}

public int MenuHandler_ChatColor(Menu menu, MenuAction action, int client, int choice)
{
	if (action != MenuAction_Select)
		return;
	PrintToChat(client, " \x06[CustomChat] \x01You have set your chat color to %s%s\x01.", g_sColorCodes[choice], g_sColorDisplay[choice]);
	g_iPlayerInfo[client].Chat = choice;
	DB_UpdateColors(client);
}

public int MenuHandler_NameColor(Menu menu, MenuAction action, int client, int choice)
{
	if (action != MenuAction_Select)
		return;
	PrintToChat(client, " \x06[CustomChat] \x01You have set your name color to %s%s\x01.", g_sColorCodes[choice], g_sColorDisplay[choice]);
	g_iPlayerInfo[client].Name = choice;
	DB_UpdateColors(client);
}

public int MenuHandler_AvailableColor(Menu menu, MenuAction action, int client, int choice)
{
	if (action != MenuAction_Select)
		return;
	PrintToChat(client, " \x06[CustomChat] \x01This is the Example color of %s%s\x01.", g_sColorCodes[choice], g_sColorDisplay[choice]);
	g_mAvailbleColorsMenu.Display(client, MENU_TIME_FOREVER);
}

public Action OnChatMessage(int & author, ArrayList recipients, char[] name, char[] message)
{
	bool n = CheckCommandAccess(author, "sm_namecolors", ADMFLAG_CUSTOM1);
	bool chat = CheckCommandAccess(author, "sm_colors", ADMFLAG_CUSTOM1);
	bool tag = CheckCommandAccess(author, "sm_settag", ADMFLAG_CUSTOM1);
	if (!n && !chat && !tag && !g_bForced[author])
		return Plugin_Continue;
	
	char ctag[64];
	bool changed;
	bool needspace = false;
	if (chat || g_bForced[author])
	{
		if (g_iPlayerInfo[author].Chat != 0)
		{
			Format(message, MAX_MESSAGE_LENGTH, "%s%s", g_sColorCodes[g_iPlayerInfo[author].Chat], message);
			changed = true;
		}
		if (CheckCommandAccess(author, "sm_colors_parse", ADMFLAG_CUSTOM1))
			ProcessColors(message, MAX_MESSAGE_LENGTH);
	}

	if (tag || g_bForced[author])
	{
		if (!StrEqual("", g_iPlayerInfo[author].Tag))
		{
			Format(ctag, sizeof(ctag), "%s", g_iPlayerInfo[author].Tag);
			ProcessColors(ctag, sizeof(ctag));
			Format(ctag, MAX_NAME_LENGTH, "%s\x03", ctag);
			changed = true;
			needspace = true;
		}
	}
	
	if (n || g_bForced[author])
	{
		Format(name, MAX_NAME_LENGTH, " %s%s", g_sColorCodes[g_iPlayerInfo[author].Name], name);
		changed = true;
		needspace = true;
	}


	Format(name, MAX_NAME_LENGTH, "%s%s%s", needspace ? " " : "", ctag, name);
	
	if (changed)
		return Plugin_Changed;

	return Plugin_Continue;
}

public int Native_SetClientNameColor(Handle hPlugin, int params)
{
	int client = GetNativeCell(1);
	char color[64];

	GetNativeString(2, color, sizeof(color));

	if(strlen(color) <= 0)
	{
		ThrowError("Invalid Color!");
		return;
	}

	SetClientNameColor(client, color);
}

public int Native_SetClientChatColor(Handle hPlugin, int params)
{
	int client = GetNativeCell(1);
	char color[64];

	GetNativeString(2, color, sizeof(color));

	if(strlen(color) <= 0)
	{
		ThrowError("Invalid Color!");
		return;
	}

	SetClientChatColor(client, color);
}

public int Native_SetClientTag(Handle hPlugin, int params)
{
	int client = GetNativeCell(1);
	char tag[64];

	GetNativeString(2, tag, sizeof(tag));

	if(strlen(tag) <= 0)
	{
		ThrowError("Invalid Tag!");
		return;
	}

	SetClientTag(client, tag);
}

public int Native_ForceClientAccess(Handle hPlugin, int params)
{
	int client = GetNativeCell(1);
	bool result = view_as<bool>(GetNativeCell(2));

	ForceClientAccess(client, result);
}

public int Native_IsClientForced(Handle hPlugin, int params)
{
	int client = GetNativeCell(1);
	return g_bForced[client];
}

void ForceClientAccess(int client, bool apply)
{
	g_bForced[client] = apply;
}

void SetClientNameColor(int client, const char[] colorname)
{
	for (int i = 1; i < sizeof(g_sColorNames); i++)
	{
		if(StrEqual(g_sColorNames[i], colorname, false))
		{
			g_iPlayerInfo[client].Name = i;
			return;
		}
	}
}

void SetClientChatColor(int client, const char[] colorname)
{
	for (int i = 1; i < sizeof(g_sColorNames); i++)
	{
		if(StrEqual(g_sColorNames[i], colorname, false))
		{
			g_iPlayerInfo[client].Chat = i;
			return;
		}
	}
}

void SetClientTag(int client, const char[] buffer)
{
	FormatEx(g_iPlayerInfo[client].Tag, 64, "%s", buffer);
}

void ProcessColors(char[] buffer, int maxlen)
{
	for (int i = 1; i < sizeof(g_sColorNames); i++)
	{
		char tmp[32];
		Format(tmp, sizeof(tmp), "{%s}", g_sColorNames[i]);
		ReplaceString(buffer, maxlen, tmp, g_sColorCodes[i]);
	}
} 