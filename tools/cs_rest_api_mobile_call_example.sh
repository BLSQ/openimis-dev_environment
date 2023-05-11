#!/bin/bash
# This is a script to reproduce the usage of the C# Rest API made by the
# claims mobile app

# another login
# curl -X POST "http://localhost/api/login" -H "accept: application/json" -H "api-version: 3" -H "Content-Type: application/json" -d "{  \"userName\": \"JMDP0011\",  \"password\": \"JMDP0011JMDP0011\"}" -o login_response.json
# token=$(cat login_response.json | sed -e "s/.*access_token\":\"\(.*\)\",\"expires_on.*/\1/")

# In claim mobile app
curl -X POST "http://localhost/api/login" -H "accept: application/json" -H "api-version: 3" -H "Content-Type: application/json" -d "{  \"userName\": \"Admin\",  \"password\": \"admin123\"}" -o login_response.json
token=$(cat login_response.json | sed -e "s/.*access_token\":\"\(.*\)\",\"expires_on.*/\1/")
curl -X GET "http://localhost/api/claim/Controls" -H "accept: application/json" -H "Authorization: Bearer ${token}" -H "api-version: 3" -o claim_controls_response.json
curl -X POST "http://localhost/api/claim/GetDiagnosesServicesItems" -H "accept: application/json" -H "Authorization: Bearer ${token}" -H "api-version: 3" -H "Content-Type: application/json-patch+json" -d "{  \"last_update_date\": \"2000-01-01\"}" -o claim_diagnoses_services_response.json
# Not used in claim mobile app
curl -X GET "http://localhost/api/claim/GetClaimAdmins" -H "accept: application/json" -H "Authorization: Bearer ${token}" -H "api-version: 3" -o claim_admins.json
grep -qw "VIHC0011" claim_admins.json || {
  echo "VIHC0011 admin code was expected"
  exit 1
}
# In claim mobile app
admin_code="VIHC0011"
curl -X POST "http://localhost/api/claim/GetPaymentLists" -H "accept: application/json" -H "Authorization: Bearer ${token}" -H "api-version: 3" -H "Content-Type: application/json" -d "{  \"claim_administrator_code\": \"${admin_code}\",  \"last_update_date\": \"2000-01-01\"}" -o claim_payments_reponse.json
# Claim status:
#   Entered
#   Checked
#   Processed
#   Valuated
#   Rejected
# Only 2 claims VIHC0011 and VIDS0011 are with a null ValidityTo which is required by GetClaims StoredPRoc
curl -X POST "http://localhost/api/claim/GetClaims" -H "accept: application/json" -H "Authorization: Bearer ${token}" -H "api-version: 3" -H "Content-Type: application/json" -d "{  \"claim_administrator_code\": \"${admin_code}\", \"status_claim\": \"Entered\", \"visit_date_from\": \"2000-01-01\",  \"visit_date_to\": \"2023-05-08\",  \"processed_date_from\": \"2000-01-01\",  \"processed_date_to\": \"2023-05-08\" }" -o get_claims_reponse.json
curl -X POST "http://localhost/api/claim/GetClaims" -H "accept: application/json" -H "Authorization: Bearer ${token}" -H "api-version: 3" -H "Content-Type: application/json" -d "{  \"claim_administrator_code\": \"JMDP0011\", \"status_claim\": \"Entered\", \"visit_date_from\": \"2000-01-01\",  \"visit_date_to\": \"2023-05-08\",  \"processed_date_from\": \"2000-01-01\",  \"processed_date_to\": \"2023-05-08\" }"

# So far, I haven't found a way to retrieve the CHFID of the insuree
# 105000002 is one associated to the 2 admincode giving back claims
curl -X GET "http://localhost/api/insuree/105000002/enquire" -H "accept: application/json" -H "Authorization: Bearer ${token}" -H "api-version: 3" -o insuree_enquire.json

# Visit Type: 'E': Emergency, 'R': Referral, 'O': Other
# ClaimCode is relative to Health Facility (HF)
# ICD: 2 A00     Cholera
# return 2010 error
curl -X POST "http://localhost/api/claim" -H "accept: application/json" -H "Authorization: Bearer ${token}" -H "api-version: 3" -H "Content-Type: application/json" -d "[  {\"details\": {\"claimDate\": \"2023-05-08\",\"hfCode\": \"JMDP001\",\"claimAdmin\": \"JMDP0011\",\"claimCode\": \"manual01\",\"chfid\": \"105000002\",\"startDate\": \"2023-05-01\",\"endDate\": \"2023-05-08\",\"icdCode\": \"A00\",\"comment\": \"This is a manual inserted claim 01\",\"total\": 0,\"visitType\": \"R\"    },    \"items\": [    ],    \"services\": [ ]  }]" -o create_claim_response.json

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
