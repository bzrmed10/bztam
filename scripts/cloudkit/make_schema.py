#!/usr/bin/env python3
"""Writes cloudkit/Bztam.ckdb, the CloudKit schema that SwiftData's iCloud sync expects.

Run after adding a model or a stored property, then the "CloudKit schema" workflow, then Deploy in CloudKit Console.
Mapping (NSPersistentCloudKitContainer): String/UUID -> STRING, Int/Bool -> INT64, Date -> TIMESTAMP,
Codable collections -> BYTES plus <name>_ckAsset ASSET, to-one relationship -> STRING (related record name),
and CD_entityName on every record type. Fields are only ever added: Production can't drop or retype them.
"""
import pathlib

MODELS = {
    "Entry": [("id", "S"), ("kindRaw", "S"), ("amount", "I"), ("date", "T"), ("merchant", "S"), ("note", "S"),
              ("incomeSourceRaw", "S"), ("sourceRaw", "S"), ("attachmentName", "S"), ("recurringID", "S"),
              ("dartID", "S"), ("dartRound", "I"), ("splitID", "S"), ("createdAt", "T"), ("category", "S")],
    "BudgetCategory": [("id", "S"), ("key", "S"), ("name", "S"), ("symbol", "S"), ("budget", "I"), ("isFixed", "I"),
                       ("order", "I"), ("isArchived", "I"), ("periodAdjustments", "B")],
    "AppSettings": [("payday", "I"), ("onboardingDone", "I"), ("expectedIncome", "I"), ("createdAt", "T")],
    "RecurringRule": [("id", "S"), ("kindRaw", "S"), ("amount", "I"), ("merchant", "S"), ("note", "S"),
                      ("incomeSourceRaw", "S"), ("frequencyRaw", "S"), ("startDate", "T"), ("lastGenerated", "T"),
                      ("isActive", "I"), ("category", "S")],
    "Dart": [("id", "S"), ("name", "S"), ("amount", "I"), ("startDate", "T"), ("memberNames", "B"), ("meIndex", "I"),
             ("paid", "B"), ("received", "B"), ("tracksMoney", "I"), ("categoryKey", "S"), ("reminders", "I"),
             ("createdAt", "T")],
    "Friend": [("id", "S"), ("name", "S"), ("createdAt", "T")],
    "SplitBill": [("id", "S"), ("merchant", "S"), ("total", "I"), ("date", "T"), ("categoryID", "S"), ("payerID", "S"),
                  ("memberIDs", "B"), ("includesMe", "I"), ("createdAt", "T")],
    "SplitShare": [("id", "S"), ("billID", "S"), ("friendID", "S"), ("amount", "I"), ("settled", "I"),
                   ("lastSettledAt", "T")],
    "SavingsGoal": [("id", "S"), ("name", "S"), ("symbol", "S"), ("target", "I"), ("deadline", "T"), ("monthlyPlan", "I"),
                    ("order", "I"), ("isArchived", "I"), ("reachedAt", "T"), ("createdAt", "T")],
    "GoalMove": [("id", "S"), ("goalID", "S"), ("amount", "I"), ("date", "T"), ("createdAt", "T")],
}

SYS = '''        "___createTime" TIMESTAMP,
        "___createdBy"  REFERENCE,
        "___etag"       STRING,
        "___modTime"    TIMESTAMP,
        "___modifiedBy" REFERENCE,
        "___recordID"   REFERENCE QUERYABLE,'''
GRANTS = '''        GRANT WRITE TO "_creator",
        GRANT CREATE TO "_icloud",
        GRANT READ TO "_world"'''
TYPES = {"S": "STRING", "I": "INT64", "T": "TIMESTAMP"}

out = ["DEFINE SCHEMA", ""]
for name, fields in MODELS.items():
    rows = [("CD_entityName", "STRING")]
    for f, k in fields:
        rows += [(f"CD_{f}", "BYTES"), (f"CD_{f}_ckAsset", "ASSET")] if k == "B" else [(f"CD_{f}", TYPES[k])]
    out += [f"    RECORD TYPE CD_{name} (", SYS]
    out += [f"        {n:<28} {t}," for n, t in sorted(rows)]
    out += [GRANTS, "    );", ""]
out += ["    RECORD TYPE Users (", SYS, "        roles                        LIST<INT64>,",
        '        GRANT WRITE TO "_creator",', '        GRANT READ TO "_world"', "    );", ""]
path = pathlib.Path(__file__).resolve().parents[2] / "cloudkit/Bztam.ckdb"
path.write_text("\n".join(out))
print("Wrote", path)
