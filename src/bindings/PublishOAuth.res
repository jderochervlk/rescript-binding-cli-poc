@module("../js/PublishOAuth.mjs")
external runPublishAuth: unit => promise<PublishAuthTypes.authIdentity> = "runPublishAuth"

@module("../js/PublishOAuth.mjs") external runPublish: unit => promise<unit> = "runPublish"
