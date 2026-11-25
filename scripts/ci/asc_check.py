"""Prints what App Store Connect holds for the app's versions (locales, text lengths, screenshots)."""
import sys
sys.path.insert(0, __file__.rsplit("/", 1)[0])
from asc_metadata import call, BUNDLE_ID

app = call("GET", f"/apps?filter[bundleId]={BUNDLE_ID}")["data"][0]
print("App", app["id"], app["attributes"].get("name"), "primaryLocale:", app["attributes"].get("primaryLocale"))
for v in call("GET", f"/apps/{app['id']}/appStoreVersions?limit=10")["data"]:
    a = v["attributes"]
    print("Version", v["id"], a["platform"], a["versionString"], a["appStoreState"])
    for l in call("GET", f"/appStoreVersions/{v['id']}/appStoreVersionLocalizations?limit=50")["data"]:
        la = l["attributes"]
        sets = call("GET", f"/appStoreVersionLocalizations/{l['id']}/appScreenshotSets?limit=50")["data"]
        counts = {s["attributes"]["screenshotDisplayType"]: len(call("GET", f"/appScreenshotSets/{s['id']}/appScreenshots?limit=50")["data"]) for s in sets}
        print("  ", la["locale"], "desc", len(la.get("description") or ""), "kw", len(la.get("keywords") or ""), counts)
for i in call("GET", f"/apps/{app['id']}/appInfos")["data"]:
    print("AppInfo", i["id"], i["attributes"])
    for l in call("GET", f"/appInfos/{i['id']}/appInfoLocalizations?limit=50")["data"]:
        print("  ", l["attributes"]["locale"], l["attributes"].get("name"), "|", l["attributes"].get("subtitle"))

# In-app purchases and subscriptions: are they ready for TestFlight (status READY_TO_SUBMIT or later)?
for p in call("GET", f"/apps/{app['id']}/inAppPurchasesV2?limit=50").get("data", []):
    a = p["attributes"]
    locs = call("GET", f"/inAppPurchases/{p['id']}/inAppPurchaseLocalizations?limit=10").get("data", [])
    print("IAP", a.get("productId"), a.get("inAppPurchaseType"), a.get("state"), "familySharable:", a.get("familySharable"),
          "locales:", [l["attributes"].get("locale") for l in locs])
for g in call("GET", f"/apps/{app['id']}/subscriptionGroups?limit=10").get("data", []):
    print("Subscription group", g["attributes"].get("referenceName"))
    for s in call("GET", f"/subscriptionGroups/{g['id']}/subscriptions?limit=10").get("data", []):
        a = s["attributes"]
        locs = call("GET", f"/subscriptions/{s['id']}/subscriptionLocalizations?limit=10").get("data", [])
        print("  SUB", a.get("productId"), a.get("subscriptionPeriod"), a.get("state"), "locales:", [l["attributes"].get("locale") for l in locs])
