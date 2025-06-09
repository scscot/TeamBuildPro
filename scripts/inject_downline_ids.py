from firebase_admin import credentials, firestore, initialize_app

# Initialize Firebase Admin SDK
cred = credentials.Certificate("../secrets/serviceAccountKey.json")  # Adjust path if needed
initialize_app(cred)
db = firestore.client()

# Admin UID
admin_uid = "KJ8uFnlhKhWgBa4NVcwT"

# downlineIds array
downline_ids = [
    "003bdd1a-4033-4eab-8c44-c7b83d3bd00b", "019a3d6c-5722-4bfa-8db6-35b19a498d56",
    "02e89ca2-6a5d-4676-953b-fa565967db4c", "04b46dad-1f1c-47a9-96d4-b5dccc8dffe4",
    "054583cc-dc12-482e-ae1c-d180a4909b2e", "06381390-cb58-4f21-a8a9-dceec57b8457",
    "08483826-9bfa-43e2-ab90-ff747639f680", "0fe2a607-7add-4cb2-bed6-e737ba54c0df",
    "109fee41-ae18-4520-9fc0-de38e3004d36", "1793d4d2-7bd9-4dbd-85a2-0dc264639b09",
    "1856a02d-1567-4754-8216-fcf96c408dd2", "1c2604f7-922e-4028-b9fd-f342d2ac901f",
    "23125bff-11f2-4abd-aa0b-ed5d9f0db7f4", "237d505d-f692-4ecb-a232-5d9a3b347ee4",
    "287c58aa-0114-4224-87a6-ea0b079cbb21", "3299733e-990c-459f-a659-9e779481a484",
    "387449ad-e4f1-44ac-9f31-fdbbfb447c1c", "3b72d049-43f5-402f-be21-d075326ed810",
    "3e0ee2c7-984a-467c-8287-73a08d863461", "4046c80c-d1b8-47f9-9267-a3a9ba3bb68f",
    "40c29e68-f1ea-4f06-961c-0634ae9a1579", "45c2a2ba-60e3-4c45-b3ef-e10cda1d0d1f",
    "4b591d80-2cf0-4baa-a572-d9932d26b334", "512a3ee0-9478-4cfe-b4f8-f85fc54ef082",
    "560d9623-d4e7-4318-b9b7-7737a3721084", "569e5c8b-4c5c-43c7-a070-a2a9b1f176c4",
    "5fd57624-ea5d-4624-83bb-1fb5c41fb154", "67b21f86-6f9a-46da-aa56-85ff09ae88f3",
    "68106fa0-f386-47e1-92f3-bdb57d52a527", "68fc538e-a586-4e84-8fb7-b19401d1f99f",
    "6ea43379-604c-41f7-934e-cb075c59a6fa", "74eda072-5887-42e0-ace4-3fd66824afeb",
    "762e2ea2-2ae1-42f9-8728-c43852f5c1ae", "76c677e0-9239-4a4b-aff1-fb46f4d8f6bf",
    "7d7cfe51-2993-4ac8-831d-97945b27364e", "7fed16b3-30f6-45a5-8676-76e3fe433870",
    "81a9301d-4619-4249-b43d-f161a9170cc2", "82040581-e020-4c7d-8842-24711aa485fe",
    "82fd7e8c-86bb-4011-951b-cb7e95ba9e54", "874ae26e-458f-4c83-a720-d9b4035ec4c6",
    "8771ed38-08f0-4259-9e49-5c7c1a6d4504", "8a916abc-0205-4d4a-83d4-f4c3431744ad",
    "8ebf30fa-c584-402d-828f-2dffd98f6f16", "9090d2da-bd69-46e2-88a0-48aab8e30ae6",
    "941f259d-2934-4b7b-b532-030737ea1378", "95c99698-4fc3-45af-9ac1-0caf136a0c2a",
    "966785c6-403a-4f3e-a844-df4a0f972859", "98ba3fa7-f89f-4490-845d-b55d23d7a94d",
    "9aeca617-a084-4a16-9858-198955ee1e10", "9da939d5-3570-43ef-b776-3e86b4fe0e24",
    "a5784ccf-c94a-441c-b01e-506f94b5cd06", "a5c5fc3c-a032-415f-9af9-b063750fa9b6",
    "a9cae7d3-caa6-4477-99da-60f7c30e347f", "aaab5d61-2e8a-45ce-8151-05f193472b1b",
    "ac7fdbc8-7da6-4aad-965c-5c1bfc82d825", "b0cdb465-c994-459d-a21f-fa6bf4a6f900",
    "b255f3b9-f5fe-483b-83a9-18d7d31a0eee", "b2c32995-acf4-4b1f-a974-ef481347dd84",
    "b3416646-f49e-4cc3-b8a2-b959ef189610", "b809e738-463f-4c9a-bde5-ba9abe375caf",
    "b9bc5052-b9ed-491d-aa4a-1f82d7abcf37", "bbaf8dd8-a08a-4326-929e-1e482ff28ab5",
    "bf8f9409-56ce-4e06-83f2-560779e3da58", "caab5390-191e-43a5-9ee7-f31e35e6101f",
    "cba6eca8-65fb-4227-a354-76960b8d3448", "d33c10cf-6ebb-481a-a3b6-66f5d2a222aa",
    "d5e8e87c-c43f-4805-a9e0-9d7f7c7ee326", "d7d0026e-37aa-448b-91b0-058662624833",
    "db83ca72-aa3b-42eb-91a9-1396bf56ffa6", "df99416f-e496-4342-9e75-8a0b857846d5",
    "e2906ff0-4679-4fec-8246-8b902de029f7", "e4493f12-612e-4ba6-8168-b6763908382c",
    "e469ed94-1980-4a95-86f9-3f2d619ab194", "e6c1e2e4-605a-40f1-ab10-958bd8c5f2a7",
    "ea411a16-4ebd-4008-a5b6-e1127f4fdbac", "ec35456d-5de1-4089-b363-6d961d156cdd",
    "ee116189-fa3b-4acd-bbd5-1822948d883d", "ee362f4c-7e5a-46dc-a8c6-8d582d8834ec",
    "f00b768c-38f2-4490-adbb-32864427c869", "f0a219c1-3687-426b-8598-7fb2492c1418",
    "f88c533b-0270-4cf3-9be0-0237287a637c", "f948e34a-fc93-4554-ab35-a88e0fbb2a85",
    "f9cdb430-46bf-4496-a220-2fc56951c0e0", "fb72b0b4-6c71-436e-994a-048a0ba04c15",
    "fe0cd676-70fd-4207-952e-e04f05dbd845"
]

# Update the Firestore document
doc_ref = db.collection("users").document(admin_uid)
doc_ref.update({"downlineIds": downline_ids})
print("✅ downlineIds successfully injected.")
