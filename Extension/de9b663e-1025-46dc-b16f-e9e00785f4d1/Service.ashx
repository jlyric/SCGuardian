<%@ WebHandler Language="C#" Class="Service" %>

using System;
using System.Linq;
using System.Text.RegularExpressions;
using Elsinore.ScreenConnect;

public class Service : WebServiceBase
{

	public object ConsoleConnectionStatus(string integrationKey, string sessionID) {

		if( integrationKey != ExtensionContext.Current.GetSettingValue("IntegrationKey") )
			return "Incorrect Integration Key";

		var session = SessionManagerPool.Demux.DemandSession(new Guid(sessionID));
		return session.ActiveConnections.Any();
	}

	public object FindSession(string integrationKey, string name) {

			if( integrationKey != ExtensionContext.Current.GetSettingValue("IntegrationKey") )
				return "Incorrect Integration Key";

		var session = SessionManagerPool.Demux.GetSessions().FirstOrDefault(s => s.Name == name);

		if (session == null)
			return false;

		return session.SafeNav(s => s.SessionID);
	}

	protected override bool ShouldAllowOrigin(string originString)
	{
		return base.ShouldAllowOrigin(originString) || Regex.IsMatch(originString, "https?://([^/]+\\.)?" + Regex.Escape(ExtensionContext.Current.GetSettingValue("AllowedOrigin")) + "(:\\d+)?(/.*)?");
	}
}
