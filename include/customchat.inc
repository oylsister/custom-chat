native void CC_SetClientChatColor(int client, const char[] colorname);
native void CC_SetClientNameColor(int client, const char[] colorname);
native void CC_SetClientTag(int client, const char[] tag);

native void CC_ForceClientAccess(int client, bool apply);
native bool CC_IsClientForced(int client);