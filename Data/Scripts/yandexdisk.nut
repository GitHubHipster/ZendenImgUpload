if(ServerParams.getParam("enableOAuth") == "")
{
	ServerParams.setParam("enableOAuth", "true") ;
}

if(ServerParams.getParam("useWebdav") == "")
{
	ServerParams.setParam("useWebdav", "false");
	ServerParams.setParam("token","");
	ServerParams.setParam("tokenType","");
}
token <- "";
tokenType <- "";
login <- "";
enableOAuth <- true;
baseUrl <-"https://cloud-api.yandex.net/v1/disk/resources/";

function base64Encode(input) {
	local keyStr = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";
    local output = "";
    local chr1, chr2, chr3, enc1, enc2, enc3, enc4;
    local i = 0;
	local len = input.len() ;

    while ( i < len ) {

        chr1 = input[i++];
		if ( i< len) {
			chr2 = input[i++];
		} else {
			chr2 = 0;
		}
		if ( i < len ) {
			chr3 = input[i++];
		} else {
			chr3 = 0;
		}

        enc1 = chr1 >> 2;
        enc2 = ((chr1 & 3) << 4) | (chr2 >> 4);
        enc3 = ((chr2 & 15) << 2) | (chr3 >> 6);
        enc4 = chr3 & 63;

        if (chr2 == 0) {
            enc3 = enc4 = 64;
        } else if (chr3 == 0) {
            enc4 = 64;
        }
		//print("enc1=" + enc1 + " enc2=" + enc2 + " enc3=" + enc3);
        output = output + format("%c", keyStr[enc1] ) + 
			format ( "%c", keyStr[enc2]) 
			+ format("%c", keyStr[enc3])
			+ format("%c", keyStr[enc4]);
    }

    return output;
}

function inputBox(prompt, title) {
	try {
		return InputDialog(prompt, "");
	}catch (e){}
	local tempScript = "%temp%\\imguploader_inputbox.vbs";
	prompt = reg_replace(prompt, "\n", "\" ^& vbCrLf ^& \"" );
	local tempOutput = getenv("TEMP") + "\\imguploader_inputbox_output.txt";
	local command = "echo result = InputBox(\""+ prompt + "\", \""+ title + "\") : Set objFSO=CreateObject(\"Scripting.FileSystemObject\") : Set objFile = objFSO.CreateTextFile(\"" + tempOutput + "\",True) : objFile.Write result : objFile.Close  > \"" + tempScript + "\"";
	system(command);
	command = "cscript /nologo \"" + tempScript + "\"";// > \"" + tempOutput + "\"";*/
	system(command);
	local res = readFile(tempOutput);
	system("rm \""+ tempOutput + "\"");
	return res;
}

function regex_simple(data,regStr,start)
{
	local ex = regexp(regStr);
	local res = ex.capture(data, start);
	local resultStr = "";
	if(res != null){	
		resultStr = data.slice(res[1].begin, res[1].end);
	}
		return resultStr;
}


function reg_replace(str, pattern, replace_with)
{
	local resultStr = str;	
	local res;
	local start = 0;

	while( (res = resultStr.find(pattern,start)) != null ) {	

		resultStr = resultStr.slice(0,res) +replace_with+ resultStr.slice(res + pattern.len());
		start = res + replace_with.len();
	}
	return resultStr;
}

function _WriteLog(type,message) {
	try {
		WriteLog(type, message);
	} catch (ex ) {
		print(type + " : " + message);
	}
}

function checkResponse() {
	if ( nm.responseCode() == 0 || (nm.responseCode() >= 400 && nm.responseCode() <= 499)) {
		_WriteLog("error", "Response code " + nm.responseCode() + "\r\n" + nm.errorString() );
		return 0;
	}
	return 1;
}


function isSuccessCode(code) {
	return ( code >= 200 && code < 300);
}


function getAuthorizationString() {
	return "OAuth " + token;
}

function msgBox(text) {
	try {
		DebugMessage(text, false);
		return true;
	}catch(ex) {
	}
	local tempScript = "%temp%\\imguploader_msgbox.vbs";
	system("echo Set objArgs = WScript.Arguments : messageText = objArgs(0) : MsgBox messageText > \"" + tempScript + "\"");
	system("cscript \"" + tempScript + "\" \"" + text + "\"");
	system("del /f /q \"" + tempScript + "\"");
	
	
	return true;
}


function internal_parseAlbumList(data,list,parentid)
{
	local start = 0;
	
	while(1)
	{
		local title="",id="",summary="";
		local response = "";
		
		start += response.len();
		local ex = regexp("<d:response>");
		local res = ex.search(data, start);
		local link = "";
		local album = CFolderItem();
		if(res != null){	
			start = res.end;
			ex = regexp("</d:response>");
			res = ex.search(data, start);
			if ( res != null){
				response = data.slice(start, res.end);
				local href = regex_simple(response,"<d:href>(.+)</d:href>",0);
				
				local resourceType =  regex_simple(response,"<d:resourcetype>(.+)</d:resourcetype>",0); 
				if ( regex_simple(response, "(d:collection)", 0) != "") {
					local displayName = regex_simple(response,"<d:displayname>(.+)</d:displayname>",0);
					album.setId(href);
					if ( href == "/" ) {
						displayName += " (/)";
					}
					album.setTitle(displayName);
					album.setSummary("");
					list.AddFolderItem(album);
				}
			} 	else {
				break;
			}
		}
		else break;	
	}
	return 1;
}

function internal_loadAlbumList(list)
{
	if(token == "")
	{
		if(!DoLogin())
			return 0;
	}
	
	if ( useRestApi() ) {
		local url = "https://cloud-api.yandex.net:443/v1/disk/resources?path=%2F&limit=100";
		nm.addQueryHeader("Authorization",getAuthorizationString());
		nm.addQueryHeader("Accept", "application/json");
		nm.doGet(url);
		if ( nm.responseCode() == 200 ) {
			local folder = CFolderItem();
			folder.setId("/");
			folder.setTitle("/ (root)");
			folder.setSummary("");
			list.AddFolderItem(folder);
			local res = ParseJSON(nm.responseBody());
			local itemsCount = res._embedded.items.len();
			for ( local i = 0; i< itemsCount; i++ ) {
				local item = res._embedded.items[i];
				if ( item.type != "dir" ) {
					continue;
				}
				local folder = CFolderItem();
				local path = item.path;
				path = reg_replace(path, "disk:", "") + "/";
				folder.setId(path);
				folder.setTitle(item.name);
				folder.setSummary("");
				list.AddFolderItem(folder);
			}
			return 1;
		}
		return 0;
	}
	
	local url = "https://webdav.yandex.ru/";
	
	nm.setUrl(url);
	nm.addQueryHeader("Authorization",getAuthorizationString());
	nm.addQueryHeader("Connection", "close");
	nm.addQueryHeader("Depth", "1");
	nm.setMethod("PROPFIND");
	nm.doGet(url);

	if ( isSuccessCode(nm.responseCode()) ) {
		return internal_parseAlbumList(nm.responseBody(), list,"");
	} else if ( nm.responseCode() == 401 ) {
			msgBox("Authentication failed for username '" + ServerParams.getParam("Login") + "'.\r\nResponse code: "+ nm.responseCode());
		return 0;
	} 
	
	return 0;
	
}

function GetFolderList(list)
{
	/*if(token == "")
	{
		if(!DoLogin())
			return 0;
	}*/

	return internal_loadAlbumList(list);
}


function CreateFolder(parentAlbum,album)
{
	if(token == "")
	{
		if(!DoLogin())
			return 0;
	}
	local folderName = album.getTitle();
	if ( folderName == "" ) {
		return 0;
	}
	local url = "https://webdav.yandex.ru/" + nm.urlEncode(folderName);
	
	nm.setUrl(url);
	nm.addQueryHeader("Authorization",getAuthorizationString());
	nm.addQueryHeader("Connection", "close");
	nm.addQueryHeader("Depth", "1");
	nm.setMethod("MKCOL");
	nm.doGet(url);
	
	if(nm.responseCode() != 201) // HTTP Status code 201 = Created
		return 0;
	
	return 1;
}

function getAuthentificationErrorString(code) {
	return "Authentication failed for username '" + ServerParams.getParam("Login") + "'.\r\nResponse code: "+code ;
}

function checkIfExists(filename){
	local url = "https://webdav.yandex.ru" + filename;
	
	nm.setUrl(url);
	nm.addQueryHeader("Authorization",getAuthorizationString());
	nm.addQueryHeader("Connection", "close");
	nm.addQueryHeader("Depth", "1");
	nm.addQueryHeader("Content-Type", "application/xml"); 
	nm.setMethod("PROPFIND");
	nm.doUpload("", "<?xml version=\"1.0\" encoding=\"utf-8\"?>" + 
					"<propfind xmlns=\"DAV:\">"+
					"<prop>"+
					"<myprop xmlns=\"mynamespace\"/>"+
					"</prop>"+
					"</propfind>"
					);
					
	if ( nm.responseCode() == 401 ) {
		throw getAuthentificationErrorString(nm.responseCode());
		return 0;
	}
	return ( nm.responseCode() >= 200 && nm.responseCode() < 300);
}

function checkResponseCode() {
	if ( !isSuccessCode(nm.responseCode()) ) {
		local errorMessage = "";
		if ( nm.responseCode() == 401 ) {
			errorMessage += "Authentication failed for username '" + ServerParams.getParam("Login") + "'.";
		} else {
			errorMessage += "\r\nResponse: " + nm.responseBody();
		}
		
		errorMessage  += "\r\nResponse code: "+ nm.responseCode();
		throw errorMessage;
	} 
}

function useRestApi() {
	local l = ServerParams.getParam("useWebdav");
	return (l == "") || ( l != "true" && l != "yes" && l != "1");
}
function openUrl(url) {
	try{
		return ShellOpenUrl(url);
	}catch(ex){}

	system("start "+ reg_replace(url,"&","^&") );
}


function DoLogin() 
{ 
	if ( enableOAuth ) {
		token = ServerParams.getParam("token");
	    	tokenType = ServerParams.getParam("tokenType");
		if ( token != "" && ServerParams.getParam("PrevLogin") == ServerParams.getParam("Login") ) {
			if ( tokenType == "oauth" ) {
				local OAuthLogin = ServerParams.getParam("OAuthLogin");
				if ( OAuthLogin != "") {
					login = OAuthLogin;
				}
			}
			return 1;
		}
		openUrl("https://oauth.yandex.ru/authorize?response_type=code&client_id=a49c34035aa8418d9a77ff24e0660719");
		
	    	local confirmCode = inputBox("You need to need to sign in to your Yandex.Disk account in web browser which just have opened and then copy confirmation code into the text field below. Please enter confirmation code:", "Image Uploader - Enter confirmation code");
		if ( confirmCode != "" ) {	
			nm.setUrl("https://oauth.yandex.ru/token");
			nm.addQueryParam("grant_type", "authorization_code");
			nm.addQueryParam("code", confirmCode);
			//nm.addQueryParam("client_id", "28d8d9c854554812ad8b60c150375462");
			//nm.addQueryParam("client_secret", "7d6fee42d583498ea7740bcf8b753197");
			nm.addQueryParam("client_id", "a49c34035aa8418d9a77ff24e0660719");
			nm.addQueryParam("client_secret", "f9496665e3494022a00b7dbe9a5f0d9e");
			nm.doPost("");

			if ( !checkResponse() ) {
				return 0;
			}
				
			local accessToken = regex_simple(nm.responseBody(), "access_token\": \"(.+)\",", 0);
			if ( accessToken != "" ) {
				
				token = 	accessToken;
				tokenType = "oauth";
				ServerParams.setParam("token", token);
				ServerParams.setParam("tokenType", tokenType);
				ServerParams.setParam("PrevLogin", ServerParams.getParam("Login"));
			
				return 1;
			} else {
				_WriteLog("error", "Unable to get OAuth token!");
				return 0;
			}
		}
	}
	
 	
	login <- ServerParams.getParam("Login");
	local pass =  ServerParams.getParam("Password");

	if(login == "" || pass=="")
	{
		_WriteLog("error","E-mail and password should not be empty!");
		return 0;
	}
	
	return 0; //Success login
} 

function  UploadFile(FileName, options)
{
	if(token == "")
		{
			if(!DoLogin())
				return 0;
		}
	local ansiFileName = ExtractFileName(FileName);
	//ansiFileName = reg_replace(ansiFileName, " ","_");
	

	local folder = options.getFolderID();
	if ( folder == "" ) {
		folder = "/";
	}
	
	local initialRemotePath = folder + (ansiFileName); 
	local remotePath = initialRemotePath; 
	remotePath = folder + (ansiFileName);
	local i = 2;

	
	if ( useRestApi() ) {
		local url = baseUrl + "upload/?path="+nm.urlEncode(remotePath);

		nm.addQueryHeader("Accept", "application/json");
		nm.addQueryHeader("Authorization",getAuthorizationString());
		try {
			nm.enableResponseCodeChecking(false);
		} catch ( ex ) {} 
		nm.doGet(url);
		while ( nm.responseCode() == 409 ) {
			local ext = GetFileExtension(ansiFileName);
			local suffix = i.tostring();
			if ( i > 5 ) {
				suffix = md5( random().tostring()).slice(0,4);
			}		
			local filename = ansiFileName.slice(0,ansiFileName.len()-ext.len()-1) + "_" + suffix;
			
			if ( ext.len() ) {
				filename += "." + ext;
			}
			remotePath = folder + filename;
			nm.setUrl(baseUrl + "upload/?path="+nm.urlEncode(remotePath));
			nm.addQueryHeader("Accept", "application/json");
			 
			nm.addQueryHeader("Authorization",getAuthorizationString());
			try {
				nm.enableResponseCodeChecking(false);
			} catch ( ex ) {} 
			nm.doGet("");
			i++;
			if ( i > 10 ) {
				return 0;
			}
		
		}	
		
		try {
			nm.enableResponseCodeChecking(true);
		} catch ( ex ) {} 
	
		if ( nm.responseCode() == 200 ) {
			local data = nm.responseBody();
			local href = null;
			local method = "PUT";
		//	DebugMessage(data,true);
			try {
				local t = ParseJSON(data);
				href = t.href;
				method = t.method;
			} catch ( ex ) {
				href = regex_simple(data, "href\":\"(.+)\"", 0);
			}
			
			if ( href == null || href == "" ) {
				return 0;
			}
			nm.setUrl(href);
			nm.setMethod(method);
			nm.addQueryHeader("Authorization",getAuthorizationString());
			nm.doUpload(FileName, "");
			if ( nm.responseCode() != 201 ) {
				_WriteLog("error", "Failed to upload file " + ExtractFileName(FileName)+".");
				return 0;
			}
			nm.setUrl(baseUrl + "publish?path=" + nm.urlEncode(remotePath));
			nm.addQueryHeader("Accept", "application/json");
			//nm.addQueryHeader("Content-Length", "0");
			nm.addQueryHeader("Transfer-Encoding", "");
			nm.addQueryHeader("Authorization",getAuthorizationString());
			nm.setMethod("PUT");
			nm.doGet("","");
			//nm.doPost("test1");
			//_WriteLog("error", nm.responseCode().tostring());
			//_WriteLog("error", nm.responseBody());
			if ( nm.responseCode() == 200 ) {
				local viewUrl = "";
				
				try {
					local t = ParseJSON(nm.responseBody());
					href = t.href;
					method = t.method;
				} catch ( ex ) {
					href = regex_simple(data, "href\":\"(.+)\"", 0);
					method = "GET";
				}
				nm.setMethod(method);
				nm.addQueryHeader("Authorization",getAuthorizationString());
				nm.doGet("https://cloud-api.yandex.net:443/v1/disk/resources?path=" + nm.urlEncode(remotePath));
				//DebugMessage(nm.responseBody(),true);
				if ( nm.responseCode() == 200 ) {
					try {
						local t = ParseJSON(nm.responseBody());
						viewUrl = t.public_url;
					} catch ( ex ) {
						viewUrl = regex_simple(data, "public_url\":\"(.+)\"", 0);
					}
					options.setViewUrl(viewUrl);
					return 1;
				}
				
			}
			
		}
		return 0;
	}
		try {
	while ( checkIfExists( remotePath) ) {
		local ext = GetFileExtension(ansiFileName);
		local suffix = i.tostring();
		if ( i > 2 ) {
			suffix = md5( random().tostring()).slice(0,4);
		}		
		local filename = ansiFileName.slice(0,ansiFileName.len()-ext.len()-1) + "_" + suffix;
		
		if ( ext.len() ) {
			filename += "." + ext;
		}
		remotePath = folder + nm.urlEncode(filename);
		i++;
		
	}	
	local url = "https://webdav.yandex.ru" + remotePath;
	nm.setUrl(url);
	nm.addQueryHeader("Authorization",getAuthorizationString());
	nm.addQueryHeader("Expect","100-continue");
	nm.addQueryHeader("Connection", "close");
	nm.addQueryHeader("Content-Type", "application/binary"); 
	nm.setMethod("PUT");
	nm.doUpload(FileName, "");
	checkResponseCode();
	
	//url = "https://webdav.yandex.ru" + remotePath;
	nm.setUrl(url);
	nm.setMethod("PROPPATCH");
	
	
	nm.addQueryHeader("Authorization",getAuthorizationString());
	nm.addQueryHeader("Content-Type","application/xml");
	local data = "<?xml version=\"1.0\" encoding=\"utf-8\"?>" + 
		"<propertyupdate xmlns=\"DAV:\">" +
		"<set>"+
		"<prop>" +
		"<public_url xmlns=\"urn:yandex:disk:meta\">true</public_url>" +
		"</prop>"  +
		"</set>"     + 
		"</propertyupdate>";
	nm.doUpload("", data);
	checkResponseCode();
	//print(nm.responseBody());			
	local data = nm.responseBody();
	
	local viewUrl = regex_simple(data,"<public_url xmlns=\"urn:yandex:disk:meta\">(.+)</public_url>",0);
	
	options.setViewUrl(viewUrl);
	} catch ( ex ) {
		//msgBox(ex.tostring());
		_WriteLog("error", "Exception:" + ex.tostring());
		return 0;
	}
	
	return 1;
}

function GetFolderAccessTypeList()
{
	local a=["Приватный", "Для всех"];
	return a;
}

/*function GetServerParamList()
{
	return 
	{
		useWebdav = "Use WebDav",
		token = "Token",
		enableOAuth ="enableOAuth",
		tokenType = "tokenType",
		PrevLogin = "PrevLogin",
		OAuthLogin = "OAuthLogin"
		
	};
}*/