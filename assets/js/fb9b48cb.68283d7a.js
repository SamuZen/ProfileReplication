"use strict";(self.webpackChunkdocs=self.webpackChunkdocs||[]).push([[749],{82597:e=>{e.exports=JSON.parse('{"functions":[{"name":"init","desc":"Initialize the system","params":[{"name":"databaseName","desc":"The name of the database","lua_type":"string"},{"name":"profileTemplate","desc":"The data template","lua_type":"table"}],"returns":[],"function_type":"method","source":{"line":47,"path":"src/ProfileReplication.lua"}},{"name":"start","desc":"Start the system, load player profiles, register player added and data changed","params":[],"returns":[],"function_type":"method","source":{"line":58,"path":"src/ProfileReplication.lua"}},{"name":"Set","desc":"Set value on path.\\nCannot set tables directly","params":[{"name":"player","desc":"Target player","lua_type":"Player"},{"name":"path","desc":"path to the data","lua_type":"string"},{"name":"newValue","desc":"value to set","lua_type":"string | number | boolean"}],"returns":[],"function_type":"method","source":{"line":98,"path":"src/ProfileReplication.lua"}},{"name":"AddTable","desc":"Set value on path","params":[{"name":"player","desc":"Target player","lua_type":"Player"},{"name":"path","desc":"path to the data","lua_type":"string"},{"name":"value","desc":"table to append","lua_type":"table"},{"name":"key","desc":"optional key to insert the table","lua_type":"string"}],"returns":[],"function_type":"method","source":{"line":127,"path":"src/ProfileReplication.lua"}},{"name":"Increment","desc":"Increment number on path","params":[{"name":"player","desc":"Target player","lua_type":"Player"},{"name":"path","desc":"path to the data","lua_type":"string"},{"name":"value","desc":"number to increment","lua_type":"number"}],"returns":[],"function_type":"method","source":{"line":164,"path":"src/ProfileReplication.lua"}},{"name":"Delete","desc":"Delete value on path","params":[{"name":"player","desc":"Target player","lua_type":"Player"},{"name":"path","desc":"path to the data","lua_type":"string"}],"returns":[],"function_type":"method","source":{"line":192,"path":"src/ProfileReplication.lua"}},{"name":"GetPlayerData","desc":"Return the player profile data","params":[{"name":"player","desc":"Target player","lua_type":"Player"}],"returns":[{"desc":"","lua_type":"{any}"}],"function_type":"method","source":{"line":213,"path":"src/ProfileReplication.lua"}},{"name":"GetPlayerDataAsync","desc":"Return the player profile within a Promise","params":[{"name":"player","desc":"Target player","lua_type":"Player"}],"returns":[{"desc":"","lua_type":"Promise<ProfileService.Profile>"}],"function_type":"method","source":{"line":226,"path":"src/ProfileReplication.lua"}},{"name":"GetPlayerProfile","desc":"Return the player profile","params":[{"name":"player","desc":"Target player","lua_type":"Player"}],"returns":[{"desc":"","lua_type":"ProfileService.Profile"}],"function_type":"method","source":{"line":253,"path":"src/ProfileReplication.lua"}}],"properties":[{"name":"Signals","desc":"","lua_type":"Signals","source":{"line":35,"path":"src/ProfileReplication.lua"}}],"types":[{"name":"Signals","desc":"","fields":[{"name":"playerProfileLoaded","lua_type":"Signal","desc":"fires when a player profile is loaded"},{"name":"beforePlayerRemoving","lua_type":"Signal","desc":"fires before a player profile is being released"}],"source":{"line":28,"path":"src/ProfileReplication.lua"}}],"name":"ProfileService","desc":"Main Class.","source":{"line":20,"path":"src/ProfileReplication.lua"}}')}}]);