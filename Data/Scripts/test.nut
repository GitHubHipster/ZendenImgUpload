

function OnLoadFinished(data) {
	//local doc = data.browser.document();
	
	//data.browser.runJavaScript("document.getElementById('submit_approve_access').disabled=false");
	/*data.browser.runJavaScript("var script = document.createElement('script');"+
		"script.src = 'http://ie7-js.googlecode.com/svn/version/2.1(beta4)/IE8.js';"+
		"document.getElementsByTagName('head')[0.appendChild(script);");*/
}



function OnFileInputFilledCallback(data) {

}

function OnTimer(data) {
	
}

function  UploadFile(FileName, options)
{
	local login = ServerParams.getParam("Login");
	local scope = "https://www.googleapis.com/auth/drive";
	local redirectUrl = /*"urn:ietf:wg:oauth:2.0:oob"*/"http://localhost:8080";
	local clientSecret = "65ie-G5nWqGMv_THtY3z2snZ";
	local clientId = "162038470312-dn0kut9j7l0cd9lt32r09j0c841goei9.apps.googleusercontent.com";
	local webBrowser = CWebBrowser();

	webBrowser.setSilent(false);
	webBrowser.addTrustedSite("http://ie7-js.googlecode.com");
	//return -1;
	local url = "https://accounts.google.com/o/oauth2/auth?scope="+ nm.urlEncode(scope) +"&redirect_uri="+nm.urlEncode(redirectUrl)+"&response_type=code&"+ "client_id="+clientId;
	ShellOpenUrl(url);
	return -1;
	webBrowser.setOnLoadFinishedCallback(OnLoadFinished, null);
	
	webBrowser.navigateToUrl(url);
	//webBrowser.setOnFileInputFilled*Callback(OnFileInputFilledCallback, null);

	//webBrowser.exec();
	webBrowser.showModal();
	return -1;
}
