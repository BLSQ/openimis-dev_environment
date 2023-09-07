#!/bin/bash
# This is a script to reproduce the usage of the C# Rest API made by the
# claims mobile app

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

SESSION_DIR="${SCRIPT_DIR}/cs_rest_api_mobile_pact_session"

[[ ! -d $SESSION_DIR ]] && mkdir "$SESSION_DIR"

# Test if the backend is reachable/available
API_URL="http://localhost"
BASE_URL="${API_URL}/rest/api"

curl -sI "${BASE_URL}/" | grep 502 >/dev/null && {
  echo "C# REST API service is not reachable at localhost:80."
  echo "Please check that it is properly running with \`./run.sh status\`. You"
  echo "can enable it with \`./run.sh enable restapi\`. Then run it with"
  echo "\`./run.sh warmup\`."
  exit 1
}

# In claim mobile app
# login and retrieve JWT
echo "login"
curl -sX POST "${BASE_URL}/login" \
  -H "accept: application/json" \
  -H "api-version: 3" \
  -H "Content-Type: application/json" \
  -d @"${SCRIPT_DIR}/cs_rest_api_mobile_pact_files/authenticate.json" \
  -o "${SESSION_DIR}/login_response.json"

token=$(sed -e "s/.*access_token\":\"\(.*\)\",\"expires_on.*/\1/" "${SESSION_DIR}/login_response.json")

echo "get feedback report"
curl -sX POST "${BASE_URL}/report/feedback" \
  -H "accept: application/json" \
  -H "Authorization: Bearer ${token}" \
  -H "api-version: 3" \
  -H "Content-Type: application/json" \
  -d '{  "fromDate": "2017-01-01T01:00:00.00Z",  "toDate": "2023-12-31T23:00:00.000Z"}' \
  -o "${SESSION_DIR}/report_feedback.json"

echo "get enrollment report"
curl -sX POST "${BASE_URL}/report/enrolment" \
  -H "accept: application/json" \
  -H "Authorization: Bearer ${token}" \
  -H "api-version: 3" \
  -H "Content-Type: application/json" \
  -d '{  "fromDate": "2017-01-01T01:00:00.00Z",  "toDate": "2023-12-31T23:00:00.000Z"}' \
  -o "${SESSION_DIR}/report_enrolment.json"

echo "get renewal report"
curl -sX POST "${BASE_URL}/report/renewal" \
  -H "accept: application/json" \
  -H "Authorization: Bearer ${token}" \
  -H "api-version: 3" \
  -H "Content-Type: application/json" \
  -d '{  "fromDate": "2017-01-01T01:00:00.00Z",  "toDate": "2023-12-31T23:00:00.000Z"}' \
  -o "${SESSION_DIR}/report_renewal.json"

echo "get snapshot indicators report"
curl -sX POST "${BASE_URL}/report/indicators/snapshot" \
  -H "accept: application/json" \
  -H "Authorization: Bearer ${token}" \
  -H "api-version: 3" \
  -H "Content-Type: application/json" \
  -d '{  "snapshotDate": "2023-08-18" }' \
  -o "${SESSION_DIR}/report_snapshot_policies.json"

echo "get cumulative indicators report"
curl -sX POST "${BASE_URL}/report/indicators/cumulative" \
  -H "accept: application/json" \
  -H "Authorization: Bearer ${token}" \
  -H "api-version: 3" \
  -H "Content-Type: application/json" \
  -d '{  "fromDate": "2017-01-01",  "toDate": "2023-12-31"}' \
  -o "${SESSION_DIR}/report_cumulative_policies.json"

echo "get master data"
curl -sX GET "${API_URL}/tools/extracts/download_master_data" \
  -o "${SESSION_DIR}/master_data.zip"

insuree_chfid="105000002"
echo "get insuree enquire"
curl -sX GET "${BASE_URL}/insuree/${insuree_chfid}/enquire" \
  -H "accept: application/json" \
  -H "Authorization: Bearer ${token}" \
  -H "api-version: 3" \
  -o "${SESSION_DIR}/insuree_enquire_${insuree_chfid}.json"

echo "get family"
curl -sX GET "${BASE_URL}/family/${insuree_chfid}" \
  -H "accept: application/json" \
  -H "Authorization: Bearer ${token}" \
  -H "api-version: 3" \
  -H "Content-Type: application/json" \
  -o "${SESSION_DIR}/family.json"

# create family (broken)
echo "create / modify family (broken)"
curl -sX POST "${BASE_URL}/family/" \
  -H "accept: application/json" \
  -H "Authorization: Bearer ${token}" \
  -H "api-version: 3" \
  -H "Content-Type: application/json" \
  -d @"${SCRIPT_DIR}/cs_rest_api_mobile_pact_files/new_family.json" \
  -o "${SESSION_DIR}/created_family.json"

curl -sX POST "${BASE_URL}/Locations/GetOfficerVillages" \
  -H "accept: application/json" \
  -H "Authorization: Bearer ${token}" \
  -H "api-version: 3" \
  -H "Content-Type: application/json" \
  -d '{"enrollment_officer_code": "E00001"}' \
  -o "${SESSION_DIR}/officer_villages.json"

echo "create policy renewal"
curl -sX POST "${BASE_URL}/policy/renew" \
  -H "accept: application/json" \
  -H "Authorization: Bearer ${token}" \
  -H "api-version: 3" \
  -H "Content-Type: application/json" \
  -d @"${SCRIPT_DIR}/cs_rest_api_mobile_pact_files/policy_renewal.json" \
  -o "${SESSION_DIR}/create_policy_renewal.json"

# if you want to get policy renewals for a given officer
# echo "login with RHOS0012"
# token_RHOS0012=$(curl -sX POST "${BASE_URL}/login" \
#   -H "accept: application/json" \
#   -H "api-version: 3" \
#   -H "Content-Type: application/json" \
#   -d '{"userName": "Admin_Fr", "password": "admin123"}' |
#   sed -e "s/.*access_token\":\"\(.*\)\",\"expires_on.*/\1/")

echo "get policy renewal"
curl -sX GET "${BASE_URL}/policy" \
  -H "accept: application/json" \
  -H "Authorization: Bearer ${token}" \
  -H "api-version: 3" \
  -H "Content-Type: application/json" \
  -o "${SESSION_DIR}/policy.json"

echo "get controls"
curl -sX GET "${BASE_URL}/claim/Controls" \
  -H "accept: application/json" \
  -H "Authorization: Bearer ${token}" \
  -H "api-version: 3" \
  -H "Content-Type: application/json" \
  -o "${SESSION_DIR}/claim_controls_response.json"

echo "get diagnoses services items"
curl -sX POST "${BASE_URL}/claim/GetDiagnosesServicesItems" \
  -H "accept: application/json" \
  -H "Authorization: Bearer ${token}" \
  -H "api-version: 3" \
  -H "Content-Type: application/json" \
  -d @"${SCRIPT_DIR}/cs_rest_api_mobile_pact_files/getpaymentlists_lastupdate.json" \
  -o "${SESSION_DIR}/claim_diagnoses_services_response.json"

# Not used in claim mobile app
echo "get claim admins"
curl -sX GET "${BASE_URL}/claim/GetClaimAdmins" \
  -H "accept: application/json" \
  -H "Authorization: Bearer ${token}" \
  -H "api-version: 3" \
  -H "Content-Type: application/json" \
  -o "${SESSION_DIR}/claim_admins.json"

grep -qw "VIHC0011" "${SESSION_DIR}/claim_admins.json" || {
  echo "VIHC0011 admin code was expected but not found in the list of claim admins"
  exit 1
}

# In claim mobile app
admin_code="VIHC0011"
echo "get payment lists"
curl -sX POST "${BASE_URL}/claim/GetPaymentLists" \
  -H "accept: application/json" \
  -H "Authorization: Bearer ${token}" \
  -H "api-version: 3" \
  -H "Content-Type: application/json" \
  -d "{  \"claim_administrator_code\": \"${admin_code}\",  \"last_update_date\": \"2000-01-01\"}" \
  -o "${SESSION_DIR}/claim_payments_reponse.json"

# Claim status:
#   Entered
#   Checked
#   Processed
#   Valuated
#   Rejected
# Only 2 claims VIHC0011 and VIDS0011 are with a null ValidityTo which is required by GetClaims StoredPRoc
echo "get claims for ${admin_code}"
curl -sX POST "${BASE_URL}/claim/GetClaims" \
  -H "accept: application/json" \
  -H "Authorization: Bearer ${token}" \
  -H "api-version: 3" \
  -H "Content-Type: application/json" \
  -d "{  \"claim_administrator_code\": \"${admin_code}\", \"status_claim\": \"Entered\", \"visit_date_from\": \"2000-01-01\",  \"visit_date_to\": \"2023-05-08\",  \"processed_date_from\": \"2000-01-01\",  \"processed_date_to\": \"2023-05-08\" }" \
  -o "${SESSION_DIR}/get_claims_reponse_${admin_code}.json"

another_admin_code="JMDP0011"
echo "get claims for ${another_admin_code}"
curl -sX POST "${BASE_URL}/claim/GetClaims" \
  -H "accept: application/json" \
  -H "Authorization: Bearer ${token}" \
  -H "api-version: 3" \
  -H "Content-Type: application/json" \
  -d "{  \"claim_administrator_code\": \"${another_admin_code}\", \"status_claim\": \"Entered\", \"visit_date_from\": \"2000-01-01\",  \"visit_date_to\": \"2023-05-08\",  \"processed_date_from\": \"2000-01-01\",  \"processed_date_to\": \"2023-05-08\" }" \
  -o "${SESSION_DIR}/get_claims_reponse_${another_admin_code}.json"

# So far, I haven't found a way to retrieve the CHFID of the insuree
# 105000002 is one associated to the 2 admincode giving back claims
insuree_chfid="105000002"
echo "get insuree enquire"
curl -sX GET "${BASE_URL}/insuree/${insuree_chfid}/enquire" \
  -H "accept: application/json" \
  -H "Authorization: Bearer ${token}" \
  -H "api-version: 3" \
  -o "${SESSION_DIR}/insuree_enquire_${insuree_chfid}.json"

# Visit Type: 'E': Emergency, 'R': Referral, 'O': Other
# ClaimCode is relative to Health Facility (HF)
# ICD: 2 A00     Cholera
# return 2010 error
echo "create claim, but does not work, this gives back an error 2010"
curl -sX POST "${BASE_URL}/claim" \
  -H "accept: application/json" \
  -H "Authorization: Bearer ${token}" \
  -H "api-version: 3" \
  -H "Content-Type: application/json" \
  -d "[  {\"details\": {\"claimDate\": \"2023-05-08\",\"hfCode\": \"JMDP001\",\"claimAdmin\": \"JMDP0011\",\"claimCode\": \"manual01\",\"chfid\": \"105000002\",\"startDate\": \"2023-05-01\",\"endDate\": \"2023-05-08\",\"icdCode\": \"A00\",\"comment\": \"This is a manual inserted claim 01\",\"total\": 0,\"visitType\": \"R\"    },    \"items\": [    ],    \"services\": [ ]  }]" \
  -o "${SESSION_DIR}/create_claim_response.json"

# this is the XML provided to the stored proc
# <Claim>
#   <Details>
#     <ClaimDate>2023-05-08</ClaimDate>
#     <HFCode>JMDP001</HFCode>
#     <ClaimAdmin>JMDP0011</ClaimAdmin>
#     <ClaimCode>manual01</ClaimCode>
#     <CHFID>105000002</CHFID>
#     <StartDate>2023-05-01</StartDate>
#     <EndDate>2023-05-08</EndDate>
#     <ICDCode>A00</ICDCode>
#     <Comment>This is a manual inserted claim 01</Comment>
#     <Total>0</Total>
#     <VisitType>R</VisitType>
#   </Details>
#   <Items />
#   <Services />
# </Claim>
# see line 25052 in fulldemo sql
# or uspRestAPIUpdateClaimFromPhone.sql

# To connect to the mssql server
#/opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P $SA_PASSWORD -d $DB_NAME
# a few useful Queries
# SELECT
#   count(i.ItemID), ca.LastName, ca.ClaimAdminCode
# FROM tblItems i
# JOIN tblClaimItems ci ON ci.ItemID = i.ItemID
# JOIN tblClaim c ON ci.ClaimID = c.ClaimID
# JOIN tblClaimAdmin ca ON c.ClaimAdminId = ca.ClaimAdminId
# GROUP BY ca.LastName, ca.ClaimAdminCode;

# SELECT
#   c.ClaimID, ca.ClaimAdminId, ca.LastName, c.ClaimStatus, ca.ClaimAdminCode,
#   c.Approved, i.CHFID
# FROM tblClaim c
# JOIN tblClaimAdmin ca ON c.ClaimAdminId = ca.ClaimAdminId
# JOIN tblInsuree i ON i.InsureeID = c.InsureeID
# WHERE ca.ClaimAdminCode IN  ('VIDS0011', 'VIHC0011');
