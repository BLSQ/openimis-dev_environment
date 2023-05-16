#!/bin/bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

SESSION_DIR="${SCRIPT_DIR}/fhir_mobile_pact_session"
COOKIE_FILE="${SESSION_DIR}/cookie.txt"

[[ ! -d $SESSION_DIR ]] && mkdir "$SESSION_DIR"

[[ -f $COOKIE_FILE ]] && rm "${COOKIE_FILE}"

# Test if the backend is reachable/available

curl -sI "http://localhost/api/" | grep 502 >/dev/null && {
  echo "Backend is not reachable at localhost:80."
  echo "Please check that it is properly running with \`./run.sh status\`. You"
  echo "can run it with \`./run.sh server\`."
  exit 1
}

# login and retrieve JWT
echo "login"
curl -sX POST "http://localhost/api/graphql" \
  -H "accept: application/json" \
  -H "Content-Type: application/json" \
  -c "${COOKIE_FILE}" \
  -d @"${SCRIPT_DIR}/fhir_mobile_pact_files/authenticate.json" >/dev/null

# nothin similar to `claim/Controls`

# https://openimis.atlassian.net/wiki/spaces/OP/pages/1389592716/FHIR+R4+-+Practitioner
# similar to `claim/GetClaimAdmins` (not directly used in claim mobile app)
echo "get practitioners (claim admins)"
curl -sX GET "http://localhost/api/api_fhir_r4/Practitioner/" \
  -H "accept: application/json" \
  -H "Content-Type: application/json" \
  -b "${COOKIE_FILE}" \
  -o "${SESSION_DIR}/claim_admins.json" >/dev/null

# https://openimis.atlassian.net/wiki/spaces/OP/pages/1400012844/FHIR+R4+-+ActivityDefinition
# similar to `claim/GetDiagnosesServicesItems` and partly `claim/GetPaymentLists`

echo "get services (diagnoses services items and payment list)"
curl -sX GET "http://localhost/api/api_fhir_r4/ActivityDefinition/" \
  -H "accept: application/json" \
  -H "Content-Type: application/json" \
  -b "${COOKIE_FILE}" \
  -o "${SESSION_DIR}/claim_services.json" >/dev/null

# https://openimis.atlassian.net/wiki/spaces/OP/pages/1400045588/FHIR+R4+-+Medication
# similar to `claim/GetPaymentLists`

echo "get medications (diagnoses services items and payment list)"
curl -sX GET "http://localhost/api/api_fhir_r4/Medication/" \
  -H "accept: application/json" \
  -H "Content-Type: application/json" \
  -b "${COOKIE_FILE}" \
  -o "${SESSION_DIR}/claim_medications.json" >/dev/null

# https://openimis.atlassian.net/wiki/spaces/OP/pages/1389592652/FHIR+R4+-+ClaimResponse
# similar to `http://localhost/api/claim/GetClaims` list or get on a given id

echo "get claims"
curl -sX GET "http://localhost/api/api_fhir_r4/ClaimResponse/" \
  -H "accept: application/json" \
  -H "Content-Type: application/json" \
  -b "${COOKIE_FILE}" \
  -o "${SESSION_DIR}/claim_responses.json" >/dev/null

# https://www.hl7.org/fhir/organization.html
# to retrieve health facilities (not directly used in claim mobile app)

echo "get organizations (health facilities)"
curl -sX GET "http://localhost/api/api_fhir_r4/Organization/" \
  -H "accept: application/json" \
  -H "Content-Type: application/json" \
  -b "${COOKIE_FILE}" \
  -o "${SESSION_DIR}/claim_organizations.json" >/dev/null

# https://openimis.atlassian.net/wiki/spaces/OP/pages/1389133931/FHIR+R4+-+Patient
# similar to `insuree/{chfid}` but list or direct ID

echo "get patients (insuree)"
curl -sX GET "http://localhost/api/api_fhir_r4/Patient/" \
  -H "accept: application/json" \
  -H "Content-Type: application/json" \
  -b "${COOKIE_FILE}" \
  -o "${SESSION_DIR}/claim_patients.json" >/dev/null

# https://openimis.atlassian.net/wiki/spaces/OP/pages/1389297783/FHIR+R4+-+Coverage
# similar to `insuree/{chfid}/enquire` but list or direct ID

echo "get coverages (enquire)"
curl -sX GET "http://localhost/api/api_fhir_r4/Coverage/" \
  -H "accept: application/json" \
  -H "Content-Type: application/json" \
  -b "${COOKIE_FILE}" \
  -o "${SESSION_DIR}/claim_coverages.json" >/dev/null
