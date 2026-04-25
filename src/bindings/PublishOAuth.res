type config

@obj external makeConfig: (~publishBaseUrl: string) => config = ""

@module("../js/PublishOAuth.mjs")
external runPublishAuth: config => promise<PublishAuthTypes.authIdentity> = "runPublishAuth"
